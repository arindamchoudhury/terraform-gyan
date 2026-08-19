# `terraform force-unlock` command

> **Source:** [developer.hashicorp.com/terraform/cli/commands/force-unlock](https://developer.hashicorp.com/terraform/cli/commands/force-unlock)
> **Added:** 2026-08-19
> **Source updated:** undated command reference; captured 2026-08-19 against v1.15.x (latest)
> **Tags:** cli, force-unlock, state-locking, lock-id, disaster-recovery, backends
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Disaster Recovery › `force-unlock` · v1.15.x*

The command half of [[tf-state-locking]], which is where the *policy* on using it lives. This page is almost entirely usage, about 900 characters, and adds three facts that page does not carry.

> "This command removes the lock on the state for the current configuration. **The behavior of this lock is dependent on the backend being used. Local state files cannot be unlocked by another process.** The `terraform force-unlock` command does not modify your infrastructure."

## Usage

```
terraform force-unlock [options] LOCK_ID
```

**`LOCK_ID` is a required positional argument.** [[tf-state-locking]] explains why: the ID is a nonce identifying one specific lock acquisition, and Terraform prints it in the `Lock Info` block when acquisition fails. There is no way to list locks and no way to unlock by path.

## Options

| Option | Effect |
| --- | --- |
| `-force` | "Don't ask for input for unlock confirmation." |

One option, and the name invites a misreading.

!!! warning "`-force` skips the prompt, not the lock ID"
    The confirmation prompt is the *second* guard, and the only one `-force` removes. The `LOCK_ID` argument is the first, and it is not optional with or without the flag. So `terraform force-unlock -force` with no ID is a usage error, not a blind unlock.

    This is the flag to reach for in automation, where there is no one to answer a prompt. Reach for it there and nowhere else, because in a pipeline the run holding the lock is exactly the kind of lock the [[tf-state-locking]] guidance says not to break.

## The two claims worth carrying

**"Does not modify your infrastructure."** Stated plainly, and it is the reassurance you want before running an unfamiliar command during an incident. It touches the lock, not the state object and not any resource. What it *can* cause is a second writer, which then corrupts state — the damage is downstream, not in the command itself.

**"Local state files cannot be unlocked by another process."** The `local` backend locks through system APIs ([[tf-backend-local]]), so its lock is held by the operating system on behalf of one process rather than recorded as data somewhere. A different `terraform` invocation cannot release it. The practical consequence is that a stuck local lock is fixed by dealing with the process that holds it, not by this command, and that `force-unlock` is really a remote-backend tool.

**Backend-dependent behaviour** is the third. There is no single unlock operation. On the `s3` backend it deletes the `<key>.tflock` object, which is why the IAM policy in [[tf-backend-s3]] needs `s3:DeleteObject` on that object and nowhere else. On `gcs` it is the same shape against `<prefix>/<name>.tflock` ([[tf-backend-gcs]]). A backend that supports no locking has nothing for this command to do.

---
Related: [[tf-state-locking]] — the concept page, the nonce rationale, the "only unlock your own lock" boundary, and a verified `Lock Info` block showing where a real `LOCK_ID` comes from. · [[tf-cli-commands]] — the command catalogue that lists this one row. · [[tf-backend-s3]] · [[tf-backend-gcs]] — the `.tflock` objects this command deletes. · [[tf-backend-local]] — the system-API locking that this command cannot touch.
