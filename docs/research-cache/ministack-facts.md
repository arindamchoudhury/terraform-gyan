# MiniStack Facts (free LocalStack alternative)

Verified facts for the book's lab sections. Refreshed by review passes.
See also [[localstack-facts]] — the two are interchangeable on port 4566.

_Last verified: 2026-07-09 (github.com/ministackorg/ministack)._

## What it is

**MiniStack** is a free, open-source (**MIT**) local AWS emulator that runs in Docker — a direct
answer to LocalStack moving its Community image behind a free account in March 2026. Tagline:
**"Free forever."** No account, **no auth token**, no signup.

- **Gateway port:** `4566` — the *same* port LocalStack uses, so tooling that targets `:4566`
  (including LocalStack's `tflocal` and `awslocal`) works against MiniStack unchanged.
- **Drop-in compatible** with boto3, the AWS CLI, **Terraform**, CDK, and Pulumi.
- **60+ services**, single port. S3, SQS, SNS, DynamoDB, Lambda, IAM, STS, plus RDS/ECS/EKS/Step
  Functions/API Gateway/Cognito/Bedrock and more.
- **Real infra where it counts:** RDS spins up actual Postgres/MySQL containers, ElastiCache real
  Redis (mount the Docker socket for these). Control-plane services are feature-complete stubs.
- **~270 MB image** (vs LocalStack ~1 GB). MIT, ~3.5k GitHub stars, actively developed (newer and
  less battle-tested than LocalStack — note this honestly).
- **LocalStack-compatible endpoints:** health at `/_ministack/health` **and** `/_localstack/health`.

## Install & run (Docker)

```bash
docker run -p 4566:4566 ministackorg/ministack             # core; no token, no account
docker run -p 4566:4566 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ministackorg/ministack                                   # + real RDS/ECS/Lambda containers
docker run -p 4566:4566 ministackorg/ministack:full        # + Athena/DuckDB
```

Health:

```bash
curl http://localhost:4566/_ministack/health      # or the LocalStack-compatible /_localstack/health
```

## Terraform integration

Because MiniStack shares LocalStack's `:4566` gateway and endpoint layout, **all three paths work**:

### Option A — `tflocal` (same wrapper as LocalStack)

`pip install terraform-local` then `tflocal init/plan/apply`. The wrapper just points the AWS
provider at `localhost:4566`; it doesn't care which emulator is listening. Zero `.tf` edits.

### Option B — `AWS_ENDPOINT_URL` env var (no wrapper, no block)

The AWS provider (recent majors, incl. `~> 6.0`) honors `AWS_ENDPOINT_URL`. Cleanest neutral path:

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
  secret_key                  = "test"      # 12-digit key → becomes the Account ID (multi-tenant)
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true

  endpoints {
    s3       = "http://localhost:4566"
    sqs      = "http://localhost:4566"
    sns      = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
    lambda   = "http://localhost:4566"
    iam      = "http://localhost:4566"
    # ...one line per service used
  }
}
```

Verify with `awslocal` (ships in MiniStack's `bin/awslocal`, or `pip install awscli-local`) or
`aws --endpoint-url=http://localhost:4566 s3 ls`.

## MiniStack vs LocalStack — pick for the book

| | MiniStack | LocalStack (2026) |
|---|---|---|
| License | MIT (open source) | Consolidated image; source-available |
| Cost / signup | **Free forever, no account, no token** | Free **Hobby** plan, but needs account + `LOCALSTACK_AUTH_TOKEN` |
| Image size | ~270 MB | ~1 GB |
| Port / API | `:4566`, AWS-compatible | `:4566`, AWS-compatible |
| Maturity | Newer, ~3.5k stars, active | Established, widely documented |
| Terraform | `tflocal` / `AWS_ENDPOINT_URL` / `endpoints` | `tflocal` / `endpoints` |

**Book stance:** lead with **MiniStack** as the zero-friction free default; keep LocalStack as the
mature, widely-documented alternative. Lab bodies use `tflocal`, which works against **either** — so
the reader swaps only the `docker run` line.

## Sources

- MiniStack repo / README — <https://github.com/ministackorg/ministack>
- Docker image — `ministackorg/ministack` (Docker Hub)
