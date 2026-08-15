# KL lab repo — inventory, citation audit, and coverage limits

What `btkrausen/terraform-associate-labs` (**KL** in [[learning-path]]) actually contains, read from
the checkout. The path cites it in nine places, so the useful work here is confirming each citation
points at material that exists — and two of them did not.

_Source: `C:\opt\learn\terraform\repos\terraform-associate-labs` at `d3841eb` ("add lab 08",
2026-05-26), level with `origin/main`. Last verified: 2026-08-15._

## Inventory

Eight labs, each written three times — **AWS, Azure and GitHub** — so a learner can pick the
provider they already understand. Labs **01–05 are cumulative** and must be done in order (the
README says so, and each builds on the previous directory); **06–08 are self-contained** and can be
done in any order. Labs 01–05 ship as instructions only (`aws.md`, `azure.md`, `github.md`); labs
06–08 add starter configuration (`main.tf`, `providers.tf`, `variables.tf`) under an uppercase
`AWS/`, `AZURE/`, `GITHUB/` directory.

| Lab | Title as written | What it actually teaches |
|---|---|---|
| 01 | Getting Started with Terraform Configuration | `terraform -version`, project layout, provider block, `fmt`, `init`, `validate`, version constraints |
| 02 | Creating Your First AWS Resource | credentials, a VPC resource, `plan`, `apply`, verify, then modify |
| 03 | Working with Variables and **Outputs** | variable definitions, `terraform.tfvars`, provider `default_tags`, outputs, **variable precedence** |
| 04 | Managing Multiple Resources and Dependencies | subnets, route table, associations, security group — implicit references plus `depends_on` |
| 05 | Working with State, Data Sources, and CLI Commands | `terraform state` subcommands, `show`, data sources (`aws_availability_zones`, region, caller identity) |
| 06 | Refactoring: Making Code Dynamic and Reusable | replacing hardcoded values with variables, data sources and interpolation |
| 07 | Simplifying Code with Local Values | a `locals` block, refactoring to use it, observing the effect of changing it |
| 08 | Creating and Managing Resources with `for_each` | `for_each` over map variables, **kept alongside the `count` version for direct comparison** |

Lab 08's design is the standout: it deliberately keeps the `count`-based resources in place next to
the `for_each` ones so the learner can compare the resulting addresses and see why keys survive
list reordering. That is the **I1** lesson, demonstrated rather than asserted.

## Citation audit — two path citations pointed at material that does not exist

Both were checked by grepping the whole repository, not by reading the lab titles.

- **`dynamic` blocks: not in this repo.** `grep -rn 'dynamic "'` returns **zero** matches across
  every `.tf` and `.md` file. Lab 06's title — "Making Code Dynamic and Reusable" — uses *dynamic*
  in the plain-English sense of parameterized: its steps are variables, data sources and string
  interpolation, and its own summary says "to see how dynamic our code is now, update the value of
  the `environment` variable". The path cited it as I3's "dynamic-blocks section".
- **`module` blocks: not in this repo either.** `grep -rn 'module "'` returns **zero** matches, and
  the word *module* does not appear anywhere in lab 06's instructions. "Reusable" in that title
  means parameterized, not modularized. The path cited it as I5's "reusable-module section".

Both citations are corrected in the path, which now says plainly that KL covers neither topic.

One smaller mismatch, harmless but worth knowing when scanning the directory listing: **lab 03's
directory is named `lab_03_working_with_variables_and_dependencies`, but the lab is titled "Working
with Variables and Outputs"** and teaches variables, `tfvars`, outputs and precedence. Dependencies
are lab 04's subject. Cite lab 03 for variables and outputs, lab 04 for dependencies.

## What the labs cover, measured

Counting files that mention each construct, across all 24 lab documents:

| Construct | Files | Notes |
|---|---|---|
| `count` | 25 | the workhorse throughout |
| `terraform state …` | 4 | lab 05 |
| `for_each` | 3 | lab 08 only |
| `sensitive` | 3 | |
| `depends_on` | 2 | lab 04 |
| `terraform import` | 1 | mentioned, not exercised |
| `backend "…"`, `terraform workspace`, `import {}`, `lifecycle`, `provisioner`, `terraform test`, `taint`, `terraform graph` | **0** | absent entirely |

So the repo covers the Beginner half of the path well and stops there. There is no remote backend,
no workspace, no state-surgery, no lifecycle, no provisioner and no testing lab — which matters
because the **004 exam** covers backends and state management. KL is a strong hands-on companion for
**B1–B8** and **I1**, and nothing beyond; the path's other lab sources have to carry the rest.

## Two claims in the README that the repo does not support

- **The dev container is in a different repository.** The README promises "a **pre-configured**
  development container that installs Terraform and prerequisites in your Codespace", and step 1
  says to "create a Codespace **from this repo**". There is no `.devcontainer` here — the only
  hidden directory is `.github`, containing `FUNDING.yml`. The "Open in GitHub Codespaces" badge
  points at **`codespaces.new/btkrausen/terraform-codespaces`**, a separate repository. So a
  Codespace created from *this* repo gets the default image, and the badge opens something else.
  Plan for installing Terraform yourself, or start from the linked repo and clone these labs into it.
- **The tested-version badge is a point-in-time claim.** It reads "Terraform 1.12.2 — Tested", while
  current stable is **1.15.8**. The CI badge next to it points at `btkrausen/terraform-testing`,
  which installs "Latest" rather than 1.12.2 — and per [[krausen-lab-ci-facts]], that harness
  validates a *different* set of lab directories (`modules/tfb/**`, not this repo) and its plan gate
  cannot fail. Treat the green badge as evidence that someone's labs still `init` and `validate`,
  not that these ones plan cleanly on 1.15.8.

Nothing here is a reason to stop citing KL. The labs themselves are well written, genuinely free,
and the three-provider structure is unusual and useful. The point of recording it is that two of the
repo's own advertised properties do not hold, and a learner hitting either one will assume they
broke something.

## Sources

- Local checkout `C:\opt\learn\terraform\repos\terraform-associate-labs` @ `d3841eb` (2026-05-26)
- `README.md` and all 24 lab documents under `labs/`
- Companion CI harness: [[krausen-lab-ci-facts]]
