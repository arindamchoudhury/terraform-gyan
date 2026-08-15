# Chapter 9 — Testing and refactoring

> *Source: Hafner (2025), **Terraform in Depth**, Chapter 9, pages 288–336.*
>
> The chapter Ch7 and Ch8 both defer to. It opens with *why* — including an argument you rarely see in a technical book, that a test suite buys **psychological safety** — then works through the theory of testing IaC (what to test, why infrastructure is unlike a Python library, unit vs integration), the practices that make it survivable (examples as test fixtures, randomised names, timeouts, account nuking), and then both frameworks in depth: **Terratest** in Go and the **native `terraform test`** framework in HCL. It closes on **refactoring** — internal versus external, renaming resources and variables without breaking users, and how to plan and ship a major version.
>
> 📌 **The testing framework has moved a long way since this was written, and one cited tool is dead.** Terraform **1.12** added **parallel test runs**, which undercuts the CI workaround in §9.4.6 (the book states the framework "only runs one test at a time"). **Mocks are 1.7 on Terraform but 1.8 on OpenTofu**, so the book's matrix comment is wrong for one engine. The `rebuy-de/aws-nuke` in Listing 9.5 is **archived** (use [`cloud-nuke`](https://github.com/gruntwork-io/cloud-nuke)). And the Copilot material (§9.3.7, §9.4.7) is a 2023 snapshot that has not aged. Each is flagged in place; versions in [[ci-quality-tooling-versions]] and [[version-facts]].

> 🔗 **See also:** owns learning-path **A2** (testing Terraform) and feeds **I5** (authoring modules), **A3** (tests in CI) and **I4** (semver and breaking changes). Builds directly on [Ch7](07-code-quality-ci.md) (the makefile, `TF_ENGINE`, the CI matrix) and [Ch8](08-cd-deployment.md) (semver, OIDC for test credentials). Source-derived detail: [[terratest-facts]] and [[terraform-testing]]. Topic pages: `testing` on the [topics backlog](../../../topics/index.md), plus `refactoring`, which this chapter completes.

---

## 9.1 The theory of IaC testing

Three benefits the chapter opens with, all durable: bugs are found faster and captured as **regression** tests; **pull requests get cheaper to review**, because without tests a reviewer must pull the branch and run it themselves (so in practice they skip it); and **backward compatibility gets maintained**, because a breaking change breaks the tests.

Then the fourth, which is the one worth remembering:

!!! quote "A test suite is psychological safety"
    *"A well-developed test suite increases the psychological safety of your team."* Incidents and outages are stressful, debugging live systems while people are using them is worse, and a fragile codebase keeps everyone tense. Tests let a team make changes without dread.

    The practical consequence is refactoring: §9.5 only works because §9.1–9.4 came first. A safety net is what makes large changes affordable.

### 9.1.1 What to test (and what not to test)

The scoping rule: **test your code, not the providers**. You may assume the providers are well tested, so passing a variable to a resource and asserting the attribute matches the input proves nothing the AWS provider does not already prove.

Test the **logic**:

- data transformations
- strings built from data sources and attributes
- anything with a regular expression, against several patterns
- `dynamic` blocks with zero, one, and many blocks
- system functionality — is the endpoint actually up, do the generated credentials actually work

The chapter's illustration is a DNS record. Pass `name` straight through and there is nothing worth testing. Compute it and there is:

```hcl
data "aws_region" "current" {}

resource "aws_route53_record" "main" {
  zone_id = var.zone_id
  name    = "${var.name}.${data.aws_region.current.name}.${var.domain}"   # ← now there is logic
  records = var.records
  type    = "A"
  ttl     = "300"
}
```

And beyond the string: if that record points at a web service, assert the **service answers at that address**. If a module writes database credentials to a secret manager, assert the **credentials work**.

### 9.1.2 How IaC testing differs from software testing

Everything follows from one fact: **IaC launches infrastructure**.

- **Time.** DNS is instant, a VM is minutes, a database can exceed thirty. Normal development is edit-run-read in under a minute; here the cycle is dominated by create and destroy.
- **Money.** Unit tests are free; infrastructure is not. This makes **guaranteed teardown** non-negotiable rather than tidy.

!!! note "Count the cost of *not* testing too"
    The chapter's own NOTE, and it is the right frame: tests cost time and money, outages cost more. The comparison is not "test spend versus zero", it is "test spend versus incident risk".

### 9.1.3 Terraform testing frameworks

Until 2023 there was exactly one option: **Terratest**, by Gruntwork (who also make Terragrunt), built on Go's `testing` package. Mature, with a large helper library. Its one real drawback is that **tests are written in Go**, which for a team learning Terraform means a second language at the same time — so people write trivial tests, or none.

Then HashiCorp and OpenTofu shipped a **native framework**: tests in HCL, no second language.

> ⚠️ **Table 9.1 did not survive text extraction** — its two columns interleave, so individual cells cannot be attributed with confidence. The comparison below is rebuilt from the chapter's prose and from source, not from the printed table.

| | Terratest | Native `terraform test` |
|---|---|---|
| Language | Go | HCL |
| First released | **2016** | **2023** (Terraform/OpenTofu 1.6) |
| Runs against older engine versions | yes | **no** — it *is* the binary |
| Third-party library ecosystem | yes (all of Go) | no |
| Reaches inside the module | no — works through outputs | **yes** — any named value |

!!! info "The 2016 date, since the book is inconsistent with itself"
    Ch7 says Terratest was "released in 2016"; this chapter says "up until 2023 there was only a single option" and that Terratest "existed for seven years before" the native framework — which also gives 2016. The garbled table appears to say 2018.

    Settled from the source: `repos/terratest` has its first commit on **2016-03-04** and tag `v0.0.1` on **2016-03-13**. So 2016, and the "seven years" arithmetic is right.

The chapter's own recommendation: **start with the native framework**. People writing Terraform already know Terraform, so keeping infrastructure and tests in one language lowers the barrier. But Terratest is not going away — it has a seven-year head start, most existing Terraform tests are written in it, and teams supporting a wide range of engine versions still need it.

!!! warning "The framework is the sharpest edge between Terraform and OpenTofu"
    The chapter flags this itself: the testing framework is *"the first major piece of functionality written after the license change and is one of the areas where both Terraform and OpenTofu have their biggest implementation differences."*

    That has held. Mocks arrived in different releases, and parallel test execution exists on only one engine — both detailed in §9.4.3 and §9.4.6 below. Treat any test-framework feature as needing a per-engine check.

### 9.1.4 Unit testing vs. integration testing

**Unit** tests isolate a piece of code, mocking external dependencies. **Integration** tests exercise components together against real systems. Most suites are a blend, and the distinction is a spectrum rather than a binary.

**Terraform is inherently hard to unit test**, because configuring external systems *is* the point. Emulators exist but tend to differ enough from the real service to be poor test targets.

The chapter's reframing is the useful bit: **unit tests for Terraform do exist — providers have them**, written in Go by provider authors. Treat every resource and data source as a well-tested function. What is left for you is almost entirely **integration testing**.

---

## 9.2 Testing IaC in practice

### 9.2.1 Simple testing flow

Four steps: **configure → launch → validate → cleanup**.

A single *test* is one configuration carrying many *test cases*. Group aggressively — because launching infrastructure is slow, you do not want a create/destroy cycle per assertion. One web-service configuration can check endpoints, the 80→443 redirect, and log delivery in one run.

Separate tests are for configurations that **contradict each other**: an S3 module used as a private log sink cannot be the same configuration as one used as a public static site.

> 💡 The chapter's reminder, easy to skip: **tests are code**. They get maintained and extended like everything else, so keep them simple and commented.

### 9.2.2 Starting with examples

The chapter's best practical idea, and it pays three ways at once: for every module, build **fully working examples**, one per feature or integration.

```text
examples/
  basic/main.tf     # simplest proof the module works
  lambda/main.tf    # module integrated with AWS Lambda
  ecs/main.tf       # module integrated with ECS
  ec2/main.tf       # module integrated with EC2
```

- **Users** get something to learn from.
- **Maintainers** get a one-command local launch — `cd` into an example and apply.
- **Tests** get ready-made configurations, which is why it belongs in this chapter.

The reason it matters for testing specifically: a Terraform module usually cannot be tested by varying variables alone. To test how an ALB works with Lambda you need *an actual Lambda* wired to it. Examples are where that surrounding infrastructure already lives — so tests can create whatever they need in the example, add test-only outputs, and keep the module itself clean.

The bonus: tying tests to examples means **your examples cannot silently rot**.

### 9.2.3 Concurrency and automated testing

Tests run concurrently because they are slow — and even a single-configuration suite runs concurrently the moment two people open pull requests.

For ordinary software this is harmless; here, tests **create real resources**, and the collision point is **names that must be unique**. Worse, some resources hold the name after deletion — the chapter's example is `aws_secretsmanager_secret`.

!!! warning "Book defect — it is 30 days by default, not “a full week”, and there is an escape hatch"
    The chapter says a deleted secret blocks reuse of its name for *"a full week by default"*. The provider documentation for `aws_secretsmanager_secret` says otherwise: `recovery_window_in_days` *"can be `0` to force deletion without recovery or range from `7` to `30` days. **The default value is `30`.**"*

    So seven days is the **minimum** you can configure, not the default, and the real collision window is more than four times what the book states — which makes its own argument stronger, not weaker.

    It also means the fix for test suites is better than randomised names alone. Set the window to zero in test configurations so the name frees immediately:

    ```hcl
    resource "aws_secretsmanager_secret" "test" {
      name                    = "testing_${random_string.random.result}"
      recovery_window_in_days = 0     # test-only: skip the recovery window entirely
    }
    ```

    Never in production, obviously — that removes the undelete safety net.

The fix is cheap:

```hcl
resource "random_string" "random" {
  length  = 8
  special = false      # many systems reject special characters in names
  upper   = false      # names are often case-insensitive; lowercase avoids surprises
}

module "alb_example" {
  source = "../"
  name   = "testing_${random_string.random.result}"
}
```

For resources that cannot reuse a name even after deletion, put the randomness **inside the module**, so tearing an environment down and standing it back up under the same name also works outside testing.

### 9.2.4 Timeouts

Two places to raise them, and both bite:

- **The test runner.** Terratest inherits Go's default, which kills tests at **10 minutes**.
- **The CI system.** GitHub Actions defaults to **360 minutes**, which is generous; self-managed Jenkins should be checked or set explicitly.

!!! danger "A timeout is worse than a failure — it orphans resources"
    Hitting a timeout stops the test immediately, so **destroy never runs**. Resources keep billing. And because test runs usually have no state backend, there is no state file to clean up from either — and even with one configured, a timeout often means state was never written.

    This is the single most expensive mistake in the chapter, and it is caused by forgetting one flag.

### 9.2.5 Automatic cleanup

Teardown fails for reasons you do not control: Terraform crashes before writing state, a logic error stops `destroy`, the CI job is killed. Resources survive, and they cost money.

So the chapter keeps a way to **reset a test account entirely**, run on a schedule. The discovery trick is genuinely useful — search for **"*vendor* nuke"**:

- AWS and GCP → [`gruntwork-io/cloud-nuke`](https://github.com/gruntwork-io/cloud-nuke), or `ekristen/aws-nuke` for AWS alone
- Azure → [`ekristen/azure-nuke`](https://github.com/ekristen/azure-nuke)

!!! danger "Only ever point this at an isolated test account"
    The chapter's WARNING, and it deserves the emphasis: automatic deletion is dangerous. Run tests in a dedicated account, run reset scripts **only** against that account, and never test in production.

!!! warning "The AWS tool the book names is archived — two live replacements"
    Listing 9.5 installs `rebuy-de/aws-nuke` by downloading a pinned release tarball. That repository is **archived** (last push 2024-10-15) and tagged `deprecated`, so the workflow as printed pins a dead project. Its homepage points at `ekristen/aws-nuke`, but that is not the only option, and probably not the best one here.

    | | [`gruntwork-io/cloud-nuke`](https://github.com/gruntwork-io/cloud-nuke) | [`ekristen/aws-nuke`](https://github.com/ekristen/aws-nuke) |
    |---|---|---|
    | Latest | **v0.52.0** (2026-06-13) | **v3.66.0** (2026-07-16) |
    | Scope | **AWS + GCP** in one binary | AWS only |
    | Non-destructive preview | **`--dry-run`**, plus `inspect-aws` / `inspect-gcp` subcommands | config-driven |
    | Licence | MIT | — |
    | Lineage | **Gruntwork** — the authors of Terratest | direct successor to the archived repo |

    **`cloud-nuke` is the better fit for this chapter**, for two reasons beyond being maintained. It is by **Gruntwork**, the same people as the Terratest this chapter spends §9.3 on, so a team already in that ecosystem adds no new vendor. And it ships a **genuinely non-destructive mode** — `--dry-run` and the `inspect-*` subcommands — which matters more here than anywhere else in the book: this is a tool whose failure mode is *deleting the wrong account*. Being able to prove what it would delete before letting it delete anything is the safeguard §9.2.5's own WARNING is asking for.

    ⚠️ Scope, stated precisely because the name overpromises: `cloud-nuke` registers `aws`, `gcp`, `inspect-aws` and `inspect-gcp` subcommands — **there is no Azure support**, and its README documents only the AWS path even though the GCP command is real. So the chapter's Azure recommendation, [`ekristen/azure-nuke`](https://github.com/ekristen/azure-nuke), still stands on its own.

    Either way the printed workflow needs more than a URL swap: the release asset naming and the invocation both differ from `aws-nuke`.

Azure and GCP make this easier structurally — group resources under a resource group or project and delete the container. Where no reset path exists, inspect every failed run manually and **set budget alerts** on the account.

### 9.2.6 Authentication and secrets

Tests authenticate to real vendors, so Ch8 §8.5 applies unchanged: **prefer OIDC**. Test credentials are the ones most likely to be over-scoped and least likely to be rotated, which is exactly the case for eliminating the stored credential entirely.

### 9.2.7 Testing as code

Test suites deserve the same standard as the code they protect: readable variable names, comments explaining *what a test is trying to prove*, real review attention on the test half of a pull request, and refactoring when the tests get hard to extend.

---

## 9.3 Terratest

### 9.3.1 Getting started with Go

The chapter's reassurance is fair: you are using a **narrow subset** of Go — the testing package — and writing what amount to small scripts, not applications.

```go
package tests

import (
    "testing"
    "github.com/stretchr/testify/assert"
)

func TestExample(t *testing.T) {     // functions starting with Test are collected
    assert.Equal(t, 1, 1)
}
```

Two setup commands, roughly Go's `terraform init`:

```bash
go mod init github.com/TerraformInDepth/terraform-module-example   # writes go.mod
go mod tidy                                                        # resolves deps, writes go.sum
go test                                                            # run
```

Re-run `go mod tidy` whenever imports change; otherwise these are one-time.

> 💡 Search for **"golang"**, not "go" — the chapter's tip, and still true.

### 9.3.2 Terratest Hello World

Terratest is a set of helpers around Go's testing package. Every Terratest test has the same four beats:

1. Build `terraform.Options` — directory, variables, and which binary to run.
2. `defer terraform.Destroy` — **deferred, so it runs even when the test fails**.
3. `terraform.InitAndApply`.
4. Assert.

```go
func TestExample(t *testing.T) {
    t.Parallel()

    testInput := "test"
    terraformBinary := os.Getenv("TERRATEST_BINARY")   // ← the OpenTofu/Terraform switch
    if len(terraformBinary) <= 0 {
        terraformBinary = "terraform"
    }

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir:    "../",
        TerraformBinary: terraformBinary,
        Vars:            map[string]interface{}{"test_input": testInput},
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    testOutput := terraform.Output(t, terraformOptions, "test_output")
    assert.Equal(t, testInput, testOutput)
}
```

Two details worth lifting. **`WithDefaultRetryableErrors`** wraps the options so known-flaky cloud errors are retried — the chapter treats plain `terraform.Options` as the lesser choice, and this is what Copilot gets wrong in §9.3.7. And **`TerraformBinary` fed from an environment variable** is the Ch7 `TF_ENGINE` trick reaching all the way into the test.

!!! danger "`go test` kills tests at 10 minutes by default"
    Long enough for the book's `terraform_data` example, nowhere near enough for a database. Pass `-timeout`:

    ```bash
    go test -v -timeout 60m
    ```

    Forget it and the test is killed mid-run, which per §9.2.4 means **destroy never happens**. This is why the flag belongs in a makefile rather than in anyone's memory.

### 9.3.3 Building on examples

Pointing a test at an example instead of the module root is a one-line change:

```go
TerraformDir: "../examples/basic",     // the variables now match the example, not the module
```

That is the whole integration story: the example already contains the surrounding infrastructure, so the test does not have to construct it. It also means new code that breaks an example is caught immediately.

### 9.3.4 Terratest helpers

The chapter rates the helper library as Terratest's biggest advantage over the native framework — **20+ packages**, covering cloud providers (AWS, Azure, GCP, Oracle), protocols (`http-helper`, `dns-helper`), and general test utilities.

Read them in the [repository](https://github.com/gruntwork-io/terratest) rather than the website — the `modules/` directory is the real index, and the repo is more current than the docs site. And you are never limited to them: the whole Go ecosystem is available.

!!! info "📌 Terratest is now past 1.0, with a v2 in beta"
    The book predates stabilisation. Terratest reached **v1.0.0 on 2026-05-11** (its first semver-stable release), **v1.0.1** on 2026-06-27, and **v2 is in per-module beta** (`v2.0.0-beta.2`, 2026-08-10) shipping under `/v2` module paths so pinned v1 consumers are unaffected. Requires **Go 1.26+**. Detail in [[terratest-facts]].

### 9.3.5 Updating our makefile and template

The Ch7 makefile absorbs the commands, and this is a good demonstration of non-`.PHONY` targets doing real work — `go.mod` and `go.sum` are generated only when missing or stale:

```makefile
TERRATEST_FILES := $(wildcard terratest/*_test.go)
GO_TEST_OPTS :=

terratest/go.mod:                       # not phony: runs only if the file is absent
	cd terratest && go mod init ModuleTests

terratest/go.sum: terratest/go.mod $(TERRATEST_FILES)   # re-runs when tests or go.mod change
	cd terratest && go mod tidy

.PHONY: terratest
terratest: terratest/go.sum
	cd terratest && \
	TERRATEST_BINARY=$(TF_BINARY) go test -v -timeout 60m $(GO_TEST_OPTS)
```

```bash
make terratest GO_TEST_OPTS="-run TestExample"      # one test instead of the suite
```

> ⚠️ **Book defects in Listing 9.13, corrected above.** As printed, the `go.sum` target depends on `tests/go.mod` and runs `cd tests`, while the `go.mod` target creates `terratest/go.mod` — the directory names do not agree, so the dependency never resolves. The variable is also `GO_TEST_OPTS` here but `GO_TEST_OPTIONS` in the CI listing (9.16); pick one.

The chapter also puts a **commented skeleton test** in the Cookiecutter template, which is the higher-leverage half: a new module starts with a test file that needs a few small edits rather than a blank page.

### 9.3.6 Testing with CI

The same matrix shape as Ch7 §7.7.3, now running tests:

```yaml
      - name: Run Terratest
        run: make terratest TF_ENGINE=${{ matrix.engine }}
```

The problem it then solves is real: with several test functions you either interleave all their logs (undebuggable) or serialise them (slow). The chapter's RDS example — four examples at ~45 minutes each — is a **three-hour** cycle serialised.

The fix is to make the **test function another matrix dimension**, so each runs as its own job:

```yaml
        test: [BasicTest, LambdaTest, ECSTest, Ec2Test]
```

```yaml
        run: make terratest TF_ENGINE=${{ matrix.engine }} GO_TEST_OPTS="-run ${{ matrix.test }}"
```

The chapter is honest that the `include:` legs force you to **duplicate the test list**, which is the ugly part of Actions matrices.

### 9.3.7 Terratest and Copilot

The chapter's argument is that Copilot is materially better at Go than at Terraform (more training data), which makes it a genuine on-ramp for a team that does not know Go. Given the module in the editor, a prompt like *"write a test for this Terraform code using Terratest"* produces a structurally correct test that correctly infers the variable and output names.

Its two identified misses are instructive because both are *local convention*, not knowledge:

- no `TERRATEST_BINARY` switch, because the engine-switching trick is the book's own
- plain `terraform.Options` instead of `WithDefaultRetryableErrors`

Its recommendation is the durable part: **use the output as inspiration, lift the assertions into your own skeleton** rather than adopting the generated file wholesale.

!!! warning "📌 This section is a 2023 snapshot and should not be read as current"
    The specific claims — what Copilot knows, that it produces an unused-import error, and especially §9.4.7's finding that it is *"completely unaware of the Terraform testing framework"* and redirects you to Terratest — describe one product at one moment in a field that has moved substantially since. The chapter says as much itself (*"this advice will probably change in the not too distant future"*).

    What survives is the method, not the measurements: keep your own test skeleton, treat generated tests as suggestions, and have someone who knows the language review them.

---

## 9.4 Terraform testing framework

Introduced in **1.6** on both engines. Two advantages over Terratest: **HCL**, and **direct integration** — where Terratest can only see what a module exposes as outputs, the native framework reads *any* named value, including resource attributes and locals.

### 9.4.1 Hello World

Tests live in `.tftest.hcl` files. A `variables` block supplies module inputs for the whole file; each `run` block is a test; `assert` blocks carry the conditions.

```hcl
variables {
  test_input = "test"
}

run "input_and_output_match" {
  assert {
    condition     = output.test_output == "test"
    error_message = "The output does not match the input."
  }
}
```

**A `run` block defaults to `apply`**; `command = plan` switches it. But a plan only knows plan-time values, so asserting on an output during a plan fails:

```text
Error: Unknown condition value
Condition expression could not be evaluated at this time. This means you have executed a
`run` block with `command = plan` and one of the values your condition depended on is not
known until after the plan has been applied.
```

That error means **the test is wrong, not the module** — a distinction worth internalising early.

### 9.4.2 Accessing named values

The framework's real edge. Address any value directly:

```hcl
run "input_passed_to_resource" {
  assert {
    condition     = terraform_data.this.input == "test"     # the resource, not an output
    error_message = "The resource parameter does not match the input."
  }
}
```

Locals are reachable too. This tests the **internal state of a module**, which Terratest structurally cannot do — it wraps Terraform rather than integrating with it, so it only ever sees outputs.

### 9.4.3 Mocks

Replace a provider with a fake that returns computed values without creating anything. This is how you get close to real unit testing: a mocked RDS instance takes a fraction of a second where a real one takes half an hour, and costs nothing.

```hcl
mock_provider "aws" {}     # every AWS resource in this test is now mocked
```

Mock values are type-correct but not realistic, defaulting by type:

| Type | Mock value |
|---|---|
| Numbers | `0` |
| Booleans | `false` |
| Maps | `{}` |
| Lists and sets | `[]` |
| Objects | attributes filled with the above |

So you override. Three scopes, increasingly narrow:

```hcl
mock_provider "aws" {
  mock_data "aws_region" {          # a default for every aws_region in the file
    defaults = { name = "us-east-1" }
  }
}
```

```hcl
run "dns_record_name" {
  command = plan

  override_data {                              # one specific address
    target = data.aws_region.current
    values = { name = "us-east-1" }
  }

  assert {
    condition     = aws_route53_record.main.name == "my_test.us-east-1.example.com"
    error_message = "Domain name not properly generated from region."
  }
}
```

`override_resource`, `override_data` and `override_module` can sit in the `mock_provider` block (applies when that provider creates the resource), at file top level (every `run`), or inside one `run` (that block only). Mocks can also be factored into **`tfmock.hcl`** files and imported — note the constraint: `source` must be a **directory**, not a file, and every mock file in it is loaded.

!!! warning "Mocks drift away from reality, and that is their failure mode"
    The chapter's caution: the more you mock, the more your tests describe your *assumptions* rather than the provider. If a provider changes a value's format and your mocks do not follow, the tests keep passing and miss it. **Review mocks when upgrading a provider major version.**

    Use mocks to *supplement* integration tests with cheap unit-level coverage of edge cases — never to replace running against real infrastructure.

!!! info "OpenTofu — mocks are 1.7 on Terraform but **1.8** on OpenTofu"
    The chapter says mocks "introduced in Terraform v1.7", and its CI matrix comments that mocks mean you cannot test earlier versions. That is right for Terraform and **wrong for OpenTofu**.

    Verified from source: Terraform's mocking parse support is commit `#34143` (2023-10-31), first tagged **v1.7.0**. OpenTofu's is `#1772` ("add mock providers for testing framework", 2024-07-09), first tagged **v1.8.0**.

    So a matrix that tests `opentofu` at `1.7` with mocks in the suite fails on that leg. This is precisely the divergence §9.1.3 warns about.

### 9.4.4 Building on examples

The same idea as §9.3.3, but the native framework makes it **harder**, and this is its clearest ergonomic loss to Terratest: `terraform test` assumes it is testing the module in the directory it runs from. Testing examples means putting the tests **beside each example** and running the command in each directory.

Upside: obvious which tests belong to which example. Downside: no single command — hence the makefile:

```makefile
TERRAFORM_EXAMPLES := $(wildcard examples/*)
TF_TEST_OPTS :=

.PHONY: $(TERRAFORM_EXAMPLES)
$(TERRAFORM_EXAMPLES):                       # one target per example directory
	@echo "Testing $@"
	cd $@ && \
	$(TF_BINARY) init -backend=false && \
	$(TF_BINARY) test $(TF_TEST_OPTS)

.PHONY: terraform_test
terraform_test: $(TERRAFORM_EXAMPLES)
	@echo "Testing Root Module"
	$(TF_BINARY) test $(TF_TEST_OPTS)
```

`make terraform_test` runs everything; `make examples/basic` runs one. Note `init -backend=false` again — tests must never touch real state.

### 9.4.5 Managing versions

The framework and the engine are **the same binary**, which cuts both ways. Switching framework versions is just switching engine versions — `tenv` and a `.terraform-version` / `.opentofu-version` file, per Ch7 §7.2.5.

The chapter extends the makefile with a `TF_VERSION` option and a neat CI detail:

```makefile
TERRAFORM_VERSION := $(shell cat .terraform-version)
TOFU_VERSION      := $(shell cat .opentofu-version)

ifeq ($(CI), )                                   # locally, let tenv switch versions
	TF_ENV_COMMAND := tenv use $(TF_BINARY) $(TF_VERSION)
else                                             # in CI the setup action already did it
	TF_ENV_COMMAND := echo "skipping tenv use in CI"
endif
```

Switching on the `CI` environment variable so the same makefile behaves correctly in both places is a genuinely good trick.

> ⚠️ **Book defect** — Listing 9.29 sets `TOFU_VERSION := $(shell cat .terraform-version)`, reading the *Terraform* version file for the OpenTofu version, while its own annotation says it reads `.opentofu-version`. Corrected above.

!!! danger "The coupling is the framework's real cost"
    You are locked to the **lowest engine version you must support**. You cannot test 1.5 at all, and if you use mocks (1.7+) you can no longer test 1.6. For a small team on current versions this is nothing; for a shared module consumed by teams that upgrade on their own schedule, it is the reason Terratest survives.

### 9.4.6 Testing with CI

Same shape again, with `-filter` as the parallelism lever instead of Go's `-run`:

```yaml
        test:
          - "examples/basic"
          - "terraform_test_root"
```

```yaml
        run: make ${{ matrix.test }} TF_ENGINE=${{ matrix.engine }}
```

!!! info "📌 Terraform 1.12 added parallel test runs — the premise of this section has changed"
    The chapter says parallelising through the CI matrix is "even more important with the Terraform testing framework as this framework only runs one test at a time". True when written; not true now.

    **Terraform 1.12** added a **`parallel`** attribute, accepted both on the test file's `test` config block and on individual `run` blocks (commit "Terraform test: Execute eligible test runs in parallel", `#36300`, 2025-02-05; earliest stable tag `v1.12.0`). Eligible runs execute concurrently inside a single `terraform test` invocation, so the matrix-per-example workaround is no longer the only route to concurrency.

    Two caveats before relying on it. It is **Terraform-only** — OpenTofu's `internal/configs/test_file.go` has no `parallel` attribute on `main` as of this check, so a two-engine matrix still needs the workaround for the OpenTofu legs. And `-parallelism=n` is a *different* knob: it limits concurrent operations **within** one run's plan/apply (default 10), not concurrency across runs.

    Also new since the book and worth knowing: **`-junit-xml=path`** for CI test reporting, **`-cloud-run`** for executing tests remotely in HCP Terraform, and the `skip_cleanup` and `state_key` run-block attributes.

### 9.4.7 Terraform testing framework and Copilot

At the time of writing, Copilot did not know the framework existed and would answer a request for a test by recommending Terratest instead. See the dated-snapshot warning in §9.3.7 — the general lesson (LLM tools lag new features by their training data) is the durable part; the specific measurement is not.

---

## 9.5 Refactoring

The bridge from testing: **tests are what make refactoring affordable**. Without a suite, every restructuring is a gamble.

The chapter's framing of why code decays without being touched is the memorable one:

> Write the best module you can today, look at it in a year, and you will want to rewrite half of it — because people learn, standards move, providers change, and Terraform gains features. Before `validation` blocks existed, no module had them; afterwards, the same unchanged code looks sloppy. **Its quality dropped without a single edit.**

### 9.5.1 Refactoring vs. development

Refactoring restructures code to make it easier to maintain and extend. Feature development serves **users**; refactoring serves **developers**.

Organisations defer it because features are what get sold — and that deferral compounds into **technical debt**, which at best slows a team and at worst causes outages.

The chapter's budget, offered as a rule of thumb rather than a law: **~20% of time** on refactoring and code quality for a mature but active codebase; more when paying down accumulated debt.

### 9.5.2 Internal vs. external refactoring

Strictly, refactoring never changes external behaviour — so all refactoring is internal. Language being loose, people say "API refactoring" anyway, so the chapter splits the term:

- **Internal** — invisible to users. Refactor whenever you like.
- **External** — users notice. Needs the management in §9.6.

**The test for which one you are doing is the module's interface: its inputs and outputs.** Change an existing variable or output and it is external. Change neither and it is almost certainly internal.

!!! tip "Your tests are the detector"
    Internal refactoring **should never break your tests**. If it does, the change had consequences you did not intend — which is the whole argument for building the suite first.

### 9.5.3 Reorganizing your project

The cheapest refactor there is, and Terraform makes it free: **it does not care which file a resource is defined in**, because ordering comes from the graph (Ch5). Move resources between files, create and delete files — the plan should show **no changes**.

Keep inputs in `variables.tf` and outputs in `outputs.tf`, but group and head them:

```hcl
#########################
# Networking
#########################

variable "vpc_id" { ... }
variable "subnet_ids" { ... }

#########################
# Load Balancing
#########################

variable "acm_certificate_arn" { ... }
```

### 9.5.4 Renaming resources and modules

Splitting a large `main.tf` is the same free move — either organise with headers or split into multiple files. The chapter declines to prescribe, with an observation worth repeating: **terminal-centric teams tend to prefer one well-organised `main.tf`; IDE-centric teams tend to prefer many files.** Consistency across your modules matters more than which you pick.

Renaming uses the **`moved` block** from Ch6 — without it Terraform destroys and recreates.

!!! warning "A `moved` block is a permanent part of your public interface"
    Adding one is safe. **Removing one breaks compatibility**, because a user still on an older version who upgrades will no longer have the rename recognised — Terraform will destroy and recreate.

    So a `moved` block may only be deleted in a **major** release, and even then the chapter suggests leaving it: it costs nothing to keep.

### 9.5.5 Renaming variables

Renaming an input looks like an automatic break. The **parallel change** pattern (also called *expand and contract*) avoids it:

```hcl
variable "my_old_variable" {
  type    = string
  default = null                    # null is how you detect "user didn't set it"
}

variable "my_new_variable" {
  type    = string
  default = "my_fancy_default"      # the real default now lives here
}

locals {
  use_this_variable = var.my_old_variable != null ? var.my_old_variable : var.my_new_variable
}
```

Then reference `local.use_this_variable` everywhere instead of either input, and mark the old variable deprecated in its `description`. Users migrate on their own schedule; the deprecated variables are deleted in the next major release.

!!! info "📌 Terraform 1.15 has a first-class deprecation mechanism now"
    The chapter's `description`-says-deprecated step was the only option available. Terraform **1.15** added a **`deprecated`** argument on variables and outputs, which emits a real warning to consumers, plus `ignore_nested_deprecations` as the consumer's opt-out. The `locals` shim above is still what carries the *value*; the `deprecated` argument is what carries the *message*. See **I5** in the learning path.

---

## 9.6 External refactoring

"External refactoring" is an oxymoron by the strict definition, but the benefits of refactoring do not stop at the module boundary. Using your own modules teaches you how the **interface** should have been designed — the chapter's example being an organisation with `subnets` in one module and `subnet_ids` in another, a small inconsistency that breaks a developer's flow every time they check the docs.

### 9.6.1 When to break compatibility

Breaking compatibility forces work on users **for no immediate benefit to them**, which is why it is the most annoying thing a module author can do. Sometimes it is unavoidable:

- insecure settings that require new behaviour or defaults
- usability changes such as renaming for consistency
- **provider releases that break compatibility themselves**
- new functionality that cannot work otherwise

The strategy is to **batch** them. Many small breaking releases are worse than one larger one, because each blocks upgrades until users do the work.

!!! tip "Ride the provider's major version"
    The best moment to ship your accumulated breaking changes is when an **upstream provider** releases a major version — your users already have to do migration work, and provider breakage often cascades into your interface anyway.

    The exception, stated plainly: **a genuine security problem does not wait** for a convenient window.

### 9.6.2 Planning your next major version

Two goals in tension — always have the best code, and rarely break users. The reconciliation is a **wishlist**: tickets or a markdown file in the repo where every idea that *would* break compatibility gets parked. New ideas are first checked for a non-breaking route; if there is none, they go on the list.

### 9.6.3 Building your next major version

Trigger it on a provider upgrade, or on time — the chapter's guidance is **no more than one major upgrade a year**.

With more than a single change, develop on a **separate branch** so several people can contribute while `main` stays releasable, tagging `v2.0.0-alpha` / `-beta` along the way.

Write **upgrade notes** as you go, in `UPGRADE.md` or `CHANGELOG.md` — each breaking change documented as it lands, by the person who made it. Written at the end, they are always wrong.

### 9.6.4 Maintaining your previous major version

Releasing the new major does not end the old one. Teams do not all upgrade at once — and **that is the point of semver**, not a failure of it. New features are fairly refused on old versions; **bug fixes** are a judgement call, and fixing them is how you earn trust.

Mechanically: branch off the **tag** of the version you need to patch, and release from there.

---

## Summary

- **Test your code, not your providers.** Logic, transformations, regexes, `dynamic` blocks, and whether the system actually works — not that a variable came back out.
- **Everything hard about IaC testing follows from launching real infrastructure**: time, money, orphaned resources, and name collisions between concurrent runs.
- **Examples are the highest-leverage practice in the chapter** — documentation, a local dev loop, and test fixtures from one artifact, and they cannot rot because the tests run them.
- **Guaranteed teardown is the thing to get right.** `defer` the destroy, raise both timeouts, and keep an account-reset path for when teardown fails anyway.
- **Two frameworks, and the trade is clear.** Terratest gives you Go's ecosystem, a huge helper library, and freedom from engine-version coupling. The native framework gives you one language, no second toolchain, and the ability to assert on values *inside* the module. Start native; expect to meet Terratest regardless.
- **Refactoring is what testing buys you.** Internal refactoring is free and detectable (tests must not break); external refactoring costs users and should be batched, ideally onto a provider major.
- **`moved` blocks are permanent**, variable renames have a no-break pattern, and the old major keeps getting bug fixes.

---

## References

- Terratest — <https://github.com/gruntwork-io/terratest> (read `modules/` for the helper index)
- `gruntwork-io/cloud-nuke` — <https://github.com/gruntwork-io/cloud-nuke> (AWS + GCP, `--dry-run` and `inspect-*`; the recommended replacement for the book's archived `rebuy-de/aws-nuke`)
- `ekristen/aws-nuke` — <https://github.com/ekristen/aws-nuke> (AWS-only; direct successor to the archived repo)
- `ekristen/azure-nuke` — <https://github.com/ekristen/azure-nuke> (Azure; `cloud-nuke` has no Azure support)
- GitHub Copilot — <https://github.com/features/copilot>
- Book's template org — <https://github.com/TerraformInDepth/>
- Source-derived detail — [[terratest-facts]], [[terraform-testing]]
