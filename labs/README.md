# Labs

Runnable Terraform configurations for the 🧪 **Lab** section of each book chapter under [`docs/book/`](../docs/book/). Every lab runs against a free local AWS emulator in Docker, so nothing here needs an AWS account, a credit card, or a network connection to a cloud provider.

## Prerequisites

- **Docker**, for the emulator.
- **Terraform** (>= 1.15) or **OpenTofu**, installed per [Chapter 2](../docs/book/ch02-install-providers-first-project.md).
- **`tflocal`** and **`awslocal`**: `pip install terraform-local awscli-local`.

Chapter 1's [lab setup section](../docs/book/ch01-iac-fundamentals.md) walks through all of it.

## Quick start

Start the emulator once. It stays up until you stop it.

```bash
docker compose -f labs/docker-compose.yml up -d
```

Set the lab environment once per shell. These forms work from anywhere inside the repository, including from inside a lab directory you have already `cd`-ed into:

```bash
source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"
```

```powershell
. "$(git rev-parse --show-toplevel)/labs/lab-env.ps1"
```

Standing in the repo root, `source labs/lab-env.sh` and `. .\labs\lab-env.ps1` do the same job with less typing. Reach for the longer form when you are already deep in a lab, because a bare relative path resolves against the current directory rather than against the script.

Then work in any lab directory:

```bash
cd labs/chapter13/lab1
tflocal init
tflocal apply
tflocal destroy
```

The emulator's web console is at `http://localhost:4500`, and `awslocal s3 ls` lists whatever your labs created. Stop everything with `docker compose -f labs/docker-compose.yml down`.

## Why `lab-env` matters

Left to its defaults, `tflocal` points the S3 endpoint at `s3.localhost.localstack.cloud`. That hostname starts with `s3.`, which `tflocal` reads as "this endpoint understands virtual-host addressing", so it omits `s3_use_path_style` from the override it generates. Every bucket then becomes a public DNS subdomain that has to be resolved over the network, and any resolver that declines to serve the wildcard turns into SDK retries that run out the two-minute resource timeout.

`lab-env.sh` and `lab-env.ps1` set `S3_HOSTNAME=localhost` to prevent that, along with the dummy credentials the emulator expects. `.envrc` does the same automatically for [direnv](https://direnv.net/) users, after one `direnv allow`. The full explanation, plus a permanent `setx` / shell-rc alternative, is in Chapter 1.

## Running the labs in a container

On a machine whose security software intercepts the loopback mTLS handshake between Terraform and its provider plugins, `tflocal` cannot run at all. `labs/tf-docker.sh` and `labs/tf-docker.ps1` are the way out. They run Terraform inside a container, where that handshake happens in its own network namespace and the host's filter driver never sees it. Nothing is disabled and no TLS is weakened.

Use them exactly where you would have used `tflocal`, from inside a lab directory:

```bash
"$(git rev-parse --show-toplevel)/labs/tf-docker.sh" init
"$(git rev-parse --show-toplevel)/labs/tf-docker.sh" apply -auto-approve
"$(git rev-parse --show-toplevel)/labs/tf-docker.sh" destroy -auto-approve
```

```powershell
& "$(git rev-parse --show-toplevel)/labs/tf-docker.ps1" init
& "$(git rev-parse --show-toplevel)/labs/tf-docker.ps1" apply -auto-approve
& "$(git rev-parse --show-toplevel)/labs/tf-docker.ps1" destroy -auto-approve
```

The script finds the emulator's Docker network from the running container, joins it, and reaches the emulator by container name instead of going back out through the host. It writes a `docker_providers_override.tf` carrying the endpoints, `s3_use_path_style`, and dummy credentials, which Terraform merges over the lab's own `provider` block. Your `.tf` files stay untouched and still apply to real AWS. That generated file is rewritten every run and is gitignored.

Provider binaries live in a Docker named volume rather than on the bind mount, which matters more than it sounds: reading a 700 MB provider through a Windows bind mount cost 21 seconds per command against 5 seconds from the volume.

`TF_IMAGE`, `EMULATOR_CONTAINER`, and `PLUGIN_VOLUME` override the defaults if you swap the emulator or pin a different Terraform version.

Two things to expect. The first `init` for a lab adds a `linux_amd64` hash to its `.terraform.lock.hcl`, which is a genuine improvement, because the lock then covers both platforms. And `chapter13/lab3` builds a Git repository in your host temp directory, which the container cannot see, so run that one on the host.

## What is where

| Directory | Chapter | Subject |
|---|---|---|
| `chapter2/` | [Ch 2](../docs/book/ch02-install-providers-first-project.md) | First project: install, init, apply |
| `chapter3/` | [Ch 3](../docs/book/ch03-core-workflow.md) | The core workflow |
| `chapter4/` | [Ch 4](../docs/book/ch04-hcl-language-basics.md) | HCL basics, split across conventional file names |
| `chapter5/` | [Ch 5](../docs/book/ch05-providers-resources.md) | Providers and resources |
| `chapter8/` | [Ch 8](../docs/book/ch08-data-sources.md) | Data sources |
| `chapter9/lab1/`, `lab2/` | [Ch 9](../docs/book/ch09-state-fundamentals.md) | State fundamentals; lab 2 measures how the `serial` moves |
| `chapter10/lab1/`, `lab2/` | [Ch 10](../docs/book/ch10-meta-arguments.md) | `count` versus `for_each`, and migrating between them with `moved` |
| `chapter11/lab1/` … `lab7/` | [Ch 11](../docs/book/ch11-lifecycle.md) | `lifecycle`: `prevent_destroy`, `create_before_destroy`, `ignore_changes` |
| `chapter12/lab1/` … `lab5/` | [Ch 12](../docs/book/ch12-dynamic-blocks-complex-types.md) | `dynamic` blocks and complex types |
| `chapter13/lab1/` … `lab3/` | [Ch 13](../docs/book/ch13-using-modules.md) | Local, registry, and Git-sourced modules |
| `chapter15/lab1/` … `lab3/`, `gitlab/` | Ch 15 (unwritten) | Backends: `local`, then `s3` on the AWS emulator, then `gcs` on the GCP one |

Chapters 6 and 7 have labs too, but you type their files out from the chapter text, so they have no committed directory here.

Chapter 15 is the exception to "one emulator": its `gcs` lab needs the **GCP** emulator, which the `gcs` backend requires because it speaks the Google JSON API at `/storage/v1/b` rather than S3. It is behind a compose profile, so it stays out of the way until you ask for it:

```bash
docker compose -f labs/docker-compose.yml --profile gcp up -d
```

That chapter also carries two directories that are not numbered labs: `chapter15/gitlab/` runs a self-hosted GitLab so a pipeline can drive an S3-backed Terraform, and `chapter15/http-backend/` is appendix reading — a whole `http` backend in one dependency-free file.

Two directories are not numbered labs. `chapter13/example-as-module/` demonstrates that a registry module's own `examples/` directory is itself a callable module, and it only needs `terraform get`. `chapter9/lab2/` holds `measure-serial.sh` and `measure-serial.ps1`, which run an apply repeatedly and report the spread in state serial numbers.

## The sidecar file convention

Several labs ship a second copy of a configuration under a suffixed name, such as `main.tf.after` or `main.tf.cbd`. These are not loaded by Terraform, because it only reads `.tf` files. The chapter tells you when to copy one over the live file to move to the next step:

```bash
cp main.tf.after main.tf
```

The suffix says what the alternate version does. `chapter10/lab2/main.tf.after` is the `for_each` rewrite with `moved` blocks, `chapter11/lab2/main.tf.cbd` adds `create_before_destroy`, `chapter11/lab4/main.tf.ignore` adds `ignore_changes`, and `chapter12/lab4/main.tf.broken` is the version whose constraint failures `terraform validate` actually reports. Not all of them land on `main.tf`. Chapter 12 copies its sidecars over `probe.tf`, `contrast.tf`, and `mod-optional/main.tf`, so follow the chapter's command rather than assuming the destination.

`chapter11/lab1/main.tf.tofu` is different in kind. It is the OpenTofu run of the same measurement, kept as a plain file because a real `main.tofu` would shadow `main.tf` and change what the directory means depending on which binary you run.

## Labs that generate their own inputs

`chapter13/lab3/` needs a Git repository to source a module from, and builds one locally rather than sending you to GitHub. Run `./setup.sh` (or `.\setup.ps1`) first. It creates a throwaway repository with two tagged releases in your temp directory and writes `repo.auto.tfvars` pointing at it. That generated file is gitignored, so re-run the setup script after a clean checkout.

## Cleaning up

Run `tflocal destroy` when you finish a lab. Leaving stale state files behind will confuse the next lab that reuses a bucket name.

### Starting the emulator from a clean slate

The emulator keeps its data in memory, so restarting the container is the whole cleanup:

```bash
docker restart floci-lab
```

Verified 2026-08-20: a bucket created on `:4566` is gone after that command returns, and gone again after `docker compose -f labs/docker-compose.yml up -d --force-recreate floci`. Do not be misled by `docker inspect floci-lab`, which shows a volume mounted at `/app/data` and an `FLOCI_STORAGE_PERSISTENT_PATH` pointing at it. That volume survives a recreate with its identifier unchanged, and the buckets still do not come back, so no `down -v` is needed to clear state.

Wait for the emulator to answer again before the next `tflocal` command, because the container reports itself started before its services are:

```bash
until curl -sf http://localhost:4566/_floci/health >/dev/null; do sleep 1; done
```

Clear the Terraform side too, or the next `apply` plans against resources the emulator no longer has. State files are per lab directory, so delete only the ones you are resetting:

```bash
rm -f terraform.tfstate terraform.tfstate.backup
```

Deleting a lab's `.terraform/` directory as well costs you a provider re-download on the next `init`, which is why it is worth keeping unless the lab is misbehaving.

State files, plan files, `.terraform/` directories, and the `localstack_providers_override.tf` that `tflocal` generates are all gitignored. Lock files and `.tfvars` are committed on purpose, so the labs pin the same provider versions the chapters measured.

## When something misbehaves

- **An S3 operation hangs, then fails with `context deadline exceeded`.** The `S3_HOSTNAME` problem above. Check that you sourced `lab-env`.
- **`Failed to load plugin schemas` on every provider.** Terraform talks to its plugins over mTLS on loopback, and some endpoint security products block it. It is not a provider or emulator fault. Run the lab through `tf-docker` instead, as described above.
- **A command takes minutes, then does its actual work instantly.** The same interception, degrading rather than failing outright. Confirm it by comparing `terraform version`, which loads no plugin, against `terraform providers schema -json`, which starts one. A gap of seconds between them means the time is going into Terraform's channel to its provider, not into the emulator. Checking the emulator's log settles it: a long silence followed by millisecond-scale operations means the API calls were never the problem.
- **`Unexpected attribute` for a service you never used.** A stale `localstack_providers_override.tf` from an older `tflocal` run. Delete it and run `tflocal init` again.
- **`Error: creating S3 Bucket (…): BucketAlreadyExists`.** The bucket is in the emulator, but not in the state file this configuration is applying, so Terraform tries to create it a second time. Real AWS words the same situation as `BucketAlreadyOwnedByYou` when your own account holds the name. It follows an earlier run whose state was lost or deleted after the bucket was created. Either adopt what is there with `tflocal import aws_s3_bucket.state <bucket>` and apply again, or restart the emulator as described under "Starting from a clean slate". Check the bucket is empty before you throw it away: `awslocal s3 ls s3://<bucket> --recursive`.
