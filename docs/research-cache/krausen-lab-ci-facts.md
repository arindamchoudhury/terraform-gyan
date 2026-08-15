# Krausen's lab CI harness — a real pipeline, read as an A3 case study

`btkrausen/terraform-testing` is the GitHub Actions harness that validates the Terraform lab
configurations used across Bryan Krausen's courses — the same author as **KL**
(`terraform-associate-labs`) cited in **B3**, **B9** and elsewhere. It is small enough to read
end to end and does the things **A3 — Terraform in CI/CD automation** teaches, which makes it a
better worked example than a synthetic pipeline. It also contains four defects that are precisely
the failure modes A3 warns about, so it doubles as the negative example.

_Source: `C:\opt\learn\terraform\repos\terraform-testing`, remote `github.com/btkrausen/terraform-testing`,
at `c5f86bb` ("Update comment for required Terraform version", 2025-11-09), level with `origin/main`.
Last verified: 2026-08-15._

!!! note "Read this as pipeline review, not as Terraform behaviour"
    Like [[tf2026-course-facts]], this note reviews someone's material rather than establishing how
    a tool behaves. The defects below are shell and Actions semantics, verifiable by reading the
    workflow; none of them says anything about Terraform itself.

## What it is

Three workflows — `aws_lab_validation.yml`, `azure_lab_validation.yml`, `github_lab_validation.yml` —
each running a **matrix over lab directories**, on push, on pull request, and on a **weekly Sunday
cron**. The lab code lives at `modules/tfb/{aws,azure,github}/lab_01…lab_16` (16 labs per provider)
plus a single `modules/tfhol/lab_02`.

The README states the purpose plainly, and the weekly cron is the part worth stealing: the point is
not to test the author's code, it is to detect when **someone else's** release breaks it — a new
provider major, a new Terraform version, a module change. Failures are meant to open an issue
automatically. Keeping the harness in a separate repository from the course material is a
deliberate choice, so students never see the CI scaffolding.

## The pattern worth copying

| Practice | As implemented |
|---|---|
| **OIDC instead of static keys** | `permissions: id-token: write` plus `aws-actions/configure-aws-credentials` with `role-to-assume: arn:aws:iam::${{ secrets.ACCOUNT_ID }}:role/github-actions` — no `AWS_ACCESS_KEY_ID` anywhere in that job |
| **Action pinned by commit SHA** | `aws-actions/configure-aws-credentials@e3dd6a429d…` rather than `@v4`, which is the supply-chain-safe form |
| **Least-privilege token** | an explicit `permissions:` block (`contents: read`, `issues: write`, `pull-requests: write`, `id-token: write`) instead of the default write-all |
| **Automation-aware Terraform** | `TF_IN_AUTOMATION: "true"` and `TF_CLI_ARGS: "-no-color"` set at job level |
| **No wrapper** | `hashicorp/setup-terraform@v3` with `terraform_wrapper: false`, so step outputs are the real exit codes rather than the action's wrapper output |
| **Config-only validation** | `terraform init -backend=false`, which validates without touching or creating remote state |
| **Isolation per matrix leg** | each lab is copied into `mktemp -d` before running, with a cleanup step `if: always()` |
| **Independent legs** | `fail-fast: false`, so one broken lab does not hide the state of the other fifteen |
| **Scheduled drift detection** | the weekly cron, which is what catches upstream breakage between commits |

`TF_IN_AUTOMATION` and `-backend=false` are the two most transferable details. The first suppresses
the "next steps" advice Terraform prints for humans; the second is what makes a plan-only gate
runnable in a repository that has no business initialising the real backend.

## Four defects, each an A3 lesson

### 1. The plan gate is inert — it cannot fail

Present in **all four jobs across all three workflows** (`aws:97`, `aws:194`, `azure:106`,
`github:92`):

```bash
terraform plan -input=false -detailed-exitcode || true
# Save the exit code to a file that can be read in the next step
echo $? > plan_exit_code.txt
```

`$?` holds the status of the **last command executed**, which is `true`, not `terraform plan`. So
the file always contains `0`, and the "Check Plan Result" step that reads it always takes the
`✅ Plan successful - No changes required` branch. A lab whose plan errors reports success, and the
badge stays green.

The intent is visible and correct: `-detailed-exitcode` returns **0** for no changes, **2** for
changes, **1** for an error, and the checking step handles all three. The `|| true` was needed
because a GitHub Actions `run:` block fails the step on a non-zero status, and 2 is non-zero. The
fix is to capture before the fallback swallows it, either

```bash
terraform plan -input=false -detailed-exitcode; echo $? > plan_exit_code.txt
```

with `continue-on-error: true` on the step, or in one line:

```bash
set +e
terraform plan -input=false -detailed-exitcode
echo $? > plan_exit_code.txt
```

This is the exact shape of the point **A3** already makes about `terraform fmt -check`: a step that
runs a command and then does not act on its status is decoration, not a gate. Worth teaching with
this example because the author clearly knew about `-detailed-exitcode` — the failure is in one
shell idiom, not in the design.

### 2. The failure notifier never runs

```yaml
needs: [test-tfb-labs, test-hol-labs]
if: always() && contains(needs.test-labs.result, 'failure')
```

There is no job called `test-labs`, so `needs.test-labs` resolves to null, `contains` is false, and
the `notify-failures` job is skipped on every run. The same `if:` appears in all three workflows
(`aws:235`, `azure:149`, `github:133`). The README's promise that failures "automatically create an
issue on the repo" therefore does not happen.

The downstream API call has a second, independent mismatch: it filters jobs with
`select(.name | contains("Test Labs"))`, while the jobs are named `TFB Labs` and `TFHOL Labs`. Even
if the `if:` were fixed, the summary would be empty.

Lesson for A3: a `needs` context reference is not validated at parse time, and a skipped job looks
identical to a passing one in the run summary. Alerting paths need a deliberate failure to prove
they work — the same reasoning that makes people test their pager.

### 3. `terraform fmt` is advertised but never run

The README says each module goes "through a `fmt`, `validate`, `init`, and `plan`". Grepping the
workflows for `fmt` returns nothing. Only `init`, `validate` and `plan` steps exist.

### 4. `scripts/test.sh` is dead code, and would misbehave if used

Nothing in `.github/` references it. It downloads a pinned Terraform version, retries three times,
verifies the zip with `unzip -t`, then runs init/validate/plan — a decent script, and it captures
the plan exit code the right way:

```bash
terraform plan -no-color -detailed-exitcode
PLAN_EXIT_CODE=$?
```

But the script opens with `set -e`, and under `set -e` a command returning **2** aborts the script
immediately. Since 2 means "plan succeeded, changes present" — the normal outcome for these labs —
the script exits before reaching the line that reads `$?`, and the branch written to translate 2
into a success `exit 0` is unreachable. So the two implementations fail in **opposite** directions:
the workflow can never fail, the script can never pass a lab that has changes to make.

The pair is worth showing together in a chapter. `-detailed-exitcode` is genuinely awkward to
consume, because the value that means "everything is fine" is also the value that shell error
handling treats as failure.

## Smaller observations

- The AWS workflow's two jobs use **two different credential models**: the TFB job authenticates
  with OIDC, while the TFHOL job in the same file passes `AWS_ACCESS_KEY_ID` and
  `AWS_SECRET_ACCESS_KEY` from secrets. A partial migration frozen in place, and a good prompt for
  "which of these two jobs would leak if the runner were compromised".
- The Azure workflow uses `azure/login@v1`, unpinned and a major version behind the current `v2`,
  and exports `ARM_SUBSCRIPTION_ID` from a secret.
- Terraform is installed as "Latest" with no version pin, which is intentional here — the harness
  exists to find out when the newest release breaks a lab — but it is the opposite of what a
  production pipeline should do.

## What this does and does not say about the labs

**KL** (`btkrausen/terraform-associate-labs`, cited in the path) is a *different* repository from the
`modules/tfb/**` labs this harness validates, so none of the above changes the standing of KL. What
it does change is how much the green badge on this repo means: `init` and `validate` failures are
caught for real, since those steps fail the job directly, while **`plan` failures are not caught at
all**. So "these configurations still parse and validate against the latest Terraform and provider"
is supported; "these configurations still plan cleanly" is not.

## Sources

- Local checkout `C:\opt\learn\terraform\repos\terraform-testing` @ `c5f86bb` (2025-11-09)
- `.github/workflows/{aws,azure,github}_lab_validation.yml`, `scripts/test.sh`, `README.md`
- Exit-code semantics of `terraform plan -detailed-exitcode` (0 / 1 / 2) — [`terraform plan` CLI docs](https://developer.hashicorp.com/terraform/cli/commands/plan)
