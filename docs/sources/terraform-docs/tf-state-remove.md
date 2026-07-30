# Remove a resource from state

> **Source:** [developer.hashicorp.com/terraform/language/state/remove](https://developer.hashicorp.com/terraform/language/state/remove)
> **Added:** 2026-07-30
> **Source updated:** undated language how-to; captured 2026-07-30 against v1.15.x (latest)
> **Tags:** state, removed-block, destroy, state-rm, import, forget
> **Type:** documentation

*Developer › Terraform › Configuration Language › State › Remove a resource from state · v1.15.x*

The short how-to for the **forget** path: drop a resource from state and leave the real object running. Terraform stops managing that infrastructure's lifecycle. For the other direction — remove from state *and* destroy the object — the page sends you to [[tf-destroy-resource]].

This is also the one State page that states the semantics correctly on first reading. It never claims `removed` is inherently non-destructive; it makes `destroy = false` an explicit step. Compare [[tf-block-removed]], whose opening sentence contradicts its own `lifecycle` section.

## The procedure

1. Replace the `resource` block with a `removed` block.
2. Set `from` to the address of the resource being removed.
3. Add a `lifecycle` block with `destroy = false`.
4. Delete any references to the resource's attributes. `terraform validate` finds them.
5. Run `terraform apply` and confirm when prompted.

```hcl
removed {
  from = aws_instance.example

  lifecycle {
    destroy = false
  }
}
```

That example removes `aws_instance.example` from state without destroying it.

!!! danger "`destroy = false` is the whole point of step 3"
    The page says it plainly: "Setting `destroy` to `true` removes the resource from state and destroys it." Omitting the `lifecycle` block is not neutral either. Verified on v1.15.6 in [[tf-block-removed]]: a bare `removed` block plans `1 to destroy`.

!!! warning "`from` takes no instance keys"
    "You cannot include instance keys, such as `"aws_instance.example[1]"`, if the resource is configured to provision multiple instances."

    So `count`/`for_each` resources are all-or-nothing here — the `removed` block forgets every instance of the resource, not a chosen one. There is no documented way to forget a single instance with this block.

Step 4 is the same `terraform validate` trick [[tf-destroy-resource]] uses for deletions. A dangling `aws_instance.example.id` elsewhere in the configuration blocks the plan.

## `removed` block vs `terraform state rm`

Both remove a resource from state. The page names the CLI command and then recommends against it:

> "we recommend using the `removed` block instead. This is because the `removed` block lets you preview the results of the operation, which makes it a safer way to remove resources."

The reason is the plan step. `terraform state rm` mutates state immediately with no plan; the `removed` block goes through the normal plan/apply cycle, so you see the outcome before committing to it. [[tf-state]] lists `state rm` among the `terraform state` subcommands.

## Getting the resource back

Removal is not reversible by editing configuration. "If you want to resume managing the resource with Terraform, you must import the resource back into your configuration." That is the `import` block or `terraform import`, same as the destination half of [[tf-state-refactor]]'s migration.

---
Related: [[tf-block-removed]] — the block reference, the verified destroy-by-default behavior, and the version drift behind it. · [[tf-destroy-resource]] — the opposite path, plus the destroy-time-provisioner use of `removed`. · [[tf-state-refactor]] — uses exactly this `removed` + `destroy = false` step as the source-side half of a cross-configuration move. · [[tf-state]] — where `terraform state rm` sits in the state CLI.
