# Built-in Functions

> **Source:** [developer.hashicorp.com/terraform/language/functions](https://developer.hashicorp.com/terraform/language/functions)
> **Added:** 2026-07-15
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-15
> **Tags:** functions, built-in-functions, provider-defined-functions, terraform-console, stacks, function-catalogue
> **Type:** documentation

The Terraform language includes built-in functions callable from expressions to transform and combine values. Call syntax is a name followed by comma-separated arguments in parentheses:

```hcl
max(5, 12, 9)
```

For call-syntax detail see [[tf-expr-function-calls]] (Function Calls in the Expressions section).

## Provider-defined functions

You **cannot** define your own functions in the configuration language, but a provider can expose functions. Call one with the `provider::<local-name>::` prefix, where `<local-name>` matches a `required_providers` entry:

```hcl
provider::terraform::encode_tfvars({
  example = "Hello!"
})
```

The docs cover built-in and built-in provider-defined functions only. Functions from external providers are documented by those providers in the Terraform Registry.

## Experimenting with functions

Try function behavior in the REPL via `terraform console`:

```
> max(5, 12, 9)
12
```

Each function's doc uses console output to show results.

## Function support by configuration file type

Standard Terraform config (`.hcl`) supports **all** functions. Other config types — notably **Terraform Stacks** (`.tfcomponent.hcl` and `.tfdeploy.hcl`) — support only a **subset**. In the tables below, **Stacks ✓** marks functions the page lists as available in `.tfcomponent.hcl` / `.tfdeploy.hcl` too; unmarked functions are `.hcl`-only.

!!! note "Base URL"
    Every function below links to `https://developer.hashicorp.com/terraform/language/functions/<name>`. Two slug irregularities: `index` lives at `/functions/index_function`, and the `provider::terraform::*` functions live at `/functions/terraform-<name>`.

### Numeric functions

| Function | Stacks | Description |
|---|---|---|
| [`ceil`](https://developer.hashicorp.com/terraform/language/functions/ceil) | ✓ | Closest whole number ≥ the given value. |
| [`floor`](https://developer.hashicorp.com/terraform/language/functions/floor) | ✓ | Closest whole number ≤ the given value. |
| [`log`](https://developer.hashicorp.com/terraform/language/functions/log) | ✓ | Logarithm of a number in a given base. |
| [`max`](https://developer.hashicorp.com/terraform/language/functions/max) | ✓ | Greatest of one or more numbers. |
| [`min`](https://developer.hashicorp.com/terraform/language/functions/min) | ✓ | Smallest of one or more numbers. |
| [`parseint`](https://developer.hashicorp.com/terraform/language/functions/parseint) | ✓ | Parse a string as an integer in a given base. |
| [`pow`](https://developer.hashicorp.com/terraform/language/functions/pow) | ✓ | Raise the first argument to the power of the second. |
| [`signum`](https://developer.hashicorp.com/terraform/language/functions/signum) |  | Sign of a number: -1, 0, or 1. |

The sidebar also lists [`abs`](https://developer.hashicorp.com/terraform/language/functions/abs) (absolute value) under Numeric.

### String functions

| Function | Stacks | Description |
|---|---|---|
| [`chomp`](https://developer.hashicorp.com/terraform/language/functions/chomp) | ✓ | Remove trailing newline characters. |
| [`endswith`](https://developer.hashicorp.com/terraform/language/functions/endswith) |  | True if the string ends with the given suffix. |
| [`format`](https://developer.hashicorp.com/terraform/language/functions/format) | ✓ | Format values per a specification string. |
| [`formatlist`](https://developer.hashicorp.com/terraform/language/functions/formatlist) | ✓ | Format values into a list of strings. |
| [`indent`](https://developer.hashicorp.com/terraform/language/functions/indent) | ✓ | Prefix spaces to each line except the first. |
| [`join`](https://developer.hashicorp.com/terraform/language/functions/join) | ✓ | Concatenate list elements with a separator. |
| [`lower`](https://developer.hashicorp.com/terraform/language/functions/lower) | ✓ | Lowercase all cased letters. |
| [`regex`](https://developer.hashicorp.com/terraform/language/functions/regex) | ✓ | Apply a regex, return matching substrings. |
| [`regexall`](https://developer.hashicorp.com/terraform/language/functions/regexall) | ✓ | Apply a regex, return a list of all matches. |
| [`replace`](https://developer.hashicorp.com/terraform/language/functions/replace) |  | Replace each occurrence of a substring. |
| [`split`](https://developer.hashicorp.com/terraform/language/functions/split) | ✓ | Divide a string at a separator into a list. |
| [`startswith`](https://developer.hashicorp.com/terraform/language/functions/startswith) |  | True if the string begins with the given prefix. |
| [`strcontains`](https://developer.hashicorp.com/terraform/language/functions/strcontains) |  | True if the first string contains the second. |
| [`strrev`](https://developer.hashicorp.com/terraform/language/functions/strrev) | ✓ | Reverse the characters in a string. |
| [`substr`](https://developer.hashicorp.com/terraform/language/functions/substr) | ✓ | Extract a substring by offset and length. |
| [`templatestring`](https://developer.hashicorp.com/terraform/language/functions/templatestring) |  | Render a string as a template with variables. |
| [`title`](https://developer.hashicorp.com/terraform/language/functions/title) | ✓ | Uppercase the first letter of each word. |
| [`trim`](https://developer.hashicorp.com/terraform/language/functions/trim) | ✓ | Remove a set of characters from both ends. |
| [`trimprefix`](https://developer.hashicorp.com/terraform/language/functions/trimprefix) | ✓ | Remove a prefix from the start. |
| [`trimsuffix`](https://developer.hashicorp.com/terraform/language/functions/trimsuffix) | ✓ | Remove a suffix from the end. |
| [`trimspace`](https://developer.hashicorp.com/terraform/language/functions/trimspace) | ✓ | Remove leading/trailing whitespace. |
| [`upper`](https://developer.hashicorp.com/terraform/language/functions/upper) | ✓ | Uppercase all cased letters. |

### Collection functions

| Function | Stacks | Description |
|---|---|---|
| [`alltrue`](https://developer.hashicorp.com/terraform/language/functions/alltrue) |  | True if all elements are true (or empty). |
| [`anytrue`](https://developer.hashicorp.com/terraform/language/functions/anytrue) |  | True if any element is true (or empty). |
| [`chunklist`](https://developer.hashicorp.com/terraform/language/functions/chunklist) |  | Split a list into fixed-size chunks. |
| [`coalesce`](https://developer.hashicorp.com/terraform/language/functions/coalesce) |  | First argument that isn't null or empty string. |
| [`coalescelist`](https://developer.hashicorp.com/terraform/language/functions/coalescelist) | ✓ | First list argument that isn't empty. |
| [`compact`](https://developer.hashicorp.com/terraform/language/functions/compact) | ✓ | Remove null/empty-string elements from a list. |
| [`concat`](https://developer.hashicorp.com/terraform/language/functions/concat) | ✓ | Combine two or more lists into one. |
| [`contains`](https://developer.hashicorp.com/terraform/language/functions/contains) | ✓ | True if a list/tuple/set contains a value. |
| [`distinct`](https://developer.hashicorp.com/terraform/language/functions/distinct) | ✓ | Remove duplicate elements from a list. |
| [`element`](https://developer.hashicorp.com/terraform/language/functions/element) | ✓ | Retrieve a single element from a list. |
| [`flatten`](https://developer.hashicorp.com/terraform/language/functions/flatten) | ✓ | Replace nested list elements with a flat sequence. |
| [`index`](https://developer.hashicorp.com/terraform/language/functions/index_function) |  | First index of a given value in a list. |
| [`keys`](https://developer.hashicorp.com/terraform/language/functions/keys) | ✓ | List of keys from a map. |
| [`length`](https://developer.hashicorp.com/terraform/language/functions/length) |  | Length of a list, map, or string. |
| [`list`](https://developer.hashicorp.com/terraform/language/functions/list) |  | **Deprecated** after 0.12 — use `tolist`. |
| [`lookup`](https://developer.hashicorp.com/terraform/language/functions/lookup) |  | Value of a map element by key. |
| [`map`](https://developer.hashicorp.com/terraform/language/functions/map) |  | **Deprecated** after 0.12 — use `tomap`. |
| [`matchkeys`](https://developer.hashicorp.com/terraform/language/functions/matchkeys) |  | Subset of one list by matching indexes in another. |
| [`merge`](https://developer.hashicorp.com/terraform/language/functions/merge) | ✓ | Merge maps/objects into one. |
| [`one`](https://developer.hashicorp.com/terraform/language/functions/one) |  | The only element, or null if empty; errors if >1. |
| [`range`](https://developer.hashicorp.com/terraform/language/functions/range) | ✓ | Generate a list of numbers (start, limit, step). |
| [`reverse`](https://developer.hashicorp.com/terraform/language/functions/reverse) | ✓ | Reverse a sequence. |
| [`setintersection`](https://developer.hashicorp.com/terraform/language/functions/setintersection) | ✓ | Elements common to all given sets. |
| [`setproduct`](https://developer.hashicorp.com/terraform/language/functions/setproduct) | ✓ | Cartesian product of the given sets. |
| [`setsubtract`](https://developer.hashicorp.com/terraform/language/functions/setsubtract) | ✓ | Elements in the first set not in the second. |
| [`setunion`](https://developer.hashicorp.com/terraform/language/functions/setunion) | ✓ | Union of all given sets. |
| [`slice`](https://developer.hashicorp.com/terraform/language/functions/slice) | ✓ | Consecutive elements from within a list. |
| [`sort`](https://developer.hashicorp.com/terraform/language/functions/sort) | ✓ | Sort a list of strings lexicographically. |
| [`sum`](https://developer.hashicorp.com/terraform/language/functions/sum) |  | Sum of a list/set of numbers. |
| [`transpose`](https://developer.hashicorp.com/terraform/language/functions/transpose) |  | Swap keys and values in a map of lists of strings. |
| [`values`](https://developer.hashicorp.com/terraform/language/functions/values) | ✓ | List of values from a map. |
| [`zipmap`](https://developer.hashicorp.com/terraform/language/functions/zipmap) | ✓ | Build a map from a keys list and a values list. |

### Encoding functions

| Function | Stacks | Description |
|---|---|---|
| [`base64decode`](https://developer.hashicorp.com/terraform/language/functions/base64decode) |  | Decode a Base64 sequence to the original string. |
| [`base64encode`](https://developer.hashicorp.com/terraform/language/functions/base64encode) |  | Base64-encode a string. |
| [`base64gzip`](https://developer.hashicorp.com/terraform/language/functions/base64gzip) |  | gzip then Base64-encode a string. |
| [`csvdecode`](https://developer.hashicorp.com/terraform/language/functions/csvdecode) | ✓ | Decode CSV into a list of maps. |
| [`jsondecode`](https://developer.hashicorp.com/terraform/language/functions/jsondecode) | ✓ | Interpret a string as JSON. |
| [`jsonencode`](https://developer.hashicorp.com/terraform/language/functions/jsonencode) | ✓ | Encode a value to JSON. |
| [`textdecodebase64`](https://developer.hashicorp.com/terraform/language/functions/textdecodebase64) |  | Base64-decode then interpret in a given encoding. |
| [`textencodebase64`](https://developer.hashicorp.com/terraform/language/functions/textencodebase64) |  | Encode in a given charset, return Base64. |
| [`urlencode`](https://developer.hashicorp.com/terraform/language/functions/urlencode) |  | URL-encode a string. |
| [`yamldecode`](https://developer.hashicorp.com/terraform/language/functions/yamldecode) | ✓ | Parse a subset of YAML. |
| [`yamlencode`](https://developer.hashicorp.com/terraform/language/functions/yamlencode) | ✓ | Encode a value to YAML 1.2 block syntax. |

### Filesystem functions

| Function | Stacks | Description |
|---|---|---|
| [`abspath`](https://developer.hashicorp.com/terraform/language/functions/abspath) |  | Convert a path to an absolute path. |
| [`dirname`](https://developer.hashicorp.com/terraform/language/functions/dirname) |  | Remove the last portion of a path. |
| [`pathexpand`](https://developer.hashicorp.com/terraform/language/functions/pathexpand) |  | Expand a leading `~` to the home directory. |
| [`basename`](https://developer.hashicorp.com/terraform/language/functions/basename) |  | Keep only the last portion of a path. |
| [`file`](https://developer.hashicorp.com/terraform/language/functions/file) |  | Read a file's contents as a string. |
| [`fileexists`](https://developer.hashicorp.com/terraform/language/functions/fileexists) |  | Whether a file exists at a path. |
| [`fileset`](https://developer.hashicorp.com/terraform/language/functions/fileset) |  | Enumerate file names by path and pattern. |
| [`filebase64`](https://developer.hashicorp.com/terraform/language/functions/filebase64) |  | Read a file's contents as Base64. |
| [`templatefile`](https://developer.hashicorp.com/terraform/language/functions/templatefile) |  | Read and render a file as a template. |

### Date and time functions

| Function | Stacks | Description |
|---|---|---|
| [`formatdate`](https://developer.hashicorp.com/terraform/language/functions/formatdate) | ✓ | Convert a timestamp to another time format. |
| [`plantimestamp`](https://developer.hashicorp.com/terraform/language/functions/plantimestamp) |  | UTC RFC 3339 timestamp at plan time. |
| [`timeadd`](https://developer.hashicorp.com/terraform/language/functions/timeadd) | ✓ | Add a duration to a timestamp. |
| [`timecmp`](https://developer.hashicorp.com/terraform/language/functions/timecmp) |  | Compare two timestamps, return their ordering. |
| [`timestamp`](https://developer.hashicorp.com/terraform/language/functions/timestamp) |  | UTC RFC 3339 timestamp at the current time. |

### Hash and crypto functions

| Function | Stacks | Description |
|---|---|---|
| [`base64sha256`](https://developer.hashicorp.com/terraform/language/functions/base64sha256) |  | SHA-256 of a string, Base64-encoded. |
| [`base64sha512`](https://developer.hashicorp.com/terraform/language/functions/base64sha512) |  | SHA-512 of a string, Base64-encoded. |
| [`bcrypt`](https://developer.hashicorp.com/terraform/language/functions/bcrypt) |  | Blowfish hash in Modular Crypt Format. |
| [`filebase64sha256`](https://developer.hashicorp.com/terraform/language/functions/filebase64sha256) |  | `base64sha256` over a file's contents. |
| [`filebase64sha512`](https://developer.hashicorp.com/terraform/language/functions/filebase64sha512) |  | `base64sha512` over a file's contents. |
| [`filemd5`](https://developer.hashicorp.com/terraform/language/functions/filemd5) |  | MD5 over a file's contents. |
| [`filesha1`](https://developer.hashicorp.com/terraform/language/functions/filesha1) |  | SHA-1 over a file's contents. |
| [`filesha256`](https://developer.hashicorp.com/terraform/language/functions/filesha256) |  | SHA-256 over a file's contents. |
| [`filesha512`](https://developer.hashicorp.com/terraform/language/functions/filesha512) |  | SHA-512 over a file's contents. |
| [`md5`](https://developer.hashicorp.com/terraform/language/functions/md5) |  | MD5 of a string, hex-encoded. |
| [`rsadecrypt`](https://developer.hashicorp.com/terraform/language/functions/rsadecrypt) |  | Decrypt RSA ciphertext to cleartext. |
| [`sha1`](https://developer.hashicorp.com/terraform/language/functions/sha1) |  | SHA-1 of a string, hex-encoded. |
| [`sha256`](https://developer.hashicorp.com/terraform/language/functions/sha256) |  | SHA-256 of a string, hex-encoded. |
| [`sha512`](https://developer.hashicorp.com/terraform/language/functions/sha512) |  | SHA-512 of a string, hex-encoded. |
| [`uuid`](https://developer.hashicorp.com/terraform/language/functions/uuid) |  | Random UUID-format string. |
| [`uuidv5`](https://developer.hashicorp.com/terraform/language/functions/uuidv5) |  | Name-based UUID (RFC 4122 §4.3). |

### IP network functions

| Function | Stacks | Description |
|---|---|---|
| [`cidrhost`](https://developer.hashicorp.com/terraform/language/functions/cidrhost) |  | Full host IP for a host number in a CIDR prefix. |
| [`cidrnetmask`](https://developer.hashicorp.com/terraform/language/functions/cidrnetmask) |  | Convert an IPv4 CIDR prefix to a subnet mask. |
| [`cidrsubnet`](https://developer.hashicorp.com/terraform/language/functions/cidrsubnet) |  | Calculate a subnet address within a CIDR prefix. |
| [`cidrsubnets`](https://developer.hashicorp.com/terraform/language/functions/cidrsubnets) |  | Sequence of consecutive subnets within a CIDR. |

### Type conversion functions

| Function | Stacks | Description |
|---|---|---|
| [`can`](https://developer.hashicorp.com/terraform/language/functions/can) | ✓ | True if an expression evaluates without error. |
| [`ephemeralasnull`](https://developer.hashicorp.com/terraform/language/functions/ephemeralasnull) |  | Return null for an ephemeral value. |
| [`issensitive`](https://developer.hashicorp.com/terraform/language/functions/issensitive) |  | True if Terraform treats a value as sensitive. |
| [`nonsensitive`](https://developer.hashicorp.com/terraform/language/functions/nonsensitive) |  | Remove the sensitive marking (exposes the value). |
| [`sensitive`](https://developer.hashicorp.com/terraform/language/functions/sensitive) |  | Mark a value sensitive. |
| [`tobool`](https://developer.hashicorp.com/terraform/language/functions/tobool) |  | Convert to bool. |
| [`tolist`](https://developer.hashicorp.com/terraform/language/functions/tolist) |  | Convert to list. |
| [`tomap`](https://developer.hashicorp.com/terraform/language/functions/tomap) |  | Convert to map. |
| [`tonumber`](https://developer.hashicorp.com/terraform/language/functions/tonumber) |  | Convert to number. |
| [`toset`](https://developer.hashicorp.com/terraform/language/functions/toset) |  | Convert to set. |
| [`tostring`](https://developer.hashicorp.com/terraform/language/functions/tostring) |  | Convert to string. |
| [`try`](https://developer.hashicorp.com/terraform/language/functions/try) | ✓ | Result of the first argument that evaluates without error. |
| [`type`](https://developer.hashicorp.com/terraform/language/functions/type) |  | Return the type of a value. |

The sidebar also lists [`convert`](https://developer.hashicorp.com/terraform/language/functions/convert) here — precise inline type conversion, **Terraform 1.15+, Terraform-only** (OpenTofu has no `convert`; portable code uses the `toType` casters). See [[tf115-ot112-features]].

### Terraform-specific (provider-defined) functions

| Function | Description |
|---|---|
| [`provider::terraform::encode_tfvars`](https://developer.hashicorp.com/terraform/language/functions/terraform-encode_tfvars) | Produce a string describing an object value. |
| [`provider::terraform::decode_tfvars`](https://developer.hashicorp.com/terraform/language/functions/terraform-decode_tfvars) | Parse `.tfvars` content into an object of raw values. |
| [`provider::terraform::encode_expr`](https://developer.hashicorp.com/terraform/language/functions/terraform-encode_expr) | Produce Terraform expression syntax approximating a value. |
| [`terraform.applying`](https://developer.hashicorp.com/terraform/language/functions/terraform-applying) | Ephemeral bool, true during apply (TF 1.10). |

---
Related: [[tf-expr-function-calls]] — the call syntax, `...` argument expansion, and plan-time vs apply-time behavior of `file`/`timestamp`/`uuid`. [[tf-conditionals]] — the `can()`/`try()` condition-building idioms live in this catalogue. [[tf-expr-type-constraints]] — the `to*`/`convert` casters implement the type-conversion rules described there.
