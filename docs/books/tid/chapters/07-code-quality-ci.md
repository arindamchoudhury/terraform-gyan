# Chapter 7 — Code quality and continuous integration

> *Source: Hafner (2025), **Terraform in Depth**, Chapter 7, pages 207–249.*
>
> The chapter's argument is that writing Terraform *is* writing software, so the tooling software developers spent decades building applies directly. It works outward from the developer's laptop: a **project template** (Cookiecutter) so quality tools are configured before the first resource is written, a **makefile** so nobody has to memorise a dozen commands, **tenv** so engine versions are per-project, and **pre-commit** so the checks run before a commit rather than after a push. Then the tools themselves — `terraform validate`, **TFLint**, **Checkov**, **Trivy**, custom policy in **Rego** or Checkov YAML, and the chore automation (`terraform-docs`, `terraform fmt`, `tflint --fix`). It closes by lifting the exact same makefile targets into **GitHub Actions**, with a matrix that runs every check against both OpenTofu and Terraform, branch protection to make the checks binding, and Dependabot to keep the pins moving.
>
> 📌 **Every version in this chapter has moved.** The book pins TFLint rulesets at `0.29.0`/`0.30.0`, the OPA plugin at `0.6.0`, `pre-commit-terraform` at `rev: v1.88.0`, and every GitHub Action a major or more behind (`checkout@v4`, `setup-terraform@v3`, `setup-opentofu@v1`, `setup-tflint@v4`). Current values are in [[ci-quality-tooling-versions]]; treat the book's numbers as illustrative syntax, never as values to copy. The engine matrix (`1.6`/`1.7`/`1.8`, with `1.10` flagged `experimental`) is likewise stale — current stable is Terraform **1.15.8** / OpenTofu **1.12.5** ([[version-facts]]). The *practices* are unchanged, and they are the point.

> 🔗 **See also:** owns learning-path **A3** (Terraform in CI/CD automation) and feeds **A5** (policy as code) and **B4** (the tooling half of HCL basics). Complements [[code-styling]] (the same toolchain from Anton Babenko's community book) and [[tf-style-guide]] (the rules it enforces). The pipeline-review counterpart, with four real defects in a live harness, is [[krausen-lab-ci-facts]]. Testing is deliberately deferred to the book's Ch9; delivery to Ch8. Topic pages: `code-style-and-tooling` and a new `ci-quality-gates` entry, both on the [topics backlog](../../../topics/index.md).

---

## 7.1 Continuous integration practices

**CI is not "we run tests before merging."** The chapter is emphatic about this. CI is the practice of integrating new work into the mainline **regularly** — high-performing teams several times a day — and the test gate exists to make that safe. Jenkins, GitHub Actions, GitLab Pipelines and CircleCI do nothing on their own; they run the checks a team already built. So a team cannot "adopt CI" before it has a code-quality system worth automating, which is why this chapter spends five sections on tools before it reaches the CI system in §7.7.

The framing device is joining a new team. On a bad team you read all the code because there are no docs, you look up tool invocations every time, errors reach other people's systems, and reviewers argue about formatting instead of behaviour. On a good team there is a template, a makefile, pre-commit hooks, and a PR that reports its own status. The difference is entirely tooling that was set up once.

### 7.1.1 SCM

Terraform arrived long after source control was settled, so much of its ecosystem — module registries especially — assumes GitHub or GitLab. Modern SCMs are more than storage: they carry the action runner, issue tracker, and security scanning the rest of the chapter plugs into.

### 7.1.2 Branching and PRs

The chapter's useful analogy: **a branch is a mini-fork**. Ch1 introduced forks to explain OpenTofu's relationship to Terraform; a branch is the same shape — a temporary copy for isolated work — except that a branch is normally merged back rather than diverging permanently. The merge request is the PR, so named because it asks the main project to *pull* the proposed changes in.

The PR is the hook everything else in the chapter hangs on. It is the one moment where an automated check can block a change before it reaches infrastructure.

### 7.1.3 Code reviews

Three things to look for when reviewing Terraform:

- **Security.** More urgent here than in ordinary software, because the code literally controls infrastructure. Beyond malice, an ordinary misconfiguration can leave a system exposed. The book's example is a database in the wrong subnet, or one with backups never configured — the class of mistake a scanner will not catch, because it depends on understanding what the infrastructure is *for*.
- **Best practices and consistency.** Teams accrete their own naming and style; a change should be consistent both internally and with the team's other modules.
- **Comments and documentation.** The tools generate docs *from* variable descriptions, but somebody still writes the descriptions.

The sharper point is what you should **not** review. Anything a machine can check — formatting, whether the code parses, whether tests pass — should be checked by a machine, so reviewers spend attention on the things only a human can judge.

!!! tip "The reviewer-attention argument"
    The chapter's own heuristic: *if you are reviewing code and have to ask the author what something does, that is a sign a comment belongs in the code.* And time spent automating a check is time repaid at every future review, plus the outages the check prevents.

---

## 7.2 Local development

The premise: if teams are to integrate several changes a day, running the checks locally has to be effortless. Divergence between the local environment and the CI environment is where errors sneak through, so the chapter builds the local setup first and then reuses *the same targets* in CI.

### 7.2.1 Standardizing and bootstrapping with software templates

Configuring quality tools is boring and mostly identical between projects, which is exactly why teams skip it. The fix is to not start from scratch: the same boilerplate, generated.

The cheapest version is a repository of boilerplate you copy — GitHub **Template Repositories** support this natively, and the book calls it a genuinely good first step. It stops being enough when the template needs *logic*: conditional files, generated names, per-provider configuration.

That is where **[Cookiecutter](https://cookiecutter.readthedocs.io/en/stable/)** comes in. Templates are rendered with **Jinja2** (`Jinja2>=2.7,<4.0.0` is a hard dependency of the package), so the generator can ask questions and branch on the answers.

> ⚠️ **Book defect** — the chapter cites Cookiecutter as `https://www.cookiecutter.io/`. That hostname **does not resolve** (DNS `ENOTFOUND`). The project lives at [`cookiecutter/cookiecutter`](https://github.com/cookiecutter/cookiecutter) on GitHub with docs on Read the Docs, linked above. The chapter's worked case is `.tflint.hcl`, where the plugin block depends on which cloud you answered:

```jinja
plugin "terraform" {          # always on, so no conditional
  enabled = true
  preset  = "all"
}

{% if cookiecutter.__short_primary_provider == "aws" %}
plugin "aws" {
  enabled = true
  version = "0.29.0"          # ← stale; see the version callout above
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
{% endif %}
```

Running it produces a project already carrying the whole chapter's configuration:

```bash
cookiecutter gh:TerraformInDepth/terraform-module-cookiecutter
```

```text
.checkov.yml  .github/  .gitignore  .opentofu-version  .pre-commit-config.yml
.terraform-docs.yml  .terraform-version  .tflint.hcl
LICENSE  README.md  main.tf  makefile  outputs.tf  providers.tf  variables.tf
```

The author's template lives in the [TerraformInDepth](https://github.com/TerraformInDepth/) GitHub org and is meant to be forked and made opinionated. It is an active project that also carries Ch8 and Ch9 material, so its prompts will not match the book's transcript exactly.

### 7.2.2 Repeatable tasks with makefiles

The chapter introduces well over a dozen commands. Nobody memorises those, so **Make** records them.

Make is from 1976, is installed almost everywhere, and — for this use — needs about four concepts. That portability is the whole argument for it over language-specific runners like npm `scripts`.

```makefile
.PHONY: hello          # this target does not produce a file, so always run it
hello:
	echo "Hello World"
```

```makefile
.PHONY: chores
chores: format document   # an empty target used purely as a group

.PHONY: format
format:
	terraform fmt

.PHONY: document
document:
	terraform-docs -c .terraform-docs.yml .
```

Two features carry the chapter: **`.PHONY`**, which tells Make the target produces no file so it runs every time, and **prerequisites**, which let an empty target act as a group (`make chores` runs `format` then `document`).

!!! warning "Tabs, not spaces"
    Make requires a **tab** to indent the commands under a target. Spaces produce an error. This is the single most common way a hand-written makefile fails.

Make also echoes each command before running it, which is why the book's transcripts show the command and its output — useful for debugging, and worth knowing so you can read the `@` suppression in §7.3.2.

> ⚠️ **Book defect** — Listings 7.5 and 7.6 have their captions swapped. "Listing 7.5 Using the makefile" contains the `chores: format document` grouping, and "Listing 7.6 Target grouping with makefiles" contains the `$ make hello` usage transcript. Read them the other way round.

### 7.2.3 Installing applications with makefiles

The tool count is itself a barrier to entry, and package managers differ per OS. So detect the package manager in the makefile and put the package list in a variable:

```makefile
BREW_PACKAGES       := cosign tenv terraform-docs tflint checkov trivy
CHOCOLATEY_PACKAGES := cosign tenv terraform-docs tflint trivy

INSTALLER_PATH := $(shell { command -v brew || command -v choco; } 2>/dev/null)
INSTALLER      := $(shell { basename $(INSTALLER_PATH) ; } 2>/dev/null)

.PHONY: install
install: install_$(INSTALLER)      # dispatches to install_brew / install_choco / install_

.PHONY: install_brew
install_brew:
	brew tap tofuutils/tap          # tenv is not in core brew
	brew install $(BREW_PACKAGES)

.PHONY: install_
install_:
	echo "No package manager found."
```

The dispatch trick is worth stealing: `install` depends on `install_$(INSTALLER)`, so an empty `$(INSTALLER)` falls through to the `install_` target and prints a real error instead of failing cryptically. The book's example covers Homebrew and Chocolatey only; Linux needs a branch per `apt`/`yum`/`apk`/`snap`.

> 💭 (mine): the Chocolatey list is one package shorter than the Homebrew list — `checkov` is missing from it, and the book does not say whether that is deliberate. Checkov is a Python package, so `pipx install checkov` is the portable answer on Windows.

### 7.2.4 Terraform and OpenTofu

The book's answer to "which engine do we support?" is: **don't choose in your code**. Replace every literal `terraform` invocation with a variable, and let the caller override it.

```makefile
TF_ENGINE := terraform          # default, overridable from the command line

ifeq ($(TF_ENGINE), terraform)
	TF_BINARY := terraform
else ifeq ($(TF_ENGINE), opentofu)
	TF_BINARY := tofu
endif

.PHONY: format
format:
	$(TF_BINARY) fmt
```

```bash
make format TF_ENGINE=opentofu
```

This is the chapter's best structural idea, and it pays off twice: switching a team's default is a one-line change, and §7.7.3 feeds the same variable from a CI matrix to test both engines with no code duplication.

!!! info "OpenTofu — the third-party tools do not read `.tofu` files"
    The `TF_BINARY` trick handles the *engine*. It does nothing for the **file extension**. OpenTofu **1.8.0** added `.tofu` / `.tofu.json`, and a `.tofu` file **takes precedence over** a same-named `.tf` in the same directory.

    None of this chapter's scanners follow that rule:

    | Tool | `.tofu` support |
    |---|---|
    | TFLint | **No** — the request was closed `not_planned` (2026-07-23) |
    | Checkov | **Not yet** — the implementing PR is still open |
    | terraform-docs | **No** — issue open, implementing PR closed unmerged |

    The failure is silent, which makes it worse than an error. A module written entirely in `.tofu` files makes TFLint exit `0` having parsed nothing. In a *mixed* module the scanner lints the `.tf` file that OpenTofu is ignoring — so it reports on code that never runs.

    **Keep configuration in `.tf` files even on OpenTofu.** Evidence and issue links in [[ci-quality-tooling-versions]].

### 7.2.5 Terraform and OpenTofu versions

Teams lag the latest release, because new versions ship breaking changes and testing takes time. So developers need to switch engine versions per project without reinstalling.

Short history: `tfswitch` and `tfenv` competed, `tfenv` won (it copied the `rbenv`/`pyenv` pattern), and then OpenTofu made both insufficient. **[tenv](https://github.com/tofuutils/tenv)** is the successor — it manages Terraform, OpenTofu **and Terragrunt** (Ch11) from one tool.

tenv works by **hijacking** the `terraform`, `tofu` and `terragrunt` commands and routing each call to the right binary for the current project. It resolves the version from `.terraform-version` / `.opentofu-version`, searching the current directory, then parents recursively, then the home directory, then a system default.

Accepted values in those files:

| Form | Example |
|---|---|
| Exact version | `1.5.7` |
| Constraint | `~>1.5` |
| Channel | `latest`, `latest-stable`, `latest-pre` |
| Constraint-derived | `latest-allowed`, `min-required` |

`tenv tf use VERSION` and `tenv tofu use VERSION` override the file.

!!! tip "`latest-allowed` and `min-required` test your own `required_version`"
    When a module declares a version range, it is a promise to consumers. These two channels resolve to the **maximum and minimum the constraint allows**, so you can actually run the ends of the range you advertised and find out whether the promise is true. Pairs directly with the CI matrix in §7.7.3.

### 7.2.6 Pre-commit hooks

A pre-commit hook is a Git script that runs on `git commit` and blocks it on failure. The point is *when* it catches things: the alternative is discovering an unformatted file after the push, from a red X on a PR, long after you left the problem's mental context.

The chapter uses the **[pre-commit](https://pre-commit.com/)** framework so the hooks are declared in a config file and installed identically by everyone. Two ways to wire it:

**Call your own makefile targets** — the DRY option, since CI runs the same targets:

```yaml
repos:
  - repo: local
    hooks:
      - id: format
        name: Test format
        entry: make test_format
        language: system
        pass_filenames: false
      # …validation, documentation, lint, security — same five fields each
```

`language: system` means "a plain shell command"; `pass_filenames: false` stops pre-commit appending the changed-file list, which these targets do not take.

**Or use the published hooks** from `antonbabenko/pre-commit-terraform`, which covers essentially every tool in this chapter:

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.88.0            # ← stale; current is v1.108.1
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
      - id: terraform_tflint
      - id: terraform_checkov
```

Then `pre-commit install` once per clone, and `pre-commit run` to run everything without committing. Both go in the makefile:

```makefile
.PHONY: precommit_install
precommit_install:
	pre-commit install
```

!!! info "OpenTofu — `tofuutils/pre-commit-opentofu`"
    `pre-commit-terraform`'s hook ids and internals are Terraform-named. The OpenTofu community maintains a fork, **[`tofuutils/pre-commit-opentofu`](https://github.com/tofuutils/pre-commit-opentofu)** (v2.4.2, 2026-06-12), with the equivalent `tofu_*` hooks. The book does not mention it. Note that the fork inherits the `.tofu` blind spot described in §7.2.4 — the underlying tools are the same binaries.

!!! warning "A pre-commit hook is a convenience, not a control"
    `git commit --no-verify` skips every hook, and a fresh clone has no hooks until somebody runs `pre-commit install`. So local hooks shorten the feedback loop; they do not enforce anything. Enforcement is §7.7.4, branch protection, where the check runs on a machine the author does not control.

---

## 7.3 Tools for maintaining quality

### 7.3.1 `terraform validate`

The cheapest check there is. `validate` catches syntax errors and **naming** errors — a misspelled function or attribute — the class of problem that stops the code running at all.

What matters is what it does **not** need: no backend, no variables set. It **does** need an initialised workspace, which in CI you get without touching real state:

```bash
terraform init -backend=false
terraform validate
```

Success prints `Success! The configuration is valid.`; failure gives the same diagnostic you would see at the start of a plan, minus the plan.

```makefile
.terraform:                              # NOT phony — the target is a real directory
	$(TF_BINARY) init -backend=false

.PHONY: test_validation
test_validation: .terraform              # prerequisite: init runs only if .terraform is absent
	$(TF_BINARY) validate
```

!!! tip "The one non-`.PHONY` target in the chapter"
    Make skips a non-phony target whose file already exists. Pointing the target at the real `.terraform` directory means `init` runs on a fresh checkout and is skipped on every subsequent local run — a small speedup, and a nice demonstration of what `.PHONY` actually means everywhere else.

    `-backend=false` also **leaves an existing backend configuration alone**, so putting this in the makefile does not clobber a developer's configured workspace.

### 7.3.2 Terratest and Terraform testing

Two options in the ecosystem, and the chapter only sketches them because **Ch9 is the testing chapter**.

- **[Terratest](https://terratest.gruntwork.io/)** (Gruntwork, 2016) — the long-standing default. Built on Go's testing package, so tests are Go. That is the blocker for many teams and also the strength: anything expressible in an imperative language is expressible as a test. See [[terratest-facts]].
- **The native test framework** — `terraform test` with `.tftest.hcl` suites, shipped in **Terraform 1.6.0**, written in Terraform itself so no second language is needed. Young and moving fast. See [[terraform-testing]].

The chapter stubs both in the makefile, which is worth copying for the `@` idiom:

```makefile
.PHONY: terratest
terratest:
	@echo "Not yet implemented."      # @ suppresses Make's echo of the command itself
```

!!! info "OpenTofu — `tofu test` exists, and has since day one"
    The book says the native framework "is also an area where OpenTofu may lag behind in features as new functionality is released in the HashiCorp Terraform." Read that as a claim about *later additions*, not about the framework's existence.

    OpenTofu **v1.6.0**, its first release, registers the command at `cmd/tofu/commands.go:290`, and its CHANGELOG says: *"the previously experimental `tofu test` command has been moved out of experimental"*, with tests *"written within `.tftest.hcl` files, controlled by a series of `run` blocks"* — the same shape as Terraform 1.6.0. Both engines run `test`; the only question is which later extensions each has. Detail belongs to Ch9.

### 7.3.3 TFLint

A **linter** does static analysis — reads the code without running it — looking for errors, bugs and style violations. It does not reason about your logic; it enforces standards. **[TFLint](https://github.com/terraform-linters/tflint)** is the Terraform one.

TFLint is **plugin-based**, and the surprise is that the generic `terraform` plugin is **not enabled by default** despite shipping alongside the binary. It has to be declared in `.tflint.hcl` at the project root:

```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"    # default; "all" is the other option
}
```

The author's recommendation is to switch to `preset = "all"`, specifically because the rules requiring **descriptions on variables and outputs** are not in `recommended` — and those descriptions are what `terraform-docs` (§7.6.1) turns into documentation. Presets compose in both directions: add rules on top of `recommended`, or disable them on top of `all`.

That claim checks out against the ruleset's own docs, and the two rules have names worth knowing: **`terraform_documented_variables`** and **`terraform_documented_outputs`** are both absent from `recommended`. So is `terraform_comment_syntax`, which is why the book has to enable it explicitly in its next listing. (`terraform_module_pinned_source` and `terraform_module_version`, by contrast, *are* in `recommended`.)

The cloud rulesets are maintained by the same team, and are large:

| Plugin | Rule count (book's figures) |
|---|---|
| `aws` | 700+ |
| `google` | 200+ |
| `azurerm` | 100+ |
| `opa` | special — write your own (§7.5.1) |

```hcl
plugin "aws" {
  enabled = true
  version = "0.30.0"        # ← stale; current is v0.48.0
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
```

> ⚠️ **Book defect** — the two listings disagree with each other: the Cookiecutter template in §7.2.1 pins `tflint-ruleset-aws` at `0.29.0`, this one at `0.30.0`. Both are long stale, so it only matters as a reminder that a template's pins and a chapter's prose drift apart the moment they are written down twice.

Plugins are installed with `tflint --init`, the same shape as `terraform init`. The book runs it every time because it is fast and idempotent:

```makefile
.PHONY: test_tflint
test_tflint:
	tflint --init
	tflint
```

**Two ways to disagree with a rule**, and the distinction matters. Disable it project-wide in the config:

```hcl
plugin "terraform" {
  enabled = true
  preset  = "all"
}

rule "terraform_comment_syntax" {   # enabled by "all"; we want // as well as #
  enabled = false
}
```

Or suppress a single occurrence with a magic comment:

```hcl
resource "aws_instance" "this" {
  ami = "ami-867166b8518f055af"
  # tflint-ignore: aws_instance_invalid_type
  instance_type = "p8.48xlarge"     # beta instance family TFLint has never heard of
}
```

The inline form is the better default. The chapter's examples for it are both about the *ruleset* being behind reality rather than the code being wrong: a new AWS instance family not yet in the ruleset, or `terraform_module_pinned_source` firing on a module that has no release to pin to yet.

!!! note "Two TFLint rules cover a gap Terraform itself cannot"
    `terraform_module_pinned_source` and `terraform_module_version` enforce module pinning — and there is no module lock file, so nothing in Terraform can check this. That is the connection to **I4**: the exact-pin discipline is only real if something enforces it, and TFLint is the cheapest thing that does. Building your own plugin is possible but requires Go; the easier route to custom rules is §7.5.

---

## 7.4 Validating security

The IaC-specific opportunity: with manual infrastructure you can only review security **after** it exists. With code you can analyse it **before** it is deployed, so a misconfiguration never becomes a vulnerability.

Two free tools, and the chapter's advice is to run **both**. They are free, they overlap imperfectly — Trivy covers more providers, Checkov has rules Trivy lacks — and redundancy in security scanning costs nothing but CPU. Neither replaces the human review from §7.1.3.

### 7.4.1 Checkov

**[Checkov](https://www.checkov.io/)** scans Terraform code, Terraform **plans**, and other IaC formats (Helm, CloudFormation). It runs entirely locally with no central service, so it is free in both senses.

It has essentially **no config file** — everything is command-line flags. That makes recording the invocation in the makefile more important than usual, because a customisation *is* a flag change:

```makefile
.PHONY: security
security: test_checkov

.PHONY: test_checkov
test_checkov:
	checkov --directory .
```

Findings are either fixed or explained. When a finding is genuinely intentional — a deliberately public dataset, a weaker cipher for legacy clients — you suppress it **in the code, with a reason**:

```hcl
resource "aws_instance" "this" {
  ami           = "ami-867166b8518f055af"
  instance_type = "t3.large"

  #checkov:skip=CKV_AWS_88:This instance is meant to be publicly accessible.
  associate_public_ip_address = true
}
```

The reason string is the load-bearing part. It tells the reviewer why, and it is what makes the exception auditable later.

!!! warning "One exception, not all of them"
    The chapter is explicit that its own example triggers several rules and suppresses exactly one. Every finding gets reviewed; only the intended ones get exceptions. Suppressing to silence the tool is how a scanner becomes decoration.

### 7.4.2 Trivy (formerly TFSec)

**[Trivy](https://trivy.dev/)** (Aqua) is the second scanner. Its IaC engine is built by the team behind **tfsec**, which is now deprecated and folded in — the `aquasecurity/tfsec` repo's own description reads "Tfsec is now part of Trivy". *(The book's heading says "formally TFSec"; that is a typo for "formerly".)*

```makefile
.PHONY: security
security: test_checkov test_trivy     # the group target now earns its keep

.PHONY: test_trivy
test_trivy:
	trivy config .
```

Two suppression mechanisms, with different blast radius:

```text
# .trivyignore — disables the rule for the ENTIRE project
# Allow public IP addresses to be used in this module.
AVD-AWS-0009
```

```hcl
resource "aws_instance" "this" {
  ami           = "ami-867166b8518f055af"
  instance_type = "t3.large"

  #checkov:skip=CKV_AWS_88:This instance is meant to be publicly accessible.
  # Trivy: Ignore Public IP address rule.
  #trivy:ignore:AVD-AWS-0009
  associate_public_ip_address = true
}
```

Prefer the inline form: `.trivyignore` is project-wide, which is almost never what you mean. Note the asymmetry with Checkov — **`trivy:ignore` takes no reason string**, so the justification has to be an ordinary comment placed above it. And the two tools' suppressions coexist happily on the same resource, which is what running both looks like in practice.

### 7.4.3 Snyk, Checkmarx and Mend

The commercial tier. What they add over the free tools is not primarily rules but **a platform**: central dashboards across many repositories, and features like SBOM generation that security teams increasingly ask for.

The author's position is pragmatic. If you have licences, use them. If you don't, Checkov and Trivy are enough. And keep Checkov even alongside a paid tool, because after setup it costs nothing.

---

## 7.5 Custom policy enforcement

Beyond "is this code correct" and "is this code secure" sits "does this code follow **our** rules" — technical, compliance, financial or contractual. Both Checkov and Trivy can carry custom policy.

The motivating example is not a security bug at all: when AWS released **GP3** volumes in 2021 they were faster *and* cheaper than **GP2**, so continuing to use GP2 was a pure loss. Nothing about that is a code error, and no generic ruleset will flag it — but it is exactly the kind of decision a team can encode once.

This section is about policy on the **source**. Policy on the **plan** — what Terraform will actually do — is Ch8, and Sentinel/OPA-on-plan is learning-path **A5**.

### 7.5.1 OPA with TFLint

**OPA** is a general policy framework using the **Rego** language. TFLint's `opa` plugin lets you write TFLint rules in Rego, with policies living in `.tflint.d/policies`:

```hcl
plugin "opa" {
  enabled = true
  version = "0.6.0"          # ← stale; current is v0.11.0
  source  = "github.com/terraform-linters/tflint-ruleset-opa"
}
```

```rego
package tflint
import rego.v1

deny_invalid_s3_bucket_name contains issue if {
	buckets := terraform.resources("aws_s3_bucket", {"bucket": "string"}, {})
	name := buckets[_].config.bucket
	not startswith(name.value, "example-com-")
	issue := tflint.issue(`Bucket names should always start with "example-com-"`, name.range)
}
```

!!! warning "The book tells you to skip this section"
    Its own NOTE: *learning Rego is hard*, the plugin is still **experimental**, and you should reach for OPA-with-TFLint only if **your team already runs OPA somewhere else**. Otherwise go straight to §7.5.2 — Checkov YAML does the same job for a fraction of the effort. That is unusually direct advice for a book to give about its own content, and it is right.

### 7.5.2 Custom Checkov rules

The pragmatic path. Checkov reads custom policies from **plain YAML** — no Rego, no Go.

The worked example blocks GPU instance families (`p*`, `g*`), which are expensive enough that an accidental launch is a budget event:

```yaml
---
metadata:
  name: "Disable the P and G families of AWS Instances."
  id: "CKV2_CUSTOM_AWS_1"        # use your company name in the id to avoid collisions
  category: "COST_SAVINGS"       # categories drive reporting
definition:
  and:
    - cond_type: "attribute"
      resource_types: ["aws_instance"]
      attribute: "instance_type"
      operator: "not_regex_match"
      value: '^p\d\..*$'
    - cond_type: "attribute"
      resource_types: ["aws_instance"]
      attribute: "instance_type"
      operator: "not_regex_match"
      value: '^g\d\..*$'
```

Checkov can also express policies in **Python**, and the chapter says not to. The only case that justifies it is a policy needing an API call; everything else pays complexity for nothing.

**Distribution** is the part worth designing. Copying policies into every repository is a maintenance trap, so Checkov can load them straight from a Git repository — one shared policy repo, every module picks up updates automatically. Since Checkov has no config file, this too is a flag, and therefore a makefile variable:

```makefile
CHECKOV_OPTIONS := --external-checks-git https://github.com/YOUR_ORGANIZATION/custom_policies.git

.PHONY: test_checkov
test_checkov:
	checkov --directory . $(CHECKOV_OPTIONS)
```

> 💭 (mine): this is the same centralisation argument as a private module registry, one layer up — the policies become a versioned artifact with one owner. It also means a policy change ships to every project on their next run, with no PR anywhere. Worth pinning the policy repo to a tag once the set is large enough to matter.

---

## 7.6 Automating chores

Formatting and documentation are busy work, so automate them behind one target:

```makefile
.PHONY: chores
chores: documentation format
```

`make chores` now updates docs and formatting in one command. Note what is deliberately **excluded** — `tflint --fix` (§7.6.3), because it changes semantics rather than presentation.

### 7.6.1 terraform-docs

**[terraform-docs](https://github.com/terraform-docs/terraform-docs)** reads the configuration and generates documentation — usually markdown tables of inputs, outputs, modules and resources. Its best feature is **inject mode**: it writes between two marker comments and leaves the rest of the file alone, so it can run repeatedly against a hand-written README.

```markdown
# My Module

This is where you'd put a description of the module.

## Usage
<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
```

```yaml
# .terraform-docs.yml
formatter: "markdown table"   # required
output:
  file: "README.md"
  mode: inject
sort:
  enabled: true
  by: required                # default is "name"; "required" puts required variables first
```

```makefile
.PHONY: documentation
documentation:
	terraform-docs -c .terraform-docs.yml .

.PHONY: test_documentation
test_documentation:
	terraform-docs -c .terraform-docs.yml --output-check .
```

The pair is the pattern the whole chapter uses: a **chore** target that changes files, and a **test** target that only checks. `--output-check` fails if the docs are out of date without writing anything, which is what makes it usable as a CI gate. Options can be passed as flags, but a config file keeps output consistent between developers.

This is also where §7.3.3's advice pays off: enabling TFLint's `all` preset forces descriptions onto every variable and output, and those descriptions are precisely what lands in the generated table.

!!! info "OpenTofu — terraform-docs has no OpenTofu support"
    Beyond the `.tofu` extension gap in §7.2.4, terraform-docs also **breaks** on OpenTofu's provider `for_each` ([issue #895](https://github.com/terraform-docs/terraform-docs/issues/895), open). First-class `.tofu` support is [issue #811](https://github.com/terraform-docs/terraform-docs/issues/811) (open, reopened) and its implementing [PR #833](https://github.com/terraform-docs/terraform-docs/pull/833) was closed unmerged. An OpenTofu project using OpenTofu-specific syntax should expect to document by hand.

    ⚠️ A widely repeated explanation for this — *"terraform-docs is stuck because it parses with HashiCorp's `terraform-config-inspect`"* — is **false**, and I had it in this note until I checked. Its `go.mod` requires **`github.com/terraform-docs/terraform-config-inspect`**, the project's own fork, alongside `hashicorp/hcl/v2`. They control the parser, so nothing structural blocks OpenTofu support. Don't substitute a different guess for it either: the nearest thing to a stated cause is [issue #845](https://github.com/terraform-docs/terraform-docs/issues/845), which is a *contributor* asking whether the project is still maintained and floating a transfer to the Linux Foundation, with no maintainer answer recorded.

### 7.6.2 `terraform fmt`

Formatting is not required to run Terraform, but consistent code is easier to read and Terraform ships a style guide it can apply itself.

```makefile
.PHONY: format
format:
	$(TF_BINARY) fmt -recursive .

.PHONY: test_format
test_format:
	$(TF_BINARY) fmt -check -recursive .
```

Same chore/test split. `-check` makes no changes and exits non-zero if it *would have*, which is the difference between a gate and a suggestion.

The chapter is honest about the tool's ceiling: `fmt` is **rudimentary by design**. It normalises whitespace and alignment. It says nothing about naming, structure, or whether the code is a good idea — that is what TFLint and the scanners are for.

### 7.6.3 `tflint --fix`

TFLint can repair many of its own findings. The simpler the rule, the more likely it is auto-fixable — comment style, for instance. Fixed files are also reformatted, so unrelated whitespace may change, which is the same effect as running `fmt`.

```makefile
.PHONY: tflint_fix
tflint_fix:
	tflint --init
	tflint --fix
```

!!! warning "Autofix is the one chore deliberately kept out of `chores`"
    TFLint pushes best practices, and best practices are sometimes wrong for your application — the book's case is code deliberately using a deprecated AWS feature, where a blind autofix would have changed working infrastructure.

    The prescribed order is: **run `tflint`, read the findings, add exceptions for the intentional ones, then autofix the remainder.** Formatting and docs can be applied unseen because they cannot change behaviour; a lint fix can.

---

## 7.7 Enforcing quality with CI systems

Everything so far runs on a laptop and is therefore optional. This section makes it binding.

### 7.7.1 Selecting a CI system

The advice is deliberately boring:

1. **Already have a CI system? Use it.** Nothing about Terraform makes CI special. (Delivery is a different story — that is Ch8.)
2. **Otherwise, use your SCM's built-in one.** GitHub Actions and GitLab Pipelines handle every case in this chapter, with no SCM↔CI integration to wire up. The author would end the search here.
3. **Self-hosting** is available and usually not worth it. Small teams should use the SaaS versions; organisations big enough to need something bespoke have a team for it.

### 7.7.2 Building the basic workflows

Every modern CI system has the same shape — jobs with triggers and steps — and a job is nearly always three moves: **check out the repo → install the tool → run the check**. The vocabulary differs (GitHub *marketplace action*, GitLab *component*, CircleCI *orb*), the concepts do not.

```yaml
# .github/workflows/tflint.yml
name: Lint
on:
  push:
  pull_request:

jobs:
  tflint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source code
        uses: actions/checkout@v4              # ← stale; current major is v7

      - name: Setup TFLint
        uses: terraform-linters/setup-tflint@v4  # ← stale; current major is v6

      - name: Run TFLint
        run: make test_tflint                  # ← the point of the whole chapter
```

That last line is the payoff for §7.2.2. CI runs **the same target a developer runs locally**, so the two environments cannot drift apart, and the workflow contains nothing project-specific — any module with this makefile can reuse it verbatim. Which is why the workflows belong in the Cookiecutter template from §7.2.1: a new project has working CI before its first resource exists.

!!! danger "Pin third-party actions by commit SHA, not by tag"
    The book uses floating major tags (`@v4`) throughout, and tags are mutable — whoever controls the action repository can repoint one at new code that runs with your runner's token and secrets. This is a live supply-chain class, not a hypothetical. `uses: actions/checkout@<40-char-sha>` is the safe form, with Dependabot (§7.7.5) moving the SHA. The harness in [[krausen-lab-ci-facts]] gets this right for its AWS credential action and demonstrates the pattern.

### 7.7.3 Validating both OpenTofu and Terraform

Most checks are engine-independent: Checkov, TFLint and terraform-docs are standalone programs that never invoke a binary. **Three things do** depend on the engine:

- formatting
- validation
- testing (Ch9)

In theory both engines agree. The chapter's line is that "reality has a habit of getting in the way of these theories", so confirm it. GitHub Actions' **matrix strategy** runs the same job once per combination, and `TF_ENGINE` from §7.2.4 is what it varies:

```yaml
name: Validation
on:
  push:
    branches: [main]        # other branches are covered by pull_request
  pull_request:

jobs:
  validation:
    strategy:
      fail-fast: false      # one failing leg must not hide the others
      matrix:
        engine:  ["opentofu", "terraform"]
        version: ["1.6", "1.7", "1.8"]
        experimental: [false]
        include:                     # extra legs the cross-product cannot express
          - engine: "terraform"      # 1.9 shipped for Terraform before OpenTofu, so
            version: "1.9"           # it cannot come from the engine × version product
            experimental: false      # …but it is released, so it must pass
          - engine: "terraform"
            version: "1.10"          # prerelease at the time of writing
            experimental: true       # …so it reports without blocking
    continue-on-error: ${{ matrix.experimental }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Terraform
        uses: hashicorp/setup-terraform@v3
        if: ${{ matrix.engine == 'terraform' }}
        with:
          terraform_version: ${{ matrix.version }}

      - name: Install OpenTofu
        uses: opentofu/setup-opentofu@v1
        if: ${{ matrix.engine == 'opentofu' }}
        with:
          tofu_version: ${{ matrix.version }}

      - name: Test Validation
        run: make test_validation TF_ENGINE=${{ matrix.engine }}
```

Three mechanisms worth extracting:

- **`fail-fast: false`** — without it the first failure cancels the rest, and you learn about one broken combination instead of all of them.
- **`include:`** — adds legs the cross-product cannot express. Here it is needed because a version existed for one engine and not the other, which is exactly the situation a two-engine matrix keeps producing.

    ⚠️ **The book's Listing 7.41 is internally inconsistent here.** It prints `version: "1.10"` on *both* include entries, while its own annotations describe the first as the 1.9 case (*"since v1.9 has only been released for Terraform we add this field to our matrix"*, *"OpenTofu is working on their v1.9 release, while Terraform's has released"*) and only the second as the alpha. Its stated total — *"our settings result in eight tests running"* — needs 6 product legs plus 2 distinct include legs, which only works on the 1.9/1.10 reading. The block above is rendered that way; the printed listing is wrong or its callout leaders are mispointed.
- **`continue-on-error: ${{ matrix.experimental }}`** — a per-leg switch for "run this, report it, but do not block the merge". That is how you test a prerelease without making it a gate.

!!! warning "Test the versions you actually promise"
    The book's own WARNING: if `required_version` starts at 1.7, drop 1.6 from the matrix — you are testing a combination you do not support while not testing ones you do. Reusable modules want a **wide** matrix; a private root module can pin to one version.

    Combine with §7.2.5: `min-required` and `latest-allowed` resolve the ends of your declared constraint, so the matrix can be derived from the promise rather than maintained beside it.

!!! info "OpenTofu — the setup actions are both several majors on"
    `hashicorp/setup-terraform` is now **v4** and `opentofu/setup-opentofu` is **v2** (which verifies the download against published `SHA256SUMS` by default — a real reason to upgrade). The book's `@v3` / `@v1` are the versions of its time. [[ci-quality-tooling-versions]] has the table.

### 7.7.4 Branch protection and required pipelines

Tests that can be ignored are not gates. Every SCM can block a merge until conditions are met, and the two conditions that matter are almost always:

1. **Tests pass** — otherwise `main` breaks and everyone else is blocked.
2. **Someone other than the author approved** — quality control and a security control at once, since it means no single person can introduce functionality unreviewed.

Enabling it is a settings-page toggle, and it should be one of the first things done once a repository is in production.

The obvious objection is emergencies: an outage, nobody around to approve, or a broken test suite. Both GitHub and GitLab allow an explicit override checkbox on the PR. The chapter's framing is worth keeping — **these controls exist to help, and a control with no escape hatch gets routed around permanently rather than bypassed once.**

### 7.7.5 Automated updates with Dependabot

A pipeline gates the changes *you* make. It does nothing about pins going stale, and this chapter has produced a lot of pins — ruleset versions, hook `rev:`s, action tags, module and provider versions. **Dependabot** opens a PR when a dependency moves, so the update arrives with a version diff and runs through the same gates as any other change.

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"   # finds .github/workflows from the root
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "terraform"        # modules and providers
    directory: "/"
    schedule:
      interval: "weekly"
```

Private module registries need a `registries:` block, with the token from the repository's secret store:

```yaml
    registries:
      terraform-private:
        type: terraform-registry
        url: https://my.private.registry.com
        token: ${{secrets.TERRAFORM_REGISTRY_API_TOKEN}}
```

!!! warning "Dependabot must be able to reach the registry"
    It runs as a GitHub service, so a registry behind a firewall or on a private network simply fails. **Self-hosted runners** are the documented workaround. Dependabot is open source though GitHub-owned; a community fork supports GitLab with more setup effort.

    Two limits the chapter does not mention, from [[krausen-lab-ci-facts]]'s neighbourhood in **A3**: Dependabot **skips non-semver refs**, so a Git module source pinned to a commit SHA — the supply-chain-safe form recommended in §7.7.2 — is never updated by it, and needs a manual review cadence. Renovate cannot do it either.

---

## Summary

The chapter's own closing points, plus the two structural ideas that make the rest work:

- IaC's real advantage is that **decades of software-development practice transfer directly**. Linters, formatters, scanners and CI were all built for other languages and apply unchanged.
- Automation is what **reduces the cognitive load of review** — reviewers should be spending attention on security and design, not formatting.
- Safety nets make teams **faster**, not slower, because the cost of a caught mistake is minutes and the cost of a missed one is an incident.
- **Two structural ideas carry everything else.** The **makefile** is the single interface — the same target runs on a laptop, in a pre-commit hook, and in CI, so those three environments cannot drift. The **template** (Cookiecutter) means a new project inherits the entire arrangement before its first resource exists, which is the only way this survives contact with the third project.
- The `TF_ENGINE` variable is the small idea with the largest reach: it turns "which engine?" from a code decision into a runtime argument, which is what makes the two-engine CI matrix free.
- Every tool in the chapter is optional until **branch protection** makes it binding. That is the line between a code-quality *system* and a code-quality *suggestion*.
- CD is deliberately absent. CI and CD are usually said in one breath, but delivery with Terraform has enough nuance to need Ch8 to itself.

---

## References

- Cookiecutter — <https://cookiecutter.readthedocs.io/en/stable/> (the book's `www.cookiecutter.io` does not resolve)
- The author's template org — <https://github.com/TerraformInDepth/> (`terraform-module-cookiecutter`)
- pre-commit framework — <https://pre-commit.com/>
- `antonbabenko/pre-commit-terraform` — <https://github.com/antonbabenko/pre-commit-terraform>
- `tofuutils/pre-commit-opentofu` — <https://github.com/tofuutils/pre-commit-opentofu>
- tenv — <https://github.com/tofuutils/tenv>
- TFLint — <https://github.com/terraform-linters/tflint>
- TFLint OPA ruleset — <https://github.com/terraform-linters/tflint-ruleset-opa>
- terraform-docs — <https://github.com/terraform-docs/terraform-docs>
- Checkov — <https://www.checkov.io/>
- Trivy — <https://trivy.dev/>
- Terratest — <https://terratest.gruntwork.io/>
- Current versions for all of the above — [[ci-quality-tooling-versions]]
