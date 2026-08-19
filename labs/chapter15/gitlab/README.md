# Self-hosted GitLab for the state-backend labs

The odd one out. Every other lab in this book runs against the AWS emulator with
no accounts and no real resources; this one runs a real GitLab, because
GitLab-managed Terraform state **is** the GitLab Rails application implementing
the `http` backend protocol. There is nothing smaller to substitute for it if you
want the product behaviour — roles, state versions, the lock UI.

If you only want the *protocol*, skip this directory. The `http`-backend lab
beside it exercises `GET`/`POST`/`DELETE` and `LOCK`/`UNLOCK` against a server
you can read in one sitting, offline, in megabytes.

## What it costs

| | |
|---|---|
| Image download | ~1.4 GB compressed |
| Disk | 20 GB available, per GitLab's own floor |
| Memory | **2 GB + 1 GB swap** minimum, 2.5 GB comfortable |
| First boot | several minutes — the image unpacks, then omnibus reconfigures |

Those numbers are GitLab's, from [Running GitLab in a memory-constrained
environment](../../../docs/sources/gitlab-docs/gitlab-memory-constrained.md),
which is also where every setting in `docker-compose.yml` comes from. Note that
GitLab's main requirements page quotes **16 GB** as the single-node baseline and
**8 GB** for constrained installs; the page it links to for the details says
2 GB. The tuned configuration here is the 2 GB one, and the page backs it with a
measured `free -h`.

On Docker Desktop, swap belongs to the Linux VM rather than to the container.
Check what you have before starting:

```bash
docker run --rm alpine free -m
```

If that shows less than ~3 GB of memory free, raise the VM's allocation in
`%USERPROFILE%\.wslconfig` (`[wsl2]` → `memory=`) and restart Docker.

## Start it

```bash
docker compose -f labs/chapter15/gitlab/docker-compose.yml up -d
```

```bash
docker logs -f tf-lab-gitlab
```

Wait for the container to report healthy, then open <http://localhost:8929>.

The initial root password is generated inside the container and **expires after
24 hours**:

```bash
docker exec tf-lab-gitlab cat /etc/gitlab/initial_root_password
```

Sign in as `root`, change the password, and create a project. You need three
things from the UI afterwards:

- the **project ID**, on the project's overview page;
- a **personal access token** with the `api` scope, from *User settings ›
  Access tokens*;
- your **username**, which is `root` unless you made another account.

## Point Terraform at it

The backend block stays empty — everything is supplied at `init`:

```hcl
terraform {
  backend "http" {
  }
}
```

```bash
export PROJECT_ID="<project-id>"
export TF_USERNAME="root"
export TF_PASSWORD="<personal-access-token>"
export TF_ADDRESS="http://localhost:8929/api/v4/projects/${PROJECT_ID}/terraform/state/lab"

terraform init \
  -backend-config=address=${TF_ADDRESS} \
  -backend-config=lock_address=${TF_ADDRESS}/lock \
  -backend-config=unlock_address=${TF_ADDRESS}/lock \
  -backend-config=username=${TF_USERNAME} \
  -backend-config=password=${TF_PASSWORD} \
  -backend-config=lock_method=POST \
  -backend-config=unlock_method=DELETE \
  -backend-config=retry_wait_min=5
```

`-backend-config` is used here because it is a lab and the values are visible on
purpose. In CI, GitLab tells you to use the `TF_HTTP_*` environment variables
instead, because flag values are cached into the plan and carried to the apply,
which can leave a job unable to lock the state.

Then apply anything — the emulator labs' configurations work — and look at
*Operate › Terraform states*.

## What to actually look at

1. **The state object**, with its serial, after the first apply.
2. **The lock**, held during an apply and released after. Lock it by hand from
   the UI or with `glab opentofu state lock <name>` and watch a second run fail.
3. **Versions**, addressed by serial, and downloadable — the same counter
   Chapter 9 measured.
4. **Who can read it.** Add a second user with the Developer role and confirm
   they can download the state file. That is the finding the docs state plainly
   and the reason this backend needs thinking about before adopting.

## Stop it

```bash
docker compose -f labs/chapter15/gitlab/docker-compose.yml down
```

Volumes survive that, so the next start is fast and your project is still there.
To reclaim the disk:

```bash
docker compose -f labs/chapter15/gitlab/docker-compose.yml down -v
```

> **Not yet run end to end.** The compose file is assembled from GitLab's
> documented settings but has not been booted on this machine. Expect to correct
> small things on the first run, and update this README when you do.
