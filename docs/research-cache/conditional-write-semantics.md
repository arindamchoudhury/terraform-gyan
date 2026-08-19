# Conditional-write semantics behind Terraform state locking

**Checked:** 2026-08-19
**Sources:**
- AWS — <https://docs.aws.amazon.com/AmazonS3/latest/userguide/conditional-writes.html>
- Google — <https://docs.cloud.google.com/storage/docs/request-preconditions>
- Terraform v1.15.8 source (`internal/backend/remote-state/`)

Written because chapter 15's lock transcripts were produced against local
emulators. The request is engine-side and provable from the source; the
response is the vendor's and needs the vendor's own page.

## What Terraform sends (engine-side, v1.15.8)

| Backend | Call | Precondition |
|---|---|---|
| `s3` | `PutObject` on `<key>.tflock` | `IfNoneMatch: aws.String("*")` (`s3/client.go:363`) |
| `gcs` | write to `<prefix>/<name>.tflock` | `If(storage.Conditions{DoesNotExist: true})` (`gcs/client.go:109`) |

Neither client inspects the HTTP status. `lockWithFile` wraps **any** upload
error as `statemgr.LockError`, attaching whatever `getLockInfoWithFile` can
read back.

## What the services answer

**Amazon S3.** *"If there's no existing object with the same key name in the
bucket, the write operation succeeds, resulting in a `200 OK` response. If
there's an existing object, the write operation fails, resulting in a
`412 Precondition Failed` response."* And for the racing case: *"If multiple
conditional writes or copies occur for the same object name, the first write
operation to finish succeeds. Amazon S3 then fails subsequent writes with a
`412 Precondition Failed` response."*

**Google Cloud Storage.** *"If there is a live version with the specified name,
the request fails with a status code of `412 Precondition Failed`."* And on the
zero value: *"When a generation-match precondition with a value of `0` is
included in a request, the request only proceeds if no object with the
specified name exists in the bucket or if there are only noncurrent versions of
the object in the bucket."*

So both emulators agreed with the documented behaviour for the ordinary
lock-collision case.

## Conditions the emulators cannot show

- **S3 returns `409 Conflict`, not 412**, when *"a delete request to an object
  succeeds before a conditional write operation on that object completes"*, and
  AWS says *"uploads may be retried after receiving a `409 Conflict` error."*
  In lock terms: one client releasing as another acquires. Terraform does not
  distinguish it, and its retry loop needs readable lock info, which is the
  thing that has just been deleted. **Not verified** whether this produces a
  spurious failure in practice.
- **`If-None-Match` requires AWS Signature Version 4.**
- On a **versioned** bucket the conditional write also succeeds when the current
  version is a **delete marker**; on GCS when only noncurrent versions remain.
- **IAM is not exercised at all** by the labs — the emulator authorises
  everything.

## Rule this establishes

Ask who decides the behaviour. The CLI deciding it means a local run is
conclusive. The service deciding it means a local run is a witness and the
vendor page is the authority.
