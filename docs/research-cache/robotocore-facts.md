# Robotocore Facts (IAM-enforcing emulator — NOT used by the book)

Verified facts for the book's lab sections. Refreshed by review passes.
See also [[floci-facts]] (book default), [[ministack-facts]] and [[localstack-facts]] — all four
serve port 4566 and the `/_localstack/health` endpoint.

!!! danger "Superseded — the book does not use Robotocore"
    Robotocore was evaluated as the IAM chapter's emulator on the belief that it was the only free
    tool that enforces IAM. That belief was wrong. **Floci enforces IAM natively** behind
    `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true` (see [[floci-facts]]), and does it *better* —
    Floci enforces on `iam:*`/`sts:*` actions, which Robotocore permanently exempts
    (`gateway/iam_middleware.py:339`). The book therefore stays single-emulator on Floci. This file
    is kept as a comparison record, not a recommendation.

_Last verified: 2026-07-10, empirically, against `ghcr.io/robotocore/robotocore:latest`
(digest `sha256:0fe802ee1120556ae349d2e6e8a183e6a02e4d995d1199bdc2fea0d02cbe9b44`).
Superseded 2026-07-12 when Floci's own IAM enforcement was found and verified._

## What it is

**Robotocore** is a free, open-source (**MIT**) local AWS emulator written in **Python**, built by
Jack Danger, a core maintainer of [moto](https://github.com/getmoto/moto). It wraps moto rather
than replacing it. **No auth token, no account.**

- **Gateway port:** `4566`. Serves `/_localstack/health`, returning a LocalStack-shaped
  `{"services": {...}, "edition": "community", "version": ...}` payload.
- **158 services / 10,200+ operations** claimed, at two fidelities. 46 "native providers" are
  implemented in-tree. The remaining ~112 forward to moto's in-memory backends and return
  well-shaped responses. Treat the second tier as a mock, not an emulator.
- **Account isolation by access key.** A 12-digit `aws_access_key_id` *is* the account ID. No setup.
- Persistence exists via `ROBOTOCORE_PERSIST=1` and `ROBOTOCORE_STATE_DIR`
  (`boot/components.py:85`).

!!! warning "The `:latest` tag is a dev build, not a release"
    The container banner self-reports `v0.0.0.dev0`; `/_localstack/health` reports
    `2026.5.15.dev0+g0741e7120.d20260514`. There is no tagged release behind `latest`. Pin by
    digest in any lab that uses it.

## What it does: enforce IAM authorization (with enforcement on)

With `ENFORCE_IAM=1`, a principal carrying an explicit `Deny` gets a verbatim-AWS refusal:

```
An error occurred (AccessDenied) when calling the CreateBucket operation:
User is not authorized to perform: s3:CreateBucket
with an explicit deny in an identity-based policy
```

The message is a shade closer to real AWS than Floci's (Robotocore appends `with an explicit deny
in an identity-based policy`; Floci stops at the action name). That is Robotocore's one remaining
edge, and it is cosmetic.

!!! warning "The claim this file was built on was false"
    It was recorded here that "nothing else in the free tier produces this" and that Floci's IAM is
    CRUD-only. Both are wrong. The 2026-07-10 Floci test that "proved" CRUD-only was run with
    Floci's enforcement flag **off**. With `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true`, Floci
    denies the same request — and also denies `iam:CreateUser`, which Robotocore does not. See the
    A–F results in [[floci-facts]].

## Verified 2026-07-10 (empirical, this machine)

| Claim | Result |
|---|---|
| IAM policy enforcement | ✅ **Works, but opt-in.** Requires `ENFORCE_IAM=1` |
| Explicit-deny wording matches AWS | ✅ Exact, including "in an identity-based policy" |
| Enforcement covers `iam:*` / `sts:*` | ❌ **Never.** Permanently exempt |
| SigV4 signature validation | ❌ **Absent.** Bogus signature and wrong secret key both return `200` |
| Persistence | ✅ Exists. `ROBOTOCORE_PERSIST` / `ROBOTOCORE_STATE_DIR` |
| Zero telemetry | ✅ Holds. `USAGE_ANALYTICS` defaults to `1`, but it is a local ring buffer; no network egress found in `audit/` |
| Terraform end-to-end | ⚠️ **Unverified.** Blocked by a local AWS-provider plugin fault, not by Robotocore |

### Claims that do not survive contact

Three widely-repeated facts about Robotocore are wrong. Two of them appear in the project's own
docs, one in every secondary write-up.

- **"Full IAM policy engine"** is not on by default. The `ENFORCE_IAM` toggle is undocumented in
  the README. It surfaces only in `config/runtime.py:24`, in the whitelist of settings mutable at
  runtime via `/_robotocore/config`.
- **"In-memory state only"** is repeated by every third-party comparison article. False. See the
  persistence env vars above.
- **"SigV4 authentication"** appears in the project's own native-provider feature list. The string
  `SignatureDoesNotMatch` appears nowhere in the codebase. Signatures are parsed, never checked.

!!! danger "IAM and STS are exempt from enforcement — by design"
    `gateway/iam_middleware.py:339` carries the comment
    `# Skip IAM/STS to avoid deadlock during credential bootstrap`.

    A user holding `{"Effect": "Deny", "Action": "*", "Resource": "*"}` can still call
    `iam:CreateUser` and mint a fresh unprivileged-in-name-only identity. Confirmed empirically.

    **Consequence for an IAM chapter:** the most natural lesson — "deny a principal the ability to
    create users and roles" — cannot be demonstrated. Deny targets must be non-IAM actions such as
    `s3:CreateBucket`, `ec2:RunInstances`, `dynamodb:CreateTable`.

!!! warning "It teaches policy evaluation, not authentication"
    Because signatures are never verified, the calling principal is *asserted* by the access key
    ID, not *proven*. A lab here demonstrates how AWS evaluates a policy document. It demonstrates
    nothing about credential security. Say so in the chapter, or a reader will draw the wrong
    conclusion from a green `terraform apply`.

## Install & run (Docker)

```bash
docker run -d --name robotocore \
  -p 4566:4566 \
  -e ENFORCE_IAM=1 \
  -e USAGE_ANALYTICS=0 \
  ghcr.io/robotocore/robotocore@sha256:0fe802ee1120556ae349d2e6e8a183e6a02e4d995d1199bdc2fea0d02cbe9b44
```

Run one emulator at a time. Robotocore and Floci both bind `4566`; stop `floci-lab` first.

Health check, same path as Floci:

```bash
curl -s http://127.0.0.1:4566/_localstack/health
```

!!! note "Use `127.0.0.1`, not `localhost`"
    On Windows, `localhost` resolves to `::1` first. Docker publishes the port on IPv4 only, so
    the AWS CLI fails with `Connection was closed before we received a valid response`. This is a
    port-publishing artifact, not an emulator fault. Applies to every emulator here.

## IAM lab recipe (verified end-to-end via AWS CLI)

```bash
EP="--endpoint-url http://127.0.0.1:4566"
export AWS_DEFAULT_REGION=us-east-1

# Act as the account root: 12-digit key = account ID
export AWS_ACCESS_KEY_ID=000000000000 AWS_SECRET_ACCESS_KEY=test

aws $EP iam create-user --user-name tf-user
aws $EP iam put-user-policy --user-name tf-user --policy-name NoBucketCreate \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {"Effect": "Allow", "Action": "s3:*",           "Resource": "*"},
      {"Effect": "Deny",  "Action": "s3:CreateBucket", "Resource": "*"}
    ]
  }'
aws $EP iam create-access-key --user-name tf-user   # capture AccessKeyId + SecretAccessKey
```

Re-export the returned key pair, then any `s3:CreateBucket` — CLI or `aws_s3_bucket` resource —
returns `AccessDenied`. Every other `s3:*` call still succeeds, which is the point: the reader sees
an explicit `Deny` beat a broad `Allow`.

## Not the book default

| | [[floci-facts]] (default) | **Robotocore** |
|---|---|---|
| License | MIT | MIT |
| Language | Java / Quarkus Native | Python |
| Stars / forks | ~16k / ~1.6k | ~327 / ~10 |
| Latest | `1.5.31`, 2026-07-07 | untagged dev build |
| Services | ~68, real Docker-backed | 158 claimed; ~112 are thin moto passthrough |
| Startup | ~24 ms | not published |
| **IAM enforcement** | ✅ opt-in flag; covers `iam:*`/`sts:*`; implicit + explicit deny | ✅ opt-in; **exempts `iam:*`/`sts:*`** |
| Deny message fidelity | stops at action name | appends "…explicit deny in an identity-based policy" |
| Terraform / OpenTofu | ✅ 2,506 compat tests | ✅ port and health endpoint match; end-to-end unverified |

**Book stance:** Floci is the default *and* the IAM chapter's emulator. Robotocore earns **no
appearance** — Floci enforces IAM natively, covers the `iam:*` actions Robotocore can't, and avoids
running a second emulator. Robotocore's only edge is a slightly more verbatim deny string, which is
not worth a whole extra tool. Kept here as a record of what was evaluated and why it lost.

## Sources

- Robotocore repo / README — <https://github.com/robotocore/robotocore>
- LocalStack migration guide (documents the Terraform gap) —
  <https://github.com/robotocore/robotocore/blob/main/LOCALSTACK.md>
- AWS API coverage — <https://robotocore.github.io/robotocore/coverage.html>
- HN discussion — <https://news.ycombinator.com/item?id=47420619>
- Everything in the "Verified" table: read from the running container's source tree
  (`/app/src/robotocore/`) and reproduced with the AWS CLI, 2026-07-10.
