# Testing

> **Sources:** Hafner, *Terraform in Depth* Ch9 · Brikman, *Terraform: Up & Running* Ch9 · [[terraform-testing]] · [[terratest-facts]] · [[ci-quality-tooling-versions]]

## In one paragraph

Testing infrastructure code is unlike testing a library, and every difficulty traces back to one fact: the code's whole purpose is to call somebody else's API and create something real. You cannot run a load balancer on localhost, you cannot mock away the dependencies without deleting the code under test, and every test run costs minutes and money. So an infrastructure test is a deploy, a validation, and a teardown — the manual loop written down — and the engineering is all in making that loop fast enough to use, cheap enough to afford, and reliable enough to trust. The two books arrive at the same practices from opposite eras: TUR (2022) predates Terraform's own test framework and teaches the Go library that existed, while TID (2025) covers both and tells you to start with the one built into the binary.

## Key concepts (cross-source)

- **You cannot use localhost, and you cannot purely unit test.** TUR's first and third takeaways. Terraform code is *"99% communicating with complicated dependencies"*, so removing them leaves nothing to test. TID reaches the same place by a better route: unit tests for Terraform **already exist — providers have them**, written in Go by provider authors, so treat each resource as a well-tested function and accept that what is left for you is integration testing.
- **Test your code, not the providers.** TID's scoping rule, and the sharpest thing either book says about *what* to assert. Passing a variable straight into a resource and checking the attribute matches proves only that the provider works. Assert on **logic** — computed strings, regexes, `dynamic` blocks at zero/one/many — and on **system behaviour**: does the endpoint answer, do the generated credentials actually work.
- **Examples are the test fixtures.** Both books, independently. A module is tested through the runnable example that ships with it, which is what makes TUR Ch8's `examples/` convention load-bearing rather than decorative.
- **Namespace everything.** TUR's fourth takeaway, TID's §9.2.3. Any two runs of the same test collide on resource names — parallel tests, two developers, CI alongside a laptop. A random suffix per run (`random.UniqueId()`, six base-62 characters) is the whole fix.
- **Guaranteed teardown is a budget requirement, not tidiness.** TUR puts `defer terraform.Destroy` *before* the apply so no failure can skip it, and warns that Go's default 10-minute timeout kills a run before its cleanup. TID makes the same point about money and adds the account-level backstop. Both recommend a scheduled nuke of anything older than a day or two.
- **Isolated accounts, plural.** A sandbox per developer for manual testing, and a *separate* account again for automated tests, on the reasoning that anything more than a few hours old in the test account is garbage by definition.
- **The pyramid, and the arithmetic under it.** TUR supplies the number that makes it concrete: at a 0.1% per-resource failure rate, a clean run has probability 99.9%ᴺ — 98% for a 20-resource unit test, 94% for a 60-resource integration test, **54.9%** for a 600-resource end-to-end run. Hence the practical end-to-end strategy: keep a persistent production-like `test` environment and apply changes to it **incrementally**, which also tests the deployment process rather than only the result.
- **Native tests check Terraform's view; Terratest checks the resource.** The distinction neither book states outright, and the reason both frameworks survive. A `.tftest.hcl` assertion reads the state the provider reported, so a provider bug that creates a wrong real resource still passes. Terratest queries the resource's own API — an HTTP request, an SSH session, an AWS API call — and catches it ([[terraform-testing]]).

!!! info "Availability, per engine — check both before writing a test-framework claim"
    TID calls the test framework *"one of the areas where both Terraform and OpenTofu have their biggest implementation differences"*, and that has held.

    | Capability | Terraform | OpenTofu |
    |---|---|---|
    | `test` command, `.tftest.hcl`, `run` blocks | **1.6.0** (2023-10-04) | **1.6.0** (2024-01-09) |
    | `mock_provider` / `override_*` | **1.7.0** (2024-01-17) | **1.8.0** (2024-07-29), plus `mock_resource` / `mock_data` |
    | `-junit-xml` for CI | **1.11** | — |
    | Parallel test runs, `-parallelism=n` | **1.12** | — |

## Where the sources differ

- **TUR argues from software testing; TID argues from infrastructure.** TUR builds every concept twice, in Ruby first — testability as a code smell, dependency injection, mocks — then translates. TID starts from what makes IaC different: time, money, and the fact that teardown failures cost real dollars. Read TUR to understand *why the techniques exist*, TID to understand *why they are harder here*.
- **On frameworks they are a generation apart.** TUR is entirely Terratest and says so plainly: you will write Go. TID covers both and recommends **starting with the native framework**, because people writing Terraform already know Terraform. TUR is not wrong so much as pre-dated; its Go code still runs, with every `terraform.*` call now needing the `…Context` form ([[terratest-facts]]).
- **Only TUR quantifies flakiness**, and only TUR has **test stages** — `test_structure.RunTestStage` with `SKIP_<stage>` environment variables, turning a 10-minute integration test into a ~14-second inner loop. The native framework has no equivalent, which is a live reason to reach for Terratest even today.
- **Only TUR surveys the cheap approaches** — static analysis, plan testing, server testing — with strengths and weaknesses for each, and the same closing caveat on all three: everything can pass while the infrastructure does not work. TID puts that material in its CI chapter instead ([[ci-quality-tooling-versions]]).
- **On mocks they disagree by accident of date.** TUR dismisses endpoint mocking (LocalStack) as impractical and unconvincing; TID notes emulators differ enough from the real service to be poor test targets. Then Terraform 1.7 put mocking *inside* the language, which answers the practicality objection while leaving the confidence objection exactly where both books left it.

## When to read which

- Want to know *what to assert* → **TID §9.1.1**, for the test-your-code-not-the-providers rule.
- Want the mechanics of a real test, line by line → **TUR Ch9**, for `defer` placement, retries, namespacing and the backend problem.
- Want a fast iterative loop on a slow test → **TUR Ch9**'s test stages.
- Writing tests today, from scratch → the **native framework** first ([[terraform-testing]]), Terratest when you need to prove the deployed thing actually works.
- Need current versions and API names → **[[terratest-facts]]**, which is source-derived.

## Sources

- [TUR Ch 9 — How to Test Terraform Code](../books/tur/chapters/09-testing.md)
- [TID Ch 9 — Testing and refactoring](../books/tid/chapters/09-testing-refactoring.md)
- [[terraform-testing]] — the native-vs-Terratest split, and which layer each one asserts against
- [[terratest-facts]] — v1.0.0 stable, the v2 module split, and the deprecated bare-function names
- [[ci-quality-tooling-versions]] — currency for the static-analysis tools both books name

## Open questions

> ❓ Neither book covers **testing across engines**. If a module must run on Terraform and OpenTofu, the test matrix doubles, and mocks are available at different versions on each — TID's CI chapter has the matrix machinery but not this case.

> ❓ Nobody quantifies what the native framework costs to run at scale. TUR's 99.9%ᴺ arithmetic assumes real resources; a mocked `command = apply` deploys nothing, so the flakiness maths should collapse — worth measuring rather than assuming.
