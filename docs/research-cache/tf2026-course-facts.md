# TF2026 Course Companion Repo — coverage map and caveats

What the **TF2026** video course (Rahul Oli, *Terraform Complete Course in One Video*) actually
teaches, read from its companion repository rather than inferred from the video's chapter titles.
Used to place the course's citations accurately in [[learning-path]] and to record where its
practices have aged.

_Source: `C:\opt\learn\terraform\repos\Terraform-Full-Course-2026`, remote
`github.com/devopsforge2304/Terraform-Full-Course-2026`, at `4f1928e` ("Added Lecture13 notes",
2026-03-25), which is level with `origin/main`. Thirteen lecture directories plus a `README.md`
syllabus and `installation.md`. Last verified: 2026-08-15._

!!! note "This is a different kind of note"
    [[terragrunt-facts]], [[terratest-facts]], [[terrakube-facts]] and [[floci-facts]] mine tools,
    where the source settles how something behaves. This repo is **teaching material**, so the
    source settles a different question: what a citation to this course actually buys, and which of
    its habits should not be copied. Treat the verdicts here as review, not as Terraform facts.

## What the repo contains

Four lectures carry prose notes (`LectureNotes.md`: 01, 03, 10, 13); the rest are runnable `.tf`
plus a few architecture PNGs. Everything targets **AWS**, and there is no Azure, GCP or OpenTofu
material anywhere.

| Lecture | Files | What it demonstrates |
|---|---|---|
| 01 | notes | IaC framing: manual vs automated, imperative vs declarative, Terraform architecture |
| 02 | `main.tf` | first resource |
| 03 | notes + full set | HCL components: variables, `tfvars`, outputs, providers, `count` |
| 04 | + `userdata.sh` | EC2 with user data, variables driving instance shape |
| 05 | + `graph.png` | loops — `count`, `for_each`, `dynamic` blocks |
| 06 | `main.tf`, `graph.png` | the dependency graph: VPC → subnet implicit dependency, plus `depends_on` |
| 07 | `backend/`, workflow diagrams | remote state: an S3 bucket with SSE, versioning and public-access block, then a `backend "s3"` block |
| 08 | `modules/{network,security,ec2}` | three local modules wired by output-to-input (`module.network.vpc_id`) |
| 09 | `workspaces-demo/`, 4 diagrams | environment management via CLI workspaces |
| 10 | notes | sensitive variables, secret managers, `fmt` / `validate` / `tflint` / `checkov` |
| 11 | `main.tf` | `create_before_destroy`, `prevent_destroy`, commented `ignore_changes` |
| 12 | `main.tf`, `app.py` | provisioners: `file`, `remote-exec`, `local-exec`, `connection` over SSH |
| 13 | notes | debugging: `TF_LOG` levels, provider errors, state conflicts, failed-apply recovery |

## Map to learning-path topics

The path already cites three timestamps. This is where the rest of the course lands:

| Lecture | Path topic |
|---|---|
| 01–02 | **B1** IaC fundamentals, **B2** install and first project |
| 03 | **B4** HCL basics, **B6** variables/outputs/locals |
| 04–05 | **B7**/**I1** meta-arguments, **I3** dynamic blocks |
| 06 | the dependency graph ([[dependency-graph]]) |
| 07 | **B8** state fundamentals, **I6** backends |
| 08 | **I4** using modules, **I5** authoring modules |
| 09 | **A7** environment isolation — *with the conflict below* |
| 10 | **A6** secrets, **B4** formatting; **not A2**, see below |
| 11 | **I2** lifecycle |
| 12 | provisioners (a last-resort topic) |
| 13 | **E5** debugging and troubleshooting |

Nothing in the repo touches the Advanced or Expert half of the path: no HCP Terraform, no policy as
code beyond a `checkov` mention, no CI/CD pipeline, no Terragrunt, no Stacks, no provider
development, no multitenancy, and **no OpenTofu** — the strings `tofu` and `opentofu` appear zero
times in the repository.

## Four things not to copy

Each was found in the committed code, not inferred from the video.

### 1. Workspaces used as environments, which is the pattern the path warns against

`Lecture09/workspaces-demo/main.tf` keys the instance size off the workspace name:

```hcl
instance_type = lookup(var.instance_type, terraform.workspace)
# variables.tf: default = { dev = "t3.micro", staging = "t3.medium", prod = "m5d.xlarge" }
```

This is exactly the shape **A7** and [[workspaces]] argue against for long-lived environments: one
backend, one set of credentials, one configuration directory, with prod separated from dev only by a
string. HashiCorp's own documentation says workspaces are not appropriate for deployments that need
separate credentials and access controls. The README does also list "Environment Folder Structures"
as a second technique, so the course is not unaware of the alternative; the runnable demo is the
workspace one.

There is also a concrete defect: two-argument `lookup` **errors when the key is absent**, and the
map has no `default` key — so the demo fails in the `default` workspace, which is the workspace a
learner is in before running `terraform workspace new`.

### 2. DynamoDB state locking

`Lecture07/main.tf` uses `dynamodb_table = "terraform-lock-table"` inside `backend "s3"`. Checked
against HashiCorp's current [S3 backend reference](https://developer.hashicorp.com/terraform/language/backend/s3)
on 2026-08-15: DynamoDB-based locking is deprecated in favour of **`use_lockfile`**, and the docs
state it "will be removed in a future minor version". The same page deprecates `endpoint`,
`dynamodb_endpoint` and `force_path_style` in favour of an `endpoints {}` block and
`use_path_style`. The course predates none of this — it is simply the older idiom, and the bucket
setup it teaches (SSE, versioning, public-access block) is still right.

### 3. `terraform refresh`

`Lecture13/LectureNotes.md` recommends `terraform refresh` for state conflicts. That command is
deprecated: the [CLI docs](https://developer.hashicorp.com/terraform/cli/commands/refresh) say to
"add the `-refresh-only` flag to `terraform apply` and `terraform plan`", available since
**v0.15.4** (verified 2026-08-15). The rest of that lecture is sound — `TF_LOG` levels,
`force-unlock`, re-plan after a partial apply — and its "never manually edit state" line is the
right instinct.

### 4. `terraform import` as the only import story

Lecture 13 recovers an out-of-band resource with the CLI `terraform import aws_instance.example
i-abc123`. That still works, but the **`import` block** (declarative, plannable, reviewable, since
1.5) appears nowhere, and neither do `moved` or `removed` blocks — the strings are absent from the
whole repository. So the course teaches state surgery as a set of imperative commands, which is the
pre-1.5 mental model.

## The gap that decides where to cite it: no native testing

The README's section 10 is titled "Terraform Security, Testing and Validation", and its testing
table is `terraform fmt`, `terraform validate`, `tflint`, `checkov`. There is **no `terraform test`,
no `.tftest.hcl`, no `run` block, and no `precondition` / `postcondition` / `check`** anywhere in
the repo. So the course cannot serve **A2**, whose entire subject is the native framework, and the
path is right to cite HCDocs and TUR there instead. What it does cover — formatting, validation,
linting, security scanning — belongs to **B4** and **A3**, and its "shift left, run these before
apply" framing is a reasonable pipeline argument.

Secrets coverage in Lecture 10 is honest about the important limitation: marking a variable
`sensitive = true` hides it from CLI output but **the value is still in state**, so the feature
"alone is not sufficient for production security". That matches what **A6** teaches.

## Runnability

The configurations are not runnable as written. They hardcode one account's identifiers — AMI IDs
(`ami-02dfbd4ff395f2a1b`, `ami-0ec10929233384c7f`), `subnet-07b8a1ecbe3cd3b56`,
`sg-0d0aefca338672102`, `key_name = "terraform-examples"`, and globally unique bucket names prefixed
`rahul-` — so every one needs editing before it applies anywhere. The provisioner lecture also reads
`file("terraform-examples.pem")` from the working directory, which is a private key the repo does
not ship (correctly).

Two typos survive in the committed code (`module "secuity"`, `resource "aws_instance" "web_rerver"`),
which is a fair signal of how much editing the repo has had. They are harmless — identifiers, not
attributes.

## Verdict

Good for the **Beginner** half and the mechanical parts of Intermediate: the module composition in
Lecture 08 and the implicit-versus-explicit dependency demo in Lecture 06 are genuinely well shaped,
and the `graph.png` artefacts make the dependency lesson concrete. Cite it where the path already
does — B1, B5, I3 — and optionally at B8/I6 and I4/I5. Do **not** cite it for testing, environment
isolation, state surgery, or anything Advanced. Where its idiom has aged (DynamoDB locking,
`refresh`, CLI `import`), the path and book already teach the current form, so no correction
propagates outward; the value of recording it here is to avoid re-deriving the same conclusion when
the course is next considered for a topic.

## Sources

- Local checkout: `C:\opt\learn\terraform\repos\Terraform-Full-Course-2026` @ `4f1928e` (2026-03-25)
- Course video: <https://youtu.be/l5qtFBsxZdk> (the path's **TF2026**)
- S3 backend argument status — <https://developer.hashicorp.com/terraform/language/backend/s3> (checked 2026-08-15)
- `terraform refresh` deprecation — <https://developer.hashicorp.com/terraform/cli/commands/refresh> (checked 2026-08-15)
