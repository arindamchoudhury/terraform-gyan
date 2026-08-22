# Chapter 9 — How to Test Terraform Code

> *Source: Brikman (2022), **Terraform: Up & Running**, 3rd ed., Chapter 9, pages 315–374.*
>
> Sixty pages, the longest chapter in the book, and the one it warns you about in a callout: *"Writing automated tests for infrastructure code is not for the faint of heart."* It builds every idea twice — first in Ruby, where testing is easy, then in Terraform, where it is not — and arrives at five numbered takeaways plus a survey of static analysis, plan testing and server testing.
>
> 📌 **Notes adapted where version-bound.** Book written 2022 against Terraform ~1.2 and Terratest v0.39.0; current stable is **1.15.8** / OpenTofu **1.12.5** ([[version-facts]]), Terratest **v1.0.1** with a v2 beta. **The chapter predates Terraform's own test framework entirely.** `terraform test` went GA in **1.6.0** and mock providers landed in **1.7.0**, which qualifies the chapter's third takeaway and re-frames the whole "you must write Go" premise. Every Terratest function it calls is now deprecated in favour of a context-taking form. Details under [Version reckoning](#version-reckoning).

> 🔗 **See also:** [Testing](../../../topics/testing.md), which synthesizes this chapter with TID Ch9 and the two framework research notes.

---

## The framing

The chapter opens on fear — of downtime, data loss, breaches — and the observation that the common response makes things worse: deploy less often, so each deployment is bigger and more likely to break.

The goal it sets is deliberately modest:

> The goal of testing is to give you the confidence to make changes.

No test proves absence of bugs. If the whole infrastructure and deployment process is code, and that code works in a pre-production environment, there is a *high probability* it works in production. The chapter is explicit that this is a game of probability, which is what makes the arithmetic later in the chapter land.

## 1. Manual tests

The Ruby comparison is the device the chapter uses throughout. A Ruby web server can be started on `localhost:8000` and poked with `curl`. What is the equivalent for a module that creates an ALB, target groups, listeners and security groups?

!!! danger "Key testing takeaway #1: when testing Terraform code, you can't use localhost"
    You cannot run an AWS ALB on your laptop, and this applies to most IaC tools rather than just Terraform. The only practical manual test is deploying to a real environment. Which means: **the `terraform apply` / `terraform destroy` loop you have been running all book *is* the manual testing story.**

This is the payoff for Chapter 8's `examples` folder convention. The easiest way to manually test `modules/networking/alb` is to apply `examples/alb` and `curl` the resulting DNS name:

```bash
curl -s -o /dev/null -w "%{http_code}" \
  hello-world-stage-477699288.us-east-2.elb.amazonaws.com
# 404
```

!!! note "Validation is infrastructure-specific; the structure is not"
    The chapter uses `curl` because it is testing a load balancer. A MySQL module needs a MySQL client, a VPN server needs a VPN client, and a server listening for nothing at all may need an SSH session running commands locally. **The test skeleton in this chapter works for any infrastructure; only the validation step changes.**

Two things every developer therefore needs: good example code, and a real deployment environment that plays the part of localhost. Because manual testing means creating and destroying a lot of infrastructure and making a lot of mistakes, that environment has to be isolated from staging and production.

The recommendation, and its gold standard:

- Every team has an isolated **sandbox environment**.
- The gold standard is **one sandbox per developer** — on AWS, a separate account each, which costs nothing extra and rolls up billing through AWS Organizations.

!!! warning "Key testing takeaway #2: regularly clean up your sandbox environments"
    Sandboxes fill with orphaned infrastructure and the bill grows. At minimum, build a culture where people `terraform destroy` what they deploy. Better, run a scheduled job: the chapter's pattern is `cloud-nuke` as a daily cron in each sandbox, deleting anything older than 48 hours on the assumption that manual-test infrastructure is dead after two days.

    ```bash
    cloud-nuke aws --older-than 48h
    ```

## 2. Automated tests

Three kinds, defined generically before being translated:

| Type | Scope | Dependencies |
| --- | --- | --- |
| **Unit** | one small unit — a function or class | external dependencies replaced with test doubles or mocks |
| **Integration** | several units working together | a mix of real and mocked |
| **End-to-end** | the whole architecture, from the user's perspective | all real, in a production-like shape |

The reason to use all three: units working in isolation do not imply they work combined, and parts working combined do not imply the system works deployed. Each catches bugs the others cannot.

### Unit tests

The Ruby half is a lesson in testability. A `do_GET` method that takes `HTTPRequest` and mutates `HTTPResponse` is hard to test, and **difficulty writing a unit test is treated as a code smell**. Extracting a `Handlers` class fixes it, and the chapter names the two properties that made the difference:

- **Simple values as inputs** — a path string, not an `HTTPServer`.
- **Simple values as outputs** — return a `[status, content_type, body]` array instead of mutating a response object.

Then the translation, which is the chapter's most-quoted line:

!!! danger "Key testing takeaway #3: you cannot do pure unit testing for Terraform code"
    Refactoring away external dependencies is what made the Ruby code testable. But Terraform code is *99% calls to complicated dependencies* — remove them and there is no code left to test.

    So **unit tests for Terraform are really integration tests**. The chapter keeps calling them unit tests anyway, to emphasise that the point is testing a *single unit* (one reusable module) for the fastest possible feedback.

    Its footnote pre-empts the obvious objection: yes, you can point provider endpoints at a mocking tool like LocalStack, but most Terraform code makes hundreds of different API calls, mocking all of them is impractical, and even if you did, *"it's not clear that the resulting unit test can give you much confidence"* — a successful apply against mock ASG and ALB endpoints says nothing about whether a working app would have come up.

The strategy that replaces pure unit testing is just manual testing written down:

1. Create a small, standalone module.
2. Create an easy-to-deploy example for it.
3. `terraform apply` the example into a real environment.
4. Validate it works — the step that differs per infrastructure type.
5. `terraform destroy` at the end.

> 💭 (mine): the mental model the chapter offers for writing any infrastructure test is the useful part. Ask *"how would I have tested this manually to be confident it works?"*, then write that down as code.

#### The ALB test, built up one line at a time

Tests are Go, using **Terratest**, chosen because it has first-class support for exactly that apply/validate/destroy shape. Setup is three steps: install Go, make a `test` folder, `go mod init <NAME>`.

The finished test, with the parts that matter:

```go
func TestAlbExample(t *testing.T) {
    opts := &terraform.Options{
        TerraformDir: "../examples/alb",
    }

    // Clean up everything at the end of the test
    defer terraform.Destroy(t, opts)

    terraform.InitAndApply(t, opts)

    albDnsName := terraform.OutputRequired(t, opts, "alb_dns_name")
    url := fmt.Sprintf("http://%s", albDnsName)

    http_helper.HttpGetWithRetry(t, url, nil, 404, "404: page not found",
        10, 10*time.Second)
}
```

Four details worth keeping:

- **You test the example, not the module.** `TerraformDir` points at `examples/alb`, which is why Chapter 8 insisted every module ship one.
- **`OutputRequired`** fails the test if the output is missing or empty, which is how the test gets the ALB's DNS name.
- **Retries are not optional.** There is always a gap between `apply` finishing and infrastructure actually being ready — health checks passing, DNS propagating — and you cannot know how long. `HttpGetWithRetry` retries until the expected status and body appear or the budget runs out.
- **`defer` goes early, before `InitAndApply`.** Go runs deferred calls when the surrounding function returns, however it returns, so this is the `try`/`finally` that guarantees `destroy` runs even when a validation fails. Put it after the apply and a failure in between leaks infrastructure.

```bash
go test -v -timeout 30m
```

!!! warning "`-timeout 30m` is not decoration"
    Go kills a test run after **10 minutes** by default, and a killed run never reaches the deferred `terraform destroy` — so the failure mode is a failed test *and* leaked infrastructure. Always set a generous timeout for tests that deploy real resources.

The ALB test takes about five minutes. The chapter's honest framing: nowhere near Ruby's 0.0005 seconds, but about as fast a feedback loop as AWS allows.

> 💡 **Tip** — automated tests deserve their own AWS account, separate even from the per-developer sandboxes. A test suite may create thousands of resources, and a dedicated account means you can safely delete anything more than a few hours old.

#### Dependency injection

The second Ruby lesson. A `/web-service` endpoint calling `example.org` directly makes tests hostage to someone else's uptime, someone else's response body, someone else's latency, and leaves no way to exercise corner cases. Extracting a `WebService` class and passing it in lets tests inject a `MockWebService`.

The Terraform translation is the most useful refactoring in the chapter. The `hello-world-app` module depends on a `terraform_remote_state` lookup of the MySQL module, plus VPC and subnet data sources. Three moves:

**One — name the dependencies.** Put every data source and resource representing an external dependency in its own `dependencies.tf`, so a reader sees at a glance what the module needs from the outside world.

**Two — add an input variable per dependency, defaulting to `null`:**

```hcl
variable "mysql_config" {
  description = "The config for the MySQL DB"
  type = object({
    address = string
    port    = number
  })
  default = null
}
```

**Three — gate the data sources on `count` and resolve through `locals`:**

```hcl
data "terraform_remote_state" "db" {
  count = var.mysql_config == null ? 1 : 0
  # ...
}

locals {
  mysql_config = (
    var.mysql_config == null
      ? data.terraform_remote_state.db[0].outputs
      : var.mysql_config
  )
}
```

Then every reference in the module points at `local.mysql_config` rather than the data source. Because the data sources now carry `count` they are lists, so every reference needs `[0]`.

!!! tip "Type-safe function composition, which is the real prize"
    `mysql_config`'s object type is designed to match the `mysql` module's outputs exactly. That makes the two modules composable in one line:

    ```hcl
    module "hello_world_app" {
      # Pass all the outputs from the mysql module straight through
      mysql_config = module.mysql
    }
    ```

    And if either side's type changes so they no longer match, **Terraform errors immediately** rather than failing at apply time. The chapter's phrasing: not just function composition, but *type-safe* function composition.

In the test, the injected value is mock data:

```go
Vars: map[string]interface{}{
    "mysql_config": map[string]interface{}{
        "address": "mock-value-for-test",
        "port":    3306,
    },
},
```

The chapter notes the alternative: point `address` at a small in-memory database started at test time. The seam is what matters, not the fake.

#### Running tests in parallel

`t.Parallel()` at the top of each test is the whole change — and it immediately breaks, because both tests create resources with the same names.

!!! danger "Key testing takeaway #4: you must namespace all of your resources"
    Design modules and examples so every resource name is configurable, then set it to something unique per test run:

    ```go
    Vars: map[string]interface{}{
        "alb_name": fmt.Sprintf("test-%s", random.UniqueId()),
    },
    ```

    `random.UniqueId()` returns a six-character base-62 string — short enough to stay inside name length limits, and 62⁶ ≈ 56 billion combinations, so collisions are effectively impossible. The problem is not exclusive to `t.Parallel()`: two developers running the same test, or CI running it alongside them, collide the same way.

Two mechanics worth remembering:

- Go runs at most **one test per CPU** in parallel by default. Override with `-parallel N` or `GOMAXPROCS`.
- Running several tests **against the same folder** in parallel breaks differently: they fight over one `.terraform` directory and one state file. The fix is `test_structure.CopyTerraformFolderToTemp`, which copies the folder to a unique temp directory and keeps relative paths working.

### Integration tests

Terraform's version of "several units together" is several modules together: deploy the real `mysql` module, then `hello-world-app` against it, and check the app works. The test targets the *staging* configuration — while authenticated to an isolated test account.

The shape:

```go
func TestHelloWorldAppStage(t *testing.T) {
    t.Parallel()

    dbOpts := createDbOpts(t, dbDirStage)
    defer terraform.Destroy(t, dbOpts)
    terraform.InitAndApply(t, dbOpts)

    helloOpts := createHelloOpts(dbOpts, appDirStage)
    defer terraform.Destroy(t, helloOpts)
    terraform.InitAndApply(t, helloOpts)

    validateHelloApp(t, helloOpts)
}
```

!!! warning "The backend is the obstacle, and partial configuration is the answer"
    A hardcoded `backend "s3"` block in the staging configuration means a test run **overwrites the real staging state file**. Workspaces do not solve it either, since they still need access to the staging account's bucket.

    The fix is partial configuration: empty the `backend "s3" {}` block, move the real values into `backend.hcl` used with `terraform init -backend-config=backend.hcl`, and let the test supply its own through Terratest's `BackendConfig`, with a `key` containing `t.Name()` and a unique ID.

The wiring detail that makes the integration real: `db_remote_state_bucket` and `db_remote_state_key` in the app's options are set from the *database's* `BackendConfig`, so the app reads exactly the state the database just wrote.

#### Test stages

The integration test takes 10–15 minutes, and iterating on the app means paying for the database's deploy and destroy every time. Terratest's `test_structure` package splits the test into named stages that can be skipped individually:

```go
stage := test_structure.RunTestStage

defer stage(t, "teardown_db", func() { teardownDb(t, dbDirStage) })
stage(t, "deploy_db", func() { deployDb(t, dbDirStage) })

defer stage(t, "teardown_app", func() { teardownApp(t, appDirStage) })
stage(t, "deploy_app", func() { deployApp(t, dbDirStage, appDirStage) })

stage(t, "validate_app", func() { validateApp(t, appDirStage) })
```

Each stage is skipped by setting `SKIP_<stage name>=true`. State passes **through disk**, not memory — `test_structure.SaveTerraformOptions` and `LoadTerraformOptions` — precisely because each run is a separate process, and a later run must find the database an earlier run deployed.

The workflow this unlocks:

```bash
# 1. Deploy everything, skip teardown
SKIP_teardown_db=true SKIP_teardown_app=true go test -timeout 30m -run '...'

# 2. Iterate: skip the DB deploy too — this is the inner loop
SKIP_teardown_db=true SKIP_teardown_app=true SKIP_deploy_db=true go test ...

# 3. Clean up: skip everything except teardown
SKIP_deploy_db=true SKIP_deploy_app=true SKIP_validate_app=true go test ...
```

The numbers are the argument: the full run is ~423 seconds, the inner loop is **~14 seconds**. Same tests, same code, run dozens or hundreds of times during development. It changes nothing about CI, where every stage runs.

#### Retries

Flaky tests are the expected condition, not a defect: an EC2 instance that fails to launch, an eventual-consistency bug, a TLS handshake error against S3. Terratest takes known-error retries as configuration:

```go
MaxRetries:         3,
TimeBetweenRetries: 5 * time.Second,
RetryableTerraformErrors: map[string]string{
    "RequestError: send request failed": "Throttling issue?",
},
```

Keys are patterns matched against the logs (regular expressions allowed); values are the explanation printed when a retry fires, which is what stops a retried failure from becoming invisible.

### End-to-end tests

The test pyramid: many unit tests, fewer integration tests, fewest end-to-end tests, because cost, complexity, brittleness and runtime all increase as you climb.

!!! danger "Key testing takeaway #5: smaller modules are easier and faster to test"
    Namespacing, dependency injection, retries and test stages were all needed for a *relatively simple* module. Larger infrastructure only makes each of them harder, which is why you push testing as far down the pyramid as it will go.

!!! quote "The arithmetic that kills naive end-to-end testing"
    Give a single resource a **0.1%** chance of an intermittent failure — the chapter says real rates are probably higher. The odds a test deploying *N* resources hits none of them is 99.9%ᴺ:

    | Test | Resources | Odds of a clean run |
    | --- | --- | --- |
    | Unit test, one module | 20 | **98.0%** |
    | Integration test, three modules | 60 | **94.1%** |
    | End-to-end, 30 modules | 600 | **54.9%** |

    At 600 resources nearly half of all runs fail for reasons unrelated to your change. Retries turn it into whack-a-mole: a retry for a TLS timeout, then an APT repo outage in a Packer build, then an eventual-consistency bug, then a brief GitHub outage. And since these suites run overnight, you get **one fix attempt per day**.

    The chapter's description of what actually happens next is the part worth remembering: developers start blaming each other for failures, convince management to deploy despite them, and eventually ignore the suite entirely.

So almost nobody deploys everything from scratch end to end. The practical strategy:

1. Pay once to stand up a **persistent, production-like `test` environment**, and leave it running.
2. On every change, apply that change **incrementally** to the test environment, then validate from the end user's perspective.

The advantage the chapter draws out is not only speed. You never rebuild production from scratch to ship a change either, so incremental end-to-end testing exercises **the deployment process itself**, not just the resulting infrastructure.

### Other testing approaches

Three cheaper families, each catching a different class of bug.

#### Static analysis

Parse the code, do not run it. Tools compared: `terraform validate`, `tfsec`, `tflint`, `Terrascan`.

```bash
$ terraform validate

 Error: Missing required argument
 The argument "alb_name" is required, but no definition was found.
```

`validate` is syntax-only. The others enforce **policy as code** — no security group open to `0.0.0.0/0`, every instance following a tagging convention.

- **Strengths:** fast, easy, stable, no provider authentication, nothing deployed.
- **Weaknesses:** only catches what is visible without executing — so a hardcoded `0.0.0.0/0` is caught and the same value arriving through a variable is not. And *"these tests aren't checking functionality, so it's possible for all the checks to pass and the infrastructure still doesn't work!"*

#### Plan testing

Run `plan` and inspect the result. More than static analysis (reads execute, data sources run), less than a unit test (nothing is created). Tools compared: Terratest, OPA, Sentinel, Checkov, terraform-compliance.

With Terratest, three levels of strictness:

```go
planString := terraform.InitAndPlan(t, opts)                     // 1. it plans at all

resourceCounts := terraform.GetResourceCount(t, planString)      // 2. the counts are right
require.Equal(t, 5, resourceCounts.Add)

planStruct := terraform.InitAndPlanAndShowWithStructNoLogTempPlanFile(t, opts)
alb, exists := planStruct.ResourcePlannedValuesMap["module.alb.aws_lb.example"]  // 3. specific values
```

The OPA path is declarative instead, and the three-command workflow is the reusable part:

```bash
terraform plan -out tfplan.binary
terraform show -json tfplan.binary > tfplan.json
opa eval --data enforce_tagging.rego --input tfplan.json --format pretty data.terraform.allow
```

```rego
package terraform

allow {
    resource_change := input.resource_changes[_]
    resource_change.change.after.tags["ManagedBy"]
}
```

Missing tag prints `undefined`; present tag prints `true`. The chapter's framing of the trade: Terratest's flexibility is its strength and its weakness, because arbitrary Go is harder to start with than a declarative policy.

- **Strengths:** fast, fairly easy, mostly stable, nothing deployed.
- **Weaknesses:** limited error classes, **requires real provider authentication** (plan needs it), and again, everything can pass while the infrastructure does not work.

#### Server testing

Tools built for the Chef/Puppet era that check a deployed server matches a spec: InSpec, Serverspec, Goss. Each offers a small DSL:

```ruby
describe port(8080) do
  it { should be_listening }
end
```

- **Strengths:** far easier than hand-rolling these checks, and they accumulate into a compliance checklist (PCI, HIPAA). Because something real is running, they catch far more than static analysis or plan testing.
- **Weaknesses:** slow, somewhat flaky, needs provider credentials *and* a second auth path (SSH) to the servers, deploys real resources, and only covers servers — not load balancers, databases or anything else.

## Conclusion

> Infrastructure code without automated tests is broken.

Meant literally as well as rhetorically. The claim is that every single time the author wrote infrastructure code — however clean, however manually tested and reviewed — writing automated tests flushed out non-trivial bugs, including bugs in Terraform, Packer, Elasticsearch, Kafka and AWS themselves.

The five takeaways, in one place:

| # | Takeaway |
| --- | --- |
| 1 | When testing Terraform code, you can't use localhost. |
| 2 | Regularly clean up your sandbox environments. |
| 3 | You cannot do pure unit testing for Terraform code. |
| 4 | You must namespace all of your resources. |
| 5 | Smaller modules are easier and faster to test. |

And Table 9-4's comparison, restated as a ranking rather than the book's square-count (▪ = weakest, ▪▪▪▪ = strongest on that row):

| | Static analysis | Plan testing | Server testing | Unit tests | Integration | End-to-end |
| --- | --- | --- | --- | --- | --- | --- |
| Fast to run | ▪▪▪▪ | ▪▪▪ | ▪▪ | ▪▪ | ▪ | ▪ |
| Cheap to run | ▪▪▪▪ | ▪▪▪ | ▪▪ | ▪▪ | ▪ | ▪ |
| Stable and reliable | ▪▪▪▪ | ▪▪▪ | ▪▪ | ▪▪ | ▪ | ▪ |
| Easy to use | ▪▪▪▪ | ▪▪▪ | ▪▪▪ | ▪▪ | ▪ | ▪ |
| Checks syntax | ✓ | ✓ | | ✓ | ✓ | ✓ |
| Checks policies | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Checks servers work | | | ✓ | ✓ | ✓ | ✓ |
| Checks other infrastructure works | | | | ✓ | ✓ | ✓ |
| Checks everything works together | | | | | | ✓ |

> ❓ Revisit: that table is a reconstruction. `pdftotext` shifts this book's table columns by one row and the filled/empty square glyphs did not survive extraction, so the capability rows were rebuilt from each section's own strengths-and-weaknesses lists. The shape is right; check page 374 before quoting a specific cell.

The answer to "which approach" is all of them, in the pyramid's proportions, added incrementally. *"Almost any testing is better than none"*, so if static analysis is all you can afford today, start there.

### State of the running example

Testing forces the code to change, which is the chapter's quiet second story. The `hello-world-app` module gains a `dependencies.tf`, three injectable inputs (`vpc_id`, `subnet_ids`, `mysql_config`), `count`-gated data sources and a `locals` block resolving each. Its `db_remote_state_bucket` / `db_remote_state_key` become optional. The `alb` and `hello-world-app` examples gain `alb_name` and `environment` variables purely so tests can namespace them, and the staging `mysql` configuration gains a `db_name` variable and moves its backend to partial configuration.

A `test/` folder now holds a Go module with unit, integration and staged tests.

---

## Version reckoning

The five takeaways survive. The premise underneath them — that testing Terraform means writing Go — does not, and every version number in the chapter has moved.

!!! danger "1. The chapter predates Terraform's own test framework"
    `terraform test` did not exist in a usable form when this was written. Verified from the local checkouts:

    | Capability | Terraform | OpenTofu |
    | --- | --- | --- |
    | `terraform test` / `tofu test` GA, `.tftest.hcl` with `run` blocks | **1.6.0** (2023-10-04) | **1.6.0** (2024-01-09) |
    | `mock_provider`, `override_resource`, `override_data` | **1.7.0** (2024-01-17) | **1.8.0** (2024-07-29), plus `mock_resource` / `mock_data` |

    Tests are HCL, in the binary, no Go and no `go.mod`.

    **What this does to takeaway #3.** Mocked providers let a test run `command = apply` *"without requiring a configured cloud provider account and credentials"* — Terraform creates fake resources and keeps them in state for the test file's lifetime. That is much closer to pure unit testing than the chapter believed possible, and it is the dependency-injection section's goal reached inside the language rather than by refactoring modules.

    **What it does not change.** A native test asserts on what the *provider reports back*, so a provider bug that creates a wrong real resource still passes ([[terraform-testing]]). That is exactly the gap Terratest's "query the resource's own API" approach closes, which is why both frameworks still exist. Also note the chapter's LocalStack footnote was arguing this same point in advance: a successful apply against fakes tells you your configuration is coherent, not that a working app came up.

!!! info "2. The native framework grew the features this chapter hand-rolls in Go"
    Each of the chapter's Terratest mechanisms now has an in-binary counterpart:

    - **Parallelism** — `terraform test -parallelism=n`, and run blocks annotated for parallel execution (**1.12**). The chapter's `t.Parallel()` plus `random.UniqueId()` namespacing.
    - **CI reporting** — `-junit-xml` GA in **1.11**, with file-level diagnostics added to skipped elements in **1.15**. The chapter has no answer for this at all; it pipes `go test` output.
    - **Mocking during plan** — `override_during = plan` (**1.11**), since mocks default to applying only.
    - **State control per run** — `state_key` on a `run` block (**1.11**), the native analogue of the chapter's per-test `BackendConfig` key.
    - **Functions inside mock blocks** (**1.15**), and test-file-level `variable` definitions (**1.13**).

!!! warning "3. Every Terratest call in the chapter is deprecated"
    The book pins **v0.39.0** and warns it is pre-1.0. It is not any more: **v1.0.0** shipped 2026-05-11, **v1.0.1** on 2026-06-27, with **v2 betas** since 2026-07-20 ([[terratest-facts]]). v1 requires **Go 1.26+**, against the book's "minimum version 1.13".

    Verified against the local checkout at `v1.0.1` — every `terraform.*` function the chapter calls now carries a `Deprecated:` marker pointing at a context-taking form:

    | Book calls | Current form |
    | --- | --- |
    | `terraform.InitAndApply` | `terraform.InitAndApplyContext` |
    | `terraform.Destroy` | `terraform.DestroyContext` |
    | `terraform.OutputRequired` | `terraform.OutputRequiredContext` |
    | `terraform.InitAndPlan` | `terraform.InitAndPlanContext` |
    | `terraform.InitAndPlanAndShowWithStructNoLogTempPlanFile` | …`Context` |

    The bare forms still work in v1 and are **removed in v2**. Not deprecated, and unchanged: `terraform.GetResourceCount`, `http_helper.HttpGetWithRetry`, `http_helper.HttpGetWithRetryWithCustomValidation`, `test_structure.RunTestStage`, `test_structure.SaveTerraformOptions`, `random.UniqueId`. So the chapter's *structure* is entirely intact; it is the apply/destroy/output calls that need renaming.

    v2 also splits the single Go module into **16 independently versioned modules** under `/v2` import paths, so a pinned v1 consumer is unaffected until it opts in.

!!! warning "4. Two tools in the comparison tables are gone"
    Checked 2026-08-21 against each repository:

    - **Terrascan is archived.** `tenable/terrascan` (the company changed hands from Accurics) last saw a push on **2025-11-20** and the repository is archived. Table 9-1 should be read as three tools, not four.
    - **tfsec is deprecated into Trivy.** The repository now describes itself as part of Trivy; Trivy is at **v0.74.0** ([[ci-quality-tooling-versions]]). Anything Table 9-1 says about tfsec applies to Trivy today.
    - **`aws-nuke` changed hands too.** `rebuy-de/aws-nuke` is **archived** (last push 2024-10-15); the maintained fork is **`ekristen/aws-nuke`**. `gruntwork-io/cloud-nuke`, the tool the chapter's cron example uses, is still active.
    - Still active and unchanged in role: **tflint** (v0.64.0), **Checkov** (3.3.x), **OPA**, **terraform-compliance**, **Sentinel** (still proprietary, still HashiCorp-only).

!!! note "5. InSpec is no longer simply Apache 2.0"
    Table 9-3 lists InSpec's license as Apache 2.0. The source still is, but the README states that **all supported versions — InSpec 5.0 and later — require accepting the Chef EULA**, and the documented install paths take a `license_id`. Serverspec (last push 2025-04-24) and Goss are unaffected and remain community-licensed.

    The wider point for this table: server-testing tools are the part of the chapter most tied to the configuration-management era it inherited them from, and the immutable-image approach the book recommends elsewhere pushes these checks into image build rather than post-apply validation.

!!! tip "6. What aged well, which is most of it"
    Nothing has made these false:

    - **No localhost** — still true, and still true of `terraform test` without mocks, which really applies.
    - **Clean up sandboxes** — the tools moved, the cron job did not.
    - **Namespace everything** — parallel test runs still collide on names, in any framework.
    - **Smaller modules test faster** — unchanged, and the native framework makes it *more* true, since a small module is what a `.tftest.hcl` file can meaningfully cover.
    - **The 99.9%ᴺ arithmetic** — a property of probability, not of Terraform.
    - **Test stages** — the native framework has no equivalent inner-loop-skipping mechanism, so this remains a genuine reason to reach for Terratest.

    The honest summary: what expired is *"you must write Go to test Terraform"*. What survives is everything the chapter says about **why** testing infrastructure is hard, which is the durable half.

---

*Related notes:* [Testing](../../../topics/testing.md) · TID Ch9 [Testing and refactoring](../../tid/chapters/09-testing-refactoring.md) for both frameworks in depth · TUR Ch8 [Production-grade](08-production-grade.md) for the `examples` folder convention this chapter depends on, and Ch3 [State](03-manage-state.md) for the partial backend configuration it reuses · [[terraform-testing]] for the native-vs-Terratest distinction · [[terratest-facts]] for the source-derived version and API state · [[ci-quality-tooling-versions]] for the static-analysis tool currency · [[version-facts]]. Feeds learning-path **A2** (testing, validation and checks), **I5** (authoring modules), **A3** (CI/CD) and **A5** (policy as code).
