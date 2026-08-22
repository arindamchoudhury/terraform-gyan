# Chapter 16 — State management operations

## Learning outcomes

By the end you can:

- Explain why a resource **address is an identity**, and read `because X is not in configuration` as the diagnostic it is.
- Rank the three ways to change state, and give the three separate arguments for putting a refactor in configuration rather than in a command.
- Write a resource address, and say why the same string means "one instance" to one command and "all instances" to another.
- Rename a resource, move it into a module, and migrate `count` to `for_each` with **`moved`** blocks, proving each with an empty plan.
- Hand a resource to another team with a **`removed`** block, and say what the lone `.` in the plan means.
- Adopt existing infrastructure with an **`import`** block, prune a generated configuration to the arguments that matter, and recognise the two plan shapes that mean the adoption is wrong.
- Split one configuration into two without destroying the stateful resources in it.
- Tell the three answers to drift apart, and say which command can empty your state with no prompt.
- Use `-replace` and `-target` for what they are, which is recovery.
- Name the state-writing operations that leave no backup, and run the pull-fix-push repair loop when one of them goes wrong.

---

## 1. The problem: an address is an identity

Chapter 9 established that state binds a resource address to a real object, one to one, and named the fields the file carries down to the `instances` array. Chapter 15 moved that file somewhere a team can share. This section looks closer at a resource entry, and at its `instances` array in particular, because everything in this chapter depends on understanding that layout properly.

Everything below can be followed along, and the configurations are in `labs/chapter16/section1/`. Chapter 1's `tflocal` wrapper points Terraform at the local emulator, so nothing here costs money or touches a real account. Start with one bucket:

```hcl
resource "aws_s3_bucket" "notes" {
  bucket = "ch16-moved-notes"
}
```

```shell
tflocal apply -auto-approve
```

Open `terraform.tfstate` and `resources` holds one entry. Trimmed to the fields that matter here:

```json
{
  "mode": "managed",
  "type": "aws_s3_bucket",
  "name": "notes",
  "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
  "instances": [
    { "attributes": { "id": "ch16-moved-notes", "arn": "arn:aws:s3:::ch16-moved-notes" } }
  ]
}
```

| Field | What it holds |
|---|---|
| `mode` | `managed` for a `resource`, `data` for a data source. Both live in the same array. |
| `type`, `name` | The two labels on the block. Together they spell the **resource address**, `aws_s3_bucket.notes`. |
| `module` | Absent at the root. A resource inside `module "wrapped"` carries `"module": "module.wrapped"`. |
| `provider` | Which provider configuration created the object. Note that it sits *beside* the address, not inside it. |
| `instances` | One element per instance. This is the field every operation in this chapter works on. |

**A `resource` block is not one object.** It is a template, and `instances` is where the objects it produced are recorded. Without `count` or `for_each` it produces exactly one, as above, and that instance carries no key.

Add a second resource that uses `count`, and apply again:

```hcl
resource "aws_s3_bucket" "archive" {
  count  = 2
  bucket = "ch16-moved-archive-${count.index}"
}
```

Its entry holds two elements, each tagged with its position:

```json
{ "instances": [
  { "index_key": 0, "attributes": { "id": "ch16-moved-archive-0" } },
  { "index_key": 1, "attributes": { "id": "ch16-moved-archive-1" } }
] }
```

Now migrate that resource from `count` to `for_each`, which is what section 4 does with it properly. Replace the block and declare where each instance went. The `moved` blocks are section 4's subject; here they are simply what makes the migration possible:

```hcl
resource "aws_s3_bucket" "archive" {
  for_each = { cold = 0, warm = 1 }
  bucket   = "ch16-moved-archive-${each.value}"
}

moved {
  from = aws_s3_bucket.archive[0]
  to   = aws_s3_bucket.archive["cold"]
}

moved {
  from = aws_s3_bucket.archive[1]
  to   = aws_s3_bucket.archive["warm"]
}
```

Apply it and read the last line:

```text
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

Three zeroes. Terraform did work, and none of it happened in S3. Look at the entry again and the keys are strings:

```json
{ "instances": [
  { "index_key": "cold", "attributes": { "id": "ch16-moved-archive-0" } },
  { "index_key": "warm", "attributes": { "id": "ch16-moved-archive-1" } }
] }
```

Compare that against the `count` version above, because the difference is the whole subject of this chapter. The `id` values are identical, so both buckets are the ones you already had. Only the keys changed, from positions to names. Two instance elements were rewritten in state while the objects they name sat untouched, and the counters are how you know: an apply that changed infrastructure could not report three zeroes.

Three shapes, and each is addressed differently: `aws_s3_bucket.notes`, `aws_s3_bucket.archive[0]`, `aws_s3_bucket.archive["cold"]`. Section 3 turns that into a grammar. It is also why the migration is a state operation rather than an edit: every `index_key` has to be rewritten, one instance at a time, and the objects have to be left alone while it happens.

`index_key` is the field this chapter changes most, but it is not the only one an instance element carries. The full set is fixed by Terraform, not by the provider, and is declared in `internal/states/statefile/version4.go`. At v1.15.8:

| Field | Present when | What it holds |
|---|---|---|
| `attributes` | any state written since 0.12 | The provider's record of the object. See below. |
| `schema_version` | always | Which version of the provider's schema `attributes` was written against. |
| `index_key` | `count` or `for_each` | The instance key: a number, or a string. |
| `sensitive_attributes` | provider marks any | Paths *within* `attributes` whose values are sensitive. |
| `status` | only when tainted | The one value Terraform writes here is `"tainted"`, which section 9 comes back to. |
| `deposed` | create-before-destroy left one behind | An eight-character deposed key naming an old object still awaiting destruction. |
| `dependencies` | the instance has any | Addresses this instance depended on, kept so `destroy` can order correctly. |
| `create_before_destroy` | that lifecycle is set | Recorded so the ordering survives into a later destroy. |
| `identity` | provider supplies one | The provider's own identity for the object, such as `{ "bucket": "…", "region": "…" }`. |
| `identity_schema_version` | always | The same versioning idea, applied to `identity`. |
| `private` | provider uses it | An opaque blob only the provider reads. |
| `attributes_flat` | pre-0.12 state | The legacy flatmap form, replaced by `attributes`. |

Only `schema_version` and `identity_schema_version` are written unconditionally; every other field is omitted when it does not apply. Data sources are thinner still: an `aws_region` instance carries neither `identity` nor `private`, because neither means anything for something Terraform only reads. The entry shown earlier looks shorter than it is because it was trimmed. The real instance element for that one bucket also carries `identity`, `private` and `sensitive_attributes`, and it has no `index_key`, no `status` and no `dependencies`, because none of those apply to a single bucket that depends on nothing and is not tainted.

**`attributes` has no fixed schema, and that is the point.** Terraform stores it as raw JSON and never looks inside at the state layer, which the source is explicit about: the value is carried straight through as `AttrsJSON`. Its shape comes from the provider's schema for that resource type, so an `aws_s3_bucket` records `bucket`, `arn`, `tags` and the rest, while an `aws_instance` records something entirely different. `schema_version` is what lets a provider recognise an older layout and migrate it during an upgrade.

Two consequences run through this chapter. Terraform cannot tell you whether an `attributes` block is *right*, only whether it parses, which is why drift in section 8 has to be detected by asking the provider rather than by reading state. And it is why hand-editing state is so dangerous, because nothing validates your edit against the provider's schema. Inject a `not_a_real_attribute` key into a bucket's `attributes` and Terraform accepts it without a word: `terraform validate` reports `Success!`, and `plan -refresh=false` reports `No changes`, with the invented key still sitting in the file. Whatever goes wrong as a result surfaces later, somewhere else.

The **binding** is the pairing inside one of those instance elements. On one side the address, spelled by `type` and `name`, with `module` and `index_key` joining them when they apply. On the other the `id` inside `attributes`, naming the object the provider actually created. `attributes` is the provider's whole record of that object, which is why `arn` sits in there too, but `id` is the half the binding turns on. That pairing is how Terraform gets from an address in your configuration to the object it has to modify.

Nothing outside the entry holds the two together. Terraform writes no ownership marker onto the bucket itself, so the object cannot tell you which resource block claims it. The connection survives only while the address recorded in state still corresponds to an address your configuration declares.

Breaking that correspondence takes one word. Rename the label on the `resource` block and the state entry does not follow: state still holds `aws_s3_bucket.notes` while the configuration now declares `aws_s3_bucket.team_notes`. The bucket is untouched and `terraform validate` reports the configuration valid, so each half is individually in perfect order. They have simply stopped referring to each other, and Terraform has no way to guess that they were ever a pair.

Both earlier chapters could assume this entry, once written by an ordinary apply, never needed adjusting. That assumption breaks constantly, and it breaks in five recognisable ways.

1. **Some infrastructure predates your configuration.** A bucket exists, someone created it in a console two years ago, and nothing in Terraform knows about it.
2. **Some of it gets renamed.** `aws_s3_bucket.notes` was a fine name until three teams started using it.
3. **Some of it moves into a module** during a refactor, which changes the address without touching the object.
4. **Some of it changes underneath you** at three in the morning, when an on-call engineer edits a security group to stop an outage.
5. **Some applies die halfway**, having created objects state never recorded, or recorded objects they never finished destroying.

All five have the same headline: configuration and state stop agreeing. What separates them is **which side moved**, and that is what decides the fix.

| Which | Which side moved | Handled in |
|---|---|---|
| 1 | **Neither. Terraform was never told.** The object was created outside Terraform, so state has no entry for it. Nothing was broken here, because nothing was ever joined. | Section 6 |
| 2, 3 | **The configuration moved, state stayed put.** You renamed the resource or pulled it into a module; the entry still holds the old address, bound to an object that never changed. | Sections 4 and 7 |
| 4 | **The object moved, state stayed put.** Someone changed a *managed* object by hand. | Section 8 |
| 5 | **Terraform moved the object, then failed to record it.** The run created or destroyed something for real and died before the state write landed. The dangerous half is a resource created but never recorded, because the next run plans to create it again. | Sections 8 and 11 |

Note how close rows 1 and 4 look and how differently they end. Both involve someone working outside Terraform, but row 1 has no entry to correct and row 4 has an entry that is merely stale, so one is answered by `import` and the other by `apply -refresh-only`.

Three sections sit outside the table. Section 5 answers a want rather than a failure, when you have decided to stop managing something that must keep running. Section 9 is for an object that is damaged while state is entirely correct. Section 10 is the command surface all of them reach for.

Take rows 2 and 3 first, where the configuration is what moved. HashiCorp's [Move Resources](https://developer.hashicorp.com/terraform/cli/state/move) page states that case in one sentence:

> "Terraform's state associates each real-world object with a configured resource **at a specific resource address**. This is seamless when changing a resource's attributes, but Terraform will **lose track** of a resource if you change its name, move it to a different module, or **change its provider**."

Three ways to break the binding, and the first two are already on the table above.

1. **Change its name.** That is failure 2.
2. **Move it to a different module.** That is failure 3.
3. **Change its provider.** This one is deliberately not among the five, because it is the only case in which nothing about the address changes at all.

The third is the one people never guess, and it is also the one easiest to get wrong in the retelling, so be precise. The provider is **not** part of the resource address. Section 3's grammar is `[module path][resource spec]` and has no provider component anywhere in it. What state does is record the provider **beside** the address, as the entry at the top of this section shows: a sibling field of `type` and `name`, not a component of the address they spell.

So a provider change breaks the **binding** without changing the address, which is precisely why it needs a command of its own. A `moved` block rewrites addresses, and there is no address here to rewrite. `terraform state replace-provider` exists to edit that one field, and it is documented on this page, in the sidebar's *Moving Resources* group, rather than anywhere provider-shaped.

What happens when the binding breaks is worth quoting too, because the docs' tone is the correct one:

> "**Usually that's fine**: Terraform will destroy the old resource, replace it with a new one (using the new resource address), and update any resources that rely on its attributes."

Destroy-and-recreate is the *right* answer to a renamed address most of the time. The refactoring half of this chapter, sections 4 to 7, exists for the minority of cases where the object has to survive the address change instead.

### The diagnostic line

Rename a resource in a lab configuration and plan it. Measured on Terraform **v1.15.8** with AWS provider **v6.61.0**:

```text
Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
  - destroy

Terraform will perform the following actions:

  # aws_s3_bucket.notes will be destroyed
  # (because aws_s3_bucket.notes is not in configuration)
  - resource "aws_s3_bucket" "notes" {
      - arn                         = "arn:aws:s3:::ch16-moved-notes" -> null
      - bucket                      = "ch16-moved-notes" -> null
      ...
    }

  # aws_s3_bucket.team_notes will be created
  + resource "aws_s3_bucket" "team_notes" {
      + acceleration_status         = (known after apply)
      + acl                         = (known after apply)
      + arn                         = (known after apply)
      + bucket                      = "ch16-moved-notes"
      ...
    }

Plan: 1 to add, 0 to change, 1 to destroy.
```

Nothing about the bucket changed. Its name is identical on both sides of the plan. The only edit was the label in the `resource` block, and Terraform read it as a deletion plus an unrelated creation, because to Terraform, **an address in state with no matching block in configuration is indistinguishable from a resource you deleted on purpose**.

`# (because X is not in configuration)` is the line to recognise. It means "state has something configuration does not claim", and it appears whether you deleted the resource, renamed it, moved it into a module, or forgot to `git add` a file.

"Indistinguishable" is meant literally, and it is worth proving rather than asserting. Apply one bucket, then make two different edits against that same state, planning each one without applying it.

1. **Delete** the `resource` block outright. Plan, and save the output as `deleted.txt`.
2. Put the block back and **rename** its label instead. Plan again, and save that as `renamed.txt`.

Neither plan is applied, so both are computed against the same state, holding the same one bucket. Now compare them line by line:

```text
$ diff deleted.txt renamed.txt
4a5
>   + create
57c58,99
< Plan: 0 to add, 0 to change, 1 to destroy.
---
>   # aws_s3_bucket.team_notes will be created
>   + resource "aws_s3_bucket" "team_notes" {
>       + acceleration_status         = (known after apply)
...
>     }
>
> Plan: 1 to add, 0 to change, 1 to destroy.
```

Those three numbers are worth checking rather than believing:

```shell
wc -l deleted.txt                              # 62
diff deleted.txt renamed.txt | grep -c '^<'    # 1  — only in deleted.txt
diff deleted.txt renamed.txt | grep -c '^>'    # 43 — only in renamed.txt
```

Measure the overlap rather than reading the diff for differences. The deletion plan is 62 lines long, and **61 of them appear in the rename plan, identically and in the same order**: every refresh line, the whole destroy block, and the reason line inside it. A deliberate deletion and an accidental rename produce the same destroy output character for character, so nothing in it can tell you which one you are looking at.

Exactly one line of the deletion plan is missing from the other, and it is the counter, `0 to add` where the rename says `1 to add`. Everything else the diff reports is the 43 lines the rename *adds*: the extra `+ create` entry in the symbol legend, and the create block itself.

That is the practical reading rule. **The `+` half is the tell, not the `-` half.** An unexpected destroy on its own is ambiguous. An unexpected destroy paired with the creation of something suspiciously similar, and `1 to add` where you expected `0 to add`, is a rename you forgot to declare.

!!! note "Failures 1 to 3 point in two directions, and need different tools"
    Which way the mismatch points decides which block you reach for. **Configuration has something state does not** is the import case: an object exists and nothing tracks it, so section 6 adopts it. **State has something configuration does not** is the destroy case, and it is where `moved` and `removed` come in, in sections 4 and 5. Both tell Terraform that the missing address is not what it looks like. One says the resource was renamed; the other says it was handed to someone else. Neither means deleted.

---

## 2. The toolkit, ranked

There are three tiers, and TID Ch 6 §6.5 puts them in the order you should reach for them: **code**, then the **CLI**, then hand-editing. The table below splits the first two into columns. The third tier, hand-editing, shows up only in the last row, where nothing better exists.

| Intent | Preferred: goes through a plan | Fallback: writes state directly | Preferred route introduced |
|---|---|---|---|
| Adopt an existing object | `import` block | `terraform import` | block: 1.5 |
| Adopt many objects | `list` blocks + `terraform query`, then the `import` blocks it generates | `terraform import`, once per object | 1.14 |
| Rename or relocate an address | `moved` block | `terraform state mv` | block: 1.1 |
| Forget an object, keep it running | `removed` + `lifecycle { destroy = false }` | `terraform state rm` | block: 1.7 |
| Move an object to another state file | `removed` + `import` in two configurations | `state mv -state -state-out` | 1.7 |
| Rewrite a provider source in state | — | `terraform state replace-provider` | — |
| Accept out-of-band changes into state | `apply -refresh-only` | `terraform refresh` (deprecated) | flag: 0.15.4 |
| Force one object to be rebuilt | `apply -replace=ADDR` | `terraform taint` (deprecated) | flag: 0.15.2 |
| Repair a corrupted state | — | `state pull` → edit → `state push` | — |

Read the fallback column as an escape hatch, not as a parallel workflow. The two deprecated rows share one flaw: each writes state outside a plan anybody could have reviewed. They get there from opposite directions, though. `taint` deferred the action behind a state write; `refresh` writes state with no preview at all.

!!! info "OpenTofu — the same blocks, and no `query` at all"
    The version column is Terraform's. OpenTofu forked from Terraform 1.5, so it inherited the `moved` and `import` blocks and both have worked since its first release, **v1.6.0**. `removed` arrived in **OpenTofu 1.7.0** ([#1158](https://github.com/opentofu/opentofu/pull/1158)), the same number Terraform used. The bulk-adoption row has no OpenTofu counterpart: **1.12.5** carries no `query` command and no `list` block, so there the fallback column is the only route.

### Why configuration wins, three times over

The ranking above is a preference until you know what is behind it. No docs page argues the case as a whole, and the pages that argue a piece of it do so while explaining one particular block or one particular command. Stated as properties of the **route** rather than of any syntax, there are three: **containment**, **distribution**, **atomicity**. Every entry in the preferred column has all three. No CLI state command has any.

**Containment.** A state change written in configuration is proposed by a plan before it happens, so it is reviewed and approved in the same step that approves everything else in the run. The two deprecated commands in the table are the negative evidence, and they fail this from opposite directions. `terraform taint` deferred the real work: it wrote an interim state snapshot recording the intent, and the replacement happened on some later apply. `terraform refresh` did the opposite, writing state immediately with no preview at all. Terraform's [v0.15.4 changelog](https://github.com/hashicorp/terraform/blob/v0.15.4/CHANGELOG.md), which introduced `-refresh-only`, gives the reason for replacing it: the new planning mode "serves as a plannable replacement for `terraform refresh`", recommended "because it will provide an opportunity to review what Terraform detected before updating the Terraform state".

That sentence is about a planning flag rather than a block, which is the point. Containment is a property of the route, not of the syntax, and it is why `-refresh-only` and `-replace` sit in the preferred column alongside the blocks.

**Distribution**, from [Move Resources](https://developer.hashicorp.com/terraform/cli/state/move):

> "**For most cases** we recommend using the Terraform language's **refactoring features** to document in your module exactly how the resource names have changed over time. Terraform reacts to this information automatically during planning, so **users of your module do not need to take any unusual extra steps**."

A CLI state operation fixes your state. Configuration fixes everyone's, because it travels with the code and Terraform acts on it wherever the code is applied. You cannot ship a command to a hundred module consumers and expect all hundred to run it correctly against their own state. Note the plural in *refactoring features*: the recommendation is about the language's refactoring blocks as a family, not about any one of them.

**Atomicity**, from the [`state mv` reference](https://developer.hashicorp.com/terraform/cli/commands/state/mv), and the sharpest of the three:

> "If you are using Terraform in a collaborative environment, you must ensure that when you are using `terraform state mv` for a code refactoring purpose you **communicate carefully with your coworkers** to ensure that nobody makes any other changes between your configuration change and your `terraform state mv` command, because otherwise they might inadvertently **create a plan that will destroy the old object and create a new object** at the new address."

A CLI refactor is two operations with a gap between them, and during that gap the repository describes a change that state has not heard about. Anyone who plans in that window gets a correct-looking destroy. Nothing in the warning is specific to renaming: `terraform state rm` followed by a configuration edit, or an edit followed by `terraform import`, opens the same window in the same way. Declaring the change instead closes it, because the state change and the configuration change arrive in the same apply.

Containment, distribution, atomicity. Sections 4 to 6 take the blocks one at a time, and each one is an instance of this argument rather than a new argument of its own.

!!! tip "The fourth argument, which is yours rather than HashiCorp's"
    A state change declared in configuration goes through **plan**, so it arrives in a pull request, gets reviewed, and leaves a diff in the history. A CLI state operation leaves a line in someone's shell history and, at best, a `terraform.tfstate.1787302875.backup` file on the machine that ran it. At best, because three state-writing paths leave no backup at all, which section 10 takes up. When a state operation goes wrong six months later, the configuration is the only artefact anyone can read.

---

## 3. Resource addressing: one grammar, several parsers

Nearly every operation in this chapter takes an address. The exceptions are the ones whose unit is larger than a resource: `state pull`, `state push` and `replace-provider`, which section 10 returns to, and `refresh`, which section 8 does. Everything else parses the same grammar, and the parsers do not agree about what an incomplete address means, so it is worth ten minutes before the rest of the chapter.

Section 1 read three of these straight out of a state file: `aws_s3_bucket.notes`, `aws_s3_bucket.archive[0]` and `aws_s3_bucket.archive["cold"]`, spelled by `type`, `name` and `index_key`, with `module` joining them when the resource lives in a child module. That is the state file's side of it. [The address reference](https://developer.hashicorp.com/terraform/cli/state/resource-addressing) gives the grammar those three are instances of, in two halves:

```text
[module path][resource spec]
```

- **Module path** is `module.NAME[index]`, repeatable for nesting: `module.foo[0].module.bar["a"]`. Omit it and you mean the root module.
- **Resource spec** is `TYPE.NAME[index]`, the same shape one level down.
- **Index** is `[N]` for `count`, a zero-based position, and `["KEY"]` for `for_each`, a string key.

The sentence that governs everything else:

> "A resource address is a string that identifies **zero or more** resource instances in your overall configuration."

Zero or more. An address is a **set**, and how big the set is depends on how much you left off.

!!! warning "Omitting the index is not shorthand for “the first one”"
    From the same page: *"Omitting an index when addressing a resource where `count > 1` means that the address **references all instances**."* The page states that rule for `count` only, and says nothing of the kind under `for_each`. The measured table below is a `for_each` resource, and it behaves the same way, so read the rule as being about instance keys rather than about `count`.

    The same holds one level up, for an address that **stops at the module**. `module.foo` is every resource in every instance of that module call, and `module.foo[0]` is the narrowing. Once a resource spec follows an un-indexed module path the rule inverts and the address matches nothing at all, which is measured later in this section.

    In a `terraform state list` that is a convenience. In a `terraform state rm` it is the difference between forgetting one object and forgetting every instance the resource has.

### The parsers disagree, and the docs say so

The address page admits it outright:

> "In some contexts Terraform might allow for an **incomplete resource address**… the meaning depends on the context, so you'll need to refer to the documentation for the **specific feature** you are using which parses resource addresses."

There is one grammar and several parsers. Measured on **v1.15.8** against a state holding `aws_s3_bucket.shard["a"]` and `aws_s3_bucket.shard["b"]`:

| Operation given the bare `aws_s3_bucket.shard` | Result |
|---|---|
| `terraform state list aws_s3_bucket.shard` | filters to **both** instances |
| `terraform state show aws_s3_bucket.shard` | **error** — `No instance found for the given address!` |
| `terraform state rm aws_s3_bucket.shard` | **removes both**, no prompt |
| `-target=aws_s3_bucket.shard` | the whole set. A targeted destroy plan reported `2 to destroy`, and the dependency walk is per resource anyway |

```text
$ terraform state show aws_s3_bucket.shard
No instance found for the given address!

This command requires that the address references one specific instance.
To view the available instances, use "terraform state list". Please modify
the address to reference a specific instance.
```

The command that refuses to guess is the one that only prints. The command that rewrites state accepts the same address and acts on everything it matches, without asking, and section 5 has that transcript next to the argument it settles.

All four rows behave identically under **OpenTofu 1.12.5**, measured on the same configuration. The only difference is presentation: `tofu state show` refuses through its normal diagnostic renderer, as a boxed `Error: No instance found for the given address` with no exclamation mark, rather than the bare line Terraform prints. Worth knowing if you are grepping output for the string.

#### The module half disagrees harder

A bare module path behaves as the reference describes. Measured on **v1.15.8** against a state holding two instances of `module.shards`, each containing two buckets: `state list module.shards` returns all four, `state list 'module.shards[0]'` narrows to the two in that instance, and a targeted destroy plan on `module.shards` reports `4 to destroy`.

Put a resource spec after an **un-indexed** multi-instance module path, though, and the index stops being optional. Three parsers, one address, three answers:

| `module.shards.aws_s3_bucket.one` given to | Answer |
|---|---|
| `terraform state list` | `Error: Unknown resource` |
| `terraform state rm -dry-run` | `Would have removed nothing.` |
| `terraform plan -destroy -target=…` | `No changes. No objects need to be destroyed.` |

Two controls on the same state say the address is the only thing wrong. `module.shards[0].aws_s3_bucket.one` plans `1 to destroy`, and `module.solo.aws_s3_bucket.one`, naming a module call declared without `count`, lists its bucket with no index at all. So the omission is only fatal where there is more than one instance to be ambiguous about, and the index that means *every instance* when the address stops at the module means *no instance* once a resource follows it.

The third row is the dangerous one. A hard error tells you to fix the address, and `Would have removed nothing` at least says nothing happened. A targeted plan reporting `No changes` reads as "your infrastructure is already in the desired state", which is a sentence about the infrastructure rather than about your typo.

`state show` adds a fourth voice: given `module.shards` it answers `Error parsing instance address: module.shards`, not the `No instance found for the given address!` it gives for a resource. Same refusal, different wording, in the same command.

**OpenTofu 1.12.5** answers all three the same way, measured on the same configuration, down to `Would have removed nothing.` and `No changes. No objects need to be destroyed.` Whatever the disagreement is, it is not a quirk of one distribution.

The three refactoring blocks parse that same grammar, and each imposes its own rule on top of it. The rules look arbitrary side by side, and each one is checkable:

| Block | Instance key in the address | Measured on **v1.15.8** |
|---|---|---|
| **`import`** — `to` | **Required**, once the target uses `count` or `for_each` | `[0]` and `["env"]` both import cleanly; a bare address fails the plan with `Invalid import 'to' expression` and `The target resource is using for_each`, or `using count` |
| **`moved`** — `from` / `to` | **Optional, on either side** | bare on both sides moves every instance and keeps its key, `0 to add, 0 to change, 0 to destroy`; a key on one side switches to instance mode, which is how a `count` → `for_each` migration is written |
| **`removed`** — `from` | **Forbidden** | `Resource address must be a resource … not a resource instance`, in section 5 |

One grammar, three rules: required, optional, forbidden. Nothing in the grammar forbids `removed` from taking an instance key, and nothing in it demands one of `import`. Each block decides for itself, and the consequence is asymmetric. A multi-instance resource can be **adopted per instance** and **rearranged per instance**, but only **forgotten wholesale**. Plan a staged migration into Terraform and you can go one instance at a time; plan a staged migration out and you cannot.

!!! info "Two legacy rules that changed what an unchanged address means"
    **Module indexes need v0.13+**, because before that a module could not have multiple instances. And **a bare resource spec has meant the root module only since v0.12**. Earlier versions matched the same type and name in *any* descendant module, so a pre-0.12 `terraform state rm aws_instance.web` removed every `aws_instance.web` in the tree, children included, where today's identical command reaches only the root.

    The mechanism is visible in the v0.11 source: `State.Remove` filtered through `StateFilter`, whose module test was a **prefix match** on the module path, and an address carrying no module path is a prefix of every path in the state. Commands with their own module flag were the exception rather than the rule. `terraform taint` took `-module`, defaulting to `root`, so its bare address never left the root module in the first place.

---

## 4. `moved`: rename without destroying

Two arguments, both required, both references rather than strings:

```hcl
moved {
  from = aws_s3_bucket.notes       # the address that is gone from configuration
  to   = aws_s3_bucket.team_notes  # the address that is now declared
}
```

The direction reads backwards to most people the first time. The rule that fixes it: **a `moved` block migrates state to match configuration, and configuration is the truth.** `to` must be an address that exists in your configuration right now. `from` must be an address that is gone from configuration but still present in state from the last apply.

Flip them and you get the destroy-and-recreate you wrote the block to avoid, because `from = team_notes, to = notes` renames the state entry to an address nothing declares.

!!! warning "You never declare both resources at once"
    A tempting misreading is that the old and new `resource` blocks coexist during the transition, with `moved` linking them. Terraform rejects that before producing any plan:

    ```text
    Error: Moved object still exists

      on both.tf line 9:
       9: moved {

    This statement declares a move from aws_s3_bucket.single, but that resource
    is still declared at both.tf:1,1.

    Change your configuration so that this resource will be declared as
    aws_s3_bucket.other instead.
    ```

    Measured on **v1.15.8**. The rename **is** the edit to the existing block's label. There is no stage where both addresses are declared, and the error names the edit it wants.

### What a clean move looks like

Add the block to the renamed configuration from section 1 and re-plan. Measured on **v1.15.8**:

```text
Terraform will perform the following actions:

  # aws_s3_bucket.notes has moved to aws_s3_bucket.team_notes
    resource "aws_s3_bucket" "team_notes" {
        id                          = "ch16-moved-notes"
        tags                        = {}
        # (15 unchanged attributes hidden)

        # (4 unchanged blocks hidden)
    }

Plan: 0 to add, 0 to change, 0 to destroy.
```

`has moved to`, and **no action symbol** in front of the resource line. That is what a pure move looks like: a plan that proposes no infrastructure action at all. Applying it reports `Apply complete! Resources: 0 added, 0 changed, 0 destroyed`, and `terraform state list` shows the new address.

[The `moved` block reference](https://developer.hashicorp.com/terraform/language/block/moved) is the only page that says why that plan can be empty:

> "**Before creating a new plan** for the resource specified in the `to` field, Terraform **checks the state** for an existing object at the address specified in the `from` field. Terraform **renames existing objects** to the string specified in the `to` field and **then creates a plan**. […] **As a result, Terraform does not destroy the resource during the Terraform run.**"

The rename happens *before* the plan is computed. By the time Terraform diffs configuration against state, the new address already has an object bound to it, so there is nothing to create and nothing orphaned to destroy. This is section 2's containment argument in its concrete form: the state change is not a step you take beside the run, it is part of the run the plan describes.

It also means a `from` that matches nothing in state has nothing to rename, and planning proceeds unchanged. Leaving the block in place costs nothing, which turns retention into a question about other people's state rather than about risk to your own.

### `count` to `for_each`, the migration everyone needs

Chapter 10 recommended `for_each` over `count` for named things, measured what `count`'s reindexing costs when you delete an element, and closed with a lab that migrates a `count` set to `for_each` and gets an empty plan. This section is the rule behind that lab: what the blocks are doing, and which part of the mapping is yours rather than Terraform's.

Start with what happens without them. Measured on this chapter's lab: two buckets created under `count`, then converted to `for_each` with the bucket names left identical and the keys changed from positions to names.

```text
  # aws_s3_bucket.archive[0] will be destroyed
  # aws_s3_bucket.archive[1] will be destroyed
  # aws_s3_bucket.archive["cold"] will be created
  # aws_s3_bucket.archive["warm"] will be created

Plan: 2 to add, 0 to change, 2 to destroy.
```

The fix is one `moved` block per instance. The rule from [Refactor modules](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) is that **an instance key on either side switches the whole block into instance mode**:

```hcl
resource "aws_s3_bucket" "archive" {
  for_each = { cold = 0, warm = 1 }
  bucket   = "ch16-moved-archive-${each.value}"
}

moved {
  from = aws_s3_bucket.archive[0]
  to   = aws_s3_bucket.archive["cold"]
}

moved {
  from = aws_s3_bucket.archive[1]
  to   = aws_s3_bucket.archive["warm"]
}
```

```text
  # aws_s3_bucket.archive[0] has moved to aws_s3_bucket.archive["cold"]
  # aws_s3_bucket.archive[1] has moved to aws_s3_bucket.archive["warm"]

Plan: 0 to add, 0 to change, 0 to destroy.
```

The mapping from index to key is yours to decide and yours to get right. Terraform cannot infer that position 0 was the cold archive.

!!! info "Adding `count` to a bare resource is free; renaming never is"
    > "When you add `count` to an existing resource that didn't previously have the argument, **Terraform automatically proposes moving the original object to instance `0`** unless you write a `moved` block that explicitly mentions that resource. However, we recommend writing out the corresponding `moved` block explicitly to make the change clearer to future readers of the module."

    There is no equivalent auto-move for `for_each`, because `for_each` needs a key that only you can choose. Measured on **v1.15.8**, one bucket taken through both edits with its name unchanged and no `moved` block written:

    ```text
    # adding count = 1
      # aws_s3_bucket.a has moved to aws_s3_bucket.a[0]
    Plan: 0 to add, 0 to change, 0 to destroy.

    # swapping count for for_each = toset(["small"])
      # aws_s3_bucket.a will be destroyed
      # aws_s3_bucket.a["small"] will be created
    Plan: 1 to add, 0 to change, 1 to destroy.
    ```

    So `aws_instance.a` → `aws_instance.a[0]` costs nothing, and `aws_instance.a` → `aws_instance.a["small"]` needs the block.

### Modules

`moved` names addresses on both sides, and either side may reach into a child module. The block lives where the refactor is being made, which is usually the root, not where the resource lives:

```hcl
moved {
  from = aws_instance.example
  to   = module.ec2_instance.aws_instance.example
}
```

Renaming a whole module call moves everything beneath it with one block, index keys included:

```hcl
moved {
  from = module.vpc
  to   = module.learn_vpc
}
```

!!! warning "Renaming a module call requires a re-`init`"
    Modules are installed under a key derived from the **call name**, so the new name has nothing installed against it and the next plan refuses to start. Measured on **v1.15.8**, renaming a call whose source is a local directory:

    ```text
    Error: Module not installed

      on main.tf line 1:
       1: module "only" {

    This module is not yet installed. Run "terraform init" to install all modules
    required by this configuration.
    ```

    `.terraform/modules/modules.json` is where that key lives, still reading `{"Key":"solo","Source":"./mod","Dir":"mod"}` after the rename. Nothing is downloaded in this case, so the requirement is not about fetching a remote module: the `init` is needed even when the source is a directory next door. The tutorial says as much in passing, *"Run `terraform init` to update your VPC module's name."* Re-run it and the move is clean, both resources reporting `has moved to` with `0 to add, 0 to change, 0 to destroy`.

### A zero-destroy plan is not a zero-impact plan

The most useful thing in HashiCorp's [Use configuration to move resources](https://developer.hashicorp.com/terraform/tutorials/modules/move-config) tutorial is that its worked example does *not* come out empty. Four resources are moved and the plan reports `0 to add, 3 to change, 0 to destroy`, because the exercise swaps a hand-written security-group module for a registry one at the same time. The tutorial's explanation:

> "The security group and its rules were updated **in-pace** when they moved because the new module includes default values for some attributes that the old module did not."

The misspelling is the tutorial's, quoted as written.

**`moved` preserves identity, not configuration.** Extracting your own code into your own module is normally a clean move. Swapping a homegrown module for a registry module is a move *and* a configuration change, and both arrive in the same apply. Read the `~` lines, not just the destroy count.

### Keeping the blocks

The tutorial states the retention rule absolutely: *"We strongly recommend you retain all `moved` blocks in your configuration as a record of your changes. Removing a `moved` block plans to delete that existing resource instead of moving it."* The reference qualifies it, and the qualification is the part that matters:

> "It can be safe to remove `moved` blocks when you are **maintaining private modules within an organization** and you are **certain that all users have successfully run `terraform apply`** with your new module version."

The question is never "has enough time passed", it is **whose state still holds the old address**. A root module you alone apply is the easy case. A configuration applied across several workspaces needs all of them to have applied. A published module keeps its blocks forever, because you cannot know which version a consumer is upgrading from.

Which is why the docs tell module authors to **chain** them rather than rewrite them:

```hcl
moved {
  from = aws_instance.a
  to   = aws_instance.b
}

moved {
  from = aws_instance.b
  to   = aws_instance.c
}
```

> "Recording a sequence of moves in this way allows for successful upgrades for **both** configurations with objects at `aws_instance.a` **and** configurations with objects at `aws_instance.b`."

A module's `moved` blocks accumulate for the same reason a database's migrations do: each one covers consumers arriving from a different starting version. That is the migration half of the module-API story whose deprecation half was `deprecated` on variables and outputs in Chapter 14.

!!! note "What `moved` cannot do"
    **It cannot cross state files.** Everything above happens inside one state file; splitting a state needs section 7's machinery.

    **It cannot change a resource's type**, except where a provider explicitly supports it. Each resource type has its own schema, so whether `aws_x` can become `aws_y` is a question for the provider docs.

    **It cannot turn a `resource` into a `data` block.** That boundary is absolute. To stop managing something and start reading it, you `removed` it with `destroy = false` and add a `data` block separately.

---

## 5. `removed`: forget without destroying

You are handing a bucket to another team, or to another tool, and Terraform should stop tracking it without deleting anything. The configuration-driven answer is a `removed` block, and it has one argument plus one `lifecycle` block that is mandatory in practice:

```hcl
removed {
  from = aws_s3_bucket.handover

  lifecycle {
    destroy = false
  }
}
```

!!! danger "A bare `removed` block destroys the object"
    The `lifecycle` block is not decoration and omitting it is not neutral. Measured on **v1.15.8**, with the `resource` block deleted and only `removed { from = ... }` written:

    ```text
      # aws_s3_bucket.handover will be destroyed
      # (because aws_s3_bucket.handover is not in configuration)
      - resource "aws_s3_bucket" "handover" {
          - arn    = "arn:aws:s3:::ch16-handover" -> null
          ...

    Plan: 0 to add, 0 to change, 1 to destroy.
    ```

    The reason line is the ordinary "not in configuration" one from section 1, which tells you what is happening: without `destroy = false`, the `removed` block adds nothing to simply deleting the resource block.

    The [block reference](https://developer.hashicorp.com/terraform/language/block/removed) states the default plainly in its `lifecycle` section — *"**By default, Terraform removes the resource from state and destroys the actual resource.** Set `destroy` to `false` to remove the resource from state without destroying the actual resource"* — and then contradicts itself in its own opening sentence, which still describes the block as removing a resource *"without changing the underlying infrastructure"*.

    **That is a documentation bug, not a leftover from older behaviour**, and it is worth being exact because the opposite story is widely repeated. Verified in the source: `internal/configs/removed.go` at tag **v1.7.0**, the release the block shipped in, already carries a `Destroy bool`, already parses `lifecycle { destroy }`, and already sets `removed.Destroy = true` *before* it looks for a `lifecycle` block. The v1.7 documentation matched: both of its examples, the resource form and the module form, were written with `destroy = false`, and it said outright that `destroy` "determines whether Terraform will attempt to destroy the object managed by the resource or not".

    So `destroy` shipped **with** the block in 1.7 and has defaulted to `true` since day one. There is no version in which a bare `removed` block was safe. Material that says otherwise, including TID Ch 2 §2.9, was wrong when it was written rather than overtaken by a change.

!!! warning "The docs call `lifecycle` required. The parser does not."
    Both the 1.7 page and the current configuration model describe the `lifecycle` block as **required**, yet `terraform validate` accepts a `removed` block without one and the plan proceeds to destroy. The schema explains why. In `removed.go` at **v1.15.8**, only `from` carries `Required: true`; `lifecycle` is an ordinary optional block, and `destroy` inside it is an optional attribute.

    That also settles what a missing `lifecycle` means, which the plan output alone leaves ambiguous. It is **not** that Terraform ignores the block and destroys the object merely for being absent from configuration. `Destroy` is initialised to `true` and nothing overrides it, so the block is honoured and asked to destroy. The observable outcome is the same either way; the reason matters if you are trying to predict behaviour from the docs, which here disagree with the parser.

### The `.` symbol, and the empty legend

With `destroy = false` in place, the same plan becomes something you will not see anywhere else. Measured on **v1.15.8**:

```text
Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:

Terraform will perform the following actions:

 # aws_s3_bucket.handover will no longer be managed by Terraform, but will not be destroyed
 # (destroy = false is set in the configuration)
 . resource "aws_s3_bucket" "handover" {
        id                          = "ch16-handover"
        # (15 unchanged attributes hidden)
    }

Plan: 0 to add, 0 to change, 0 to destroy.

Warning: Some objects will no longer be managed by Terraform

If you apply this plan, Terraform will discard its tracking information for
the following objects, but it will not delete them:
 - aws_s3_bucket.handover

After applying this plan, Terraform will no longer manage these objects. You
will need to import them into Terraform to manage them again.
```

Three things in that output are worth naming.

**The action symbol is a lone period.** Not `+`, `-`, `~` or `-/+`. It is the forget marker, and it is easy to read as formatting noise.

**The symbol legend is printed empty.** The line *"Resource actions are indicated with the following symbols:"* is followed by nothing at all, because Terraform has no legend entry for `.`. That is a small documentation bug you can see with your own eyes, and it is why nobody recognises the symbol.

**`0 to destroy` on a plan that rewrites state.** The counters count *infrastructure* actions, and forgetting is not one. The same counter behaviour shows up in `apply -refresh-only` in section 8.

Applying it reports `Apply complete! Resources: 0 added, 0 changed, 0 destroyed`, `terraform state list` comes back empty, and the bucket is still there:

```text
$ awslocal s3api list-buckets --query 'Buckets[?Name==`ch16-handover`].Name' --output text
ch16-handover
```

!!! info "OpenTofu — the forget is a first-class plan action, and it has a counter"
    Measured on **OpenTofu 1.12.5**, same configuration, same emulator. OpenTofu documents the symbol, words the message differently, and adds a **fifth counter**:

    ```text
    OpenTofu used the selected providers to generate the following execution
    plan. Resource actions are indicated with the following symbols:
      . forget

    OpenTofu will perform the following actions:

      # aws_s3_bucket.ot will be removed from the OpenTofu state but will not be destroyed
      . resource "aws_s3_bucket" "ot" {
      ...

    Plan: 0 to add, 0 to change, 0 to destroy, 1 to forget.
    ```

    `1 to forget` is genuinely better output. Terraform's `0 to destroy` is technically accurate and tells a reviewer nothing about what the plan is going to do to their state, which is exactly the review step the block exists to provide.

### The two constraints

**`from` takes no instance keys.** Measured on **v1.15.8** against a `for_each` resource:

```text
Error: Resource instance keys not allowed

  on keytest.tf line 7, in removed:
   7:   from = aws_s3_bucket.shard["a"]

Resource address must be a resource (e.g. "test_instance.foo"), not a
resource instance (e.g. "test_instance.foo[1]").
```

So a `count` or `for_each` resource is forgotten in full or not at all. This is the asymmetry from section 3, met in the field.

**Every reference to the resource's attributes must go first.** A dangling `aws_s3_bucket.handover.id` elsewhere in the configuration blocks the plan, and `terraform validate` enumerates them for you.

### Getting back in

The warning in the plan output names the exit cost, and it is not reversible by editing configuration:

> "You will need to import them into Terraform to manage them again."

Not an undo, not a re-added `resource` block. An import. Measured, adding the `resource` block back plus an `import` block pointing at the same bucket:

```text
aws_s3_bucket.handover: Importing... [id=ch16-handover]
aws_s3_bucket.handover: Import complete [id=ch16-handover]

Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.
```

Forgetting is reversible, but only by re-adopting. That round trip, `removed` with `destroy = false` and then `import`, is also the entire cross-configuration migration in section 7.

!!! info "OpenTofu — `lifecycle { destroy = false }` on the resource itself, and it fails the destroy"
    OpenTofu **1.12** puts the same argument on the resource's own `lifecycle` block, with no `removed` block involved. Measured on **1.12.5**: `tofu validate` accepts it, and `tofu destroy` forgets the object rather than deleting it, then **exits non-zero**:

    ```text
    Error: Destroy was successful but left behind forgotten instances

    As requested, OpenTofu has not deleted some remote objects that are no longer
    managed by this configuration. Those objects continue to exist in their
    remote system and so may continue to incur charges. Refer to the original
    plan for more information.
    To suppress this error for the future 'destroy' runs, you can add the CLI
    flag "-suppress-forget-errors".
    ```

    The bucket survived the destroy. Terraform **1.15.8** rejects the argument outright:

    ```text
    Error: Unsupported argument

      on main.tf line 5, in resource "aws_s3_bucket" "ot":
       5:     destroy = false

    An argument named "destroy" is not expected here.
    ```

    Terraform **1.16** adds the resource-level form, so this converges rather than staying a permanent fork difference. Until 1.16 is stable, the `removed` block is Terraform's only route. Note the design difference that survives the convergence: OpenTofu makes leaving objects behind an **error you opt out of**, where Terraform's plan says `0 to destroy` and moves on.

### The CLI alternative, and why the docs argue against it

`terraform state rm` does the same job in one command. [Remove a resource from state](https://developer.hashicorp.com/terraform/language/state/remove) recommends against it and gives the reason:

> "we recommend using the `removed` block instead. This is because the `removed` block lets you **preview the results** of the operation, which makes it a safer way to remove resources."

Measured on **v1.15.8**, `state rm` given a bare address takes out the whole set with no preview and no prompt:

```text
$ terraform state rm aws_s3_bucket.shard
Removed aws_s3_bucket.shard["a"]
Removed aws_s3_bucket.shard["b"]
Successfully removed 2 resource instance(s).
```

It does write a forced backup, which the `removed` block does not. See section 10 for why that consolation is smaller than it sounds.

---

## 6. `import`: adopt what already exists

Import runs the workflow backwards. Infrastructure exists first, and configuration and state have to be made to describe it.

Since **Terraform 1.5** the supported way is a configuration block, and the three reasons given for it are the same three from section 2 in different clothes. It is **safer**, because the import goes through plan. It **works in CI**, because nothing is typed at a terminal. And it can **generate a first draft** of the configuration.

An import needs **two** things, not one:

1. an **`import` block** naming the object and the address it should occupy;
2. a **`resource` block at that address**, because an address in state with no matching block is the destroy case from section 1.

```hcl
import {
  to = aws_s3_bucket.legacy
  id = "ch16-legacy-notes"
}

resource "aws_s3_bucket" "legacy" {
  bucket = "ch16-legacy-notes"
}
```

### `id` is provider-specific, and `identity` exists for a reason

There is no general rule for `id`. A Docker container wants a full SHA256, an S3 bucket wants its name, an IAM role wants its name rather than its ARN, and an `aws_security_group_rule` wants the five-field composite `sg-04c74100cc8b9fc8c_ingress_tcp_8080_8080_0.0.0.0/0`, which the provider assembles itself and nothing about the resource block hints at. Every import page says the same thing: ask the provider's documentation.

Terraform **1.12** added an alternative, `identity`, mutually exclusive with `id`. [The import overview](https://developer.hashicorp.com/terraform/language/import) explains why it is not a stylistic choice:

> "Terraform uniquely identifies resources according to **either the ID assigned by the cloud provider or a collection of specific attributes defined by the provider**."

Its own example is the argument. An AWS `s3_bucket` identity is three attributes — `account_id`, `bucket`, `region` — because a bucket name is not unique on its own, and the same name in another account or region is a different object. An `aws_instance` ID already is globally unique, so `id` suffices there. Structured identity exists for objects whose identity is genuinely compound.

What each accepts is settled by the [block reference](https://developer.hashicorp.com/terraform/language/block/import). `id` takes *"a string or an expression that evaluates to a string"* whose value must be **known during the plan operation**, so a variable, a local or `each.value` are all legal and another managed resource's attribute is not, because that is `(known after apply)`. `identity` is an object of key-value pairs rather than a string.

### The defaults trap, measured

This is the part that bites, and it bites in both directions.

For the lab a bucket was created outside Terraform with two tags and versioning enabled, then adopted with a **minimal** resource block naming only `bucket`. Measured on **v1.15.8** with AWS provider **v6.61.0**:

```text
  # aws_s3_bucket.legacy will be updated in-place
  # (imported from "ch16-legacy-notes")
  ~ resource "aws_s3_bucket" "legacy" {
        id                          = "ch16-legacy-notes"
      ~ tags                        = {
          - "managed_by" = "nobody" -> null
          - "owner"      = "platform-team" -> null
        }
      ~ tags_all                    = {
          - "managed_by" = "nobody" -> null
          - "owner"      = "platform-team" -> null
        }
        ...
    }

Plan: 1 to import, 0 to add, 1 to change, 0 to destroy.
```

The adoption would succeed and then immediately **strip both tags**, because the configuration did not mention them and Terraform substitutes the schema default for anything you leave out. The rule from [Import a single resource](https://developer.hashicorp.com/terraform/language/import/single-resource):

> "You should include provider-specific resource arguments that have **non-default values** to prevent Terraform from destroying the imported resource on the next apply operation. **Terraform uses default values for arguments you do not include in the resource block.**"

Add the tags and the plan comes out clean:

```text
Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.
```

```text
aws_s3_bucket.legacy: Importing... [id=ch16-legacy-notes]
aws_s3_bucket.legacy: Import complete [id=ch16-legacy-notes]

Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.
```

!!! danger "Read the second number, not the first"
    `1 to import` on its own tells you nothing. The three shapes to recognise:

    | Plan | Meaning |
    |---|---|
    | `1 to import, 0 to add, 0 to change, 0 to destroy` | ✅ a clean adoption |
    | `1 to import, 0 to add, 1 to change, 0 to destroy` | ⚠️ Terraform will modify the object right after adopting it |
    | `1 to import, 1 to add, 0 to change, 1 to destroy` | ❌ Terraform will adopt the object and then **replace** it |

    The third is not hypothetical. In HashiCorp's own import tutorial it is where a naive adoption lands, because a generated `env = null` on an attribute that forces replacement produced exactly that plan, with the plan itself printing `# Warning: this will destroy the imported resource`.

    And nothing in a `~ update in-place` tells you whether the change is safe. The tutorial says so outright: *"Provider documentation may not indicate if a change is safe. You must understand the lifecycle of the underlying resource."* The same symbol covers a harmless default being written into state and a database being restarted.

### Generating a draft

Write only the `import` block, leave the `resource` block out, and `terraform plan -generate-config-out=FILE` writes a first draft. Measured:

```text
$ terraform plan -generate-config-out=generated.tf

aws_s3_bucket.legacy: Preparing import... [id=ch16-legacy-notes]
aws_s3_bucket.legacy: Refreshing state... [id=ch16-legacy-notes]

Terraform will perform the following actions:

  # aws_s3_bucket.legacy will be imported
  # (config will be generated)
    resource "aws_s3_bucket" "legacy" {
        acceleration_status         = null
        arn                         = "arn:aws:s3:::ch16-legacy-notes"
        bucket                      = "ch16-legacy-notes"
        ...
    }

Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.

Warning: Config generation is experimental
```

Note the plan line: the resource is rendered with **no action symbol at all**, because a pure import proposes no infrastructure action and there is nothing to mark. That is a fifth rendering after `+`, `-`, `~`, `-/+`, and the `.` forget marker from section 5.

The generated file for this bucket:

```hcl
# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "ch16-legacy-notes"
resource "aws_s3_bucket" "legacy" {
  bucket              = "ch16-legacy-notes"
  bucket_namespace    = "global"
  force_destroy       = false
  object_lock_enabled = false
  region              = "us-east-1"
  tags = {
    managed_by = "nobody"
    owner      = "platform-team"
  }
  tags_all = {
    managed_by = "nobody"
    owner      = "platform-team"
  }
}
```

It is a draft, not an answer. `force_destroy`, `object_lock_enabled` and `region` are defaults, and `tags_all` is a **computed** attribute that has no business in a configuration file. The pruning target is the same one the hand-writing rule arrives at from the opposite direction: **name exactly the arguments whose values differ from the provider's defaults, no more and no fewer.** Here that is `bucket` and `tags`.

!!! danger "Configuration generation is still experimental, and nothing that uses it says so"
    From [Generate configuration](https://developer.hashicorp.com/terraform/language/import/generate-configuration), on a page banner-versioned v1.15.x:

    > "**Experimental:** Configuration generation is available in Terraform **v1.5 as an experimental feature**. Later minor versions may contain changes to the **formatting of generated configuration** and **behavior of the `terraform plan` command using the `-generate-config-out` flag**."

    Every run prints `Warning: Config generation is experimental` beside the plan. The **`import` block itself is not experimental**. Only the generation is, and the distinction matters because config-driven import is otherwise the recommended path. Fine for a one-off adoption you review by hand. Do not build tooling on the output format.

!!! warning "The file may not be overwritten, and a failed run still writes it"
    Measured on **v1.15.8**, re-running the identical command:

    ```text
    Error: Target generated file already exists

    Terraform can only write generated config into a new file. Either choose a
    different target location or move all existing configuration out of the
    target file, delete it and try again.
    ```

    That is a property of the flag rather than of the command, and `terraform query` behaves the same way. It collides badly with the documented fact that a generation which **errors**, on a resource whose schema has mutually exclusive arguments say, *"still generates configuration and writes it to `generated.tf`"*. So a failed generation leaves a file behind, and the retry then fails for a completely different reason. Edit the file in place, or delete it before regenerating.

    One more trap for adoption work in an empty repository. If the configuration contains no other resources for that provider you must add a `provider` block explicitly, and adding one costs a re-`init`.

### `for_each`, aliases, and modules

Three things the `import` block accepts that the tutorials never show.

**`for_each`** (Terraform and OpenTofu **1.7**) adopts an estate from one block. Measured in the lab, re-adopting two buckets after a `state rm`:

```hcl
resource "aws_s3_bucket" "shard" {
  for_each = toset(["a", "b"])
  bucket   = "ch16-shard-${each.key}"
}

import {
  for_each = toset(["a", "b"])
  to       = aws_s3_bucket.shard[each.key]
  id       = "ch16-shard-${each.key}"
}
```

```text
Apply complete! Resources: 2 imported, 0 added, 0 changed, 0 destroyed.
```

Driving the destination resource's own `for_each` from the same expression is what keeps the addresses aligned. The reference's second example goes further, looping over a list of objects into *module* instances with `to = module.group[each.value.group].aws_s3_bucket.this[each.value.key]`. A module instance key and a resource instance key in one address, both computed. That is the shape adopting a real estate takes.

**A `provider` alias**, which is how you import an object the default provider configuration cannot see:

```hcl
import {
  provider = aws.europe
  to       = aws_instance.example
  id       = "i-abcd1234"
}
```

That is the correct fix for the wrong-region problem in section 8, where a misconfigured provider reports a running instance as deleted.

**A `module.` prefix** on `to`, so the destination `resource` block can live in a child module while the `import` block stays in the root.

### Leave the block in

```text
$ terraform plan     # after the import has been applied
No changes. Your infrastructure matches the configuration.
```

Measured: the second plan does not even print a `Preparing import...` line.

> "Because the import block is **idempotent**, applying an import action and running another plan does not generate another import action as long as that resource remains in your state. Furthermore, attempting to import a resource into the same address more than once **has no impact**."

Terraform records that it *imported* the resource and did not create it, so the block costs nothing on every later plan and is the only thing in the configuration distinguishing an adopted resource from a created one. Both import pages recommend keeping it *"as a record of the resource's origin for future module maintainers"*, and the recommended placement is either one `imports.tf` for a bulk adoption you intend to delete, or the block beside its destination `resource` block when you intend to keep it.

### Bulk adoption: `list` blocks and `terraform query`

Every tutorial in this space does discovery by hand, with `docker inspect --format="{{.ID}}"` or `aws ec2 create-security-group` followed by `echo $SG_ID`. Terraform **1.14** replaced that step with a query language, and no HashiCorp tutorial covers it.

```hcl
# queries.tfquery.hcl
list "aws_instance" "prod" {
  provider = aws
  limit    = 50

  config {
    region = "us-east-2"
    filter {
      name   = "tag:Name"
      values = ["prod-*", "staging-*"]
    }
  }
}
```

Two labels like a `resource` block, for the type queried and a local name. `provider` is **required**. `config` is provider-specific, `filter` included. `include_resource` defaults to `false`, so only identities come back unless you need attributes. `limit` defaults to 100 per block and is a **hard stop rather than a filter** — *"when the number of results reaches the specified limit, Terraform breaks the connection to the provider and stops reporting results"* — so raising it is how you find out whether you were seeing everything. `list` blocks are legal **only in `.tfquery.hcl` files**, and they take `count`, `for_each`, `variable` and `locals`, so one query file is reusable across accounts.

!!! warning "`-generate-config-out` is a flag on two commands and they do different jobs"
    | Command | Input | Generates |
    |---|---|---|
    | `terraform plan -generate-config-out=…` | `import` blocks **you wrote** | the missing `resource` blocks |
    | `terraform query -generate-config-out=…` | `list` blocks | **both** `resource` and `import` blocks, identities included |

    Two operational traps carry across both. The output file is written **to the local workstation even when connected to HCP Terraform**, so remote execution does not remove the local step. And the refuse-to-overwrite rule above applies to both.

On HCP Terraform there is one more payoff: *"HCP Terraform uses resource identities to determine when resources are managed by another workspace."* That is the guard against a bulk import quietly adopting something another team already owns, which is Chapter 9's one-to-one mapping broken in the least visible way possible, two states over one object with neither aware.

!!! warning "Take syntax from the workflow pages, not the block references"
    The `import` and `list` block reference pages carry six and seven defects respectively: examples that do not parse, `count` written inside a `config` block, an Azure resource declared with `provider = aws`, summary boxes contradicting their own prose. The argument tables and behavioural sentences are authoritative; the samples are unproofread.

### What adopting commits you to

!!! danger "Import hands Terraform the whole lifecycle, destruction included"
    The lab's bucket was created by hand and adopted by Terraform. Running `terraform destroy` at the end of the lab deleted it, because after an import there is no longer any difference between an object Terraform created and one it adopted.

    Import also reads only what the provider reports. It cannot tell you the infrastructure's **health**, its **intent**, or anything out of band such as the contents of a container's filesystem. Adoption never tells you whether the thing you just adopted is the thing you wanted.

---

## 7. Splitting one state into two

Chapter 15 kept deferring the question of how many state files you should have, and Chapter 24 answers it. This section answers the narrower operational one: given that you have decided to split, how do the stateful resources get across without being destroyed?

[Refactor Terraform state](https://developer.hashicorp.com/terraform/language/state/refactor) is the guide, and its one-line rule is worth keeping. **Refactoring means updating the configuration and the state files together.** Neither alone.

It splits resources by kind before giving any procedure:

- **Stateless resources** — recreate them in the new configuration, if that costs no downtime and no money.
- **Stateful resources** such as databases and object stores — usually cannot be deleted and recreated, and backup-and-restore is complex and expensive. Move them between state files instead.

And it gives two ways to move them, with a clear ranking:

| Approach | Minimum version | Status |
|---|---|---|
| `removed` + `import` blocks | Terraform **1.7** | **Recommended.** The blocks *"help keep a record of the configuration history."* |
| `terraform state mv -state/-state-out` | Terraform **1.0** | *"This is a legacy command."* |

### The recommended route, measured end to end

Two configurations, `source/` and `dest/`, and a bucket moving from one to the other.

**Back up first.** The section index for manual state changes makes this instruction unconditional, and it is the one that fits here:

```shell
terraform state pull > customer-split.backup.tfstate
```

!!! warning "Do not use the docs' own backup filename"
    HashiCorp's example writes to `terraform.tfstate.backup`, which is exactly the filename the **local backend** uses for its own automatic backup of the previous state. On a local backend that command overwrites Terraform's backup with yours. Pick any other name.

    And note what `state pull` actually gives you. It *"upgrades the local copy to the latest state file version"* on the way out, so a file written by 1.9.0 comes back stamped `1.15.8` with a `check_results` field materialised that the older format never had. `serial` and `lineage` survive, which is what keeps the pull-edit-push loop legal, but the result is a **format-upgraded** copy rather than the bytes the backend holds.

**Find the ID** the destination will import by:

```shell
terraform state show aws_s3_bucket.customer_data
```

**In the source configuration**, replace the `resource` block with a `removed` block:

```hcl
removed {
  from = aws_s3_bucket.customer_data

  lifecycle {
    destroy = false
  }
}
```

```text
 # aws_s3_bucket.customer_data will no longer be managed by Terraform, but will not be destroyed
 # (destroy = false is set in the configuration)
 . resource "aws_s3_bucket" "customer_data" {
        id                          = "ch16-split-customer-data"

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

**In the destination configuration**, add the `resource` block and an `import` block:

```hcl
resource "aws_s3_bucket" "customer_data" {
  bucket = "ch16-split-customer-data"
}

import {
  to = aws_s3_bucket.customer_data
  id = "ch16-split-customer-data"
}
```

```text
aws_s3_bucket.customer_data: Importing... [id=ch16-split-customer-data]
aws_s3_bucket.customer_data: Import complete [id=ch16-split-customer-data]

Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.
```

**Verify.** This is the point of the exercise, and it is not optional:

```text
$ terraform plan     # in dest/
No changes. Your infrastructure matches the configuration.

$ terraform plan     # in source/
No changes. Your infrastructure matches the configuration.
```

An **empty plan on both sides** is the proof the migration worked. Anything else means one side still believes something the other side does not. The docs add two steps most people skip: open pull requests for both repositories, and if your review process produces a speculative plan, check that too.

### Before you split, find what you are about to sever

Splitting breaks references. Move the network resources into their own state and the compute that referenced `aws_vpc.main.id` can no longer reach it. `terraform graph` is the suggested way to see the edges you are about to cut before you cut them.

The replacement for a severed reference should be **dynamic**, never a hard-coded value, and the docs rank the three options in a deliberate order:

1. **A resource-specific data source**, if the provider has one.
2. **`tfe_outputs`**, on HCP Terraform or Terraform Enterprise.
3. **`terraform_remote_state`**, for any other backend.

That ordering is the security argument from Chapter 15 in a different setting. Reading one output through `terraform_remote_state` requires credentials that can read the **entire** state snapshot of the configuration you are reading from.

### The legacy route, and the one thing it can do that blocks cannot

```shell
terraform state mv -state source.tfstate -state-out destination.tfstate \
  aws_instance.example aws_instance.example
```

On a remote backend this needs a `state pull` on each side first and a `state push` on each side afterwards, and the docs warn that it *"does have some risk of corrupting your remote state"*. A shorter form run from the source directory leaves the source state implicit:

```shell
terraform state mv -state-out=../terraform.tfstate aws_instance.example_new aws_instance.example_new
```

!!! warning "`state mv` moves state and leaves the configuration behind"
    *"The move command will update the resource in state, but not in your configuration file."* So a successful move leaves the destination exactly one plan away from undoing it:

    ```text
      # aws_instance.example_new will be destroyed
      # (because aws_instance.example_new is not in configuration)
    Plan: 0 to add, 0 to change, 1 to destroy.
    ```

    That is section 1's diagnostic line again, produced this time by an operation whose entire purpose was to preserve the object. The fix is manual: paste the `resource` block into the destination configuration, then the next plan is empty.

Reproduced in the lab within a single state file, which is enough to show the shape. Measured on **v1.15.8**:

```text
$ terraform state mv 'aws_s3_bucket.archive["cold"]' 'aws_s3_bucket.archive["frozen"]'
Move "aws_s3_bucket.archive[\"cold\"]" to "aws_s3_bucket.archive[\"frozen\"]"
Successfully moved 1 object(s).

$ terraform plan
  # aws_s3_bucket.archive["cold"] will be created
  # aws_s3_bucket.archive["frozen"] will be destroyed
Plan: 1 to add, 0 to change, 1 to destroy.
```

No preview, no prompt, and a plan afterwards that undoes the move. The one thing this command does that `moved` cannot is **cross a state file boundary**, and the web reference does not even mention it in prose. Only `terraform state mv -help` leads with it:

> "This command can also move to a destination address in a **completely different state file**… it can also be used for **refactoring one configuration into multiple separately managed Terraform configurations**."

!!! danger "Quote the flag on PowerShell"
    PowerShell splits an unquoted `-flag=value` into separate arguments. Write `-state source.tfstate` in the space form, or quote the pair. The same applies to `-backup`, where the consequence is a backup written somewhere other than where you meant.

    The address quoting the docs give for PowerShell is also wrong on PowerShell 7. `'aws_s3_bucket.archive[\"cold\"]'` fails, because single quotes are already literal there and the backslashes reach Terraform, which runs the address through the HCL parser and answers `Error: Invalid character`. Plain single quotes around real double quotes is the form that works.

---

## 8. Drift: detect, then choose

**Drift** is infrastructure that changed outside Terraform, so state no longer matches reality.

The first thing to know is that you are already detecting it. Every `plan`, `apply` and `destroy` runs an **implicit in-memory refresh** before doing anything else, so an ordinary plan already sees drift and already proposes to undo it. There is no detection step to add.

The second is that drift is a **symptom**. Infrastructure rarely changes itself. TID Ch 6 §6.6 sorts the causes on two axes, machine versus human and accidental versus intentional:

- **Accidental manual changes.** Wrong account, wrong command. Treat it as a systems problem rather than an individual's fault: restrict production access, enforce CI/CD. These are the easiest to fix, because a plain `terraform plan` usually works out exactly how to restore the intended state.
- **Intentional manual changes.** Someone fixed an outage by hand. Harder, because the change was *wanted* and the next Terraform run will revert it. Until the change is in code, **it is not safe to run Terraform at all**.
- **Conflicting automated changes.** New machine images, an orchestrator adding tags, autoscaling running at a different count, an RDS minor-version bump in a maintenance window. None are errors. `ignore_changes` exists mainly for this.
- **Terraform's own errors.** A crash before state was saved, a mid-run credential expiry, a corrupted write. The dangerous shape is a resource that was **created but never recorded**, so the next run plans to create it again. What follows depends on the resource: a genuine duplicate where the provider allocates the identifier, or a hard failure where the name must be unique. Measured on the emulator, dropping a bucket's entry and re-applying gives the second outcome, `Error: creating S3 Bucket (ch16-dup-demo): BucketAlreadyExists`. Neither is recoverable by re-running.

### `plan -refresh-only`: see it without acting on it

```text
$ terraform plan -refresh-only

Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform since the
last "terraform apply" which may have affected this plan:

  # aws_s3_bucket.site has changed
  ~ resource "aws_s3_bucket" "site" {
        id                          = "ch16-drift-site"
      ~ tags                        = {
          ~ "owner" = "platform-team" -> "oncall-hotfix"
        }
      ...
    }

This is a refresh-only plan, so Terraform will not take any actions to undo
these.
```

The **verb tense is the fastest way to tell the two kinds of plan apart**. A refresh-only plan reports the past, `has changed`, where a normal plan reports intent in the future: `will be updated in-place`.

!!! note "The exact wording moved between versions"
    HashiCorp's drift tutorial transcript reads `# aws_instance.example has been changed`. Measured on **v1.15.8** the line is `# aws_s3_bucket.site has changed`, and the surrounding note has gained a clause: *"since the last `terraform apply` **which may have affected this plan**"*. Same mechanism, shorter sentence. If you are matching on these strings in tooling, they are not stable across releases.

### The three answers

At this point you have a decision, and only you can make it.

**Revert.** Run a plain `terraform apply`. Measured on the same drift:

```text
  # aws_s3_bucket.site will be updated in-place
  ~ resource "aws_s3_bucket" "site" {
      ~ tags = {
          ~ "owner" = "oncall-hotfix" -> "platform-team"
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

Correct when the manual change was a mistake.

**Adopt into state.** Run `terraform apply -refresh-only` and confirm. Terraform prompts, which is the entire point of the flag:

```text
Would you like to update the Terraform state to reflect these detected changes?
  Terraform will write these changes to the state without modifying any real
  infrastructure. There is no undo. Only 'yes' will be accepted to confirm.
```

```text
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

!!! warning "The counters lie, and here is the measurement"
    `0 added, 0 changed, 0 destroyed` on an operation that demonstrably rewrote state. Measured on **v1.15.8** across that apply:

    | | `serial` |
    |---|---|
    | before `apply -refresh-only` | 1 |
    | after | 2 |

    And `terraform state show` afterwards reports `"owner" = "oncall-hotfix"`. The counters count **infrastructure actions**, and a state write is not one. Same behaviour as the `removed` block's `0 to destroy` in section 5.

    Note that adopting drift into state alone leaves the configuration still saying `platform-team`, so the *next* plain plan will propose reverting it. Accepting drift is a stopgap; the durable version is to change the configuration to describe the new reality, after which the plan is empty.

**Adopt into configuration.** Change the configuration to describe what is actually there, and import anything the manual change *created*. The ordering matters and is easy to get wrong: **import first, then apply**. Import writes state and never touches the object, so a manually-created security group must be imported before the reconciling apply, or that apply creates a *second* one and orphans the original. `0 to add, 1 to change, 0 to destroy` is the evidence the adoption worked.

**Keep it and stop planning against it.** `ignore_changes`, from Chapter 11. Correct for the conflicting-automation bucket, where the drift is expected and permanent.

!!! warning "Outputs drift too, and other configurations read them"
    A computed output over a drifted attribute is rewritten by the same refresh-only apply. Anything reading this state through `terraform_remote_state` then consumes drift it never asked for.

    The docs frame this both ways and both are right. The drift tutorial calls it a hazard; the refresh tutorial calls it a feature, because *"the `-refresh-only` mode allows you to **anticipate the downstream effects**"*. Same mechanism. The plan step is what turns the hazard into a preview.

### `terraform refresh` is deprecated, and the reason is not stylistic

```shell
terraform refresh
# is effectively an alias for
terraform apply -refresh-only -auto-approve
```

The [command reference](https://developer.hashicorp.com/terraform/cli/commands/refresh) deprecates it in its second sentence, and `-auto-approve` here is **always enabled and cannot be switched off**. There is no flag that makes `terraform refresh` prompt.

!!! danger "Misconfigured credentials can empty your state with no prompt"
    > "Automatically applying the effect of a refresh is risky. If you have **misconfigured credentials** for one or more providers, Terraform may be misled into thinking that all of the managed objects have been **deleted**, causing it to **remove all of the tracked objects without any confirmation prompt**."

    HashiCorp's own [refresh tutorial](https://developer.hashicorp.com/terraform/tutorials/state/refresh) stages exactly this, and it is worth running because it needs no broken credential. Create an instance in the provider's default region, then write one line of `terraform.tfvars`:

    ```hcl
    region = "us-west-2"
    ```

    Nothing is wrong with the instance. The provider is now looking somewhere that genuinely has no such object, and it answers honestly:

    ```text
    # aws_instance.server has been deleted
    - resource "aws_instance" "server" {
    ```

    The tutorial's instruction at this point is the only one of its kind in the collection: *"refreshing your state file would drop your resources, so **do not run the apply operation**."* That refusal is the lesson. `terraform refresh` would have done it unprompted, and the instance would have become unmanaged infrastructure nobody is tracking. Cleanup starts with `rm terraform.tfvars`, because removing the misconfiguration is a step rather than an afterthought.

    The correct fix if the object really is in another region is the `provider` alias on an `import` block from section 6, not a change to the default provider.

Two more facts about the deprecation, neither of which is on the reference page. `terraform refresh` is **not supported at all in workspaces using HCP Terraform as a remote backend**, while `-refresh-only` is, so on a `cloud` block the choice is already made for you. And the deprecation is explicitly not a removal: *"Though Terraform will continue to support the `refresh` subcommand in future versions, it is deprecated."* That is why it keeps reappearing in material written years apart, including in one page of HashiCorp's own State tutorial collection, which still reconciles an out-of-band delete with a bare `terraform refresh` and no warning at all.

The closing advice on the reference page goes one step further than "prefer the flag":

> "Wherever possible, **avoid using `terraform refresh` explicitly** and instead rely on Terraform's behavior of automatically refreshing existing objects as part of creating a normal plan."

Prefer *neither*. The ordinary answer to drift is a normal plan.

!!! note "A standalone refresh does have one remaining job"
    The `state` subcommands do not refresh. Anything you read through `terraform state list` or `terraform state show` is as stale as the last plan left it, which is the one gap the automatic refresh does not cover.

---

## 9. Replacement, targeting, and other blunt instruments

### `-replace`: rebuild one object on purpose

Sometimes the object is fine as far as the provider can tell and broken as far as you are concerned. A process crashed inside a running VM; the provider reports a healthy instance, because the instance *is* healthy at the layer the provider models.

[Recreate Resources](https://developer.hashicorp.com/terraform/cli/state/taint) states that boundary better than anything else in the docs:

> "When remote objects become damaged or degraded, such as when software running inside a virtual machine crashes but the virtual machine is still running, Terraform does not have no way to detect and respond to the problem. **This is because Terraform only directly manages the machine as a whole.**"

The double negative is theirs. An `apply` acts only on mismatches between object and configuration, and a crashed process is not a mismatch. So replacement is a manual instruction:

```text
$ terraform plan -replace=aws_s3_bucket.site

  # aws_s3_bucket.site will be replaced, as requested
-/+ resource "aws_s3_bucket" "site" {
      + acceleration_status         = (known after apply)
      ~ arn                         = "arn:aws:s3:::ch16-drift-site" -> (known after apply)
      ...
```

`as requested` is the plan distinguishing an operator-forced replacement from one the diff demanded. Measured on **v1.15.8**.

### `taint` is dead, `untaint` is not, and the asymmetry is the interesting part

`terraform taint` was deprecated in **0.15.2** in favour of `-replace`, and the reason given is a mechanism rather than a preference:

> "that approach is **deprecated in favor of the `-replace=...` option, which avoids the need to create an interim state snapshot with a tainted object**."

`taint` had to write state to record the intent, and the next apply acted on the mark. Two operations with a gap between them, which is the same flaw as the `state mv` race in section 2.

But **tainted is not only a command**. It is a **state field Terraform sets on its own** when it can infer that an object was left half-built:

> "Terraform automatically marks an object as 'tainted' if an error occurs during a **multi-step 'create' action**, because Terraform can't be sure that the object was left in a fully-functional state."

A failed provisioner is the common case, since a provisioner is a step of the create action. A tainted object plans as `# aws_instance.example is tainted, so must be replaced`, and it poisons everything downstream of it, not just itself.

That is why `terraform untaint` survives the deprecation. It answers a question `-replace` cannot, which is *Terraform thinks this is damaged and I disagree*. And you do not have to re-taint to change your mind back: if you later decide it was degraded after all, `apply -replace=` schedules the rebuild directly.

### `-target`: a subgraph, not a filter

The most-misused flag in the CLI. Its legitimate uses, in the docs' own words, are *"exceptional situations such as recovering from errors or mistakes, **or when Terraform specifically suggests to use it as part of an error message**"*. That last clause is the one case where reaching for it is following instructions rather than improvising.

The mechanical fact, stated in one sentence by HashiCorp's [targeting tutorial](https://developer.hashicorp.com/terraform/tutorials/state/resource-targeting):

> "**Resource targeting updates resources that the target depends on, but not resources that depend on it.**"

Targeting walks **upstream only**. The tutorial's measurement, on one configuration and one one-line change:

| Plan | Result |
|---|---|
| `terraform plan` | `8 to add, 0 to change, 8 to destroy` |
| `-target="random_pet.bucket_name"` | `1 to add, 0 to change, 1 to destroy` |
| `-target="module.s3_bucket"` | `4 to add, 0 to change, 4 to destroy` — the module **plus** the pet it depends on |

So a target is a **subgraph selection closed under "depends on" in one direction**, not a filter over the plan. Everything the target needs comes along; everything that needs the target is left stale.

!!! warning "Instance-level targeting gives no upstream precision at all"
    Targeting `aws_s3_object.objects[2]` planned the replacement of **all four** `random_pet.object_names` instances, because `objects[2] → object_names[2]` is not an edge Terraform has. `objects → object_names` is.

    This is Chapter 10's dependency-graph fact showing up as behaviour: edges are built between **resource** nodes, not between instance nodes. If your intent was to touch one object, an instance-level target achieves the opposite of blast-radius reduction.

Two consequences to plan around. The two warnings Terraform prints say different things: plan-time says `Resource targeting is in effect`, and apply-time says `Applied changes may be incomplete` and tells you to run `terraform plan` to see what is still pending. And a targeted apply leaves state **internally inconsistent rather than corrupt**. In the tutorial, one output described the new bucket name and another described the old bucket, every value correctly recorded, describing different moments. Always follow a targeted run with an untargeted apply. In that exercise the follow-up cost `7 to add, 7 to destroy`, so the partial apply deferred and fragmented the work rather than reducing it.

!!! info "OpenTofu — `-exclude` is the inverse, and the two families never mix"
    OpenTofu **1.9** added `-exclude`, the deny-list form, and **1.10** added `-target-file` and `-exclude-file`. When one resource is broken and you want to apply everything else, enumerating every *other* resource with `-target` is far worse than one `-exclude`.

    Any target-side option combined with any exclude-side option **fails at argument parsing**, before planning begins:

    ```text
    The target and exclude planning options are mutually-exclusive. Each plan
    must use either only the target options or only the exclude options.
    ```

    Verified in `internal/command/arguments/extended.go`. At 1.9 the check guarded only the two direct flags; 1.10 widened it to the two families on the same commit that added the file variants. The consequence for recovery work is that you cannot express "everything except X, but only within module Y" in one run. Terraform has neither flag, so this is an OpenTofu-only escape hatch and an OpenTofu-only constraint.

---

## 10. The CLI family, and the backup rule that has three holes

`terraform state` is six or seven subcommands sharing two rules that appear on none of the individual command pages.

| Subcommand | Writes state? | Preview? | Prompt? |
|---|---|---|---|
| `state list` | no | — | — |
| `state show` | no | — | — |
| `state mv` | **yes** | no | **no** |
| `state rm` | **yes** | no | **no** |
| `state replace-provider` | **yes** | **yes** | **yes** |
| `state pull` | no | — | — |
| `state push` | **yes** | no | no |

!!! warning "The family hub omits `state push` entirely"
    The [`terraform state` reference](https://developer.hashicorp.com/terraform/cli/commands/state) lists six subcommands, and `state push` is not among them, although it exists, has its own reference page, and sits in the sidebar next to `state pull`, which *is* listed. It is documented under *Disaster Recovery* instead. A reader navigating by the `terraform state` index will never learn that the one subcommand that **overwrites a whole state file** exists.

### Approval defaults are backwards from the risk

Three commands in this chapter write state, and each handles confirmation differently. Verified on **v1.15.8**:

| Command | Preview? | Prompt? |
|---|---|---|
| `state replace-provider` | Yes — lists every affected address | **Yes**, and with no terminal attached it aborts: `Error asking for approval: EOF` |
| `state mv` | No | No — it rewrites bindings immediately |
| `refresh` | No | **Impossible** — `-auto-approve` is always on and cannot be disabled |

The command that merely rewrites a source string asks first. The one that rebinds objects to new addresses does not. The one that can drop every tracked object on bad credentials cannot be made to ask. Remember which way round that is, and remember that `replace-provider` is the one that will hang a CI job unless you pass `-auto-approve`.

### `replace-provider` is the only all-or-nothing one

```shell
terraform state replace-provider hashicorp/aws registry.acme.corp/acme/aws
```

There is no address argument, so the unit of operation is **every resource bound to that provider source**. Nothing else in the family works that way. The real uses are a registry namespace change, a vendored fork, or a Terraform-to-OpenTofu move, where the plugin is the same but the source address recorded in state no longer matches what `required_providers` resolves.

### The forced backup, and where it does not reach

> "Note that backups for state modification **can not be disabled**. Due to the sensitivity of the state file, Terraform **forces** every state modification command to write a backup file. You'll have to remove these files manually if you don't want to keep them around."

Measured on **v1.15.8**: the file is `terraform.tfstate.<unix-timestamp>.backup`, and a real one from the lab is `terraform.tfstate.1787302875.backup`. The timestamp means successive operations do not overwrite each other, and none of them overwrites the local backend's own `terraform.tfstate.backup`. They **accumulate**, one full copy of a sensitive file per operation, and nothing prunes them.

!!! danger "Three state-writing paths that leave no backup at all"
    The guarantee is a property of the `terraform state` command family, not of the act of writing state.

    **`terraform state push` writes no backup.** Verified on v1.15.8 and confirmed in the source at that tag: `internal/command/state_push.go` has no backup handling, where `state_mv.go` threads a backup path through. The most destructive command in the family keeps no copy of what it replaced.

    **`removed` and `moved` blocks go through `apply`**, not through these commands, so nothing here protects the path this chapter otherwise recommends. That is precisely why the manual-state section index gives its "keep backups" instruction unconditionally.

    **`terraform untaint` modifies state and takes the lock**, but it is not a `state` subcommand. Its `-backup` is grouped with `-state` and `-state-out` as a **legacy, local-backend-only** option, so an `untaint` against a remote backend writes state with no automatic backup at all.

!!! warning "On a remote backend the backups still land on local disk"
    > "The Terraform state subcommands all work with remote state just as if it was local state. Reads and writes may take longer than normal as **each read and each write do a full network roundtrip**."

    And backups are *"still written to disk"*. So a `state mv` against an S3 backend leaves a complete plaintext copy of production state on whatever machine or CI runner ran the command. That is one more hole in everything Chapter 15 said about who can read state.

### Hand-editing, and the one legitimate way to do it

Editing `terraform.tfstate` in a text editor is the method of last resort, for cases like recovering a corrupted state. You lose Terraform's validation and repeatability, JSON is unforgiving, and a slip can drop a resource so Terraform recreates something that already exists.

!!! danger "If you genuinely must hand-edit state"
    Work through `terraform state pull` → edit → `terraform state push`, never on the backend's object directly. Then:

    - keep a **separate backup** before you start, under a filename the local backend does not use;
    - run the result through a **JSON validator**;
    - **diff** it against the backup to see exactly what you changed;
    - **increment `serial` by 1**, so the push passes the safety checks instead of needing `-force`.

    State files must be **UTF-8 without a byte order mark**. The docs' Windows advice is version-dependent and they do not say which PowerShell they mean. Measured here:

    | | piped into `Set-Content` | redirected with `>` |
    |---|---|---|
    | **PowerShell 7.6.5** | UTF-8, no BOM ✅ | UTF-8, no BOM ✅ |
    | **Windows PowerShell 5.1** | no BOM, but **ANSI** — `é` becomes `E9`, not `C3 A9` ⚠️ | **UTF-16LE with a `FF FE` BOM** ❌ |

    On 7 the advice is redundant. On 5.1 it only avoids the BOM, and `-Encoding UTF8` does not help because 5.1 writes UTF-8 *with* one. The reliable form there, verified:

    ```powershell
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))
    ```

---

## 11. Recovery: when state and the backend disagree

The [Disaster Recovery](https://developer.hashicorp.com/terraform/cli/state/recover) section is three sentences and three commands, and it exists for one scenario: *"an accident when performing other state manipulation actions"*. It is what all those forced backups are for.

**1. Unlock, if a run died holding the lock.**

> "You may need to unlock Terraform when a `terraform apply` or other process unexpectedly terminates before Terraform can release its lock on the state backend. Unlocking Terraform overrides protections that prevent two processes from modifying state at the same time. **We do not recommend unlocking until you determine what caused the lock to get stuck.**"

Diagnose first, unlock second. Chapter 15 covered `force-unlock` and the `LOCK_ID` nonce it demands, which is the structural enforcement of that sequencing: you can only get the ID from the error Terraform printed, so there is no blind-unlock form.

**2. Read** with `terraform state pull`, remembering it upgrades the format on the way out.

**3. Write** with `terraform state push`.

### What `state push` will and will not accept

Two safety checks, both reproduced on **v1.15.8**:

| Attempt | Result |
|---|---|
| Push lineage `bbbb…` over lineage `aaaa…` | `cannot import state with lineage "bbbb…" over unrelated state with lineage "aaaa…"` — exit 1 |
| Push `serial 2` over `serial 5` | `cannot import state with serial 2 over newer state with serial 5` — exit 1 |
| Either, with `-force` | Silent success, exit 0. The destination went from serial 5 to serial 2, a downgrade applied without a word. |

A successful push prints **nothing**. The only signal is the exit status.

!!! danger "Three cases where the checks never run, and no flag is needed to bypass them"
    Found in `statemgr.CheckValidImport` at tag `v1.15.8`, after the checks failed to fire on a first test:

    1. **The destination state is empty.** *"It's always okay to overwrite an empty state, regardless of its lineage/serial."* A state file with no resources counts.
    2. **The destination is a legacy state** with no lineage.
    3. **Same lineage, same serial, identical content** is allowed. Same lineage and serial with *different* content is the one remaining error.

    The practical form of the first: pushing into a workspace whose state has been emptied, say by a `destroy` or by an earlier bad push, is completely unguarded. The checks protect state that has something in it.

Chapter 15 covered the other recovery case, `errored.tfstate`, where the apply succeeded but persisting state to the backend failed. The rule there is worth restating because it is the one people get wrong under pressure: push the file, do **not** re-run apply first.

---

## 🧪 Lab

Six configurations, one operation each, in the order the chapter teaches them. Everything below was run end to end against the emulator on **Terraform v1.15.8** with **AWS provider v6.61.0**, plus **OpenTofu 1.12.5** for the last part. The configurations are committed at `labs/chapter16/`.

Start the emulator:

```shell
docker compose -f labs/docker-compose.yml up -d      # start the emulator on :4566
curl -s http://localhost:4566/_floci/health          # wait until the services read "running"
```

Set the lab environment once per shell:

```shell
source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"
```

```powershell
. "$(git rev-parse --show-toplevel)/labs/lab-env.ps1"
```

!!! warning "Emulation is not AWS"
    A green apply here proves your HCL and your workflow, not AWS fidelity. The emulator implements the S3 API well enough for every operation in this chapter, and it is not a substitute for validating a load-bearing configuration against real free-tier AWS. That matters more in this chapter than in most, because import IDs and identity attributes are **provider implementation details** and a composite ID format can differ between provider versions even against real AWS.

### Lab 1 — adopt a bucket nobody told Terraform about

Create something unmanaged, the way it happens in real life:

```shell
awslocal s3api create-bucket --bucket ch16-legacy-notes
awslocal s3api put-bucket-tagging --bucket ch16-legacy-notes \
  --tagging 'TagSet=[{Key=owner,Value=platform-team},{Key=managed_by,Value=nobody}]'
awslocal s3api put-bucket-versioning --bucket ch16-legacy-notes \
  --versioning-configuration Status=Enabled
```

In `labs/chapter16/lab1`, `imports.tf` holds an `import` block and nothing else. Generate a draft:

```shell
tflocal init
tflocal plan -generate-config-out=generated.tf
```

Read `generated.tf`. Every argument it emits is either required, a default, or computed. Now do the experiment the chapter describes: save it, then replace it with a **minimal** block naming only `bucket`, and plan again. You should see `1 to import, 0 to add, 1 to change, 0 to destroy` and a `~ tags` block that removes both tags. Add the `tags` argument back and the plan becomes `1 to import, 0 to add, 0 to change, 0 to destroy`.

```shell
tflocal apply
tflocal state list          # aws_s3_bucket.legacy
tflocal plan                # No changes — the import block is idempotent
```

Try re-running the generation with the file still present, to see `Error: Target generated file already exists`.

### Lab 2 — rename, and migrate `count` to `for_each`

`labs/chapter16/lab2` starts with `aws_s3_bucket.notes` and a two-instance `aws_s3_bucket.archive` under `count`.

```shell
tflocal init && tflocal apply
```

Rename the label from `notes` to `team_notes` and plan **without** a `moved` block. Read the `# (because aws_s3_bucket.notes is not in configuration)` line and the `1 to add, 1 to destroy` counters.

Before fixing it, prove section 1's claim for yourself. Save that plan, then **delete** the `notes` block entirely and save a second one:

```shell
tflocal plan -no-color > renamed.txt      # with the label renamed
# now delete the resource block instead, and:
tflocal plan -no-color > deleted.txt
diff deleted.txt renamed.txt
```

```powershell
Compare-Object (Get-Content deleted.txt) (Get-Content renamed.txt)
```

Measured here, `Compare-Object` reports 44 differing rows: 43 on the renamed side, which are the `+ create` legend entry and the create block, and 1 on the deleted side, which is its counter line. The destroy block, reason line included, is identical in both and appears nowhere in the output.

Then add:

```hcl
moved {
  from = aws_s3_bucket.notes
  to   = aws_s3_bucket.team_notes
}
```

and confirm `has moved to` with `0 to add, 0 to change, 0 to destroy`.

For the second half, convert `archive` from `count` to `for_each` with the bucket names left unchanged, plan it bare to see `2 to add, 2 to destroy`, then add one `moved` block per index and watch the same plan go empty.

### Lab 3 — forget a bucket, then take it back

`labs/chapter16/lab3` creates `ch16-handover`. Replace the `resource` block with a **bare** `removed` block and plan. Do not apply: the plan says `1 to destroy`, which is the whole point of the exercise.

Add the `lifecycle` block, plan again, and look closely at three things: the empty symbol legend, the lone `.`, and the `Warning: Some objects will no longer be managed by Terraform`. Then apply and verify:

```shell
tflocal state list                                    # empty
awslocal s3 ls | grep ch16-handover                   # still there
```

Take it back with a `resource` block plus an `import` block, and confirm `Resources: 1 imported`.

`keytest.tf` in the same directory adds a `for_each` resource. Point a `removed` block at one instance to see `Error: Resource instance keys not allowed`, then use `terraform state rm` on the **bare** address and watch it take out both instances with no prompt at all.

### Lab 4 — split one configuration into two

`labs/chapter16/lab4/source` holds two buckets, and `ch16-split-customer-data` is moving to `lab4/dest`.

```shell
cd labs/chapter16/lab4/source
tflocal init && tflocal apply
tflocal state pull > customer-split.backup.tfstate    # not terraform.tfstate.backup
tflocal state show aws_s3_bucket.customer_data        # find the id
```

Replace the resource block with `removed` and `destroy = false`, apply, then in `dest/` add the resource block plus an `import` block and apply there. Finish with the step that is the actual deliverable:

```shell
cd ../dest && tflocal plan     # No changes.
cd ../source && tflocal plan   # No changes.
```

Two empty plans is the proof. Anything else means one side still believes something the other does not.

### Lab 5 — manufacture drift and answer it three ways

`labs/chapter16/lab5` creates a bucket tagged `owner = platform-team`. Change it behind Terraform's back:

```shell
awslocal s3api put-bucket-tagging --bucket ch16-drift-site \
  --tagging 'TagSet=[{Key=owner,Value=oncall-hotfix}]'
```

Then run all three answers in turn and read the differences:

```shell
tflocal plan -refresh-only     # "has changed" — past tense, no action proposed
tflocal plan                   # "will be updated in-place" — the revert
tflocal apply -refresh-only    # accept it into state; note the counters say 0/0/0
```

To see that the counters are lying, read `serial` before and after the refresh-only apply:

```shell
tflocal state pull | python -c "import sys,json; print(json.load(sys.stdin)['serial'])"
```

It went 1 → 2 in the measurement above while the apply reported `0 added, 0 changed, 0 destroyed`. Finish by editing the configuration to say `oncall-hotfix`, which is the durable form of adopting drift, and confirming the plan is empty.

### Lab 6 — the same forget under OpenTofu

`labs/chapter16/opentofu` is one bucket with `lifecycle { destroy = false }` on the resource itself. Run it with `tofu`:

```shell
TF_CMD=tofu tflocal init
TF_CMD=tofu tflocal apply
TF_CMD=tofu tflocal destroy
```

Two things to notice. The `removed`-block plan under OpenTofu prints `. forget` in the symbol legend and counts `1 to forget` as a fifth counter, where Terraform prints an empty legend and `0 to destroy`. And the resource-level `destroy = false`, which Terraform 1.15.8 rejects as an unsupported argument, makes `tofu destroy` **forget rather than delete** and then exit non-zero with `Destroy was successful but left behind forgotten instances`.

### Clean up

```shell
tflocal destroy     # in each lab directory
```

Every lab's `destroy` is worth running deliberately rather than skipping, because in labs 1 and 3 it deletes a bucket Terraform did not create. That is section 6's commitment, arriving.

---

## Common pitfalls

- **Writing a bare `removed` block when you meant to forget.** It destroys the object. `lifecycle { destroy = false }` is the whole operation, and the block's own documentation still opens by describing the safe behaviour as the default.
- **Getting the `moved` direction backwards.** `to` is the address in your configuration now; `from` is the one that has gone. Reversed, you get the destroy you were avoiding.
- **Declaring both resources during a `moved` migration.** Terraform rejects it. The rename is the edit to the existing block's label.
- **Deleting `moved` blocks too early.** The question is whether any state anywhere still holds the old address, not how long ago the change was. Published modules keep theirs forever, and chain them.
- **Importing with a minimal `resource` block.** Every argument you omit is silently the schema default. Measured here, that stripped two tags from a bucket on the very apply that adopted it.
- **Reading `1 to import` and stopping.** Read the other three counters. `1 to import, 1 to add, 0 to change, 1 to destroy` means Terraform is going to adopt the object and then replace it.
- **Treating generated configuration as finished.** It emits defaults and computed attributes, it is experimental, and a failed generation still leaves the file behind so the retry fails for a different reason.
- **Using `terraform refresh`.** It is `apply -refresh-only -auto-approve` with an auto-approve you cannot switch off, and misconfigured credentials turn it into a state-wipe with no prompt.
- **Believing the counters on a refresh-only or forget plan.** They count infrastructure actions. State was written anyway; check `serial`.
- **Reaching for `-target` to reduce blast radius.** It selects upstream only, computes dependencies per resource rather than per instance, and leaves state internally inconsistent until you run an untargeted apply.
- **Trusting the forced backup.** `state push` writes none, `untaint` on a remote backend writes none, and the `removed`/`moved` path goes through `apply` so it writes none either.
- **Backing up to `terraform.tfstate.backup`.** That is the local backend's own filename, and you will overwrite its copy with yours.
- **Splitting a state without checking both plans afterwards.** An empty plan on one side proves nothing.

---

## Exercises

1. Take any two-resource configuration you have applied. Rename one resource and plan. Now add a `moved` block and plan again. Write down which line in the first plan told you it was a rename rather than a deletion, and explain why Terraform could not tell.
2. Create an S3 bucket in the emulator with two tags and a non-default setting. Adopt it with a hand-written `resource` block naming **only** the bucket name. Predict the plan's four counters before you run it, then run it.
3. Repeat exercise 2 with `-generate-config-out`. Prune the generated file to a clean plan and list every line you deleted, sorted into "default", "computed" and "genuinely redundant".
4. Convert a `count`-based resource to `for_each` on a live state. Do it wrong first, with no `moved` blocks, and record what the plan proposes to destroy. Then do it right.
5. Forget a resource with `removed` and `destroy = false`, then bring it back. Write down the two artefacts that had to change on the way out and on the way in, and explain why one direction needs an `import` and the other does not.
6. Manufacture drift, then answer it three ways in three separate runs: revert, adopt into state, and adopt into configuration. Record the `serial` before and after each. Which of the three leaves the next plan empty?
7. Split a two-resource configuration into two directories using `removed` and `import`. Then break the migration deliberately: skip the `import` in the destination and run its plan. What does it propose, and why is that the most dangerous plan in this chapter?
8. Run the same `removed` and `destroy = false` plan under `terraform` and under `tofu`. List every difference in the output, and say which tool's version you would rather have in a pull request.

---

## Summary

State operations exist because an **address is an identity**, and identities change for reasons that have nothing to do with the infrastructure they name.

- Terraform loses the binding when you **rename** a resource, **move it to another module**, or **change its provider**. Usually destroy-and-recreate is the right answer; this chapter is for when it is not.
- `# (because X is not in configuration)` is the universal diagnostic. It means state holds an address configuration does not claim, and it looks identical whether you deleted, renamed, or forgot to commit a file.
- **Prefer configuration to the CLI**, for three separate reasons. `moved` renames state *before* the plan is computed. A block ships to every consumer where a command does not. And a block makes the rename part of the same apply, so there is no window in which a coworker's plan proposes a destroy.
- **`moved`** renames without destroying, migrates `count` to `for_each` one index at a time, cascades over a whole module call, and preserves **identity, not configuration**. A zero-destroy plan can still be a three-change plan.
- **`removed`** forgets without destroying, but only with `lifecycle { destroy = false }`. Bare, it destroys. It plans as a lone **`.`** under an empty symbol legend and `0 to destroy`, it refuses instance keys, and the only way back is an import.
- **`import`** needs two things, the block *and* a `resource` block at the same address, and its hard part is the configuration rather than the ID. Name exactly the arguments whose values differ from the provider's defaults. Read all four counters, not just `1 to import`. Generation is a draft and is still experimental.
- **Splitting a state** is `removed` plus `import` across two configurations, verified by an **empty plan on both sides**. `state mv -state-out` is the legacy route and the only one that crosses a state boundary in a single command.
- **Drift** is detected by every ordinary plan. `-refresh-only` reports it in the past tense and lets you accept it with a prompt; `terraform refresh` is the same operation with the prompt permanently disabled, and with bad credentials it removes every tracked object without asking. There are three legitimate answers, revert, adopt and ignore, and choosing is your job rather than Terraform's.
- **The counters count infrastructure actions.** Measured: `apply -refresh-only` reported `0 added, 0 changed, 0 destroyed` while `serial` went 1 → 2. OpenTofu is honest about the forget case and reports `1 to forget`; Terraform is not.
- **`-replace` for a degraded object, `-target` only for recovery.** Targeting walks upstream only and computes dependencies per resource, so instance-level targeting buys no precision at all.
- **Backups are forced only for `terraform state` subcommands.** `state push`, `untaint` on a remote backend, and the whole `removed`/`moved` path leave nothing behind, and on a remote backend the backups that *are* written land in plaintext on the local disk.

---

## What's next

You can now bring unmanaged infrastructure under Terraform, rearrange what you already manage without destroying it, and repair state when it and reality disagree. Chapter 17 goes back to the thing every one of these operations quietly depends on: **provider configuration**, including the aliases the `import` block takes, the meta-arguments that pass providers into modules, and how a provider gets its credentials in the first place.

Two threads from this chapter continue later. Refactoring **at scale** — the module-split shim, the migration sequencing, and what to do when a rename spans dozens of consumers — is Chapter 25. Deciding **how many state files you should have**, which is the structural answer to most of the operations here, is Chapter 24.

---

## References

**Reading notes:** [Update state manually](../sources/terraform-docs/tf-cli-state.md) · [`terraform state` commands](../sources/terraform-docs/tf-cmd-state.md) · [Resource addressing](../sources/terraform-docs/tf-resource-addressing.md) · [Move resources](../sources/terraform-docs/tf-cli-state-move.md) · [`state mv`](../sources/terraform-docs/tf-cmd-state-mv.md) · [`state pull`](../sources/terraform-docs/tf-cmd-state-pull.md) · [`state push`](../sources/terraform-docs/tf-cmd-state-push.md) · [`state replace-provider`](../sources/terraform-docs/tf-cmd-state-replace-provider.md) · [`state list`](../sources/terraform-docs/tf-cmd-state-list.md) · [`state show`](../sources/terraform-docs/tf-cmd-state-show.md) · [Recover state from backup](../sources/terraform-docs/tf-cli-state-recover.md) · [Recreate resources (taint)](../sources/terraform-docs/tf-cli-state-taint.md) · [`terraform untaint`](../sources/terraform-docs/tf-cmd-untaint.md) · [`terraform refresh`](../sources/terraform-docs/tf-cmd-refresh.md) · [Inspect state](../sources/terraform-docs/tf-cli-state-inspect.md) · [Refactor state](../sources/terraform-docs/tf-state-refactor.md) · [Remove a resource from state](../sources/terraform-docs/tf-state-remove.md) · [`removed` block](../sources/terraform-docs/tf-block-removed.md) · [`moved` block](../sources/terraform-docs/tf-block-moved.md) · [Refactor modules](../sources/terraform-docs/tf-modules-refactoring.md) · [Import overview](../sources/terraform-docs/tf-import.md) · [Import a single resource](../sources/terraform-docs/tf-import-single.md) · [Bulk import](../sources/terraform-docs/tf-import-bulk.md) · [Generate configuration](../sources/terraform-docs/tf-import-generate.md) · [`import` block](../sources/terraform-docs/tf-block-import.md) · [`list` block](../sources/terraform-docs/tf-block-list.md) · [OpenTofu `-exclude`](../sources/opentofu-docs/ot-exclude-flag.md)

**Tutorial notes:** [Import Terraform configuration](../sources/terraform-tutorials/tut-state-import.md) · [Manage resources in Terraform state](../sources/terraform-tutorials/tut-state-cli.md) · [Manage resource drift](../sources/terraform-tutorials/tut-resource-drift.md) · [Use refresh-only mode](../sources/terraform-tutorials/tut-refresh.md) · [Target resources](../sources/terraform-tutorials/tut-resource-targeting.md) · [Use configuration to move resources](../sources/terraform-tutorials/tut-move-config.md)

**Books:** TID Ch 6 §6.5–6.6 [Manipulating state, State drift](../books/tid/chapters/06-state-management.md) · TUR Ch 3 [State file isolation](../books/tur/chapters/03-manage-state.md)

**HashiCorp docs:** [Import resources](https://developer.hashicorp.com/terraform/language/import) · [Import a single resource](https://developer.hashicorp.com/terraform/language/import/single-resource) · [Generate configuration](https://developer.hashicorp.com/terraform/language/import/generate-configuration) · [`import` block](https://developer.hashicorp.com/terraform/language/block/import) · [`moved` block](https://developer.hashicorp.com/terraform/language/block/moved) · [`removed` block](https://developer.hashicorp.com/terraform/language/block/removed) · [Remove a resource from state](https://developer.hashicorp.com/terraform/language/state/remove) · [Refactor state](https://developer.hashicorp.com/terraform/language/state/refactor) · [Refactor modules](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) · [Manually update state](https://developer.hashicorp.com/terraform/cli/state) · [Resource addressing](https://developer.hashicorp.com/terraform/cli/state/resource-addressing) · [Move resources](https://developer.hashicorp.com/terraform/cli/state/move) · [Recreate resources](https://developer.hashicorp.com/terraform/cli/state/taint) · [Recover state from backup](https://developer.hashicorp.com/terraform/cli/state/recover) · [`terraform state`](https://developer.hashicorp.com/terraform/cli/commands/state) · [`terraform state mv`](https://developer.hashicorp.com/terraform/cli/commands/state/mv) · [`terraform state push`](https://developer.hashicorp.com/terraform/cli/commands/state/push) · [`terraform refresh`](https://developer.hashicorp.com/terraform/cli/commands/refresh)

**HashiCorp tutorials:** [Import Terraform configuration](https://developer.hashicorp.com/terraform/tutorials/state/state-import) · [Manage resources in Terraform state](https://developer.hashicorp.com/terraform/tutorials/state/state-cli) · [Manage resource drift](https://developer.hashicorp.com/terraform/tutorials/state/resource-drift) · [Use refresh-only mode](https://developer.hashicorp.com/terraform/tutorials/state/refresh) · [Target resources](https://developer.hashicorp.com/terraform/tutorials/state/resource-targeting) · [Use configuration to move resources](https://developer.hashicorp.com/terraform/tutorials/modules/move-config) · [Migrate CloudFormation templates to Terraform](https://developer.hashicorp.com/validated-patterns/terraform/migrate-from-cloudformation)

**OpenTofu docs:** [`tofu plan` targeting options](https://opentofu.org/docs/cli/commands/plan/)

**Topic page:** [State](../topics/state.md)

**🧪 Lab:** configurations at `labs/chapter16/` · [Floci Facts](../research-cache/floci-facts.md) · [MiniStack Facts](../research-cache/ministack-facts.md) · [LocalStack Facts](../research-cache/localstack-facts.md)
