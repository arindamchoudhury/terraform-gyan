# Chapter 9 — State fundamentals

## Learning outcomes

By the end you can:

- Explain why Terraform needs a state file at all, and why the obvious alternative — rediscovering resources by tag on every run — was tried and abandoned.
- Name the four jobs state does: **bindings**, **retained dependencies**, **an attribute cache**, and **state-only resources**.
- Open `terraform.tfstate`, identify every top-level field, and say what `serial` and `lineage` are for.
- Trace a resource address in state to the real cloud object it manages, and back again from a cloud ID to the address that owns it.
- State the **one-to-one mapping rule** and name the two operations that break it.
- Read state safely with `terraform state list`, `state show`, `show -json`, and `output -json` — and explain which of those is a supported machine interface and which is not.
- Explain how drift is detected, what `-refresh-only` does, and why `-refresh=false` inverts Terraform's model of truth.
- **Articulate three reasons never to edit state by hand**, and prove that a `sensitive` value is stored in it as plaintext.

---

## 1. The problem: your code and your cloud share no identifier

You write this:

```hcl
resource "aws_s3_bucket" "notes" {
  bucket = "state-lab-notes"
}
```

AWS creates a bucket. Now run `terraform apply` again. Terraform has to answer one question before it can do anything useful: **is the thing I am looking at the thing I made?**

Nothing in the configuration answers it. `aws_s3_bucket.notes` is a name that exists only in your `.tf` files. The bucket's real identity lives in AWS. The two are connected by nothing at all — unless something remembers the connection.

That something is **state**.

It is worth sitting with how load-bearing this is. Without a remembered link, Terraform's second run cannot tell "the bucket I created and nobody touched" from "a bucket somebody else happens to have named the same thing" from "no bucket at all". Every one of those needs a different action, and the configuration alone cannot distinguish them.

### The alternative was tried, and it shipped

The obvious escape is to make the cloud remember instead: tag every created object with its Terraform address, and rediscover the mapping by searching tags on each run. Early Terraform prototypes did exactly this — no state file, AWS tags as the index.

It failed for blunt reasons:

- **Not every resource supports tags.** Whole categories of cloud object have nowhere to put one.
- **Not every provider supports tags at all**, and the ones that do expose different search APIs, so a generic solution collapses into per-vendor special-casing.
- **People edit tags out of band.** An index anyone can rewrite is not an index.

!!! note "The honest version of the argument"
    HashiCorp's own framing, on the [Purpose of Terraform State](https://developer.hashicorp.com/terraform/language/state/purpose) page, concedes more than a defence usually does: "in the scenarios where Terraform may be able to get away without state, doing so would require shifting massive amounts of complexity from one place (state) to another place (the replacement concept)."

    So the claim is not that stateless Terraform is impossible. It is that every replacement is worse — and the tag prototype is the evidence, not a thought experiment.

There is a second cost to going stateless that is easy to miss: it would land on **provider authors**, not just on Terraform's core. Every provider would need lookup paths for every vendor capability. Terraform's value comes from a huge ecosystem of community providers, so anything that raises the bar for writing a good one weakens the whole tool.

---

## 2. What state actually stores: bindings

Most confusion about state dissolves once you have the precise statement: state stores **bindings between objects in a remote system and resource instances declared in your configuration**.

When Terraform creates a remote object, it records that object's identity against one resource instance. On later runs it uses the binding to decide whether to update, destroy, or leave the object alone.

Everything else in the file — cached attributes, dependency lists, output values — is supporting material. The binding is the point.

### The one-to-one mapping rule

Terraform expects **exactly one remote object per resource instance, and exactly one resource instance per remote object**.

Normally Terraform guarantees this for free, because it is the only party creating and destroying: it makes the object, it writes the binding; it destroys the object, it removes the binding. The invariant holds because one actor controls both sides.

Two operations hand that guarantee back to you:

| Operation | What it does | What you now owe |
|---|---|---|
| `terraform import` / `import` block | Binds an *existing* object to a resource instance | Make sure that object is not already bound elsewhere |
| `terraform state rm` / `removed` block | Makes Terraform forget an object it still manages | Delete the real object, or re-import it somewhere |

Skip the obligation and you get one of two failure shapes. **An orphan** — a real resource nobody manages, still costing money, invisible to every plan. Or **a double binding** — two resource instances pointed at one object, where each run fights the other and the config-to-object mapping is genuinely ambiguous.

HashiCorp's [Purpose of Terraform State](https://developer.hashicorp.com/terraform/language/state/purpose) page states the second case, under *Mapping to the Real World*:

> "Terraform expects that each remote object is bound to only one resource instance in the configuration. If a remote object is bound to multiple resource instances, the mapping from configuration to the remote object in the state becomes ambiguous, and Terraform may behave unexpectedly."

"May behave unexpectedly" undersells it, and the failure is easy to reproduce. Bind one emulator bucket to a second resource instance with an `import` block, give that second instance a tag the first one does not have, and the two never converge:

```
# apply 1
aws_s3_bucket.shadow: Modifications complete   # tag owner=shadow added

# plan
# aws_s3_bucket.notes will be updated in-place
  ~ tags = { - "owner" = "shadow" -> null }    # the other instance takes it away

# apply 2, then plan again
# aws_s3_bucket.shadow will be updated in-place
  + "owner" = "shadow"                         # and it comes straight back
```

Every apply is a fight, with each instance reverting the other. Destroying either one is worse: `terraform destroy -target=aws_s3_bucket.shadow` deletes the bucket, and the next plan for the *other* instance reports `# aws_s3_bucket.notes will be created`, because its binding now points at nothing.

!!! danger "The rule is an invariant, not a warning"
    **One remote object, one resource instance — in both directions, at all times.** Not a guideline that degrades gracefully when broken. Terraform's whole model of "what exists and what do I own" is built on it holding.

    Everything in Chapter 16 (state operations) exists to move bindings around *without* breaking that rule. When you learn `moved`, `import`, and `removed` there, the reason they are preferred over CLI surgery is that they are declarative — the plan shows you the binding change before it happens, and an empty plan afterwards is the proof the invariant survived.

---

## 3. The other three jobs

Bindings alone would justify the file. State does three more things, and each one answers a question you will eventually ask.

### Retained dependencies — the reason destroy works at all

Terraform derives dependency order from your configuration: `aws_instance.app` references `aws_subnet.main.id`, so the subnet is created first and destroyed last.

Now delete both blocks from your `.tf` files and run `apply`. Terraform must destroy two objects — and **the edges that told it the order have been deleted along with the code.**

Those edges come from two places, and both live in your expressions. **Implicit** ones come from a reference to another resource's attribute, which is the `aws_subnet.main.id` above. **Explicit** ones come from a `depends_on` entry. A create walks the edges in order and a destroy walks them reversed, so deleting the blocks deleted the only thing that knew which way round to go.

State solves this by keeping a copy of each resource instance's most recent dependency set, as a `dependencies` array of plain addresses next to its attributes:

```json
"dependencies": [
  "tls_private_key.ca_key",
  "tls_self_signed_cert.ca_cert"
]
```

Destroy order for resources that are no longer in configuration comes from that array, not from config. It is written on every apply while the code still exists, which is what makes it available after the code is gone.

!!! note "The alternative Terraform explicitly rejected"
    Terraform "could know that servers must be deleted before the subnets they are a part of. The complexity for this approach quickly explodes, however: in addition to Terraform having to understand the ordering semantics of every resource for every provider, Terraform must also understand the ordering across providers."

    That is the complexity-shifting argument again, made concrete. Terraform's graph is derived from *your configuration*, never from built-in knowledge of resource types — see Chapter 3.

Other metadata rides along for the same reason. The most useful is a pointer to the **provider configuration** last used with each resource, which is what lets Terraform notice when a resource moves between aliased providers.

### The attribute cache — the optional part

State also caches every attribute of every resource. The [Purpose of Terraform State](https://developer.hashicorp.com/terraform/language/state/purpose) page is unusually blunt about this one: "This is the most optional feature of Terraform state and is done only as a performance improvement."

Default behaviour ignores the cache. Every plan and apply refreshes all resources against the provider. That is correct, and for small configurations it is free.

At scale it stops being free:

- Many providers have no API to query many resources at once, so it is one round trip per resource.
- Round trips are hundreds of milliseconds each.
- Providers rate-limit, capping how much you can ask for per window.

So large users reach for `-refresh=false`.

!!! warning "`-refresh=false` promotes the cache to the source of truth"
    Normally state is a record that gets *corrected* against reality at the start of every run. With `-refresh=false` the cached attributes are the only input, and any out-of-band change is invisible to the plan.

    That is not a small tuning knob — it inverts the model. It is the accidental-drift category from §6, made undetectable **by choice**. Use it when you know why you are using it, and never as a default in CI.

### State-only resources

Because state exists, Terraform can offer resources with no backing infrastructure at all. `random_password`, `time_static`, `tls_private_key`, `terraform_data` — these create nothing in any cloud. Their entire existence *is* the state entry.

You will use one in this chapter's lab. It is the cleanest possible demonstration that state is a database, not a cache of an API.

---

## 4. Opening the file

A word this chapter is about to use a lot. A **backend** is the thing that decides *where state lives and who is allowed to write it*: it stores the state and, optionally, provides an API for locking it. Write no `backend` block and you get the default one, `local`, which keeps state as a file in your working directory, locks it through the operating system, and runs operations on your own machine. Point Terraform at `s3`, `gcs`, `azurerm`, or HCP Terraform instead and the same state goes to shared storage that several people can use safely. Chapter 15 is about making that switch; everything here is the default local case, and none of it changes when you move.

State is JSON, and with that default backend it sits in your working directory as `terraform.tfstate`. Read it. The instruction "never edit it" is not "never look at it" — a state file you have never opened is a part of Terraform you do not understand.

Here is the real top level from this chapter's lab (one S3 bucket, one `random_password`, one output):

```json
{
  "version": 4,
  "terraform_version": "1.15.8",
  "serial": 3,
  "lineage": "be6d1c55-9f31-c363-4c6b-f14974d7f93b",
  "outputs": { ... },
  "resources": [ ... ],
  "check_results": null
}
```

One term first, because the field descriptions lean on it. A **snapshot** is one complete state document, written out whole. Terraform never patches the file in place or appends a delta to it: every write serialises the entire state and replaces what was there, which is why the previous snapshot has to be preserved separately as `terraform.tfstate.backup`.

| Field | Meaning |
|---|---|
| `version` | Format version of the state data structure itself — currently **4**. Lets a newer Terraform recognise and upgrade an older file. |
| `terraform_version` | The CLI version that **last wrote** the file. Informational in practice. |
| `serial` | Incremented on every persisted snapshot **whose content differs** from the previous one. Counts *writes*, not applies. |
| `lineage` | A random 128-bit ID minted the first time a snapshot is written **at a location**, then copied forward forever. Answers "same project?". |
| `resources` | Every managed resource **and data source**, with its bindings and cached attributes. |
| `outputs` | The **root module's** outputs only, each with its recorded type. |
| `check_results` | Results of `check` blocks from the last run; `null` when there are none. |

### `serial` counts writes, not applies

The lab's first apply created two managed resources and left `serial` at **3**, not 1. A single apply writes the state file several times: the local backend writes a fresh snapshot each time the graph walk produces a new state, and `serial` moves whenever that document differs from the one on disk. Under `TF_LOG=trace` you can watch it happen, as repeated `statemgr.Filesystem: writing snapshot at terraform.tfstate` lines within one run.

What you cannot do is predict the number. Measured by repeating each configuration from scratch and recording every run — you can reproduce this yourself with the second lab below:

| Configuration | Terraform 1.15.8 | OpenTofu 1.12.4 |
|---|---|---|
| 4 × `random_password` (`serial/provider-backed`) | 4, 5, 5, 5, 5, 5 | 1, 1, 1, 1, 1, 1 |
| 4 × `terraform_data` (`serial/in-core`) | 5, 4, 4, 1, 5, 5 | 1, 1, 1, 1, 1, 1 |
| 2 × `random_password` | 3, 3, 3 | 1, 1, 1 |
| 1 × `random_password` + 1 × `local_file` data source | 1, 1, 1 | 1, 1, 1 |
| 1 × `random_password` + 1 × `aws_s3_bucket` (first lab) | 3 | 1 |

Read the second row again: the same four resources, the same machine, and a first apply that wrote **five** snapshots on one run and **one** on another. Nothing about the configuration changed between those runs. When resources finish close enough together their state updates coalesce into a single write, and how they fall out is a matter of scheduling.

So `serial` is not "resources plus one", and it is not a count of applies either. The small rows look stable only because there is little there to reorder.

The practical rules that survive:

- `serial` is a reliable **ordering** key — "which of these backups is newest?" — but nothing more. Gaps and jumps mean nothing.
- Never assert an expected `serial` in a test or a script. It is timing-dependent.
- Data sources are recorded in `resources` with `"mode": "data"` and produced no bump of their own in any run above.
- Interrupting an apply writes *more* snapshots, not fewer: Terraform persists on the way out so a subsequent kill costs less recovery.

!!! danger "Those extra writes are a crash safety net, and OpenTofu's is time-gated"
    Terraform's habit of writing state throughout the run is what protects you when a run dies with no chance to clean up. OpenTofu writes at most once per interval, so what survives a `kill -9` depends on when you kill it. Three measured runs of the same shape — one resource that completes immediately, then a long `time_sleep`:

    | Killed | Terraform 1.15.8 | OpenTofu 1.12.4 |
    |---|---|---|
    | 15 s into a 40 s apply | 852 bytes, the finished resource recorded | **0 bytes** |
    | 30 s into a 40 s apply | 852 bytes | **0 bytes** |
    | 35 s, with a second resource completing at 25 s | — | 725 bytes, partial |

    The middle row is the one to understand. Thirty seconds is past OpenTofu's twenty-second interval, and it still wrote nothing — because the interval is only **checked when a state update arrives**, and during a long-running resource none does. The third row supplies the missing trigger: with a resource completing at 25 s, that completion finds the interval elapsed and persists.

    So the exposure is not "the first 20 seconds". It runs until the first resource completes after the interval has elapsed, which one slow resource can stretch to the length of the whole apply.

    What that costs you: a real object created inside the window is an orphan the moment it exists. It is running, it is billing, and the next plan will create another one, because nothing recorded the first. That is §6's "created but not recorded" failure, reached without anything going wrong beyond a power cut.

    An ordinary Ctrl-C is safe on both — the stop path forces a persist before exiting. The exposure is a hard kill, an OOM kill, or a lost machine.

    **You cannot tune this into Terraform's behaviour.** Both CLIs read `TF_STATE_PERSIST_INTERVAL`, in seconds, and both refuse to go below the 20-second default — the knob only makes the window *longer*. Terraform ignores a smaller value silently. OpenTofu 1.12.4 rejects it by panicking:

    ```
    $ TF_STATE_PERSIST_INTERVAL=5 tofu apply
    Can't use value lower than 20 for env variable TF_STATE_PERSIST_INTERVAL, got 5
    github.com/opentofu/opentofu/internal/logging.panicHandler(...)
    ```

    On Terraform's local backend the setting is moot in any case: `WriteState` already writes every update to disk, and the interval governs only the remote backends, where a persist is a network round trip. On OpenTofu it is the whole mechanism, and 20 seconds is the floor.

    So the mitigation is procedural, not configuration. Treat a hard-killed OpenTofu apply as having possibly created objects that state never recorded: plan first, look for resources it wants to create that you believe already exist, and import them before re-running.

    One more observation from the third run, repeated twice: the snapshot OpenTofu did write held only `time_sleep.wait_a`, not the `terraform_data` resource that had completed 25 seconds earlier and was in the in-memory state at the time. A mid-run snapshot is not a promise that everything finished so far is in it.

!!! info "OpenTofu — one write, not several"
    Every configuration in the table ends at `serial` **1** on OpenTofu **1.12.4** — all five of them, every run measured, including the emulator-backed first lab where Terraform lands on 3. Terraform ranged from 1 to 5 over the same configurations. OpenTofu is not writing less state, it is writing it fewer times; the file is otherwise the same format down to the `terraform_version` key.

    What is *not* different is the rule that decides a bump. A second, no-op apply of the first lab moved OpenTofu from 1 to 2, exactly as Terraform went 3 to 4, for the same reason: the marshalled document differed. So the counter still tracks writes-whose-content-differed on both. Only the number of writes per run changes — which is the step change any tooling that reads `serial` will see across a migration.

    **Why one and not several.** The two local state managers split the same two operations differently. In Terraform, `WriteState` writes the file immediately and `PersistState` is a no-op, so every mid-apply state update reaches disk. In OpenTofu, `WriteState` only updates an in-memory copy and the disk write lives in `PersistState`, which the apply hook calls only when a state update arrives *and* its interval — 20 seconds by default — has elapsed since the last one. A fast apply therefore declines every intermediate persist and writes once at the end. `TF_LOG=trace` shows it plainly: four `declined to persist a state snapshot` lines, then a single `writing snapshot`. Both behaviours are in the released sources, `v1.15.8` and `v1.12.4`.

!!! warning "“No changes” in the plan does not mean the state file is unchanged"
    The plan summary counts **managed resources**. The `serial` guard compares the **whole marshalled state document**.

    Verified in this chapter's lab: a second, entirely no-op apply — plan reported no changes — still moved `serial` from 3 to 4. Diffing the new snapshot against `terraform.tfstate.backup` showed the whole difference:

    ```
    /serial                                              3 -> 4
    /resources[0]/…/attributes/replication_configuration[0]/rules   null -> []
    /resources[0]/…/attributes/tags                                 null -> {}
    ```

    Two attributes came back from the refresh as empty containers instead of `null`. The document genuinely differed, so the counter moved. (Here the round-trip noise comes from the local emulator; on real AWS the same *class* of thing happens whenever a provider does not round-trip a value identically.) The lesson generalises: any attribute that changes on refresh — most classically a data source with a volatile attribute — drives `serial` on its own.

### `lineage` is narrower than it sounds

`lineage` is usually described as the guard that stops one project's state overwriting another's. That is true, but the comparison happens in far fewer places than the description implies.

A routine `plan`/`apply` **never compares lineage**. Terraform reads state, carries the lineage forward verbatim, and writes it back. The check only runs where two *independently obtained* snapshots meet: `terraform state push`, a backend migration, applying a saved plan, or a remote backend detecting a concurrent write. And `-force` disables it on the push path entirely.

So nothing stops two configurations from pointing at the same state file during normal operation. What lineage catches is importing a *foreign snapshot over an existing one*.

!!! info "Not actually a UUID"
    Despite the shape, lineages are not RFC 4122 v4 UUIDs — they are 128 random bits from a CSPRNG wearing UUID punctuation, with no version or variant bits set. Uniqueness rests entirely on the randomness. You can check any state file: a v4 UUID has `4` as the first nibble of the third group; the lab's `be6d1c55-9f31-c363-4c6b-f14974d7f93b` has `c`.

### `resources` and `outputs`

Each entry in `resources` carries the identity triple **`module` + `type` + `name`** — together unique, and together the resource address you type on the command line — plus the `provider` it was created with, and an `attributes` object holding every computed attribute and supplied argument. A provider-set `schema_version` lets the provider migrate its own attribute layout across upgrades.

`outputs` is an object, not an array, and holds **only the root module's** outputs, each with its type recorded so another configuration can consume it without access to the generating code.

!!! warning "Child-module outputs are not in state"
    Only root outputs are stored. If a nested module's output needs to be visible to `terraform output` or to another configuration, you must re-export it explicitly from the root:

    ```hcl
    output "address" {
      value = module.loadbalancer.lb_address
    }
    ```

    This is the same root-only restriction you met in Chapter 6, showing up in the file format.

---

## 5. Reading state the supported way

You now know the file. Mostly, you should not parse it.

Terraform ships four ways to read state, and they split cleanly into two groups.

**For humans:**

```shell
terraform state list                        # every address Terraform tracks
terraform state show aws_s3_bucket.notes    # every attribute of one instance
```

`state list` sorts by **module depth then alphabetically**, so your own root resources are always at the top and deeply nested module resources at the tail. It also takes filters, and one flag worth knowing:

```shell
terraform state list -id=state-lab-notes
# aws_s3_bucket.notes
```

That is a **reverse lookup**: from a provider-assigned ID back to the address that owns it. It answers "the console shows me this object — whose is it?" without grepping the file.

!!! warning "A miss is silent with `-id`, loud with an address"
    `terraform state list -id=does-not-exist` prints nothing and exits **0**. `terraform state list some.address` that matches nothing is an `Error: Unknown resource` with exit **1**. So `-id` cannot be used as an existence check by exit status — test the output, not `$?`.

**For machines:**

```shell
terraform show -json           # the whole state snapshot
terraform output -json         # root outputs only
```

The distinction is not stylistic. `terraform state show` output is **explicitly not a machine interface** — its [command documentation](https://developer.hashicorp.com/terraform/cli/commands/state/show) says the output is "intended for human consumption, not programmatic consumption" and redirects you to `terraform show -json`. The rendered form is unversioned and free to change; the JSON form carries a `format_version` and a written spec.

That is also the answer to "how do I read state from another tool?" — not by parsing `terraform.tfstate`, whose format is explicitly allowed to change between versions, but by running one of the `-json` commands right after a successful apply and storing the result as an artifact of the run.

!!! note "`show -json` returns different documents for state and for plans"
    Run it on state and you get exactly three keys. Save a plan to a file and run it on that, and you get twelve. Both from the same command:

    ```shell
    terraform show -json | jq keys              # the current state

    terraform plan -out tfplan                  # save a plan first
    terraform show -json tfplan | jq keys       # then read it back
    terraform show tfplan                       # same file, human form
    ```

    ```
    ["format_version","terraform_version","values"]

    ["applyable","complete","configuration","errored","format_version",
     "output_changes","planned_values","prior_state","resource_changes",
     "resource_drift","terraform_version","timestamp"]
    ```

    The plan document is the plan, the configuration, and the state, three documents in one, plus the run's own verdict in `applyable`, `complete`, `errored`, and `timestamp`.

    Its key set is not fixed, because keys appear only when there is something for them to describe. The twelve above came from planning against existing state. The very first plan in an empty directory returns **eleven** instead: no `prior_state` and no `resource_drift`, since there is no prior state to report or drift against, and a `relevant_attributes` key that the later plan does not carry. `output_changes` is likewise absent from a plan for a configuration with no outputs. Read the keys you get, rather than assuming the set.

!!! tip "Quoting an instance address on Windows"
    A `for_each` address contains double quotes, so it needs care in a shell. On **PowerShell 7**, single quotes are already literal — write the address exactly as `state list` prints it:

    ```powershell
    terraform state show 'terraform_data.worker["example"]'
    ```

    The [`terraform state show` documentation](https://developer.hashicorp.com/terraform/cli/commands/state/show) still shows a backslash-escaped form (`'…worker[\"example\"]'`) for PowerShell. That is Windows PowerShell 5.1-era advice and **fails on PowerShell 7** with `Error parsing instance address` — the backslashes are passed through literally. The same page's `cmd.exe` row is correct.

---

## 6. Refresh, drift, and how state gets corrected

State would rot immediately if nothing corrected it. The correction is **refresh**: before computing a plan, Terraform asks each provider for the current attributes of every resource in state and updates its in-memory copy.

That is how **drift** — infrastructure changed outside Terraform — gets noticed. A normal plan then proposes whatever changes pull reality back toward your configuration.

To see drift *without* being offered changes, use refresh-only mode:

```shell
terraform plan -refresh-only     # what has drifted?
terraform apply -refresh-only    # accept the drift into state, change no infrastructure
```

!!! info "`terraform refresh` is deprecated — and the reason is instructive"
    The standalone command still exists but the CLI reference deprecates it outright. It is "effectively an alias for `terraform apply -refresh-only -auto-approve`", and the auto-approve **cannot be turned off**.

    The documented hazard: with misconfigured provider credentials, a provider that cannot see its objects reports them **gone**, and refresh removes them from state "without any confirmation prompt". Nothing is destroyed in the cloud — but Terraform now believes it owns nothing, and the next plan proposes recreating all of it.

    The standing advice goes further than "use the flag instead": prefer *neither*, and rely on the refresh a normal plan already performs.

### Drift is a symptom — ask what changed and why

Infrastructure does not change itself. Sorting causes on two axes (human vs machine, accidental vs intentional) gives four categories, each with a different response:

| Category | Example | Response |
|---|---|---|
| **Accidental manual change** | Wrong account, wrong console button | Usually the easiest — a normal plan works out how to restore intent. Treat as a systems problem: restrict production access, route changes through CI. |
| **Intentional manual change** | On-call engineer fixing an outage by hand | Harder: the change was *wanted*, and the next run reverts it. Until it is in code, **it is not safe to run Terraform**. |
| **Conflicting automated change** | Autoscaling, tags added by an orchestrator, an RDS minor-version bump | Not errors. Decide deliberately: adopt it (apply), accept it (`-refresh-only`), or stop fighting it (`lifecycle { ignore_changes = [...] }`). |
| **Terraform error** | Crash before state was saved, corrupted write, backend auth expiring mid-run | The nastiest. The dangerous shape is a resource **created but not recorded** — the next run creates a second one. Read the logs, then import it or delete it. Corrupted state means restoring from backup. |

The fourth category is the one that argues hardest for backups you control, independent of whatever durability your backend advertises.

---

## 7. State is a security problem

Open the lab's state file and search it for the generated password. It is there, in the clear:

```
password attribute in state: 4Ni-aVJ85B1Sk16i0be$
same value in outputs      : 4Ni-aVJ85B1Sk16i0be$
```

The output that produced the second line is declared `sensitive = true`. That changed nothing about storage.

!!! danger "`sensitive` hides values from logs. It does not protect them."
    Values marked `sensitive` are stored in **both state and plan files** in plaintext. The marking suppresses display in the operation log and the HCP Terraform UI. That is all it does.

    And the redaction it does provide is narrower than most people assume. Verified on 1.15.8:

    | Command | Output |
    |---|---|
    | `terraform output` | `db_password = <sensitive>` |
    | `terraform output db_password` | `"4Ni-aVJ85B1Sk16i0be$"` |
    | `terraform output -raw db_password` | `4Ni-aVJ85B1Sk16i0be$` |

    Querying **by name** needs no flag at all. `sensitive` protects the aggregate listing; a named read is a normal, flagless command.

    If you need a value never to be stored, that is what **ephemeral** values and **write-only** arguments are for (Chapter 23). If it must be stored, protect the file.

Which makes the choice of **backend** — the storage from §4 — a security decision, not a plumbing one. Chapter 15 covers configuring and migrating them; what belongs here is the criteria, because they follow from what you have just seen inside the file. Three properties matter when deciding where state lives.

- **Resiliency.** Losing state is among the worst positions to be in: Terraform can no longer plan, and recovery means manually deleting or re-importing every real resource. Judge a backend on durability — S3 advertises eleven nines of per-object durability — but remember that no durability figure stops an engineer deleting the bucket. **A resilient backend is not a backup.**
- **Security.** State holds every attribute of every resource. A leaked state file exposes your architecture *and* its secrets. The concrete failure modes are mundane: state access without MFA, or a storage bucket left publicly readable.
- **Availability.** If the state store is unreachable, you cannot deploy at all. On a normal day that is friction; during an incident it is an emergency. Treat state storage as critical infrastructure and expect an SLA from whoever provides it.

!!! danger "Never put state in version control"
    Git supports neither state locking nor per-file access control, which is exactly the pair state needs. No locking means concurrent writes lose data. No access control means every secret in the file is readable by everyone with repository access — including in history, forever, after the file is deleted.

    Add `terraform.tfstate` and `terraform.tfstate.backup` to `.gitignore` on day one.

!!! info "OpenTofu — client-side state encryption"
    OpenTofu ships opt-in **state encryption**, configured in the `terraform` block or through `TF_ENCRYPTION`. It covers "state and plan files at rest, both for local storage and when using a backend" — so the plaintext password you found above would be encrypted in the file itself, not merely in whatever the backend does underneath. Terraform's open-source CLI has no equivalent as of 1.15; it relies on the backend's at-rest encryption (S3's `encrypt`, GCS's customer-managed keys) or on HCP Terraform. If encrypted-at-source state is a hard requirement, that is a real reason to evaluate OpenTofu.

---

## 8. Why you must never hand-edit it

You now have the three reasons, and they are structural rather than superstitious.

1. **You will break bookkeeping you cannot see.** `serial` orders snapshots, `lineage` identifies the project, and each resource carries a provider-set `schema_version`. Hand-editing bypasses every rule that maintains them — and a wrong `serial` silently defeats "which backup is newest?" at the moment you most need it.
2. **You will break the one-to-one rule.** Deleting a resource block from JSON is not "removing a resource"; it is orphaning a real object that still exists and still costs money, with nothing left to point at it.
3. **The format is explicitly allowed to change.** Terraform stays backward compatible with older snapshots, but anything you write *against* the format needs maintenance forever. The CLI exists precisely to insulate you from that.

The corollary is what makes the rule livable: **there is a supported operation for everything you might be tempted to hand-edit.**

| Temptation | Supported route |
|---|---|
| "This resource was renamed" | `moved` block |
| "This resource already exists in the cloud" | `import` block |
| "Stop managing this, but leave it running" | `removed` block with `lifecycle { destroy = false }` |
| "State disagrees with reality" | `terraform apply -refresh-only` |
| "I need to see what's in there" | `terraform state list` / `state show` / `show -json` |

Chapter 16 covers the first three properly. The rule for now: if you are opening state in an editor, stop and find the block or command that does it for you.

---

## 🧪 Lab 1: dissect a state file, and follow a binding both ways

The milestone made concrete. You will apply a two-resource configuration, open the state file, map an address to a real object and back, prove a `sensitive` value is stored in plaintext, and watch `serial` move on a no-op apply. Everything runs against the free local **AWS emulator** from [Chapter 1's lab setup](ch01-iac-fundamentals.md#lab-setup-a-free-local-aws-docker). S3 is on the reliable free surface.

**Start the emulator** (from the repo root; skip if already running):

```shell
docker compose -f labs/docker-compose.yml up -d      # start the emulator on :4566, detached
curl -s http://localhost:4566/_floci/health     # wait until the services read "running"
```

**The configuration** — one real cloud object, one state-only resource, one sensitive output. It is committed at `labs/chapter9/lab1`:

```hcl
# main.tf
terraform {
  required_version = ">= 1.15"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "random_password" "db" {
  length = 20
}

resource "aws_s3_bucket" "notes" {
  bucket = "state-lab-notes"
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
```

**Apply it:**

```shell
tflocal init
tflocal apply
```

```
random_password.db: Creation complete after 0s [id=none]
aws_s3_bucket.notes: Creation complete after 1s [id=state-lab-notes]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

db_password = <sensitive>
```

### Step 1 — read the top level

```shell
terraform state list
```

```
aws_s3_bucket.notes
random_password.db
```

Now open `terraform.tfstate` and find the seven top-level fields. `version` is **4**, `terraform_version` is the CLI that wrote it, and `check_results` is `null` because the configuration has no `check` blocks. This run landed at `serial` **3** — treat that as an observation, not a prediction, for the reason in §4.

### Step 2 — follow the binding outward

```shell
terraform state show aws_s3_bucket.notes
```

```
# aws_s3_bucket.notes:
resource "aws_s3_bucket" "notes" {
    arn                         = "arn:aws:s3:::state-lab-notes"
    bucket                      = "state-lab-notes"
    bucket_regional_domain_name = "state-lab-notes.s3.us-east-1.amazonaws.com"
    ...
```

Then confirm the object on the other side:

```shell
awslocal s3api list-buckets --query 'Buckets[].Name'
```

```
[
    "state-lab-notes"
]
```

That is the binding, seen from both ends: the address `aws_s3_bucket.notes` in your code, the bucket `state-lab-notes` in the cloud, and a line in state joining them.

### Step 3 — follow it back inward

Pretend you found the bucket in a console and have no idea who owns it:

```shell
terraform state list -id=state-lab-notes
```

```
aws_s3_bucket.notes
```

### Step 4 — prove the secret is plaintext

```shell
terraform output db_password
```

```
"4Ni-aVJ85B1Sk16i0be$"
```

No flag, no `-raw`, and the output is declared `sensitive`. Now find the same string twice inside `terraform.tfstate` — once in `random_password.db`'s attributes, once in the root `outputs` object next to `"sensitive": true`.

That is the whole security argument in one file: the marking is about display, the storage is unchanged.

### Step 5 — watch `serial` move on a no-op

```shell
tflocal apply         # plan reports no changes
```

Compare the two files Terraform now keeps:

```shell
python -c "import json; [print(f, json.load(open(f))['serial']) for f in ('terraform.tfstate','terraform.tfstate.backup')]"
```

```
terraform.tfstate 4
terraform.tfstate.backup 3
```

`terraform.tfstate.backup` is the previous snapshot, written automatically by the local backend. The `serial` moved even though nothing in your infrastructure changed — because two bucket attributes came back from the refresh as empty containers rather than `null`, and the guard compares the whole document.

**Clean up:**

```shell
tflocal destroy
```

!!! warning "Emulation is not AWS"
    A green apply here proves your HCL and your workflow, not AWS fidelity. The emulator's attribute round-tripping in particular is its own behaviour — the *principle* it demonstrates (state content, not the plan summary, drives `serial`) is real, but the specific attributes involved are an artifact of the emulator. Validate anything load-bearing against real free-tier AWS.

---

## 🧪 Lab 2: measure `serial` yourself

§4 claims `serial` is unpredictable. Claims like that are worth distrusting, so here is the measurement, ready to run.

Nothing in this lab touches a cloud. `random_password` and `terraform_data` create no remote objects, so there are **no credentials to set up and no emulator to start** — the whole thing works on a laptop on a plane.

Two configurations, four resources each. `labs/chapter9/serial/provider-backed` is four `random_password` resources, one plugin round trip apiece:

```hcl
resource "random_password" "a" { length = 8 }
resource "random_password" "b" { length = 8 }
resource "random_password" "c" { length = 8 }
resource "random_password" "d" { length = 8 }
```

`labs/chapter9/serial/in-core` is four `terraform_data` resources, served by the built-in provider with no plugin involved:

```hcl
resource "terraform_data" "a" { input = "1" }
resource "terraform_data" "b" { input = "2" }
resource "terraform_data" "c" { input = "3" }
resource "terraform_data" "d" { input = "4" }
```

The runner destroys, deletes the state, and applies again, so **every apply is a first apply**. It then reads the top-level `serial` out of `terraform.tfstate` and prints one line per run.

```powershell
cd labs/chapter9/serial
./measure-serial.ps1 -Dir provider-backed -Runs 6
```

```shell
cd labs/chapter9/serial
./measure-serial.sh provider-backed 6
```

A real run of each, on Terraform 1.15.8:

```
run 1: serial = 4          run 1: serial = 5
run 2: serial = 5          run 2: serial = 4
run 3: serial = 5          run 3: serial = 4
run 4: serial = 5          run 4: serial = 1
run 5: serial = 5          run 5: serial = 5
run 6: serial = 5          run 6: serial = 5

provider-backed            in-core
```

Four resources; a first apply that wrote one snapshot in one run and five in another. That is the whole point, and it is why nothing should ever assert an expected `serial`.

Now the same thing on OpenTofu, if you have it:

```powershell
./measure-serial.ps1 -Dir in-core -Runs 6 -Binary tofu
```

```shell
./measure-serial.sh in-core 6 tofu
```

```
run 1: serial = 1
run 2: serial = 1
...
tofu in-core, 6 runs: 1 1 1 1 1 1
```

**What to take away:** the counter is a write count, the write count is a scheduling artifact, and the two CLIs schedule differently. Ordering is the only question `serial` answers reliably.

!!! tip "If you get a different spread"
    You should. The numbers depend on how fast four resources happen to complete on your machine, so a busy laptop and an idle one will not agree, and neither will two runs on the same laptop. A run of six that lands on the same value every time is not a refutation — raise `-Runs` and watch it eventually disagree with itself.

---

## Common pitfalls

- **Committing `terraform.tfstate`.** No locking, no access control, secrets in history forever. `.gitignore` it before your first apply, not after.
- **Believing `sensitive = true` protects a value.** It suppresses display. The value is in state, in plan files, and one flagless `terraform output <name>` away.
- **Parsing `terraform.tfstate` in a script.** The format may change between versions. Use `terraform show -json` or `terraform output -json`.
- **Treating `terraform state show` output as machine-readable.** It is explicitly documented as human-only, for the same reason.
- **Reading `serial` as a count of applies, or predicting it.** It counts *writes whose content differed*, and identical runs of the same configuration can land on different numbers. Use it for ordering backups, nothing else.
- **Assuming lineage protects you during normal runs.** It is not consulted on a routine plan or apply, and `-force` disables it on `state push`.
- **Running `-refresh=false` habitually.** It makes the cache the source of truth and hides all out-of-band drift.
- **Reaching for `terraform refresh`.** Deprecated, always auto-approved, and capable of emptying your state if provider credentials are misconfigured. Use `terraform apply -refresh-only`.
- **Editing state by hand because "it's just JSON".** There is a supported operation for every case — see the table in §8.
- **Expecting a child module's outputs in state.** Only root outputs are stored; re-export explicitly.

---

## Exercises

1. **Break and restore a binding.** In the lab directory, run `terraform state rm random_password.db`, then `terraform plan`. Explain in one sentence what Terraform now believes, and what it will do. Restore the situation without destroying anything.
2. **Fail to predict the serial.** Before running Lab 2, write down the `serial` you expect from four resources. Run `measure-serial` with `-Runs 10` on both directories, then explain the spread you got — and what it would have done to a CI check that asserted your predicted number.
3. **Find the orphan.** Create a bucket with `awslocal s3 mb s3://orphan-bucket` (outside Terraform), then use `terraform state list -id=orphan-bucket` and explain the result. What would you have to do to bring it under management?
4. **Prove the format claim.** Run `terraform show -json > snapshot.json` and compare its top-level keys against the raw `terraform.tfstate`. Which of the two would you point a monitoring script at, and why?
5. **Three reasons, from memory.** Without looking, write down three distinct reasons never to hand-edit state. Then check §8 — if you wrote "it's dangerous" three ways, try again.

---

## Summary

- State exists because **your configuration and your cloud share no identifier**. The tag-based alternative was built and abandoned: not all resources support tags, not all providers do, and humans edit them.
- State's primary content is **bindings** between resource instances and remote objects. Terraform maintains a strict **one-to-one mapping**, and only `import` and `state rm` hand that obligation to you.
- Three more jobs: **retained dependencies** so destroy order survives the deletion of the code, an **attribute cache** that is explicitly optional, and **state-only resources** that exist nowhere else.
- The file is JSON with seven top-level fields. `serial` counts **writes whose content differed**, and how many a run produces is timing-dependent, so it is an ordering key and nothing else. `lineage` identifies the project but is checked in far fewer places than its description suggests.
- Read state with `state list` / `state show` for humans, `show -json` / `output -json` for machines. Never parse the file.
- **Refresh** is what corrects state against reality and detects drift. `-refresh-only` accepts drift without changing infrastructure; `terraform refresh` is deprecated and unprompted.
- State holds **secrets in plaintext**. `sensitive` hides values from logs, not from the file, and a named `terraform output` reads them back with no flag at all.
- Never hand-edit: you break invisible bookkeeping, you break the one-to-one rule, and you write against a format that is free to change. There is a supported operation for every case.

---

## What's next

You now understand state as a *file*. Chapter 15 turns it into shared infrastructure: **remote backends**, state **locking**, and the collaboration model that makes Terraform usable by more than one person. Chapter 16 covers **state operations** — `import`, `moved`, `removed`, and the recovery procedures for when a run leaves state and reality out of step.

Before either, Chapters 10–14 cover the meta-arguments, dynamic blocks, and modules that make configurations big enough for state management to matter.

---

## References

**Reading notes:** [State (overview)](../sources/terraform-docs/tf-state.md) · [Purpose of Terraform State](../sources/terraform-docs/tf-state-purpose.md) · [TID Ch 6 — State management](../books/tid/chapters/06-state-management.md) · [Manage sensitive data](../sources/terraform-docs/tf-manage-sensitive-data.md) · [`terraform state list`](../sources/terraform-docs/tf-cmd-state-list.md) · [`terraform state show`](../sources/terraform-docs/tf-cmd-state-show.md) · [`terraform show`](../sources/terraform-docs/tf-cmd-show.md) · [`terraform output`](../sources/terraform-docs/tf-cmd-output.md) · [`terraform refresh`](../sources/terraform-docs/tf-cmd-refresh.md) · [Inspect Infrastructure overview](../sources/terraform-docs/tf-cli-inspect.md) · [`local` backend](../sources/terraform-docs/tf-backend-local.md)

**Docs:** [State](https://developer.hashicorp.com/terraform/language/state) · [Purpose of Terraform State](https://developer.hashicorp.com/terraform/language/state/purpose) · [Manage sensitive data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data) · [`terraform state list`](https://developer.hashicorp.com/terraform/cli/commands/state/list) · [`terraform state show`](https://developer.hashicorp.com/terraform/cli/commands/state/show) · [`terraform show`](https://developer.hashicorp.com/terraform/cli/commands/show) · [JSON Output Format](https://developer.hashicorp.com/terraform/internals/json-format) · [OpenTofu state encryption](https://opentofu.org/docs/language/state/encryption/)

**🧪 Lab:** [Floci Facts](../research-cache/floci-facts.md) · [MiniStack Facts](../research-cache/ministack-facts.md) · [LocalStack Facts](../research-cache/localstack-facts.md)
