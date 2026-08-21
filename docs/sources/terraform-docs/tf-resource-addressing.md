# Resource Address Reference

> **Source:** [developer.hashicorp.com/terraform/cli/state/resource-addressing](https://developer.hashicorp.com/terraform/cli/state/resource-addressing)
> **Added:** 2026-08-21
> **Source updated:** undated CLI reference; captured 2026-08-21 against v1.15.x (latest)
> **Tags:** cli, resource-addressing, module-path, instance-index, count, for-each, state, targeting
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Resource Addressing · v1.15.x*

The grammar every state command, `-target` flag, `moved`/`removed`/`import` block and plan line is written in. It sits under *Manually Update State* ([[tf-cli-state]]) but is not about state — it is the shared notation, documented once and referenced everywhere.

## The two parts

> "A resource address is a string that identifies **zero or more** resource instances in your overall configuration."

```
[module path][resource spec]
```

Both halves are optional in the sense that omitting the module path means the root module. *Zero or more* is the operative phrase: an address is a **set**, and how big that set is depends on how much of it you leave off.

**Module path** — `module.module_name[module index]`, repeatable for nesting:

```
module.foo[0].module.bar["a"]
```

- `module` is the keyword marking a child module. Multiple keywords in one address mean nesting, not siblings.
- The index is optional and selects one instance of a `count`/`for_each` module call.
- `module.foo` alone "applies to every resource within the module… or **all instances** of a module if a module has multiple instances." `module.foo[0]` narrows to one instance's resources.

**Resource spec** — `resource_type.resource_name[instance index]`, the same shape one level down.

## Index values

- `[N]` — 0-based position, for `count`.
- `["INDEX"]` — string key, for `for_each`.

The rule underneath both is the one worth memorising:

!!! warning "Omitting the index is not shorthand for “the first one”"
    > "Omitting an index when addressing a resource where `count > 1` means that the address **references all instances**."

    So `aws_instance.web` with `count = 4` is four instances, and `module.foo` is every resource in every instance of that module. In a `-target` or a `state rm` that is the difference between one object and the whole set. This is the same behaviour [[tf-cmd-state-list]] shows from the other side, where filtering by a bare resource address returns all its instances — and the opposite of [[tf-cmd-state-show]], which rejects anything that does not resolve to exactly one.

That contrast is the page's own caveat made concrete:

> "In some contexts Terraform might allow for an **incomplete resource address**… the meaning depends on the context, so you'll need to refer to the documentation for the **specific feature** you are using which parses resource addresses."

**There is one grammar and several parsers.** That sentence is the missing explanation for an asymmetry this project recorded from the block references without a reason attached: `import`'s `to` accepts an instance key, `moved` accepts them on both sides, and `removed`'s `from` rejects them outright ([[tf-block-removed]], [[tf-block-moved]], [[tf-block-import]]). Nothing in the address grammar forbids any of it — each feature decides what completeness it demands.

## Version rules

Two behaviours here are old enough to be invisible, and both changed the meaning of an unchanged address:

- **Module indexes require v0.13+.** Before that a module could not have multiple instances, so there was nothing to index.
- **A bare resource spec means the root module only, since v0.12.** In earlier versions the same address "would match resources with the same type and name in **any descendant module**." A pre-0.12 `terraform taint aws_instance.web` could therefore reach into a child module; the identical command today cannot.

## The examples

`count` — given `count = 4` on `aws_instance.web`:

```
aws_instance.web[3]   # only the last instance
aws_instance.web      # all four
```

`for_each` — given a `tomap({...})` with keys `terraform`, `resource`, `indexing`, `example`:

```
aws_instance.web["example"]
```

## Page flaws

**"a alphanumerical key index"** understates what `for_each` keys can be. They are arbitrary strings, and HashiCorp's own `for_each` page keys a set on `subnet-012345` ([[tf-meta-for-each]]) — an address of `aws_instance.server["subnet-012345"]`, which is not alphanumeric. The quoting in the grammar is doing the real work, which is why [[tf-cmd-state-show]] has to spend a section on shell escaping.

**The `for_each` example conflates the instance with its value** — the address "refers to only the `example` instance… and **resolves to** `value4`". An address resolves to an instance; `value4` is that instance's `each.value`. Harmless here, misleading if read as a rule.

---
Related: [[tf-cli-state]] — the section this page sits in, though addressing is used far outside it. · [[tf-cmd-state-list]] — a bare address filters to all instances, this page's rule in the field. · [[tf-cmd-state-show]] — the opposite parser: one instance or an error, plus the shell quoting the string keys force. · [[tf-meta-for-each]] / [[tf-meta-count]] — where the two index forms come from, and the key-versus-position argument. · [[tf-block-moved]] · [[tf-block-import]] · [[tf-block-removed]] — three parsers of this grammar that disagree about instance keys, which the *incomplete address* caveat here explains.
