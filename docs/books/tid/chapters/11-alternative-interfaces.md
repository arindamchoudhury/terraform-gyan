# Chapter 11 — Alternative interfaces

> *Source: Hafner (2025), **Terraform in Depth**, Chapter 11, pages 383–425.*
>
> Terraform without Terraform. Three ways out of HCL: **wrap the binary** from another language and consume its machine-readable output (§11.1, three quarters of the chapter, built as a working Python library); **write configuration as JSON** instead of HCL so a program can generate it (§11.2); and **write it in a general-purpose language** and let CDKTF synthesise the JSON for you (§11.3). The chapter's own framing is right: you will not need this often, and when you do, nothing else substitutes for it.
>
> 📌 **Its third section is about a dead project.** CDKTF was **sunset and archived on 10 December 2025** — HashiCorp's own docs say it "is deprecated" and "no longer supports or maintains" it, and the repository README says no further updates, fixes or compatibility work will be made. §11.3 is now history rather than a recommendation, which is a strange kind of vindication for §11.3.1, where the author argues against using it.
>
> ⚠️ **And the chapter does not contain two of the things its introduction promises.** The opening paragraph says it covers "the CDKTF and Pulumi projects" and that "we end the chapter with Terragrunt". **Neither Pulumi nor Terragrunt appears anywhere in it** — it ends at CDKTF and goes straight to the summary. Terragrunt is covered nowhere else in the book either; for that, the path's own material is the substitute.

> 🔗 **See also:** feeds **A3** (the machine-readable UI is what a CI pipeline actually parses), **B4** (`*.tf.json` as a first-class syntax), **E5** (integrating Terraform into your own tooling) and **E1** (§11.3's "write a provider instead" is [Ch12](12-terraform-providers.md)). Builds on [Ch6](06-state-management.md) (`terraform state pull`, and the state JSON this chapter parses) and [Ch5](05-terraform-plan.md) (the plan structure it maps into classes). Every measurement below is on **Terraform 1.15.8** and **OpenTofu 1.12.5**, 2026-08-16.

---

## 11.1 Wrapping Terraform

**There is no Terraform SDK.** No library exposes the engine; the only supported integration point is the CLI. So every tool you have met that "integrates with Terraform" — Terragrunt, Checkov, Trivy, HCP Terraform, Spacelift, Env0, Atlantis — wraps the binary and parses its output. Wrapping means calling the CLI, parsing what comes back, and presenting it as native objects in your language.

!!! warning "Read the licence before you build a product on it"
    The chapter's TIP, and it is the commercially important sentence in the chapter: from **Terraform 1.6** the HashiCorp binary is **BSL 1.1**, not open source, and the licence restricts what you may build around the engine. If you are shipping a product, **OpenTofu's MPL 2.0** is the permissive option. See [[version-facts]] for the licensing timeline.

### 11.1.1 JSON output and machine-readable UI

Two different contracts, and knowing which one a command speaks decides how you consume it.

| | **JSON output format** | **Machine-readable UI** |
| --- | --- | --- |
| Shape | One JSON object | **JSONL** — one JSON object per line |
| Used by | `show`, `validate`, `output` | `plan`, `apply` |
| Why | The command has a single answer | The command runs long and reports as it goes |
| Consumption | Parse once at the end | Parse each line as it arrives |

Both are versioned and documented, and both engines have kept them backward-compatible. The chapter's advice holds: read the current docs when you wrap, because fields get added.

!!! tip "The library in this chapter is real and installable"
    It is [`TerraformInDepth/tofupy`](https://github.com/TerraformInDepth/tofupy), on PyPI as `tofupy`. Useful for a second opinion when a listing looks wrong — though as it turns out, two of the bugs below are in the *published library* too, not just in print.

### 11.1.2 Initial Terraform client

The wrapper's constructor collects what every later command needs: the **working directory** (which defines the configuration), the **binary** (`tofu` or `terraform`), a **log level**, and **environment variables**. It resolves the binary with `shutil.which` and raises immediately if it is absent — fail at construction, not at first command.

```python
class Tofu:
    def __init__(self, cwd=os.getcwd(), binary="tofu", log_level="ERROR", env={}):
        self.binary_path = shutil.which(binary)
        if not self.binary_path:
            raise FileNotFoundError(f"Could not find {binary}, please make sure it is installed.")
```

Then a `CommandResults` dataclass holding `command`, `stdout`, `stderr`, `returncode`, with `.json()`, `.jsonl()` and `.raise_error()` helpers. Keeping the *command string* on the result is the small idea worth stealing — it is what makes the error message useful later.

The runner is the one piece everything else depends on:

```python
def _run(self, args, raise_on_error=True):
    args = [self.binary_path] + [str(x) for x in args]
    results = subprocess.run(
        args, cwd=self.cwd, capture_output=True, encoding="utf-8",
        env={**os.environ, "TF_IN_AUTOMATION": "1", "TF_LOG": self.log_level, **self.env},
        timeout=None,        # a plan or apply can take a very long time
    )
    ...
```

Two environment choices carry real meaning. **`TF_IN_AUTOMATION`** tells the engine no human is present, so it stops printing "next step" advice; **`TF_LOG`** carries the caller's log level. And `timeout=None` is deliberate — a wrapper that times out an apply is worse than one that waits.

The constructor then runs `version -json` and refuses anything that is not major version 1, which is the honest way to express a compatibility promise.

> 💭 (mine): `TF_IN_AUTOMATION` is the same variable **A3** sets in CI. A wrapper library is a CI pipeline that happens to be written in Python — the environment hygiene is identical.

### 11.1.3 Init and 11.1.4 testing

`init` is the first wrapped command, and it introduces the pattern used for all of them: name the **common** options as parameters (`disable_backends` → `-backend=false`, `backend_conf` → `-backend-config`), then add **`extra_args`** so users are never locked out of a flag the author did not anticipate. That escape hatch is the design decision that keeps a wrapper alive across engine releases.

The test setup is worth copying wholesale:

- A **test module built from `terraform_data`** plus one `http` data source, an input variable, an output and a `check` block — every construct the library needs to exercise, at zero cost and near-zero runtime. This is the [Ch9](09-testing-refactoring.md) rule applied to tooling: test your code, and do not pay for real infrastructure to do it.
- A **pytest fixture that copies the module into a fresh temporary directory per test** (`tmpdir` + `copytree`), so tests cannot contaminate each other, plus a second fixture layered on it that runs `init` first. Two fixtures give you both the uninitialised and initialised states, which is exactly what the `validate` tests need.

### 11.1.5 Validating

The measured structure on 1.15.8, from an uninitialised workspace:

```json
{
  "format_version": "1.0",
  "valid": false,
  "error_count": 1,
  "warning_count": 0,
  "diagnostics": [ { "severity": "error", "summary": "…", "detail": "…" } ]
}
```

The wrapper maps this to two dataclasses, `Validate` and `Diagnostic`, using a pattern repeated for every structure in the chapter: **keep the raw `data` on the object** (with `repr=False` so it does not flood the console), declare the mapped fields as `field(init=False)`, and fill them in `__post_init__`. Nested structures get the raw dict passed down and build themselves. It is verbose, and it means a new upstream field costs one line in one place.

```python
def validate(self) -> Validate:
    res = self._run(["validate", "-json"], raise_on_error=False)   # invalid ≠ failed
    return Validate(res.json())
```

`raise_on_error=False` is the subtlety: an invalid configuration exits **1**, but the command did its job. Confirmed — `terraform validate -json` on a configuration with a missing provider exits `1` and still emits a complete JSON document.

!!! danger "⚠️ Listing 11.10's sample output does not match what either engine produces"
    The listing shows the diagnostic as `"summary": "registry.terraform.io/hashicorp/http: there is no package for … cached in .terraform/providers"` with `"detail": ""`. Run on an uninitialised workspace today, both engines say something different:

    ```text
    summary : Missing required provider
    detail  : This configuration requires provider registry.terraform.io/hashicorp/http,
              but that provider isn't available. You may be able to install it automatically…
    ```

    Terraform 1.15.8 and OpenTofu 1.12.5 agree (OpenTofu differs only in the registry host). The book's *tests* four listings later assert `summary == "Missing required provider"` and `"hashicorp/http" in detail` — so **the tests are right and the sample output is stale**; the "no package cached" message belongs to a different failure, an initialised workspace whose provider cache was emptied. The printed JSON also carries trailing commas, so it is not parseable as-is.

### 11.1.6 State

Two ways to read state, and **neither is sufficient alone** — which is the useful finding in this section.

| | `state pull` | `show -json` |
| --- | --- | --- |
| Format | Terraform's internal state representation | Documented machine-readable UI |
| Documented as a stable contract | No | Yes |
| Completeness | Full | Missing fields |
| Input | Reads the backend | Needs a **file** |

Measured on the same workspace, top-level keys:

- `state pull` → `check_results`, `lineage`, `outputs`, `resources`, `serial`, `terraform_version`, `version`
- `show -json` → `format_version`, `terraform_version`, `values`

So `show -json` loses `serial` and `lineage` exactly as the chapter says. The wrapper's answer is to run both: pull the state, write it to a temporary file, `show -json` that file, then hand the parsed result plus the two missing fields to the `State` model.

!!! note "📌 Two corrections to the section's framing"
    **The `.tfstate` extension is not required.** The chapter says `show` "expects the state file to exist as an actual file (including with the appropriate file extension, tfstate)". The file part is true — `show` cannot read stdin. The extension part is not: copying a state file to a name with **no extension at all** and running `terraform show -json <file>` works on 1.15.8, and `tofu show -json` accepts it too. The `suffix=".tfstate"` in the listing is harmless, not load-bearing.

    **`serial` and `lineage` are not the only losses.** `state pull` also carries **`check_results`** — the recorded outcomes of `check` blocks and conditions — which `show -json` omits here. That matters for this very chapter, whose test module includes a `check` block specifically so there is one in state to test against, and whose `State` model then cannot see it.

The `State` → `Module` → `Resource` / `Output` models are a plain recursive mapping. Two details worth keeping: `root_module` may legitimately be **absent** (a new or fully destroyed workspace), and `Module.child_modules` is recursive, so a module builds its children by passing the raw dict down.

!!! danger "⚠️ Listing 11.18 declares `sensitive_values` and never assigns it"
    The `Resource` dataclass lists `sensitive_values: Dict[str, bool] = field(init=False)` among its fields, and `__post_init__` sets eight fields — not that one. With `init=False` and no assignment, the attribute is **never created**, so the first `resource.sensitive_values` raises `AttributeError`.

    The published `tofupy` has the line (`schema.py`, in `Resource.__post_init__`), so this is a listing that dropped it in print. Anyone typing the chapter's code in gets a class that looks complete and fails on the one field that tells you which attributes are secret.

### 11.1.7 Apply, and the event stream

`apply -json` emits JSONL. Every line carries five fields, and the fifth decides what else is present:

| Field | Meaning |
| --- | --- |
| `@level` | `info` normally; `error` / `warn` when something goes wrong |
| `@message` | The human-readable line |
| `@module` | `terraform.ui` or `tofu.ui` — the engine that produced it |
| `@timestamp` | When it happened |
| `type` | **The discriminator.** Determines which extra fields exist |

Confirmed on a real apply: `@level`, `@message`, `@module`, `@timestamp` are the only `@`-prefixed fields, and one replace-in-place run produced this type sequence:

```text
version → refresh_start → refresh_complete → planned_change → change_summary →
outputs → apply_start → apply_complete → apply_start → apply_complete →
change_summary → outputs
```

The wrapper handles three types — `version`, `outputs`, `change_summary` — plus `diagnostic` for errors and warnings, and it exposes **`event_handlers`**, a dict of `type → callable` (plus `"all"`), so a caller can react per event.

!!! danger "⚠️ `_run_stream` does not stream, in the book or in the shipped library"
    The stated purpose of the generator and the handlers is to process events "as they come in instead of having to wait for the command to completely run" — to push them to a log server or a console live. The implementation cannot do that, because it calls **`subprocess.run`**, which blocks until the child process exits and only then returns its captured output. The character-by-character loop then re-splits a string that is already complete.

    Measured with a stand-in that prints one line per second for three seconds, using the listing's own call shape:

    ```text
    subprocess.run returned at t+3.07s
      yielded {"n": 0} at t+3.07s
      yielded {"n": 1} at t+3.07s
      yielded {"n": 2} at t+3.07s
    ```

    Every event arrives after the process is over. Handlers still *fire*, in order, so nothing is lost — but "live progress for a twenty-minute apply" is not what you get, which is the one thing the feature exists for. The published `tofupy` has the same `subprocess.run` call, so it is a design bug rather than a print error. Real streaming needs **`subprocess.Popen`** with the process still running and an iteration over `process.stdout` line by line.

!!! note "📌 `change_summary` arrives twice, and the model keeps only the last"
    An apply that also plans emits **two** `change_summary` events, distinguished by an `operation` field:

    ```json
    {"add":1,"change":0,"import":0,"remove":1,"action_invocation":0,"operation":"plan"}
    {"add":1,"change":0,"import":0,"remove":1,"action_invocation":0,"operation":"apply"}
    ```

    `StreamLog.__post_init__` overwrites `added`/`changed`/`removed`/`operation` on each one, so the apply's numbers win and the plan's are discarded silently. Usually that is what you want; if you are comparing *planned* against *applied* — the thing a deployment gate cares about — the model has already thrown away half the comparison. Note also the newer **`action_invocation`** counter, which the chapter's mapping does not carry.

### 11.1.8 Plan

The hardest wrapper, for three reasons at once: it needs a second command (`show -json` against the saved plan file), it is long-running so it uses the event stream, and the plan structure is the largest in the machine-readable UI.

The method always writes a plan file — into a temporary directory if the caller did not ask for one — because without the file there is no way to get the structured plan. It returns a **tuple** of `(PlanLog, Plan | None)`, with `None` when the plan failed, since a failed plan produces no file.

`ApplyLog` extends `PlanLog` extends `StreamLog`, with the neat justification that an apply without a plan file *does* plan, so every apply log is also a plan log. Distinct classes with no added behaviour, purely so callers can tell them apart.

The `Plan` model splits into metadata (`format_version`, `terraform_version`, `applyable`, `complete`, `errored`, `variables`), the **prior state** (reusing `State`, minus lineage and serial), the **planned values** (reusing `Module`), and the change lists: `resource_changes`, `resource_drift`, `output_changes`, `relevant_attributes`.

The genuinely useful observation is about **`ChangeContainer`**: the plan's per-resource entries are not `change` objects, they are metadata envelopes *containing* a change, and the envelope is not documented as its own structure. Splitting it out into its own class is the right call.

!!! danger "⚠️ `ChangeContainer` sets three fields from the same key — and the shipped library does too"
    ```python
    self.address          = self.data.get("address")
    self.previous_address = self.data.get("address")   # ← should be "previous_address"
    self.module_address   = self.data.get("address")   # ← should be "module_address"
    ```

    Verified in the published `tofupy` (`schema.py`, `ChangeContainer.__post_init__`), so this is not a transcription slip. `previous_address` is precisely the field that tells you a resource was **`moved`**, and `module_address` is how you group changes by module; both silently equal `address` for every change, which means a consumer sees "no resource ever moved" and cannot distinguish module membership. Wrong values that look plausible, in the class most likely to be used for a policy gate.

Alongside it, the chapter's note on `Change` is right and worth remembering: **`before` and `after` are flat attribute maps**, unchanged attributes are omitted, `before_sensitive` / `after_sensitive` mark what must not be printed, `after_unknown` lists what is only known after apply, and `actions` is a **list** because a replacement is a delete *and* a create. The author also flags that the published documentation for this structure describes something more complex that only applies to state — a caveat worth carrying into any plan parser.

### 11.1.9–11.1.10 Output, and what it is all for

`output` is four lines, because `Output` already exists — the payoff for having modelled the small structures first.

The closing example is the point of the section: a ~30-line CLI (`typer` + `tofupy`) that runs `init`, runs `plan`, walks `plan.resource_changes`, and flags any `aws_vpc_security_group_ingress_rule` whose planned `cidr_ipv4` is `0.0.0.0/0`. That is a **plan-time policy gate in a general-purpose language**, and it is the honest answer to "why would I wrap the CLI": Checkov and Trivy are this, with more rules.

> ⚠️ Listing 11.30 has a scope slip of its own — inside the loop it binds `change_container` but then reads `change.after["cidr_ipv4"]`, a name that is never defined. It should be `change_container.change.after`, which the line directly above it uses correctly.

---

## 11.2 Using JSON instead of HCL

HCL is for humans; **JSON is for programs**. Terraform accepts both, in the same directory, mixed freely — the same blocks expressed as a single JSON object per file.

Why generate configuration at all? The chapter's three cases: a diagram-to-infrastructure tool, an existing-infrastructure-to-Terraform importer, and a front end that lets another language define infrastructure without building an engine (which is exactly §11.3).

### 11.2.1 JSON structure

- Filename ends **`.tf.json`** (or `.tofu.json` under OpenTofu's shadowing rules from [Ch10 §10.7](10-advanced-topics.md#107-opentofu-and-terraform-compatibility)).
- Each file is **one JSON object**; top-level keys are block types: `resource`, `data`, `variable`, `output`, `locals`, `module`, `provider`, `terraform`.
- Nesting replaces block labels: `resource` → type → name → arguments.

```json
{
  "variable": { "website": { "type": "string", "default": "https://catfact.ninja/fact" } },
  "resource": { "terraform_data": { "main": { "input": "${var.website}" } } },
  "output":   { "site_data": { "value": "${resource.terraform_data.main.output}" } }
}
```

!!! note "📌 That `resource.` prefix is valid, and I did not expect it to be"
    `"${resource.terraform_data.main.output}"` looks like a mistake — nobody writes `resource.` in HCL. It is legal: applied on 1.15.8, the output resolved to the resource's real value. It is the explicit form of a managed-resource reference, the counterpart to `data.`, and it exists so a resource type can never be shadowed by something else in scope. Harmless in a generator, and unnecessary.

**Blocks that may repeat with the same name become a list.** `provider` is the case that bites, since aliases mean two `aws` blocks:

```json
{ "provider": { "aws": [ { "region": "us-east-1" }, { "alias": "backups", "region": "us-west-2" } ] } }
```

The chapter's rule is the safe one: use the list form even when there is only one block.

### 11.2.2 Expressions and keywords

JSON has no expressions, so **everything expression-shaped becomes a string template**. Interpolation, function calls, and even the directive form for conditionals:

```json
{ "locals": { "config": "%{ if var.option == null }default%{ else }${var.option}%{ endif }" } }
```

This is the section's real lesson, and it is a limitation to design around rather than fight: **logic in JSON configuration only produces strings**. A ternary whose arms are booleans or numbers has nowhere to live. A generator should compute in its own language and emit settled values, using templates only where a reference genuinely must be resolved by Terraform.

Keyword-style arguments follow the same rule — `depends_on` and `provider` take resource addresses **as quoted strings**, since JSON has no bare identifiers.

> ⚠️ Listing 11.35 prints `"${upper(var.config})"` — the parenthesis and brace are transposed. It should be `"${upper(var.config)}"`.

### 11.2.3 Comments

JSON has no comments, so Terraform accepts a **`"//"` key** in any object, at any level, with any string value. Confirmed working at top level and inside a resource object on 1.15.8.

```json
{
  "//": "Generated file — do not edit by hand.",
  "resource": { "terraform_data": { "main": { "//": "generated at example.py:38", "input": "…" } } }
}
```

Both uses are worth adopting in a generator: a header saying *do not hand-edit*, and per-object provenance saying which line of which program produced this.

!!! danger "⚠️ Listing 11.38 uses “resources”, and the file will not load"
    The comments listing pluralises the top-level key. Run as printed on 1.15.8:

    ```text
    Error: Extraneous JSON object property
      on main.tf.json line 3:
       3:   "resources": {
    No argument or block type is named "resources". Did you mean "resource"?
    ```

    The prose immediately above it also says "you instead create an object under the resources key" — same slip. Every other listing in the section uses the correct singular `resource`.

---

## 11.3 Cloud Development Kit for Terraform

!!! danger "⚠️ CDKTF is deprecated — sunset and archived 10 December 2025"
    HashiCorp's documentation states it "is deprecated as of December 10, 2025" and that they "no longer support or maintain" it; the repository README says the project sunsets and is archived on that date, with **no further updates, fixes, or compatibility work** — including compatibility with future Terraform releases. The code stays on GitHub, read-only.

    Read §11.3 as background, not as an option to evaluate. The irony is that §11.3.1 already advised against adopting it, so the chapter's *recommendation* has aged better than its subject.

**What it was:** a HashiCorp framework letting you define infrastructure in **TypeScript, Python, Java, C# or Go**, which it then **synthesised into Terraform JSON** — the §11.2 format — and handed to Terraform. Terraform-only; it never supported OpenTofu.

Its structure was three layers:

- **Resources** — one object per resource or data source, first argument the enclosing scope, second a stack-unique id, then the arguments.
- **Stacks** — classes extending `TerraformStack`, each corresponding to a root module with **its own state**.
- **Apps** — a collection of stacks, and the layer with no Terraform equivalent. `app.synth()` was what actually produced configuration; a stack not registered with the app simply did not exist.

The cycle was `cdktf init` → write code → `cdktf synth` → `cdktf deploy <stack>` → `cdktf destroy <stack>`, with `synth` re-run automatically unless `-skip-synth` was passed.

Two things from this section stay useful after the deprecation:

- **§11.3.1's argument, which generalises well beyond CDKTF.** The pitch was "teams should not have to learn another language". The counter is that the language is the small part: *"most of learning Terraform is not about the language but about the concepts around IaC"* — CI/CD for infrastructure, state, testing pitfalls — none of which changes by writing TypeScript. The book's own shape is the evidence, one third language and two thirds practice. The narrow case where it *was* justified is telling: not teams managing infrastructure, but **products that generate infrastructure** for someone else.
- **The abstraction-layer picture.** Language → CDKTF → JSON → Terraform → gRPC → provider. Same argument as [Ch10 §10.8.1](10-advanced-topics.md#1081-kubernetes) makes against Terraform-over-Kubernetes: every layer is another place a bug can hide and another thing to debug through.

> ⚠️ One operational trap the chapter records, now of historical interest: `cdktf synth --hcl` emits HCL **alongside** the JSON, and Terraform then reads both and errors on duplicate blocks. The fix was deleting `cdktf.out` before deploying.

---

## Summary

- **There is no Terraform SDK.** Every integration wraps the CLI — that is the supported path, not a hack, and the engines are built for it.
- **Two machine contracts, not one.** Single-answer commands (`show`, `validate`, `output`) return one JSON object; long-running ones (`plan`, `apply`) stream JSONL where the `type` field decides what else the line contains.
- **`show -json` is the documented view of state, and it is lossy** — no `serial`, no `lineage`, no `check_results`. Combine it with `state pull`, which is complete but undocumented as a contract.
- **Wrap with an escape hatch.** Name the common flags, then pass `extra_args` through, or your library expires at the next engine release.
- **The reason to do any of this** is a policy or cost gate that reads the plan in your own language — thirty lines gets you the shape of Checkov.
- **JSON configuration is for generators.** `.tf.json`, one object per file, list form for repeatable blocks, string templates for every expression, `"//"` for provenance — and accept that logic in JSON only ever produces strings.
- **CDKTF is over.** Deprecated December 2025; the chapter's own scepticism about it is the part worth keeping.
- **Verify listings before typing them.** In this chapter alone: a wrong sample output, a dropped assignment, an undefined variable, a transposed paren, a pluralised key that will not parse, a stream that does not stream, and a triple copy-paste that silently blanks `previous_address`.

---

## References

- `tofupy` — <https://github.com/TerraformInDepth/tofupy> (the chapter's library, on PyPI as `tofupy`)
- Terraform JSON output format — <https://developer.hashicorp.com/terraform/internals/json-format>
- Machine-readable UI — <https://developer.hashicorp.com/terraform/internals/machine-readable-ui>
- JSON configuration syntax — <https://developer.hashicorp.com/terraform/language/syntax/json>
- CDKTF (deprecated) — <https://developer.hashicorp.com/terraform/cdktf> · <https://github.com/hashicorp/terraform-cdk>
- Typer, used for the scanner CLI — <https://typer.tiangolo.com/>
- Licensing and engine version state — [[version-facts]]
