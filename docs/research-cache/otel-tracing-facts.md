# Terraform / OpenTofu observability with OpenTelemetry — verified facts

**Checked:** 2026-08-15
**Verified against:** `hashicorp/terraform` at `b9e178decf` (“Prepare before 1.15.8 release”), `opentofu/opentofu` at `d529119038` (v1.12.4), the OpenTofu docs, and HCP Terraform cloud-docs.

Scope: **observability *of* Terraform/OpenTofu runs** — emitting traces and metrics about plan/apply themselves. Using Terraform *to deploy* an observability stack (an OTel Collector, Grafana, alert rules via providers) is a different subject and is not covered here.

There are three separate mechanisms, and they do not overlap:

| Layer | Signal | Enabled by | Documented? | Status |
|---|---|---|---|---|
| Terraform CLI | traces (OTLP) | `OTEL_TRACES_EXPORTER=otlp` | **No** — nothing on developer.hashicorp.com | experimental, uncommitted interface |
| OpenTofu CLI | traces (OTLP) | `OTEL_TRACES_EXPORTER=otlp` | Yes — `/docs/internals/tracing` | experimental, since 1.10.0 |
| HCP Terraform agent | traces **and** metrics (OTLP) | `-otlp-address` / `TFC_AGENT_OTLP_ADDRESS` | Yes — cloud-docs | supported product feature |

## 1. Terraform CLI (undocumented, experimental)

- Set `OTEL_TRACES_EXPORTER=otlp` and Terraform enables an OTLP trace exporter. Every other knob is the standard OTLP env-var set, handled by `go.opentelemetry.io/contrib/exporters/autoexport`.
- Source: `telemetry.go` at repo root. The comment is explicit: “BEWARE! This is not a committed external interface… This mechanism might be removed altogether if a different strategy seems better based on experience with this experiment.”
- **No docs page exists.** A grep of `website/` in the Terraform repo for `OTEL_TRACES_EXPORTER` or `opentelemetry` returns nothing. The only public description is the source comment and community threads.
- **Span coverage is thin.** Outside the Stacks runtime there are only ~10 span sites, all in `main`, `checkpoint.go`, and `internal/command`:
    - root span named `terraform <args>` (`main.go`)
    - `HashiCorp Checkpoint`
    - `install modules`, `install providers`, `install providers for state store`, `initialize backend`, `initialize HCP Terraform`, `initialize directory from module`, `-from-module=...`
- **The graph walk is not traced at all.** No per-resource, per-provider, plan-phase or apply-phase spans exist in `internal/terraform`. A trace of `terraform apply` tells you nothing about which resource was slow. This is the single biggest gap versus OpenTofu.
- **Stacks is the exception.** `internal/stacks/stackruntime`, `internal/rpcapi`, and `internal/promising` are instrumented (`planning`, `applying`, per-object `… planning` / `… apply` / `apply-time checks`, `validate stack configuration`). That path is driven over the RPC API by HCP Terraform, not by the CLI's own plan/apply.
- **Exporter is a `SimpleSpanProcessor`** — every span is exported synchronously as it ends, with no batching. OpenTofu batches instead. On a large run this is a real cost, not a theoretical one.
- **`TRACEPARENT` is not honoured.** `telemetry.go` sets a `TraceContext`+`Baggage` propagator but never extracts trace context from the environment, so CLI spans always start a fresh trace and cannot be nested under a CI pipeline's trace. Feature request [hashicorp/terraform#35444](https://github.com/hashicorp/terraform/issues/35444) has been **open since 2024-07-10**.
- Service name is hardcoded to `Terraform CLI`; `OTEL_SERVICE_NAME` is ignored. Resource attributes are just service name and version, at semconv `v1.4.0`.

!!! danger "The root span name contains the full command line"
    Terraform names its root span `fmt.Sprintf("terraform %s", displayArgs)` from `shquot.POSIXShellSplit(os.Args)`. Anything passed on the command line ends up in the span name and therefore in the tracing backend, including `-var="password=…"`. OpenTofu avoids this — its root span is named simply `tofu`.

## 2. OpenTofu CLI (documented, experimental, since 1.10.0)

Full note: [[ot-otel-tracing]]. The facts worth carrying:

- Same activation (`OTEL_TRACES_EXPORTER=otlp`), same `autoexport` delegation, same “not a committed interface” warning in source.
- **Instrumented end to end**: commands, module/provider installation, registry and OCI fetches, lock-file writes, then `Validation phase` / `Plan phase` / `Apply phase`, then **one span per graph node** (`Plan resource instance changes`, `Apply resource instance changes`, destroy/orphan/deposed variants, `Validate provider configuration`, `Configure provider`).
- Spans carry `opentofu.resource_instance.address`, `opentofu.resource.type`, `opentofu.provider.source`, `opentofu.plan.mode`, `opentofu.plan.target_addrs`, `opentofu.plan.exclude_addrs`, `opentofu.plan.force_replace_addrs`, `opentofu.plan.refresh`, `opentofu.plan.plan_changes`.
- Reads **`TRACEPARENT`** and `TRACESTATE` (1.10.0), so a run nests under the pipeline trace that invoked it. Reads **`OTEL_SERVICE_NAME`** (1.11.0), defaulting to `OpenTofu CLI`.
- Batching exporter with a 5-second `ForceFlush` on exit; sampling is fixed at `AlwaysSample()` and not configurable.
- Version gate (`git tag --contains`): init spans, graph-node spans, and `TRACEPARENT` support are all first released in **v1.10.0**; `OTEL_SERVICE_NAME` first in **v1.11.0**.
- **Coming in 1.13** (verified in `origin/main`'s CHANGELOG, unreleased as of 2026-08-15): `local-exec` **propagates `TRACEPARENT` into child processes** when tracing is active, so a provisioner's script can continue the trace; OpenTelemetry library logs are copied into the `TF_LOG` debug stream, which is how you debug a silent exporter; and a logging bug is fixed where the `TRACESTATE` message printed the `TRACEPARENT` value instead (visible in 1.12.4's `internal/tracing/init.go`, cosmetic only).

## 3. HCP Terraform agents (supported, traces + metrics)

Source: [cloud-docs/agents/telemetry](https://developer.hashicorp.com/terraform/cloud-docs/agents/telemetry), [/tracing](https://developer.hashicorp.com/terraform/cloud-docs/agents/tracing), [/metrics](https://developer.hashicorp.com/terraform/cloud-docs/agents/metrics).

- The agent is “a simple producer of telemetry data” and relies on an **OpenTelemetry Collector** for aggregation, post-processing, and export. Point it at one with `-otlp-address` / `TFC_AGENT_OTLP_ADDRESS` (a `host:port` gRPC collector). `-otlp-cert-file` / `TFC_AGENT_OTLP_CERT_FILE` encrypts that connection; without it the connection is unsecured.
- Use the **`contrib`** collector distribution (`otel/opentelemetry-collector-contrib`), not `core`. Documented compatibility: agent `>= 0.1.12, <= 1.7.0` with collector `<= 0.42.0`; agent `>= 1.7.1` tested up to collector `0.73.0`. A DataDog agent can be targeted directly instead of a collector, over OTLP gRPC.
- **Traces:** spans are named in plain English (“writing a file”, “downloading an artifact”) and are deliberately *not* enumerated in the docs. Attributes use letters/numbers/underscores, sometimes dots for structure; the `debug` namespace carries scope-specific detail.
- **Metrics:** prefixed `tfc-agent.`, unit as the final component (`.bytes`, `.milliseconds`), underscores between words over OTLP. Families: `tfc-agent.core.*` (`status.busy`, `status.idle`, `register.milliseconds`, `fetch_job.milliseconds`, `update_status.milliseconds`), `tfc-agent.core.runtime.*` (Go heap, GC, goroutines, uptime), `tfc-agent.core.profiler.*` (CPU %, memory, I/O while busy), `tfc-agent.core.terraform.*` (30+ metrics over init/plan/apply/output-streaming/provider-schema), `tfc-agent.core.policy.*` (~13 OPA/Sentinel metrics, **Premium only**).
- Telemetry attributes: global (`agent_id`, `agent_name`, `agent_version`, `agent_pool_id`), per-run (`organization_name`, `run_id`, `run_operation`, `workspace_name`), policy (`policy_evaluation_id`).
- This is the only one of the three that emits **metrics**. Neither CLI does.

## Gotchas that apply to both CLIs

- **Port/protocol mismatch.** `autoexport`'s default `OTEL_EXPORTER_OTLP_PROTOCOL` is **`http/protobuf`**, i.e. port **4318**. Setting `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317` without also setting `OTEL_EXPORTER_OTLP_PROTOCOL=grpc` points HTTP at a gRPC port. The OpenTofu docs page contains both numbers in different sections, which is how people hit this.
- **A broken exporter fails the command.** Both binaries exit **1** with “Could not initialize telemetry: …” if the exporter cannot be constructed while `OTEL_TRACES_EXPORTER=otlp` is set. Exporting that variable globally in CI means a collector outage breaks `plan`, not just tracing.
- **Providers emit nothing.** Spans stop at the plugin boundary. Time attributed to a resource span is time spent in the provider RPC, with no breakdown of the provider's own API calls.
- **No metrics, no logs.** Both CLIs export traces only. `TF_LOG` / `TOFU_LOG` remain the logging story.

## Practical recipes

**Local Jaeger, one command** (works for both; swap `tofu` for `terraform`):

```bash
docker run -d --rm --name jaeger -p 16686:16686 -p 4317:4317 -p 4318:4318 jaegertracing/jaeger:latest
export OTEL_TRACES_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export OTEL_EXPORTER_OTLP_INSECURE=true
tofu plan
# open http://localhost:16686
```

**Nest a run inside a CI pipeline trace (OpenTofu only):** have the pipeline export `TRACEPARENT` in W3C format before invoking `tofu`, and every span from that run parents under the pipeline span. On Terraform this silently does nothing.

Sources: [OpenTofu — OpenTelemetry Tracing](https://opentofu.org/docs/internals/tracing/), Terraform source `telemetry.go` + `main.go` + `internal/command/*`, OpenTofu source `internal/tracing/*` + `internal/tofu/*`, [hashicorp/terraform#35444](https://github.com/hashicorp/terraform/issues/35444), [HCP Terraform agent telemetry](https://developer.hashicorp.com/terraform/cloud-docs/agents/telemetry), [agent tracing](https://developer.hashicorp.com/terraform/cloud-docs/agents/tracing), [agent metrics](https://developer.hashicorp.com/terraform/cloud-docs/agents/metrics), [autoexport package docs](https://pkg.go.dev/go.opentelemetry.io/contrib/exporters/autoexport).
