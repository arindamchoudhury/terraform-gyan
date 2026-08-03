# Floci Facts (free LocalStack alternative — book default)

Verified facts for the book's lab sections. Refreshed by review passes.
See also [[ministack-facts]] and [[localstack-facts]] — all three share port 4566 and are interchangeable in the labs.
[[robotocore-facts]] also serves `:4566` and enforces IAM, but Floci enforces IAM natively (see
below) and covers `iam:*`/`sts:*` actions that Robotocore cannot, so the book does not need it.

_Last verified: 2026-07-09; IAM enforcement added 2026-07-12; floci-cli internals + health-path
(`/_floci/health` native, `/_localstack/health` alias) verified 2026-07-15 (github.com/floci-io/floci-cli)._

## What it is

**Floci** is a free, open-source (**MIT**) local AWS emulator built on **Quarkus Native** — a
LocalStack alternative that emphasises a tiny native binary and fast startup. Part of the
**floci-io** org, which also ships `floci-az` (Azure), `floci-gcp` (GCP), `floci-ui` (an
AWS-Console-style local UI), `floci-cli`, and a Testcontainers module. **No auth token, no account.**

- **Gateway port:** `4566` — same as LocalStack/MiniStack, so `:4566` tooling works unchanged.
- **LocalStack-API-compatible:** it still serves the `/_localstack/health` and `/_localstack/init`
  endpoints, so **LocalStack's `tflocal` wrapper drives Floci directly**. Floci's own **native**
  control-plane path is **`/_floci/health`** (what `floci-cli` polls); `/_localstack/health` is a
  compat **alias** — verified 2026-07-15 that both return **200** with an **identical** JSON body
  (`{"edition":"community","version":"1.5.31","original_edition":"floci-always-free","services":{…}}`).
- **69 AWS services** (README, verified 2026-07-11) (S3, SQS, SNS, DynamoDB, Lambda, RDS, ECS, EKS, IAM, STS, events, APIs,
  containers, databases, messaging, security, billing). 100% SDK compatibility claimed.
- **EC2 mock is usable — verified 2026-07-09.** Unlike LocalStack's free Community tier (where EC2
  is a shallow mock; see [[localstack-facts]]), Floci mocks EC2 deep enough that the full
  Terraform hello-world shape applies clean via `tflocal`: `data.aws_ami` (Canonical Ubuntu
  filter), `data.aws_vpc {default=true}`, `data.aws_subnets`, and `aws_instance` all resolve and
  create. Confirmed with `terraform state list` (all four in state). Still a mock — no real VM
  boots; a green apply proves HCL/workflow, not AWS fidelity. **Book labs keep S3** for
  cross-emulator portability (S3 is reliable on all three), but EC2 examples are runnable on Floci.
- **Real infra where it counts:** mounts the Docker socket to spin up real containers (RDS, ECS,
  Lambda). Run with `-u root` per the README so it can reach the socket.
- **Quarkus-native footprint.** Project reports ~90 MB image, ~13 MiB idle memory, ~24 ms startup
  (vs LocalStack's ~1 GB / ~143 MiB / ~3.3 s). Treat the exact numbers as the project's own
  benchmarks, not independently verified — the *order of magnitude* (much smaller/faster) is the point.
- MIT, actively developed with ongoing security updates (newer than LocalStack; very popular).

## IAM policy enforcement — off by default, one flag to turn on

Floci ships a real IAM authorization engine: `IamPolicyEvaluator`, `AssumeRolePolicyEvaluator`,
`IamActionRegistry`, and 50 seeded AWS managed policies (all found in the native binary). It is
**disabled by default** — with it off, a user carrying `Deny * on *` still creates buckets, which
is why earlier notes wrongly called Floci's IAM "CRUD-only." One undocumented env var switches it
on:

```
FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true
```

On boot Floci then logs `Seeded 50 AWS managed policies`. Verified empirically 2026-07-12 against
`floci/floci:latest`:

| Scenario | Result |
|---|---|
| Explicit `Deny s3:CreateBucket` on an otherwise-allowed user | ✅ `AccessDenied` |
| `Allow s3:*` → `s3:ListBuckets` | ✅ allowed |
| Explicit deny → `iam:CreateUser` | ✅ `AccessDenied` — **enforced on IAM itself** |
| Implicit deny (user has no `sqs` permission) → `sqs:CreateQueue` | ✅ `AccessDeniedException` |
| Root/seed access key (`test`) | god-mode, bypasses enforcement — use it to set labs up |

The denial wording is AWS-shaped: `User is not authorized to perform: s3:CreateBucket`. (Real AWS
appends `with an explicit deny in an identity-based policy`; Floci stops at the action.)

!!! warning "Enforcement is authorization, not authentication"
    A wrong secret key is **not** rejected even with enforcement on (`FLOCI_AUTH_VALIDATE_SIGNATURES`
    did not change this in testing). The calling principal is identified by its access-key ID and
    the attached policy is evaluated against it; the SigV4 signature itself is not verified. So a
    lab here teaches how AWS **evaluates a policy** — explicit deny beats allow, default is deny —
    not credential security. Say so in the chapter.

This makes Floci a strict superset of [[robotocore-facts]] for teaching IAM: same explicit-deny
behavior, plus implicit default-deny, plus enforcement on `iam:*`/`sts:*` actions that Robotocore
permanently exempts. The IAM chapter adds `-e FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true` to the
`docker run` and needs no second emulator. Leave the flag **off** in every other chapter — the
hello-world labs use throwaway `test` creds and should not hit denials.

## Install & run (Docker)

```bash
docker run -d --name floci \
  -p 4566:4566 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -u root \
  floci/floci:latest
```

docker-compose:

```yaml
services:
  floci:
    image: floci/floci:latest
    ports:
      - "127.0.0.1:4566:4566"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock   # for real RDS/ECS/Lambda containers
    user: root
```

Health — native path and the LocalStack-compat alias both return **200** with the same body:

```bash
curl -s http://localhost:4566/_floci/health        # native (floci-cli uses this)
curl -s http://localhost:4566/_localstack/health   # compat alias — identical body
```

Optional: `floci-ui` gives an AWS-Console-style view of what the labs create; `floci-cli`
orchestrates the container (see next section).

### floci-ui — the web console (published all-in-one image)

`floci-io/floci-ui` (MIT) publishes an **all-in-one** image `floci/floci-ui:latest` (tags `latest`,
`0.2.0`, ~40 MB): one compiled process serves both the web frontend and its API on **`:4500`**, and
reads the emulator over the network via **`FLOCI_ENDPOINT`** (Hono `serveStatic` from `./public` +
`/api/*` routes for ec2/rds/eks/secretsmanager/clouds). **No repo clone, no build, no second
emulator** — point it at the running `:4566` and it reflects real state. The book's
`labs/docker-compose.yml` ships it as a **normal service** that comes up with the emulator on a plain
`docker compose up -d` (console on `:4500`); add `profiles: ["ui"]` to make it opt-in.

```yaml
  floci-ui:
    image: floci/floci-ui:latest
    container_name: floci-ui               # add `profiles: ["ui"]` to make opt-in
    ports: ["127.0.0.1:4500:4500"]
    environment:
      FLOCI_ENDPOINT: http://floci:4566    # emulator by compose service name
      AWS_REGION: us-east-1
      AWS_ACCESS_KEY_ID: test
      AWS_SECRET_ACCESS_KEY: test
    depends_on: [floci]
```

Verified end-to-end 2026-07-15: `aws --endpoint-url :4566 secretsmanager create-secret` → the same
secret returned by `GET http://localhost:4500/api/secretsmanager/secrets`. The floci-ui *repo*
compose (`docker-compose.yml`) instead **builds from source** and bundles its own `floci` on `:4566`
(dev setup) — for the book, prefer the published image service above, not the repo clone.

## floci-cli internals — it's a thin wrapper on `floci/floci`

Verified against the floci-cli source (`github.com/floci-io/floci-cli`, 2026-07-15). The cli shells
out to the `docker` binary and talks HTTP to `/_floci/health`; it adds **no capability the container
lacks**. So the labs do **not** need it — bare `docker run` + `tflocal` covers everything. Map:

| cli command | what it actually does | raw equivalent |
|---|---|---|
| `floci start` | builds a `docker run -d --name floci -p <port>:4566 <socket-mount> [-v dir:/app/data -e FLOCI_STORAGE_MODE=persistent] floci/floci:latest` line, `docker pull` per policy, then calls `wait` | the `docker run` above |
| `floci env` | prints **4 constant** vars, no container call: `AWS_ENDPOINT_URL=http://localhost.floci.io:4566`, `AWS_ACCESS_KEY_ID=test`, `AWS_SECRET_ACCESS_KEY=test`, `AWS_DEFAULT_REGION=us-east-1` | hardcode them |
| `floci wait` | polls `GET /_floci/health` every 500 ms until 200 / timeout | curl-loop |
| `floci status` | `docker inspect` + one `GET /_floci/health` (version/edition) | `docker ps` + curl |
| `floci doctor` | **11 checks + `--fix`** (below) | not trivially replaceable |

**`floci env` supports PowerShell** — `floci env --shell powershell` emits `$env:KEY = "…"`, so on
Windows: `floci env --shell powershell | Invoke-Expression` (bash default is `eval $(floci env)`).
The book still drives Terraform via **`tflocal`** (portable, no env juggling); `env` is only for the
raw-endpoint path.

**`floci doctor`** is the one genuine value-add — a beginner-proof setup check. Checks: docker
installed, daemon up, socket reachable, docker version, port free, image present, image version,
container running, endpoint reachable (`/_floci/health`), aws-cli endpoint configured, aws-cli S3
path-style. `--fix` auto-resolves the fixable ones. **Use it as the Ch1 lab health check**; skip cli
elsewhere.

## Terraform integration

Because Floci speaks the LocalStack API on `:4566`, **all three paths work**:

### Option A — `tflocal` (LocalStack's wrapper, works here)

`pip install terraform-local` → `tflocal init/plan/apply`. It points the AWS provider at
`localhost:4566` and injects dummy creds; Floci's LocalStack-compatible endpoints make it a
drop-in. Zero `.tf` edits, config stays portable to real AWS.

### Option B — `AWS_ENDPOINT_URL` env (no wrapper)

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
terraform init && terraform apply
```

### Option C — manual `endpoints {}` block

```hcl
provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true

  endpoints {
    s3       = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
    # ...one line per service used
  }
}
```

Verify with `awslocal` or `aws --endpoint-url=http://localhost:4566 s3 ls`.

## Free emulator comparison — book stance

| | **Floci** (default) | MiniStack | LocalStack (2026) |
|---|---|---|---|
| License | MIT | MIT | source-available |
| Token / account | **None** | **None** | Free account + `LOCALSTACK_AUTH_TOKEN` |
| Port / API | `:4566`, LocalStack-compatible | `:4566` | `:4566` |
| Services | 69 | ~60 | most |
| IAM authz enforcement | ✅ opt-in flag, covers `iam:*` too | ❌ | Pro only |
| Image / startup | ~90 MB, native, very fast | ~270 MB | ~1 GB |
| `tflocal` | ✅ (LS-compatible endpoints) | ✅ | ✅ |
| Extras | UI, CLI, Azure/GCP siblings | — | mature docs/ecosystem |
| Maturity | newer, active, popular | newer, active | established, most documented |

**Recommendation:** lead with **Floci** (smallest/fastest, most services, LocalStack-compatible so
`tflocal` just works, no signup). Keep MiniStack and LocalStack as alternatives. Lab bodies use
`tflocal`, which drives all three — the reader swaps only the `docker run` line.

## Measured fidelity gaps

Things the emulator does differently from AWS, found while writing labs. Each one was isolated with a
control configuration before being recorded here.

| Gap | Detail | Found in |
|---|---|---|
| **S3 bucket tags are dropped at create** | `aws_s3_bucket` with a `tags` map applies cleanly, but the tags never reach the object. State records `tags = {}`, `get-bucket-tagging` returns an empty `TagSet`, and **every subsequent plan proposes to add them again** — a perpetual diff. A control bucket with no `lifecycle` block behaves identically, so it is the emulator, not Terraform. Tags set afterwards through `put-bucket-tagging` **do** persist and are read back correctly on refresh. Measured 2026-08-03, TF 1.15.8. | Book Ch 11 lab, Part D |
| **DynamoDB duplicate table names are refused** | Not a gap — worth recording as *working* fidelity. `CreateTable` on an existing name returns `ResourceInUseException: Table already exists`, which is what makes the `create_before_destroy` collision lab reproducible. Measured 2026-08-03. | Book Ch 11 lab, Parts C and C2 |

## Sources

- Floci repo / README — <https://github.com/floci-io/floci>
- floci-io org (floci-az, floci-gcp, floci-ui, floci-cli) — <https://github.com/floci-io>
