# Self-hosted GitLab for the state-backend labs

The odd one out. Every other lab in this book runs against the AWS emulator with
no accounts and no real resources; this one runs a real GitLab, because
GitLab-managed Terraform state **is** the GitLab Rails application implementing
the `http` backend protocol. There is nothing smaller to substitute for it if you
want the product behaviour — roles, state versions, the lock UI.

If you only want the *protocol*, skip this directory. The `http`-backend lab
beside it exercises `GET`/`POST`/`DELETE` and `LOCK`/`UNLOCK` against a server
you can read in one sitting, offline, in megabytes.

Everything below was measured on this repository's own machine on 2026-08-19,
running `gitlab/gitlab-ce:19.2.4-ce.0` under Docker Desktop on Windows 11 with a
9.7 GB WSL2 VM. Where a number differs from GitLab's documentation, both are
given.

## What it costs

| | Documented | Measured here |
|---|---|---|
| Image | 1.38 GB on Docker Hub | **3.54 GB on disk** after pull |
| Disk | 20 GB available | not re-measured; 20 GB is a fair budget |
| Memory | 2 GB + 1 GB swap | **1.5 GB** at first serve, **2.5–3.2 GB** warming, **2.3 GB** steady |
| Time to serve | "could take a while" | **~7 minutes** from `up -d` on 16 cores |

The documented figures come from [Running GitLab in a memory-constrained
environment](../../../docs/sources/gitlab-docs/gitlab-memory-constrained.md),
which is also where every setting in `docker-compose.yml` comes from. GitLab's
main requirements page quotes **16 GB** as the single-node baseline and **8 GB**
for constrained installs; the page it links to for the details says 2 GB. This
container is the 2 GB configuration, and it fits — with the honest caveat that
2.3 GB resident is what it settles at here with swap untouched, so GitLab's 2 GB
figure assumes the swapping its own page says to expect.

On Docker Desktop, swap belongs to the Linux VM rather than to the container:

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

!!! warning
    **Do not wait for the container to report `healthy` — it says so too early.**
    Measured here: healthy after ~1 minute, while `gitlab-ctl status` still showed
    only `gitaly`, `postgresql`, `redis`, `logrotate` and `sshd`, with no `puma`
    and no `nginx`. HTTP did not answer for another six minutes.

Wait for the application itself instead:

```bash
until [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8929/users/sign_in)" = "200" ]; do sleep 20; done
```

**Use `127.0.0.1`, never `localhost`.** On Windows, `localhost` resolves to `::1`
first and the published IPv6 mapping does not answer: measured here,
`127.0.0.1:8929` returned 200 while `localhost:8929` returned an empty reply
(curl exit 52), with the same request succeeding *inside* the container. That is
why `external_url` in the compose file is an IPv4 literal — otherwise every link
GitLab generates points somewhere your browser cannot reach.

## Get in

The initial root password is generated inside the container and **expires after
24 hours**:

```bash
docker exec tf-lab-gitlab cat /etc/gitlab/initial_root_password
```

Sign in at <http://127.0.0.1:8929> as `root`, then create a project and a
personal access token with the `api` scope from *User settings › Access tokens*.

For a scripted setup, both can be done without the UI. A token first:

```bash
docker exec tf-lab-gitlab gitlab-rails runner "
u = User.find_by_username('root')
t = u.personal_access_tokens.create!(scopes: ['api'], name: 'tf-lab', expires_at: 30.days.from_now)
t.set_token('glpat-tflabtflabtflabtfla')
t.save!
puts 'TOKEN_OK'
"
```

Then a project, and its ID:

```bash
curl -s -H "PRIVATE-TOKEN: glpat-tflabtflabtflabtfla" \
  -X POST "http://127.0.0.1:8929/api/v4/projects" \
  -d "name=tf-state-lab&visibility=private"
```

The first project on a fresh instance gets **ID 1**, which keeps the rest of this
file copy-pasteable. That token value is a throwaway for a container on your own
loopback interface; never reuse the pattern against a real instance.

## Point Terraform at it

The backend block stays empty — everything is supplied at `init`:

```hcl
terraform {
  backend "http" {
  }
}
```

```bash
export TF_ADDRESS="http://127.0.0.1:8929/api/v4/projects/1/terraform/state/lab"

terraform init \
  -backend-config=address=${TF_ADDRESS} \
  -backend-config=lock_address=${TF_ADDRESS}/lock \
  -backend-config=unlock_address=${TF_ADDRESS}/lock \
  -backend-config=username=root \
  -backend-config=password=glpat-tflabtflabtflabtfla \
  -backend-config=lock_method=POST \
  -backend-config=unlock_method=DELETE \
  -backend-config=retry_wait_min=5
```

`-backend-config` is used here because it is a lab and the values are visible on
purpose. In CI, GitLab tells you to use the `TF_HTTP_*` environment variables
instead, because flag values are cached into the plan and carried to the apply,
which can leave a job unable to lock the state.

A configuration using only `terraform_data` is enough, and is what this lab was
verified with — no provider plugin means no registry download and no loopback
mTLS handshake for endpoint security software to interfere with.

## What to actually look at

**1. The state, over the API rather than the UI.** After the first apply:

```bash
curl -s -H "PRIVATE-TOKEN: glpat-tflabtflabtflabtfla" \
  "http://127.0.0.1:8929/api/v4/projects/1/terraform/state/lab"
```

Verified: the document comes back with `"serial": 1` and your outputs in it.

**2. The lock, by taking it out from under Terraform.** Hold it by hand:

```bash
curl -s -X POST "${TF_ADDRESS}/lock" \
  -H "PRIVATE-TOKEN: glpat-tflabtflabtflabtfla" \
  -H "Content-Type: application/json" \
  -d '{"ID":"manual-holder","Operation":"OperationTypeApply","Who":"lab@host","Version":"1.15.8","Created":"2026-08-19T09:45:00Z","Path":""}'
```

Then run `terraform apply` and read the refusal:

```
Error: Error acquiring the state lock

Error message: HTTP remote state already locked: ID=manual-holder
Lock Info:
  ID:        manual-holder
  Operation: OperationTypeApply
  Who:       root
  Version:   1.15.8
  Created:   2026-08-19 09:33:14.783 +0000 UTC
```

Note `Who: root`. The request above claimed `lab@host`, and **GitLab replaced it
with the identity of the token**, along with its own `Created` timestamp. The
holder of a GitLab state lock is a GitLab user, not whatever the client asserted
— which is the concrete form of the docs' rule that locking and unlocking are
role-gated.

Release it with the same ID:

```bash
curl -s -X DELETE "${TF_ADDRESS}/lock" \
  -H "PRIVATE-TOKEN: glpat-tflabtflabtflabtfla" \
  -H "Content-Type: application/json" -d '{"ID":"manual-holder"}'
```

**3. Versions, addressed by serial.** After a second apply the current state is
at `"serial": 2`, and both snapshots are retrievable:

```bash
curl -s -H "PRIVATE-TOKEN: glpat-tflabtflabtflabtfla" "${TF_ADDRESS}/versions/1"
```

Verified: serial 1 and 2 return 200, serial 3 returns 404. This is the same
counter Chapter 9 measured, now doubling as an addressable version history.

**4. Who can read it.** Add a second user with the Developer role and confirm
they can download the state file. That is the finding the docs state plainly and
the reason this backend needs thinking about before adopting.

## Stop it

```bash
docker compose -f labs/chapter15/gitlab/docker-compose.yml down
```

Volumes survive that, so the next start is fast and your project is still there.
To reclaim the disk:

```bash
docker compose -f labs/chapter15/gitlab/docker-compose.yml down -v
```
