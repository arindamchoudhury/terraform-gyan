# Configuration Syntax

> **Source:** [developer.hashicorp.com/terraform/language/syntax/configuration](https://developer.hashicorp.com/terraform/language/syntax/configuration)
> **Added:** 2026-07-08
> **Source updated:** undated language reference; captured 2026-07-08
> **Tags:** hcl, syntax, arguments, blocks, identifiers, comments, encoding
> **Type:** documentation

*Developer › Terraform › Configuration Language › Syntax › Configuration Syntax · v1.15.x*

> 📌 **Version note:** Captured against Terraform **1.15.x** (2026-07-08, see [[version-facts]]). This is the low-level native (HCL) syntax; it is stable and version-agnostic. Identical in OpenTofu.

This page describes the **lower-level native syntax** — the building blocks the higher-level constructs (resources, variables, outputs, etc.) are built from. The native syntax is defined in terms of **HCL**, the same language other HashiCorp products use. There is also a [JSON-equivalent syntax](https://developer.hashicorp.com/terraform/language/syntax/json) (`*.tf.json`) — harder to read, easier to machine-generate/parse. Full grammar lives in the HCL native syntax specification.

## Arguments and Blocks

Two key constructs: **arguments** and **blocks**.

### Arguments

An argument assigns a value to a name:

```hcl
image_id = "abc123"
```

Identifier before `=` is the **argument name**; the expression after is the **value**. The context (e.g. a resource type's schema) determines which value types are valid. Many arguments accept **arbitrary expressions** — literal, or computed from other values.

!!! note "“argument” vs “attribute”"
    HCL's own docs call this an **attribute**. Terraform docs say **argument** instead, because Terraform also has resource **attributes** (like `id`) that can be *referenced* in expressions but *not assigned* in configuration. The terms are interchangeable in casual use; the docs reserve "attribute" for the read-only referenceable kind.

### Blocks

A block is a container for other content:

```hcl
resource "aws_instance" "example" {
  ami = "abc123"

  network_interface {
    # ...
  }
}
```

- A block has a **type** (`resource` here).
- Each block type defines how many **labels** must follow the keyword. `resource` expects two: the resource type (`aws_instance`, provider-specific) and an arbitrary **name** (`example`). A block type may require any number of labels, or none — like the nested `network_interface`.
- The **body** is delimited by `{` … `}`; further arguments and blocks nest inside, forming a hierarchy.

**Top-level blocks** appear outside any other block. Most Terraform features (resources, input variables, outputs, data sources, …) are implemented as top-level blocks. Terraform uses a limited, fixed set of them.

## Identifiers

Argument names, block type names, and names of most Terraform constructs are **identifiers**.

- May contain letters, digits, underscores (`_`), and hyphens (`-`).
- First character **must not be a digit** (avoids ambiguity with literal numbers).
- Full rule: Unicode identifier syntax, extended to allow the ASCII hyphen `-`.

## Comments

Three comment syntaxes:

- `#` — single-line, to end of line. **Default/idiomatic style.**
- `//` — single-line alternative.
- `/* … */` — multi-line delimiters.

Auto-formatters (`terraform fmt`) rewrite `//` into `#`, since `//` is not idiomatic.

## Character Encoding and Line Endings

- Files **must be UTF-8**. Delimiters are ASCII, but non-ASCII is accepted in identifiers, comments, and string values.
- Accepts Unix (LF) **or** Windows (CRLF) line endings. Unix LF is idiomatic; auto-formatters convert CRLF → LF.

---
Related: [[provider-requirements]] — a concrete top-level `terraform`/`required_providers` block using this syntax. [[tf-aws-create]] — a real `resource "aws_instance"` block with two labels in action. Feeds learning-path **B4 — HCL language basics** (this page is B4's reference #1).
