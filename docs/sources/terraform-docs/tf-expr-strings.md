# Strings and Templates

> **Source:** [developer.hashicorp.com/terraform/language/expressions/strings](https://developer.hashicorp.com/terraform/language/expressions/strings)
> **Added:** 2026-07-14
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-14
> **Tags:** strings, heredoc, interpolation, template-directives, escape-sequences, whitespace-strip
> **Type:** documentation

String literals are the most complex and most-used literal. Two syntaxes: **quoted** and **heredoc**. Both support template sequences for interpolating values and manipulating text.

## Quoted Strings

Characters delimited by straight double-quotes: `"hello"`.

**Escape sequences** (backslash) in quoted strings:

| Sequence | Replacement |
|---|---|
| `\n` | Newline |
| `\r` | Carriage Return |
| `\t` | Tab |
| `\"` | Literal quote (without terminating the string) |
| `\\` | Literal backslash |
| `\uNNNN` | Unicode char, basic multilingual plane (4 hex digits) |
| `\UNNNNNNNN` | Unicode char, supplementary planes (8 hex digits) |

Two special escapes that use **no** backslash:

| Sequence | Replacement |
|---|---|
| `$${` | Literal `${`, without beginning an interpolation |
| `%%{` | Literal `%{`, without beginning a template directive |

## Heredoc Strings

Unix-shell-inspired multi-line string form:

```hcl
value = <<EOT
hello
world
EOT
```

A heredoc consists of:

- an opening sequence: a marker (`<<` or `<<-` — optional hyphen for indented heredocs), a delimiter word of your choosing, and a line break;
- the string contents, spanning any number of lines;
- the chosen delimiter word alone on its own line (indentation allowed for indented heredocs).

The `<<` marker + any identifier at line end starts it; Terraform reads lines until one consists entirely of that identifier. Convention: all-uppercase starting with `EO` ("end of"); `EOT` = "end of text".

!!! tip
    Don't use heredocs to generate JSON or YAML. Use `jsonencode` / `yamlencode` so Terraform guarantees valid syntax.

    ```hcl
    example = jsonencode({
      a = 1
      b = "hello"
    })
    ```

### Indented Heredocs

Standard `<<` treats all spaces as literal, so each line must sit flush with the left margin — awkward inside an indented block. The `<<-` variant fixes this:

```hcl
block {
  value = <<-EOT
  hello
    world
  EOT
}
```

Terraform finds the line with the fewest leading spaces and trims that many spaces from every line, giving:

```
hello
  world
```

### Escape Sequences in heredocs

Backslash sequences are **not** interpreted as escapes in a heredoc — the backslash is literal. Heredocs support only the two non-backslash specials, same as quoted strings:

| Sequence | Replacement |
|---|---|
| `$${` | Literal `${` |
| `%%{` | Literal `%{` |

## String Templates

Inside quoted and heredoc strings, `${` and `%{` begin template sequences — embedding expressions to build strings dynamically.

### Interpolation

`${ ... }` evaluates the expression, converts the result to a string if needed, and inserts it:

```hcl
"Hello, ${var.name}!"
```

→ `"Hello, Juan!"`.

### Directives

`%{ ... }` allows conditionals and iteration, like conditional and `for` expressions.

**`if` / `else` / `endif`** — chooses between two templates on a bool. The `else` may be omitted (result is empty string when false):

```hcl
"Hello, %{ if var.name != "" }${var.name}%{ else }unnamed%{ endif }!"
```

**`for` / `endfor`** — iterates a collection/structural value, evaluating the template once per element and concatenating. The name after `for` is the temporary loop variable:

```hcl
<<EOT
%{ for ip in aws_instance.example[*].private_ip }
server ${ip}
%{ endfor }
EOT
```

### Whitespace Stripping

Add a strip marker `~` immediately after the opening chars or before the end. It consumes all literal whitespace (spaces + newlines) before the sequence (marker at start) or after (marker at end) — lets you format directives readably without injecting stray whitespace:

```hcl
<<EOT
%{ for ip in aws_instance.example[*].private_ip ~}
server ${ip}
%{ endfor ~}
EOT
```

The newline after each directive is dropped, but the one after `server ${ip}` is kept — one line per element:

```
server 10.1.16.154
server 10.1.16.1
server 10.1.16.34
```

Recommendation: for template directives, always use the heredoc form and format over multiple lines. Quoted literals should usually contain only interpolation sequences.

---
Related: parent [[tf-expressions]]. Detailed form of the string literal from [[tf-expr-types]]. Directive `if`/`for` mirror the [[tf-conditionals]] ternary and (forthcoming) `for` expression semantics.
