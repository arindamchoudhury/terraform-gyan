# Secrets and state

> **Sources:** Brikman, *Terraform: Up & Running* Ch6 (and Ch3) · Hafner, *Terraform in Depth* Ch8 §8.5 · HCDocs [[tf-manage-sensitive-data]], [[tf-remote-state-data]], [[tf-input-variables]] · [[infisical-terraform-secrets]] · [[version-facts]]

## In one paragraph

Terraform handles two kinds of secret and they have nothing in common except the word. There are the secrets it **uses** — the cloud credentials that let it call an API — and the secrets it **manages**, the database passwords and API keys it sets *on* your infrastructure. The first kind is solved outside the configuration, by making the credential arrive from the environment the run happens in, ideally as a short-lived token nobody stored. The second kind was, for a decade, not solved at all: whatever route the value took into a `resource` block, it came to rest in the state file in plaintext, and `sensitive = true` only stopped it being printed. That is the fact all three sources organise themselves around, and it stopped being true in 2024–2025, when ephemeral values and write-only arguments gave the value a path into a resource that never touches state or plan.

## Key concepts (cross-source)

- **`sensitive` hides; it does not protect.** All three sources say so, and [[tf-manage-sensitive-data]] gives the framework: *hide* (`sensitive`), *omit* (ephemeral), or *both*. The gap is wider than the docs admit — `terraform output db_password` prints the value with no flag at all, verified on v1.15.8 in [[tf-cmd-output]]. Treat `sensitive` as a control on **logs**, never on access.
- **The state file is the boundary, so "who can read this state" is the real permission question.** TUR Ch6 gets there from encryption (use a backend that encrypts, restrict the bucket); TID §8.5.2 gets there from centralisation (a secret manager does not help, because a data source writes the value to state anyway); [[tf-remote-state-data]] gets there from exfiltration (reading one output requires the credentials to fetch the whole snapshot). Same conclusion, three routes.
- **A saved plan file has the identical problem and gets a fraction of the attention.** TUR Ch6 is the source that says it plainly, next to the `-out` flag that creates one. Encrypt it and restrict it exactly as you would state, or do not save one.
- **Best is to have no secret.** TID §8.5 makes this a ranked hierarchy — **OIDC → secret manager → orchestrator storage** — with the last two carrying explicit costs. TUR Ch6 reaches the same place from the machine-user angle: stored credentials are permanent and hand-managed, IAM roles fix that inside AWS, OIDC fixes it from outside too.
- **Registering an identity provider is authentication; the trust policy's conditions are the authorization.** Both books show the `sub` condition pinning `repo:org/repo:ref:refs/heads/main`, and both warn that without it the role trusts *every* customer of that IdP. The role ARN is not a secret and does not need to be.
- **Pass coordinates into modules, not values.** [[infisical-terraform-secrets]] is the only source that states it as a rule: a `db_password` input means every caller holds the raw value and every calling configuration's state gets a copy. Pass the path or workspace ID and let the module fetch its own value, so access is controlled in the secrets manager rather than by who holds the variable.
- **Ephemeral values and write-only arguments are the mechanism, and the `_version` companion is the part people miss.** Because the value is never stored, Terraform cannot diff it, so `password_wo_version` is what signals a change. Availability: Terraform **1.10** (ephemeral) and **1.11** (write-only), OpenTofu **1.11.0** for all of it.

## Where the sources differ

- **TUR is a catalogue; TID is a hierarchy.** TUR Ch6 lays out three techniques for resources (environment variables, encrypted files, secret stores) with symmetrical advantage/drawback lists and declines to rank them, because the two lists are mirror images: files win on *versioned with the code*, stores win on *rotation and audit*, and nothing wins both. TID §8.5 ranks its options instead and argues each step down costs you something. Read TUR to understand the trade space, TID to make the decision.
- **TUR is the only source that costs the options in money.** $1/month per KMS key, $0.40 per Secrets Manager secret per month, with worked monthly estimates. Both figures were still exact when re-checked in 2026, which is unusual enough to be worth knowing.
- **Only [[infisical-terraform-secrets]] proves the leak instead of asserting it.** A `grep` finds `random_password` in state three times — attribute, output, and bcrypt hash — after an apply that printed `<sensitive>` throughout, next to a 181-byte state for the ephemeral version of the same thing. It is a vendor post, so read the product comparison as marketing; the mechanics check out.
- **On the state problem itself, the two books disagree with each other only because of when they were written.** TUR Ch6 calls it an open issue with no first-class solution planned and teaches damage control. TID, three years later, points at ephemeral and write-only. [hashicorp/terraform#516](https://github.com/hashicorp/terraform/issues/516) — opened 2014-10-28, the issue TUR refers to — was closed as completed on **2025-05-21**.
- **Engine divergence sits right on this topic.** OpenTofu **1.7** encrypts state *and plan files* client-side, so the "encrypt the bucket and hope" advice is a fallback there rather than the whole answer. Terraform has no equivalent. See [State](state.md).

## When to read which

- Need the trade space before choosing a tool → **TUR Ch6**, and its two comparison tables.
- Need to decide what a team should do → **TID Ch8 §8.5**, for the ranked hierarchy and the trust-policy warning.
- Need the current mechanism and the version gates → **[[tf-manage-sensitive-data]]**, then [[tf-cmd-output]] for how far redaction actually goes.
- Need to convince someone the leak is real → **[[infisical-terraform-secrets]]**, for the `grep`.
- Need the credential half in CI → **[[gha-oidc]]** / **[[bitbucket-pipelines-oidc]]**, and TUR Ch6's machine-user section for the IAM shape underneath.

## Sources

- [TUR Ch6 — Managing Secrets with Terraform](../books/tur/chapters/06-managing-secrets.md)
- [TUR Ch3 — How to Manage Terraform State](../books/tur/chapters/03-manage-state.md) — `sensitive` plus `TF_VAR_`, and the S3 backend that then stores the value in plaintext
- [TID Ch8 — Continuous delivery](../books/tid/chapters/08-cd-deployment.md) — §8.5, the hierarchy
- [[tf-manage-sensitive-data]] · [[tf-remote-state-data]] · [[tf-input-variables]] · [[tf-cmd-output]]
- [[infisical-terraform-secrets]] · [[gha-oidc]] · [[bitbucket-pipelines-oidc]] · [[tut-no-code-provisioning]]

## Open questions

> ❓ No source here covers what to do about **secrets already in state**. Rotating the value is obvious; every historical state version in the bucket still holds the old one, and neither book discusses expiring them.

> ❓ Ephemeral resources solve the read path and write-only arguments solve the write path. **Nothing solves an attribute a provider returns** — a generated key or certificate an API hands back on create still lands in state. Worth chasing whether any provider models that as ephemeral output.
