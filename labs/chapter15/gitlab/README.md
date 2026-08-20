# The forge lab — GitLab CI, state in S3

The arrangement most teams actually run, and the one the chapter argues for:
**the repository and the pipeline live on the forge; the state lives in an
object store.** GitLab can store Terraform state itself, and this lab
deliberately does not use that feature — it runs the same `s3` backend as lab 2,
from a CI job.

Everything below was run end to end on 2026-08-19 against
`gitlab/gitlab-ce:19.2.4-ce.0`, `gitlab/gitlab-runner:v19.2.2` and Terraform
1.15.8 in the job container, under Docker Desktop on Windows 11 with a 9.7 GB
WSL2 VM. Where a number differs from GitLab's documentation, both are given.

## What it costs

| | Documented | Measured here |
|---|---|---|
| Image | 1.38 GB on Docker Hub | **3.54 GB on disk** after pull |
| Memory | 2 GB + 1 GB swap | **1.5 GB** at first serve, **2.3 GB** steady |
| Time to serve | "could take a while" | **~7 minutes** from `up -d`, twice measured |

The documented figures come from GitLab's own
[memory-constrained guidance](../../../docs/sources/gitlab-docs/gitlab-memory-constrained.md),
which is where every setting in `docker-compose.yml` comes from. GitLab's
requirements page quotes 16 GB as the single-node baseline and 8 GB for
constrained installs; the page it links to for detail says 2 GB. This is the
2 GB configuration, and it fits — with the caveat that 2.3 GB resident is what
it settles at here with swap untouched.

Check the Docker VM has room before starting:

```bash
docker run --rm alpine free -m
```

## Run it

The emulator first, because the pipeline writes into the bucket lab 2 creates:

```bash
docker compose -f labs/docker-compose.yml up -d
cd labs/chapter15/lab2/bootstrap && tflocal init && tflocal apply
```

Then GitLab and the runner, which join the emulator's network so a job container
can resolve `floci-lab:4566`:

```bash
docker compose -f labs/chapter15/gitlab/docker-compose.yml up -d
```

!!! warning "Do not wait for `healthy` — it reports healthy long before it serves"
    Measured twice: healthy after ~1 minute while `gitlab-ctl status` still
    listed only `gitaly`, `postgresql`, `redis`, `logrotate` and `sshd`. Puma
    and nginx arrived six minutes later, with a window of **502** in between
    while Puma booted the app.

    `setup.py` polls `/users/sign_in` for a 200 rather than trusting the health
    status. That is the check to copy.

**Use `127.0.0.1`, never `localhost`.** On Windows, `localhost` resolves to
`::1` first and the published IPv6 mapping returns an empty reply (curl exit
52), while `127.0.0.1` returns 200 — with the same request succeeding *inside*
the container. That is why `external_url` is an IPv4 literal.

Then:

```bash
python setup.py
```

It creates an API token, a project and an instance runner; registers the runner
with the docker executor; and commits `ci/` into the project, which triggers the
first pipeline. Re-running it is safe.

It is Python rather than a shell script so that one implementation covers every
shell this lab runs in, PowerShell included. It imports nothing outside the
standard library, and it shells out only to `docker`. The section below maps
every step to the UI equivalent if you would rather click it.

## What `setup.py` does, and why each part is needed

Doing it by hand in the UI works too — this is the map.

**An admin API token**, created through `gitlab-rails runner`, because the API
needs a token before it can make one. The initial root password is at
`/etc/gitlab/initial_root_password` and expires after 24 hours.

**An instance runner**, created with `POST /api/v4/user/runners` and registered
with three arguments that matter:

- `--docker-network-mode labs_default` puts every **job container** on the
  emulator's network. Without it the job resolves nothing, and
  `endpoints = { s3 = "http://floci-lab:4566" }` fails.
- `--clone-url http://tf-lab-gitlab:8929` overrides the `external_url` GitLab
  advertises. The UI needs `127.0.0.1` for your browser; a job container cannot
  reach that, and would fail at `git fetch`.
- `--docker-image hashicorp/terraform:1.15.8` is only the default; the pipeline
  names its own.

!!! danger "Pin the runner image — `:latest` is a pre-release and every job fails"
    Measured 2026-08-19. `gitlab/gitlab-runner:latest` was
    **19.3.0~pre.1819.g9cbf0074**, and the runner derives its helper image tag
    from its own version, so every job died in `prepare_executor`:

    ```
    ERROR: Job failed: failed to pull image
    "registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper:x86_64-v19.3.0"
    ... manifest unknown
    ```

    The helper image for an unreleased version does not exist.
    `x86_64-<commit-sha>` did exist, but the fix is to pin the runner to a
    released tag on the same line as GitLab itself — `v19.2.2` here. This is a
    general trap rather than a lab artefact: a "latest" runner against a stable
    GitLab is a broken pipeline.

## The pipeline

`ci/.gitlab-ci.yml`, three stages, and nothing in it is GitLab-specific except
the file name:

- **validate** — `terraform fmt -check` then `terraform validate`. `-check`
  rather than bare `fmt`, so the job fails instead of silently reformatting.
- **plan** — `terraform plan -out=tfplan`, kept as an artifact with
  `expire_in: 1 hour` and `access: 'developer'`. A plan file holds the full
  prior state and every variable value in cleartext, and job artifacts are
  readable by Guests by default.
- **apply** — `terraform apply tfplan`, `when: manual`. It applies the **saved
  plan**, so what was reviewed is what runs.

Every job runs `terraform init -input=false -backend-config=config.s3.tfbackend`
first. `-input=false` turns a missing value into a failure rather than a job
that hangs until it times out.

The backend file differs from lab 2's in exactly one line — the endpoint is a
container name rather than the host's loopback:

```hcl
endpoints = { s3 = "http://floci-lab:4566" }
```

## Verified

Pipeline 2, after pinning the runner:

```
4 validate success
5 plan     success
6 apply    manual  -> success once played
```

From the apply job's trace:

```
Initializing the backend...
Successfully configured the backend "s3"! Terraform will automatically
terraform_data.probe: Creation complete after 0s [id=21e8f9c6-...]
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
Outputs:
probe = "managed-from-gitlab-ci"
```

And the bucket afterwards, which is the whole lab in two lines:

```bash
aws --endpoint-url http://localhost:4566 s3 ls s3://tf-state-lab --recursive
```

```
2026-08-20 11:09:29        922 app/terraform.tfstate     # lab 2, from a workstation
2026-08-20 10:26:24        958 ci/terraform.tfstate      # this pipeline, from a runner
```

That command works in PowerShell as well, once `labs/lab-env.ps1` has been
sourced for the dummy credentials. Without them the AWS CLI reaches for a real
login provider and fails at `https://us-east-1.signin.aws.amazon.com`, which
looks like a network problem and is not one.

Two states, two operators, one bucket, and nothing about Terraform state stored
on the forge.

## What changes against a real cloud

The `access_key`/`secret_key` pair in `config.s3.tfbackend` is emulator
scaffolding. Against real AWS you delete both and let the job assume a role
through OIDC — the S3 backend's `assume_role_with_web_identity` block, fed by
the forge's identity token. The mechanism is the same on all three forges (see
the `gha-oidc` and `bitbucket-pipelines-oidc` notes for the other two), and
topic **A6** owns the secrets hierarchy behind it.

## If you want GitLab-managed state instead

This lab does not use it, but it exists, and it is the `http` backend rather
than a backend type of its own: an empty `backend "http" {}` pointed at
`/api/v4/projects/<ID>/terraform/state/<NAME>`. The trade is that project roles
replace bucket IAM — and that every **Developer** can download the state file.
See `docs/sources/gitlab-docs/gitlab-tf-state.md`, and the appendix in
`../http-backend/` for what the protocol underneath looks like.

## Stop it

```bash
docker compose -f labs/chapter15/gitlab/docker-compose.yml down
```

Volumes survive, so the next start is fast and the project is still there. To
reclaim the disk as well:

```bash
docker compose -f labs/chapter15/gitlab/docker-compose.yml down -v
```
