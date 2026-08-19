# Chapter 15 — Remote state & backends

Three labs, one idea each, in the order the chapter teaches them: **local**,
then **s3**, then **gcs**. Everything here was run end to end on Terraform
1.15.8 on 2026-08-19; the command output quoted in the chapter comes from these
directories.

| Directory | Backend | Needs |
|---|---|---|
| `lab1/` | `local` | nothing — no emulator, no credentials, no network |
| `lab2/` | `s3` | the AWS emulator on `:4566` (the book's usual one) |
| `lab3/` | `gcs` | the GCP emulator on `:4588`, behind a compose profile |
| `gitlab/` | `s3`, driven from GitLab CI | a self-hosted GitLab container and a runner |
| `http-backend/` | — | appendix reading, not a lab |

Every configuration uses **`terraform_data`** for the thing being tracked. It is
built into Terraform, so no lab needs a provider plugin, a registry download, or
the loopback plugin handshake that endpoint security software interferes with.
The one exception is `lab2/bootstrap`, which genuinely has to create an S3
bucket and so uses the AWS provider.

## lab1 — the local backend, said out loud

Every earlier chapter used the local backend without naming it. This one names
it and moves the file:

```hcl
backend "local" {
  path = "state/dev.tfstate"
}
```

```bash
cd labs/chapter15/lab1
terraform init
terraform apply
```

The state appears at `state/dev.tfstate` rather than `./terraform.tfstate`.
Then copy the sidecar `main.tf.default` over `main.tf` and re-run `terraform
init`. A backend is already recorded in `.terraform/`, so a plain `init` refuses:

```
Error: Backend configuration changed
...
If you wish to attempt automatic migration of the state, use "terraform
init -migrate-state".
```

Run `terraform init -migrate-state` and Terraform offers to bring the state
*back*, which is the whole of "removing a backend" — there is no separate
command for it. Measured on 1.15.8: only a **first** backend adoption prompts
without the flag; every later change, including removal, errors first.

The old `state/dev.tfstate` is still there afterwards, complete. Migration
copies and never cleans up.

## lab2 — the `s3` backend, and the two-step bootstrap

The chicken-and-egg: the bucket holding your state cannot be tracked in that
state before it exists. So there are two configurations.

```bash
docker compose -f labs/docker-compose.yml up -d
source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"

cd labs/chapter15/lab2/bootstrap
tflocal init && tflocal apply       # creates tf-state-lab, versioned, PAB on
```

`bootstrap/` stays on the local backend forever. `app/` is the configuration
that migrates:

```bash
cd ../app
terraform init && terraform apply   # local state first, so there is something to move
cp main.tf.s3 main.tf
terraform init -backend-config=config.s3.tfbackend -migrate-state
```

Answer `yes` and the state lands at `s3://tf-state-lab/app/terraform.tfstate`.
Verified: `Successfully configured the backend "s3"!`, and

```bash
aws --endpoint-url http://localhost:4566 s3 ls s3://tf-state-lab --recursive
```

shows `app/terraform.tfstate`.

Two things `config.s3.tfbackend` exists to teach. **The backend block is
empty** — partial configuration keeps the shape in Git and the environment out
of it. And **`endpoints` is an attribute, not a block**: `endpoints { s3 = … }`
is a parse error, which is the first thing that goes wrong against any emulator.

Then the lock:

```bash
cp slow.tf.lock slow.tf
terraform apply -auto-approve      # holds the lock for 30 seconds
# in a second terminal:
terraform plan
```

Verified refusal, and the mechanism is visible in it:

```
Error message: operation error S3: PutObject, https response error StatusCode: 412,
api error PreconditionFailed: At least one of the pre-conditions you specified did not hold
Lock Info:
  Path:      tf-state-lab/app/terraform.tfstate
```

`use_lockfile = true` writes a `<key>.tflock` object with a conditional PUT. The
412 *is* the lock. No DynamoDB table anywhere.

## lab3 — the `gcs` backend

The same shape against a different cloud, which is the point: seeing where the
two backends agree and where they do not.

```bash
docker compose -f labs/docker-compose.yml --profile gcp up -d
cd labs/chapter15/lab3
./create-bucket.sh                  # .\create-bucket.ps1 on PowerShell
terraform init -backend-config=config.gcs.tfbackend
terraform apply
```

Verified: the state object is `terraform/state/default.tfstate`. Note what that
name is made of. There is **no `key`** in the gcs backend — state is addressed
as `<prefix>/<workspace>.tfstate`, so the default workspace supplies `default`.
That is the first real difference from `s3`.

The second is that **locking is not opt-in here**. `gcs` locks by default, with
no `use_lockfile` equivalent to remember, and the refusal names the mechanism:

```
Error message: writing "gs://tf-state-lab/terraform/state/default.tflock" failed:
googleapi: Error 412: ifGenerationMatch: 1787133258314 != 0, conditionNotMet
```

A **412 conditional write on an object**, exactly like S3's — same idea, two
vendors' spellings of it. Worth noticing that this is the whole of distributed
state locking on both clouds: no lock service, no table, one object that must
not already exist.

!!! note "`storage_custom_endpoint` is being used off-label"
    HashiCorp documents it for **Private Service Connect**, describing a URL of
    "the protocol, the DNS name … and the path for the Cloud Storage API
    (`/storage/v1/b`)". It is a plain URL override, which is why pointing it at
    an emulator works. That is this lab's finding, not a documented promise —
    against real GCS you would not set it at all.

## gitlab — the forge half

Its own README. The point it makes is deliberately *not* "GitLab can store
state": it is that your repository and your pipeline can live on a forge while
state stays in **S3**, which is the arrangement most teams actually run. See
`gitlab/README.md`.

## http-backend — appendix, not a lab

`state_server.py` is a complete Terraform `http` backend in one file with no
dependencies: `GET`/`POST`/`DELETE` for the state, `LOCK`/`UNLOCK` returning
**423** when the lock is held. It is here as reading material for what a backend
*is* underneath — the same contract GitLab's Terraform-state feature implements
inside a Rails app. Nothing in the chapter requires it.

## Cleaning up

```bash
docker compose -f labs/docker-compose.yml --profile gcp down
```

State files, plan files, `.terraform/` directories and the `slow.tf` copies are
gitignored. The emulators keep everything in memory, so restarting either one
clears the buckets.
