# LocalStack Facts (for hands-on labs)

Verified facts for the book's LocalStack lab sections. Refreshed by review passes.

_Last verified: 2026-07-09 (docs.localstack.cloud, blog.localstack.cloud, Docker Hub)._

**Current release:** `localstack/localstack` **2026.06.2** (latest stable, mid-2026). CalVer `YYYY.MM.patch`.
Use `:stable` (or a pinned CalVer like `:2026.06`) for the current image; `:latest` tracks newest tested
commit (can break); `:dev` is bleeding edge. **Default the labs to the current image**, not the legacy pin.

## What it is

**LocalStack** is a local AWS cloud emulator that runs in Docker. It exposes AWS-compatible
API endpoints on a single gateway port so the AWS provider (and the AWS CLI/SDKs) can create,
read, and destroy *emulated* resources with **no AWS account, no cloud credentials, no bill**.

- **Gateway port:** `4566` (all services multiplex through it). External service ports `4510–4559`.
- **Health/readiness endpoint:** `GET http://localhost:4566/_localstack/health` — JSON of each
  service's state (`available` / `running`). Diagnostics: `GET /_localstack/diagnose`.
- **Emulation, not AWS.** Resources are mocked. A resource can `apply` clean on LocalStack yet
  behave differently (or not exist) on real AWS. Good for workflow/HCL practice; **not** a
  fidelity guarantee. Advanced services and deep IAM behavior are weaker or Pro-gated.

## 2026 packaging change — IMPORTANT (get this right in prose)

LocalStack **discontinued the standalone open-source Community image** in **March 2026**:

- The Community image (`localstack/localstack`, semver 4.x) stopped receiving updates in
  **March 2026**; its GitHub repo is marked inactive (source still viewable).
- Development consolidated into a **single unified image** (`localstack/localstack`) that **now
  prompts for an auth token**. Versioning switched from semver to **CalVer** `YYYY.MM.patch`
  (e.g. `2026.03.0`).
- A **free "Hobby" plan** (non-commercial use) provides the equivalent of the old community
  image. It requires a **free sign-up** + an auth token exported as `LOCALSTACK_AUTH_TOKEN`.
- **Tokenless path still exists:** pin an **older Community tag** (semver, pre-March-2026, e.g.
  `localstack/localstack:4.12`). Runs without a token locally and in CI. Caveat: **no future
  updates or security patches**. (Last tokenless community tags are the 4.x line, ~≤ 4.14.)
- **Student Plan** (GitHub Student Developer Pack) is free and unaffected. Special free
  subscriptions for verified students, OSS projects, and non-profits.

> So the honest 2026 framing for the book: "free, but as of March 2026 the current image needs a
> free account + `LOCALSTACK_AUTH_TOKEN` (Hobby plan); or pin an older `4.x` Community tag to run
> fully tokenless." Do **not** claim a no-signup open-source image is still current.

## Install & run (Docker)

**LocalStack CLI (wraps Docker) — current image, recommended:**

```bash
pip install localstack
export LOCALSTACK_AUTH_TOKEN=<your-token>   # free Hobby-plan token
localstack start -d                          # detached; pulls the current stable image
localstack status services                   # readiness table
```

**Plain `docker run` — current stable image:**

```bash
docker run --rm -it \
  -p 127.0.0.1:4566:4566 \
  -p 127.0.0.1:4510-4559:4510-4559 \
  -e LOCALSTACK_AUTH_TOKEN=${LOCALSTACK_AUTH_TOKEN:?} \
  localstack/localstack:stable          # or a pinned CalVer, e.g. :2026.06
```

**docker-compose.yml — current image pinned to stable:**

```yaml
services:
  localstack:
    image: localstack/localstack:stable   # pin :2026.06 for reproducibility
    ports:
      - "127.0.0.1:4566:4566"
      - "127.0.0.1:4510-4559:4510-4559"
    environment:
      - LOCALSTACK_AUTH_TOKEN=${LOCALSTACK_AUTH_TOKEN:?}   # free Hobby plan
      - DEBUG=0
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

**Zero-signup fallback (legacy, no updates):** pin an old Community tag —
`docker run --rm -it -p 127.0.0.1:4566:4566 localstack/localstack:4.12` — runs tokenless but
gets no security patches. Prefer the current image + free token above.

## Terraform integration

### Option A — `tflocal` (recommended)

`pip install terraform-local` ships the **`tflocal`** wrapper. It drops a temporary
`localstack_providers_override.tf` (Terraform override file) that points every AWS provider
endpoint at `localhost:4566` and injects dummy creds. Use it exactly like the CLI:

```bash
pip install terraform-local
tflocal init
tflocal plan
tflocal apply
tflocal destroy
```

No edits to your real `.tf` files — the override is created/removed around the run, so the same
config also applies to real AWS with plain `terraform`.

### Option B — manual provider block

```hcl
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"      # dummy — LocalStack accepts anything
  secret_key                  = "test"
  s3_use_path_style           = true        # S3 needs path-style against LocalStack
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3       = "http://s3.localhost.localstack.cloud:4566"  # S3 virtual-hosted form
    ec2      = "http://localhost:4566"
    iam      = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
    sts      = "http://localhost:4566"
    # ...one line per service the config uses
  }
}
```

Downside vs. `tflocal`: this block is LocalStack-specific — it won't apply to real AWS unchanged.
Keep it in an `override.tf` / `*.auto.tfvars`-style local file, or use `tflocal` instead.

### Verifying results

- `awslocal` (from `pip install awscli-local`) = the AWS CLI pre-pointed at LocalStack:
  `awslocal s3 ls`, `awslocal s3api list-buckets`.
- Or `terraform state list` / `terraform output` as usual — state works identically.

## Service coverage (free tier)

Core services emulated for free: **S3, EC2 (mocked), IAM, STS, DynamoDB, SQS, SNS, Lambda,
CloudFormation, CloudWatch, Kinesis, Secrets Manager, SSM, API Gateway, Route53** and more.
Advanced/enterprise services (deeper EKS/ECS/RDS behavior, some IAM enforcement) are Pro-gated or
partial. Treat S3/DynamoDB/SQS/SNS/IAM as the reliable lab surface. Live service list:
<https://docs.localstack.cloud/aws/services/>.

## Sources

- Using Terraform with LocalStack — <https://docs.localstack.cloud/aws/integrations/infrastructure-as-code/terraform/>
- Installation — <https://docs.localstack.cloud/aws/getting-started/installation/>
- The Road Ahead for LocalStack (packaging change) — <https://blog.localstack.cloud/the-road-ahead-for-localstack/>
- 2026 pricing & packaging — <https://blog.localstack.cloud/2026-upcoming-pricing-changes/>
- Docker Hub `localstack/localstack` — <https://hub.docker.com/r/localstack/localstack>
- Internal endpoints (health) — <https://docs.localstack.cloud/aws/capabilities/config/internal-endpoints/>
