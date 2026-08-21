# Secrets tooling & state-secrecy — verified facts

Captured while writing TUR Ch6 notes. Last verified: **2026-08-21**.

## The state-secrecy mechanisms

| Claim | Verified value | How |
|---|---|---|
| Ephemeral values / ephemeral resources | Terraform **1.10.0**, tagged 2024-11-26 | `git log -1 --format=%cd v1.10.0` in `repos/terraform` |
| Write-only arguments | Terraform **1.11.0**, tagged 2025-02-27 | same, `v1.11.0` |
| OpenTofu parity | **1.11.0**, tagged 2025-12-09 — ephemeral values, ephemeral resources *and* write-only attributes in one release | `git show v1.11.0:CHANGELOG.md` in `repos/opentofu` |
| "Secrets in state" issue | [hashicorp/terraform#516](https://github.com/hashicorp/terraform/issues/516) opened **2014-10-28**, closed **2025-05-21**, `stateReason: COMPLETED` | `gh issue view 516 --repo hashicorp/terraform --json …` |
| Closing rationale | Maintainer comment 2025-05-01: *"ephemeral write-only arguments were added in 1.11"* | same |

## AWS provider (checked at tag `v6.54.0`; latest 6.54.0, 2026-07-08)

| Claim | Verified value |
|---|---|
| `ephemeral "aws_kms_secrets"`, `ephemeral "aws_secretsmanager_secret_version"`, `ephemeral "aws_lambda_invocation"` | Added in provider **5.77.0** (2024-11-21) |
| Other ephemeral resources shipped since | `secretsmanager_random_password`, `ssm_parameter`, `eks_cluster_auth`, `ecr_authorization_token`, `ecrpublic_authorization_token`, `sts_web_identity_token`, `cognito_identity_openid_token_for_developer_identity` |
| `password_wo` / `password_wo_version` on `aws_db_instance` | Provider **5.88.0** (2025-02-20); `RequiredWith` validation added in 5.90.0 |
| `manage_master_user_password` | Cannot be set together with `password` **or** `password_wo`; exposes a `master_user_secret` attribute block |
| Doc defect | The `password_wo` argument line still says *"it will be stored in the state file"* — copied verbatim from `password`. The page's header note has it right |
| `thumbprint_list` on `aws_iam_openid_connect_provider` | **Optional**. For *"Auth0, GitHub, GitLab, Google, or those using an Amazon S3-hosted JWKS endpoint"* AWS uses its own trusted-CA library and any configured list *"is retained in the configuration but not used for verification"*. Removing a previously configured list does **not** make IAM re-derive one |

## Tool status (GitHub releases API, 2026-08-21)

| Tool | Current | Note |
|---|---|---|
| `actions/checkout` | v7.0.1 (2026-07-20) | TUR shows `@v2` |
| `hashicorp/setup-terraform` | v4.0.1 (2026-05-12) | TUR shows `@v1` |
| `aws-actions/configure-aws-credentials` | v6.2.3 (2026-07-22) | TUR shows `@v1` |
| `getsops/sops` | v3.13.3 (2026-07-23) | Mozilla → **CNCF Sandbox, accepted 2023-05-17**. Backends now include **age** and HuaweiCloud KMS alongside AWS/GCP/Azure KMS and PGP |
| `carlpett/terraform-provider-sops` | v1.4.1 (2026-03-19) | **v1.3.0 (2025-10-07) added an ephemeral resource** |
| `99designs/aws-vault` | abandoned | README points at the fork **`ByteNess/aws-vault`**, v7.13.5 (2026-08-17) |
| `openbao/openbao` | v2.6.2 (2026-08-18) | **MPL-2.0**, repo created 2023-11-09, LF Projects / OpenSSF sandbox. `hashicorp/vault` reports license `NOASSERTION` |
| 1Password CLI | v2 syntax | `op signin`, `op item get <item> --fields label=<field>`, `op read "op://vault/item/field"`. TUR's `op get item` / `op signin my` are v1 |

## Prices (unchanged from the book's 2022 figures)

- **AWS KMS** — *"$1/month (prorated hourly)"* per customer managed key, *"$0.03 / 10,000 requests"*.
- **AWS Secrets Manager** — $0.40 per secret per month, $0.05 per 10,000 API calls.

## IMDS

- IMDSv2 is the **default for new instance launches** (account-level setting, announced 2024-03-25); instance types released from **mid-2024 are IMDSv2-only**.
- Where IMDSv2 is required, an IMDSv1 request gets no response; a token-less `GET` returns **401 Unauthorized**.
- Token form: `PUT http://169.254.169.254/latest/api/token` with `X-aws-ec2-metadata-token-ttl-seconds`, then `GET` with `X-aws-ec2-metadata-token`. `PUT` to a *version-specific* token path returns 403 by design.
- The AWS SDKs call IMDSv2 by default, so provider authentication from an instance profile is unaffected.

## Staleness notes

Durable: the version numbers for ephemeral/write-only, the [#516](https://github.com/hashicorp/terraform/issues/516) dates, the sops donation date, the provider versions. Expires: every "current release" row above, and the prices whenever AWS moves them.
