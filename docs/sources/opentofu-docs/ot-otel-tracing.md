# OpenTelemetry Tracing (OpenTofu)

> **Source:** [opentofu.org/docs/internals/tracing](https://opentofu.org/docs/internals/tracing/)
> **Added:** 2026-08-15
> **Source updated:** OpenTofu current docs (feature introduced in **1.10.0**)
> **Tags:** opentofu, observability, opentelemetry, otel, tracing, performance, debugging, divergence
> **Type:** documentation

OpenTofu 1.10.0 added OpenTelemetry (OTel) tracing over its internal operations. The stated purpose is debugging performance problems, understanding operation flow, and optimising workflows. Terraform's open-source CLI has an equivalent hook but no docs and far fewer spans, so this is a practical divergence for the **E3** and **E5** milestones. See [[otel-tracing-facts]] for the side-by-side.

!!! warning "Experimental feature"
    The docs page carries an explicit *Experimental Feature* banner: tracing support “is experimental and may change in future releases”. The source comment is stronger — “BEWARE! This is not a committed external interface… This mechanism might be removed altogether” (`internal/tracing/init.go`).

## Privacy and security

The page leads with privacy, not features. Four claims:

- **Opt-in only.** Tracing is completely disabled by default.
- **Local-only.** No telemetry goes to OpenTofu or any external service unless you configure it.
- **Your infrastructure.** You choose where traces are sent, using standard OpenTelemetry configuration.
- **Zero overhead.** When disabled, tracing has no performance impact.

The framing is deliberate. The docs quote the team: this builds on a project named Open*Telemetry*, but it is added “for you to trace *your application* using *your tooling* on *your infrastructure*”. It is not usage analytics about OpenTofu itself.

## Quick start

**1. Run a tracing backend.** The docs use Jaeger.

```bash
docker run -d --rm --name jaeger \
  -p 16686:16686 \
  -p 4317:4317 \
  -p 4318:4318 \
  jaegertracing/jaeger:latest
```

**2. Configure OpenTofu.**

```bash
# Enable OTLP trace exporter
export OTEL_TRACES_EXPORTER=otlp

# Point to your Jaeger instance
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318

# Required for local development (skip TLS verification)
export OTEL_EXPORTER_OTLP_INSECURE=true
```

**3. Run any command.**

```bash
tofu init    # Traces provider downloads
tofu plan    # Traces planning operations
tofu apply   # Traces apply workflow
```

**4. View traces** at <http://localhost:16686>.

## Configuration options

| Variable | Description | Example |
|---|---|---|
| `OTEL_TRACES_EXPORTER` | Must be set to `otlp` to enable tracing | `otlp` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP endpoint URL | `http://localhost:4317` |
| `OTEL_EXPORTER_OTLP_INSECURE` | Skip TLS verification | `true` for local dev |

The page then defers to the [OTLP exporter spec](https://opentelemetry.io/docs/specs/otel/protocol/exporter/#configuration-options) for everything else, because OpenTofu delegates configuration wholesale to the OTel `autoexport` helper.

!!! warning "The two port numbers in this page disagree, and the difference matters"
    The quick start sets the endpoint to port **4318**, but the table's example says **4317**. Those are different protocols: 4318 is OTLP over HTTP, 4317 is OTLP over gRPC. OpenTofu builds its exporter with `go.opentelemetry.io/contrib/exporters/autoexport`, whose documented default for `OTEL_EXPORTER_OTLP_PROTOCOL` is **`http/protobuf`**. So the quick start works as written, and copying the table's `4317` without also setting `OTEL_EXPORTER_OTLP_PROTOCOL=grpc` sends HTTP at a gRPC port. Verified against `pkg.go.dev/go.opentelemetry.io/contrib/exporters/autoexport` (module version pinned in OpenTofu's `go.mod`: `v0.67.0`), 2026-08-15.

!!! note "Sampling is not configurable"
    Quoted from the page: in this experimental implementation OpenTofu **always samples 100%** of traces when tracing is enabled. Confirmed in source — the tracer provider is built with `sdktrace.AlwaysSample()`.

## Integration with observability platforms

Jaeger is the getting-started backend. Any OTLP-compatible backend works, and the page names Grafana Tempo, AWS X-Ray, and Datadog.

## Use cases the page claims

**Debugging slow operations**

- Which provider downloads are slowest?
- How long does each resource take to plan/apply?
- Where is time spent during initialisation?

**CI/CD pipeline optimisation**

- Parallel operation conflicts
- Cache effectiveness
- Network latency issues
- Lock contention problems

**Multi-environment deployments**

- Compare performance across different backends
- Identify region-specific delays
- Track provider version update impacts

## Future development

The team asks for feedback on which additional operations should be traced, real-world performance impact, backend integration experience, and use cases that benefit. Feedback goes to GitHub issues or the OpenTofu Slack.

## What the docs leave out

The page never lists the spans, the span attributes, or three of the environment variables that the implementation reads. All of the following comes from the OpenTofu source, version-gated with `git tag --contains`.

**Undocumented environment variables**

| Variable | Effect | Since |
|---|---|---|
| `TRACEPARENT` | W3C trace context of the calling process. When set, OpenTofu extracts it and parents its spans under the caller's trace, so a `tofu apply` appears inside the CI pipeline's trace. | 1.10.0 (`19afe5ffbb`) |
| `TRACESTATE` | Companion vendor state for `TRACEPARENT`; only read when `TRACEPARENT` is set. | 1.10.0 (`19afe5ffbb`) |
| `OTEL_SERVICE_NAME` | Overrides the reported service name. Default is `OpenTofu CLI`. | 1.11.0 (`a9751ee2b6`) |

`TRACEPARENT` is the one worth knowing. It is exactly the feature Terraform's CLI still lacks, and it is what turns per-run traces into one pipeline-wide trace.

**Span coverage, by phase** (all present since 1.10.0 unless noted)

- **Commands.** `Init`, `Get`, `Import`, `Show`, `Login`, `Logout`, `Unlock`, `Providers lock` — one root-ish span per command.
- **Init internals.** `Backend init`, `Cloud backend init`, `Get Modules`, `Get Providers`, `From module`, plus registry calls (`List Versions`, `Find Module Location`, `Fetch Package`), installer spans (`Install Providers`, `Install Registry Module`, `Install Local Module`), archive handling (`Install (http)`, `Decompress (local archive)`), OCI getters, and `Save lockfile`.
- **Graph phases.** `Validation phase`, `Plan phase`, `Apply phase`. The plan span carries `opentofu.plan.mode`, `opentofu.plan.target_addrs`, `opentofu.plan.exclude_addrs`, and `opentofu.plan.force_replace_addrs` — chosen because they change how much provider work the phase does. The apply span carries `opentofu.plan.mode`.
- **Per graph node** (commit `914f51ed5f`, first released in 1.10.0). `Plan resource instance changes` and `Apply resource instance changes` per instance, plus destroy, orphan, deposed, and `Validate resource configuration` nodes, and provider-level `Validate provider configuration` and `Configure provider`.

**Span attributes worth filtering on**

`opentofu.resource_instance.address`, `opentofu.resource.address`, `opentofu.resource.type`, `opentofu.provider.source`, `opentofu.provider_config.address`, `opentofu.provider_instance.address`, `opentofu.plan.refresh`, `opentofu.plan.plan_changes`.

The per-instance spans are what make the “which resource is slow” question answerable. Terraform's CLI has no equivalent for its graph walk.

**Already merged for 1.13** (from `origin/main`'s CHANGELOG, unreleased as of 2026-08-15)

- `local-exec` sets `TRACEPARENT` in child processes when tracing is active, so a provisioner script continues the run's trace instead of starting its own.
- OpenTelemetry library logs are copied into the `TF_LOG` debug stream. Today a misconfigured exporter is close to silent, so this is the debugging story for tracing itself.
- Fix: the `TRACESTATE` log line printed the `TRACEPARENT` value. Cosmetic, and visible in 1.12.4's `internal/tracing/init.go`.

!!! tip "Pairs with `TOFU_CPU_PROFILE`"
    OpenTofu's environment-variable docs point at `TOFU_CPU_PROFILE`, which writes a Go pprof file, and say it “pairs well with the more granular and well structured OpenTelemetry tracing (available in OpenTofu 1.10.0)”. Tracing tells you *which* resource or provider is slow; pprof tells you *where in the code* the time went. `TOFU_CPU_PROFILE` is also outside the compatibility promise.

    ```shell
    TOFU_CPU_PROFILE=./tofu.pprof tofu plan
    go tool pprof -http ./tofu.pprof
    ```

---
Related: [[otel-tracing-facts]] — the cross-tool comparison this note feeds, covering Terraform CLI's undocumented equivalent and HCP Terraform agent telemetry. [[ot-dependency-lock]] and [[ot-exclude-flag]] — sibling OpenTofu divergences for the same E3 milestone.
