# Chapter 12 — Terraform providers

> *Source: Hafner (2025), **Terraform in Depth**, Chapter 12, pages 426–464.*
>
> The last chapter, and the only one that leaves HCL entirely. It builds a real provider for **Mastodon** in Go with the **Terraform Plugin Framework**: design the interface first (§12.1), set up Go and a local install path (§12.2), learn schemas, diagnostics and `tflog` (§12.3), implement the provider entry point (§12.4), then a data source (§12.5), a resource with full CRUD (§12.6), a provider-defined function (§12.7), and finally sign and publish it (§12.8). The chapter's own framing is honest: most people never need this.
>
> 📌 **Two of the printed listings will not build.** Listing 12.3 puts a `Default:` on a *provider* schema attribute, which the framework has no field for; Listing 12.12 defines data source attributes with neither `Required`, `Optional`, nor `Computed`, which fails schema validation at runtime. Both are flagged below, and both are correct in the author's published repository — so the bugs are in print only.
>
> ⚠️ **The plugin interfaces have grown a lot since the book.** Table 12.1's provider interface is now missing four methods: ephemeral resources (Terraform 1.10), list resources and actions (1.14), and state stores. Resource identity (1.12) also changed how import works. Everything the chapter teaches still compiles; it is just no longer the whole surface.

> 🔗 **See also:** feeds **E1** (extending Terraform) and closes the book's arc from **B4** (what a provider *is*) through **I3** (using providers) to writing one. Builds on [Ch9](09-testing-refactoring.md) (Terratest and the Go testing package — the plugin test framework is the same shape), [Ch11 §11.1](11-alternative-interfaces.md#111-wrapping-terraform) (§11.3's "write a provider instead" lands here) and [Ch7](07-code-quality-ci.md) (`terraform-docs` → `tfplugindocs`). Checked against **terraform-plugin-framework v1.19.0** (2026-03-10), **terraform-plugin-testing v1.16.0** (2026-04-23), **Terraform 1.15.8** and **OpenTofu 1.12.5**, 2026-08-16.

---

## Why a chapter on this at all

The chapter opens by talking you *out* of it: there are thousands of providers, and most developers never need another. Three cases where you do:

- **You sell or run a platform** and want other developers to drive it with Terraform. True for commercial developer platforms, equally true for internal ones.
- **You use an open-source platform that has no provider.** This is the chapter's own case.
- **You want provider-defined functions** for data processing that the built-in function set does not cover. The book's example is the open-source [`corefunc`](https://github.com/northwood-labs/terraform-provider-corefunc) provider — "utilities that should have been Terraform core functions", community-maintained rather than HashiCorp's, and a rare example of a provider that calls no API at all.

Two prerequisites the chapter states plainly. First, **you need Go** — the chapter teaches the Terraform-specific parts and assumes the language. Second, **the internals are not stable the way the language is**: there have been several SDKs and protocol versions over the years, and the current one is the **Terraform Plugin Framework** speaking **protocol version 6**. The framework hides the protocol well enough that you never write gRPC yourself.

The architecture is one sentence: Terraform ⇄ *gRPC* ⇄ your provider ⇄ *HTTPS* ⇄ the service. Your provider is a separate binary Terraform launches and talks to over a local socket.

> 💭 (mine): that plugin channel is the same one that goes wrong when local security software intercepts loopback TLS — the "Failed to load plugin schemas" failure. Worth remembering that a provider is a *process*, not a library.

---

## 12.1 Design

The chapter's one genuinely architectural section, and it is short: **decide the user-facing interface before writing Go**.

The argument is a scale argument. Breaking a module hurts its callers; breaking a *provider* hurts every module that uses it. So the compatibility discipline you apply to a module API (see [Ch3](03-variables-modules.md) and [Ch8](08-cd-deployment.md) on module delivery) applies harder here.

The method is to write the HCL you want your users to write, first:

```hcl
terraform {
  required_providers {
    mastodon = { source = "terraformindepth/mastodon" }
  }
}

provider "mastodon" {
  host = "https://hachyderm.io"
}

data "mastodon_account" "me" { username = "tedivm" }

resource "mastodon_post" "this" { content = "Hello, World!" }
```

That sketch already fixes the three things the rest of the chapter implements: a **data source** to look things up, a **resource** to manage things, and a **function** to validate the `@user@server` identity format. It also fixes the naming rule you get for free — every type name is `<provider type name>_<thing>`, derived in code from `req.ProviderTypeName`.

!!! tip "The chapter's project is a real, readable repository"
    [`TerraformInDepth/terraform-provider-mastodon`](https://github.com/TerraformInDepth/terraform-provider-mastodon) — "An example Terraform Provider for the Mastodon Fediverse Server", last pushed 23 January 2025. Same trick as [Ch11](11-alternative-interfaces.md)'s `tofupy`: when a listing looks wrong, diff it against the published source. That is how both bugs below were confirmed as print-only.

---

## 12.2 Developer environment

Install Go and the Go extension for your editor, then set up the project.

### 12.2.1 Template

Start from HashiCorp's [**terraform-provider-scaffolding-framework**](https://github.com/hashicorp/terraform-provider-scaffolding-framework) rather than an empty directory. It is a plain repository to clone, not a Cookiecutter template, so it needs manual cleanup. The chapter's list:

1. Update `.github/dependabot.yml` (there is a `@TODO` in it) so actions get updated.
2. Replace `.github/CODEOWNERS` and `.github/CODE_OF_CONDUCT.md` with your own.
3. Delete `.copywrite.hcl` — a HashiCorp-internal repository tool.
4. `go mod edit -module github.com/YOUR_ORG/terraform-provider-YOUR_SERVICE`, using the GitHub path even before the repo exists.
5. `go mod tidy`.
6. Rewrite the description in `README.md`; keep the usage instructions.
7. Update the module name in `main.go`, **including in comments**, so `go generate` works.

!!! warning "Step 3 is the one that has drifted — and step 7 needs a second file"
    The template still ships `.copywrite.hcl`, but the `go:generate` directives now live in **`tools/tools.go`**, not `main.go`, and one of them *runs* copywrite:

    ```go
    //go:generate go run github.com/hashicorp/copywrite headers -d .. --config ../.copywrite.hcl
    //go:generate terraform fmt -recursive ../examples/
    //go:generate go run github.com/hashicorp/terraform-plugin-docs/cmd/tfplugindocs generate --provider-dir .. -provider-name scaffolding
    ```

    So deleting `.copywrite.hcl` while leaving `tools/tools.go` alone breaks `go generate` — and `-provider-name scaffolding` is the string you actually have to change for step 7 to be complete. `main.go` carries a matching `TODO` comment pointing at that flag. The template's headers now read **`// Copyright IBM Corp. 2021, 2025`**, not `HashiCorp, Inc.` as in Listing 12.5 — cosmetic, but a quick way to tell a fresh clone from the book's vintage.

### 12.2.2 Developer overrides

To run a locally built provider, point the CLI configuration at the directory `go install` writes to. Find it with `go env GOBIN`, falling back to `$HOME/go/bin` when that is empty, then:

```hcl
provider_installation {
  dev_overrides {
    "terraformindepth/mastodon" = "/Users/tedivm/go/bin/"
  }
  # Without this, ONLY the overridden provider is available.
  direct {}
}
```

The `direct {}` block is not optional decoration. Omit it and `dev_overrides` becomes the *only* installation method, so every other provider in the configuration stops resolving.

The behaviour to expect: **`terraform init` still tries to install a published version** and record it in the lock file, which is why the chapter later says to run `init` "ignoring any errors about it not being able to find our provider". Nothing has been published yet, so init fails — and `apply` works anyway, because it disregards the lock entry and uses your directory. Terraform also prints a warning on every command while an override is active, by design. HashiCorp documents the whole mechanism as **not for general use** and subject to breaking changes.

!!! info "OpenTofu — the file is `.tofurc`, not `.terraformrc`"
    The chapter says to edit `~/.terraformrc`, which is right for Terraform and only accidentally right for OpenTofu. In `repos/opentofu` at `v1.12.5`, `internal/command/cliconfig/config_unix.go` builds both paths and hands them to `getNewOrLegacyPath`, whose rule is: **use `.terraformrc` only if `.tofurc` does not exist**. On Windows the pair is `tofu.rc` / `terraform.rc`, and a fresh install with `XDG_CONFIG_HOME` set prefers `$XDG_CONFIG_HOME/opentofu/tofurc`.

    Consequence worth knowing: the moment you create a `~/.tofurc` for anything else, your `dev_overrides` in `~/.terraformrc` silently stop applying to `tofu`. The `provider_installation`/`dev_overrides` blocks themselves are identical — OpenTofu implements them in `internal/command/cliconfig/provider_installation.go`.

---

## 12.3 Terraform Plugin Framework features

### 12.3.1 Schemas

A **schema** is how every component — provider, resource, data source — declares its parameters and attributes to Terraform: type, whether it is required or computed, defaults, descriptions, sensitivity, deprecation. Schemas are maps of typed attributes, defined in their own `Schema` function:

```go
func (p *MastodonProvider) Schema(ctx context.Context, req provider.SchemaRequest, resp *provider.SchemaResponse) {
    resp.Schema = schema.Schema{
        Attributes: map[string]schema.Attribute{
            "access_token": schema.StringAttribute{
                MarkdownDescription: "Token to use for connecting to the server.",
                Optional:            true,
                Sensitive:           true,   // filtered out of logs
            },
        },
    }
}
```

`MarkdownDescription` is not just documentation — it is what `tfplugindocs` reads in §12.8.1, so writing it well is writing your docs.

!!! danger "⚠️ Listing 12.3 does not compile — provider schemas have no `Default`"
    The listing shows a provider attribute with `Default: stringdefault.StaticString("mastodon.social")` and a comment reading "Schemas can have default values". They can, but not this kind of schema. `provider/schema.StringAttribute` (framework v1.19.0) has exactly these fields: **`CustomType`, `Required`, `Optional`, `Sensitive`, `Description`, `MarkdownDescription`, `DeprecationMessage`, `Validators`**. No `Default`, no `PlanModifiers` — those are resource-schema concepts, because a provider block has no plan and no state to hold a default in.

    HashiCorp's own default-values page states the rule outright — *"A `Default` can only be added to a resource schema attribute"* — and adds the second half the chapter also never says: an attribute carrying a `Default` must be `Computed`. The published `provider.go` sets no defaults anywhere, and the real Listing 12.7 four pages later is clean. So read 12.3 as an illustration of *field vocabulary*, not as code. The corollary is the practical one: **a provider option's "default" is code**, the `os.Getenv` fallback in `Configure` — which is exactly what §12.4.3 does.

    `DeprecationMessage` and `Sensitive` in that listing are real and do work on provider attributes.

### 12.3.2 Error handling and logging

Two rules, and the chapter is emphatic about both.

**Use `Diagnostics`, not returns.** The `resp` object passed to nearly every function carries a `Diagnostics` collection you can append to repeatedly. So do not bail on the first bad value — validate everything, collect every error, then check once:

```go
if data.AccessToken.IsUnknown() {
    resp.Diagnostics.AddAttributeError(
        path.Root("access_token"),
        "Unknown Mastodon Access Token",
        "Either target apply the source of the value first, set it statically, "+
            "or use the MASTODON_ACCESS_TOKEN environment variable.",
    )
}
// … every other attribute …
if resp.Diagnostics.HasError() {
    return
}
```

`AddAttributeError` takes a `path.Root("…")`, which is what makes Terraform point at the offending line in the user's configuration. Each error is a *title* plus a *description*, and the description should say what to do, not just what happened.

**Use `tflog`, never the `log` package — and never `Fatal`.** `tflog.Debug` / `Error` / `Trace` map onto the levels `TF_LOG` selects, so your provider's logs show up in the same stream as the engine's ([Ch11 §11.1.2](11-alternative-interfaces.md#1112-initial-terraform-client) sets `TF_LOG` from the wrapper for exactly this reason). A `log.Fatal` kills the plugin process: Terraform gets no diagnostics back, the user sees a crash instead of an error, and state can be left corrupted. If you must stop, record diagnostics, log, and `return`.

Secrets get a matching pair of calls — add the field to the context, then mask it:

```go
ctx = tflog.SetField(ctx, "mastodon_access_token", access_token)
ctx = tflog.MaskFieldValuesWithFieldKeys(ctx, "mastodon_access_token")
```

> 💭 (mine): `Sensitive: true` in the schema keeps a value out of *Terraform's* rendering; `MaskFieldValuesWithFieldKeys` keeps it out of *your provider's* logs. Two different pipes, two different mechanisms, and the second one is easy to forget.

### 12.3.3 Testing

Provider testing is the Go testing package again, the same base as Terratest in [Ch9](09-testing-refactoring.md). The difference: with **terraform-plugin-testing** you write the HCL *inside the test* as a string, and you test **one resource or data source at a time** rather than a whole module.

| | Unit test | Acceptance test |
| --- | --- | --- |
| Prefix | `TestXxx` | `TestAccXxx` |
| Helper | `resource.UnitTest` | `resource.Test` |
| Talks to the real service | No | Yes |
| Gate | always runs | only when `TF_ACC=1` |
| Typical subject | provider functions, shared logic | resources, data sources |

Acceptance tests really do run the Terraform binary and really do create things, so **they can cost money** — a provider for a major cloud bills you for every test run. Skipping them while iterating on functions saves both time and money.

!!! warning "`make acctest` is not a thing — the target is `make testacc`"
    §12.3.3 gets it right, and §12.5.6 then tells you to run `make acctest`. The scaffolding template's `GNUmakefile` has targets `default`, `build`, `install`, `lint`, `generate`, `fmt`, `test` and **`testacc`** — the last one being `TF_ACC=1 go test ./... -v -timeout 120m`. There is no `acctest`.

---

## 12.4 Provider interface

The entry point is a Go type implementing `provider.Provider`. The chapter's Table 12.1:

| Function | Purpose |
| --- | --- |
| `Metadata` | Type name prefix (`mastodon` → `mastodon_post`) and version |
| `Schema` | The provider block's configuration schema |
| `Configure` | Build the API client; hand it to resources and data sources |
| `Resources` | List of resource constructors |
| `DataSources` | List of data source constructors |
| `Functions` | List of function constructors |
| `New` | Constructor for the provider itself |

Two precision points. The interface method is **`DataSources`** (plural — the table prints it singular), and `Functions` is *not* part of `provider.Provider`: it comes from the optional **`ProviderWithFunctions`** interface, which is why the boilerplate asserts both:

```go
var _ provider.Provider = &MastodonProvider{}
var _ provider.ProviderWithFunctions = &MastodonProvider{}
```

That "core interface plus optional extensions" pattern is how the framework has added everything since — and it has added a lot.

!!! info "What the provider interface gained after the book was written"
    All verified against framework **v1.19.0** on pkg.go.dev, 2026-08-16. Each is an opt-in interface, so existing providers keep compiling.

    | Interface | Method | Needs |
    | --- | --- | --- |
    | `ProviderWithConfigValidators` | `ConfigValidators` | — |
    | `ProviderWithValidateConfig` | `ValidateConfig` | — |
    | `ProviderWithMetaSchema` | `MetaSchema` | — |
    | `ProviderWithFunctions` | `Functions` | Terraform 1.8+ |
    | `ProviderWithEphemeralResources` | `EphemeralResources` | Terraform 1.10+ |
    | `ProviderWithListResources` | `ListResources` | Terraform 1.14+ |
    | `ProviderWithActions` | `Actions` | Terraform 1.14+ |
    | `ProviderWithStateStores` | `StateStores` | experimental |

    On the resource side the same period added **write-only attributes** (1.11) and **managed resource identity** (1.12), the latter giving import a structured identity instead of a single ID string.

!!! info "OpenTofu — supports the framework, not all of the newer surfaces"
    Providers are engine-agnostic: OpenTofu speaks the same plugin protocol and runs framework-built providers unchanged. But two of the newest additions have no OpenTofu implementation. Checked in `repos/opentofu` at `v1.12.5`:

    - **Ephemeral resources, write-only attributes, resource identity** — implemented (`internal/command/jsonformat/computed/renderers/write_only.go`, `internal/command/jsonprovider/identity.go`, plus ephemeral handling throughout the CHANGELOG).
    - **List resources and actions** — `ListResource` and the action RPCs appear **only** in generated protobuf and mocks (`internal/tfplugin5`, `internal/tfplugin6`, `mock_proto`); there is no core support, no `tofu query`, no `action` block. Terraform shipped both in **1.14.0** (19 Nov 2025).

    So a provider that exposes list resources or actions degrades to its ordinary resources on OpenTofu.

### 12.4.1 Template cleanup

Delete the example constructors from `Resources`, `DataSources` and `Functions`; find-and-replace `ScaffoldingProvider` → `MastodonProvider`; set `resp.TypeName = "mastodon"` in `Metadata`. That type name is the user-visible prefix for every type the provider ships, so it is a one-way decision.

### 12.4.2 Provider model and schema

Add the client library (`go get github.com/mattn/go-mastodon && go mod tidy`), then declare the configuration twice — once as a schema, once as a Go struct whose `tfsdk` tags map back to the schema keys:

```go
type MastodonProviderModel struct {
    Host        types.String `tfsdk:"host"`
    ClientID    types.String `tfsdk:"client_id"`
    AccessToken types.String `tfsdk:"access_token"`
    // …
}
```

Everything is `Optional`, on purpose: the values are meant to come from environment variables too, so users can switch credentials without editing code. That is the convention across the provider ecosystem, and it is why `Optional` here does not mean "you may omit it entirely".

Note the types are `types.String`, not `string`. The framework's types carry three states — known, **null**, and **unknown** — which is what the next section is really about.

### 12.4.3 Provider configuration

`Configure` does the credential resolution and then builds the client. The per-attribute pattern, in order:

1. **Check `IsUnknown()`.** Unknown means the value is derived from something not yet applied — the classic case is configuring the Kubernetes provider from an EKS cluster the AWS provider has not created yet. Terraform cannot configure the provider until that resolves, so emit an error telling the user to `-target` the source first, set the value statically, or use the environment variable.
2. **Read the environment variable** into a local (empty string when unset).
3. **Override with the configuration value** if `!IsNull()` — so the provider block beats the environment.
4. **Run cross-field validation** and register errors; here, that neither `access_token` nor the email/password pair was supplied.

Only then `if resp.Diagnostics.HasError() { return }`.

Client creation branches on which credential arrived, and the chapter does one thing worth stealing: it **verifies the client immediately** with `GetAccountCurrentUser`, converting "wrong credentials" from a confusing failure at first `apply` into a clear failure at configure time.

```go
resp.DataSourceData = c
resp.ResourceData = c
```

Both fields get the same client. **There is no `FunctionData`** — deliberately, because provider functions must be pure logic and never call out to a service. That still holds at v1.19.0, even though `ConfigureResponse` has since grown `EphemeralResourceData`, `ActionData`, `ListResourceData` and `StateStoreData` beside the two the chapter uses: every new component type got a channel for the client, and functions still did not.

### 12.4.4 Provider testing

Two pieces of shared scaffolding that every later test reuses:

```go
var testAccProtoV6ProviderFactories = map[string]func() (tfprotov6.ProviderServer, error){
    "mastodon": providerserver.NewProtocol6WithError(New("test")()),
}

func testAccPreCheck(t *testing.T) {
    assert.NotEmpty(t, os.Getenv("MASTODON_HOST"), "MASTODON_HOST must be set for acceptance tests")
    // … one per required variable
}
```

The factory map spins up a provider server per test; the precheck fails fast with a readable message when credentials are missing, instead of letting the failure surface as an opaque API error three steps later.

---

## 12.5 Data source

A data source implements four functions — `Metadata`, `Schema`, `Configure`, `Read` — and a provider can have many. Start by copying `internal/provider/example_data_source.go` to `account_data_source.go` and replacing `Example` with `Account`.

### 12.5.1 Data source schema

The parameter/attribute distinction is expressed entirely through three booleans:

- **`Required: true`** — the user must set it. Here, `username`.
- **`Optional: true`** — the user may set it.
- **`Computed: true`** — the provider fills it in. Values that are computed may not be known at plan time.

```go
resp.TypeName = req.ProviderTypeName + "_account"   // → mastodon_account
```

Deriving the type name from `req.ProviderTypeName` rather than hardcoding it means renaming the provider renames every type with it.

!!! danger "⚠️ Listing 12.12 fails at runtime — every output attribute is missing `Computed`"
    The listing gives `id`, `display_name`, `note`, `locked` and `bot` exactly `Optional: false, Required: false` and stops. All three booleans false is not a valid attribute. The framework rejects it in `AttributeValidate` with:

    > **Invalid Attribute Definition** — "Attribute missing Required, Optional, or Computed definition. This is always a problem with the provider and should be reported to the provider developer."

    At least one of the three must be true; the valid combinations are *required only*, *optional only*, *computed only*, or *optional + computed*. The prose two paragraphs earlier names `computed` as one of the three keys, so this is a listing slip rather than a misunderstanding — and the published `account_data_source.go` sets `Computed: true` on all five. Fix it as the repository does: `username` required, everything else computed.

### 12.5.2 Configure

Identical in body across every data source and resource — pull the client out of `req.ProviderData`, with a type assertion:

```go
if req.ProviderData == nil {   // provider not configured yet — do not panic
    return
}
client, ok := req.ProviderData.(*mastodon.Client)
if !ok {
    resp.Diagnostics.AddError("Unexpected Data Source Configure Type",
        fmt.Sprintf("Expected *mastodon.Client, got: %T. Please report this issue to the provider developers.",
            req.ProviderData))
    return
}
d.client = client
```

The `nil` guard matters: `Configure` can run before the provider has configured its client, and dereferencing there is a plugin crash. The "report this to the provider developers" wording is the framework's convention for errors the user cannot possibly fix.

### 12.5.3 Read

The heart of a data source, and the shape repeats everywhere: **parse into the model → call the API → populate the model → save to state**.

```go
var data AccountDataSourceModel
resp.Diagnostics.Append(req.Config.Get(ctx, &data)...)      // user-provided config
if resp.Diagnostics.HasError() { return }

account, err := d.client.AccountLookup(ctx, data.Username.ValueString())
if err != nil {
    resp.Diagnostics.AddError("Failed to lookup account", fmt.Sprintf("Failed to lookup account: %s", err))
    return
}

data.Id     = types.StringValue(string(account.ID))         // type coercion is on you
data.Locked = types.BoolValue(account.Locked)
resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)      // save
```

Data sources read from `req.Config`; resources will read from `req.Plan` or `req.State` instead, and that difference is the thing to keep straight. Not every data source calls an API — the chapter points at `cloudinit_config` as one that is purely local computation.

### 12.5.4–12.5.5 Registration and usage

Add the constructor to the provider's `DataSources` list, `go install`, and write an example under `examples/data-sources/account/` — which doubles as documentation input for §12.8.1.

### 12.5.6 Testing

`resource.Test` does the heavy lifting: spins up the provider server, **calls the real Terraform binary** so the test path matches production, and cleans up afterwards.

A `resource.TestCase` needs `PreCheck` and `ProtoV6ProviderFactories` (the two things §12.4.4 built — identical in every test in the project), plus `Steps`. Each `resource.TestStep` carries a `Config` string of literal HCL and a `Check`. Data sources usually need one step; resources need several.

For the assertions themselves:

- `resource.TestCheckResourceAttr(addr, attr, value)` and friends generate a check function.
- `resource.ComposeTestCheckFunc` fails at the first failing check; **`ComposeAggregateTestCheckFunc` runs them all and aggregates**, which is nearly always what you want in a test you have to debug.

```go
Config: `data "mastodon_account" "test" { username = "tedivm@hachyderm.io" }`,
Check: resource.ComposeAggregateTestCheckFunc(
    resource.TestCheckResourceAttr("data.mastodon_account.test", "bot", "false"),
),
```

Note the address gains a `data.` prefix for data sources.

!!! tip "There is a newer assertion API worth knowing about"
    terraform-plugin-testing **v1.16.0** ships a `statecheck` package used via `ConfigStateChecks` on a step — `statecheck.ExpectKnownValue(addr, tfjsonpath.New("bot"), knownvalue.Bool(false))`, plus `ExpectSensitiveValue`, `ExpectKnownOutputValue`, `CompareValuePairs`, and identity checks (`ExpectIdentity`, Terraform 1.12+). It is typed rather than string-based, so `false` is a bool instead of `"false"`, and it reaches nested attributes by path. The chapter's `Check` functions still work and are still everywhere in the ecosystem; reach for `statecheck` when an assertion gets awkward to express as a flat string.

---

## 12.6 Resources

Resources are data sources plus the three functions that change the world: **Create**, **Update**, **Delete** — CRUD, with `Read` doing the R.

| Function | Purpose |
| --- | --- |
| `Metadata`, `Schema`, `Configure` | as for data sources |
| `Create` | create from the plan, write everything back to state |
| `Read` | refresh from the ID in state |
| `Update` | update in place using the existing ID |
| `Delete` | delete by ID; the framework drops it from state |
| `ImportState` | adopt an existing object into state from an ID |

`ImportState` is worth separating out: it is **not** part of `resource.Resource` but of the optional `resource.ResourceWithImportState`. You get it for free here because the scaffolding's `example_resource.go` — the file you copied — already implements it as a one-liner:

```go
func (r *ExampleResource) ImportState(ctx context.Context, req resource.ImportStateRequest, resp *resource.ImportStateResponse) {
    resource.ImportStatePassthroughID(ctx, path.Root("id"), req, resp)
}
```

The chapter never mentions this, yet §12.6.8's second test step asserts `ImportState: true` — that test passes only because the copied file brought the implementation along.

### 12.6.1 Resource schema

Same model-plus-schema pair, with more thought needed about which changes are updates and which force replacement. `mastodon_post` exposes `content`, `visibility` (default `"public"`) and `sensitive` (default `false`), and computes `id`, `created_at` and `account`.

Two schema features appear here that provider schemas do not have:

```go
"id": schema.StringAttribute{
    Computed:      true,
    PlanModifiers: []planmodifier.String{stringplanmodifier.UseStateForUnknown()},
},
"visibility": schema.StringAttribute{
    Optional: true,
    Computed: true,                                          // required alongside Default
    Default:  stringdefault.StaticString("public"),
},
```

- **`UseStateForUnknown()`** stops Terraform printing `(known after apply)` for a computed value that cannot change — it reuses the state value instead. Cheap, and it makes plans much easier to read.
- **A `Default` requires `Computed: true`.** That is the rule behind the book's comment "this field has to be marked as computed because it has a default value" — which, thanks to a callout landing on the wrong line, appears next to `content` (a plain `Required` attribute with no default). Apply the comment to `visibility` and `sensitive`, where it belongs.

> ⚠️ Two typos in this section: the prose names the post's text parameter **`status`** while the schema and every listing call it **`content`**, and the file to copy is given as `port_resource.go` for `post_resource.go`.

### 12.6.2 Resource configure

Byte-for-byte the data source version, with `resource.ConfigureRequest` in the signature and `r.client` as the destination.

### 12.6.3 Resource create

Called exactly once per resource instance, so there is no prior state to reconcile. Read the **plan** (not the config), create, then write *everything the server returned* back into the model:

```go
resp.Diagnostics.Append(req.Plan.Get(ctx, &data)...)

post, err := r.client.PostStatus(context.Background(), &mastodon.Toot{
    Status:     data.Content.ValueString(),
    Visibility: data.Visibility.ValueString(),
    Sensitive:  data.Sensitive.ValueBool(),
})

p := bluemonday.NewPolicy()                                  // Mastodon wraps content in HTML
data.Id      = types.StringValue(string(post.ID))
data.Content = types.StringValue(p.Sanitize(post.Content))   // normalise, or drift forever
resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
```

Writing back fields that *already* had values looks redundant until you see the reason: it is how you find out the server changed your input. Which leads to the chapter's most transferable lesson:

!!! warning "Normalise server-modified values, in every function, or you get permanent drift"
    Mastodon returns the post content wrapped in HTML, so what comes back never equals what went in. Left alone, that mismatch is **eternal state drift** — a diff on every plan, forever, with nothing the user can do about it. The fix here is `bluemonday` stripping the HTML, applied identically in `Create`, `Read` and `Update`. Miss it in *one* of the three and the drift comes back through that path. This is the provider-side origin of the "always detected changes" pathology from [Ch5](05-terraform-plan.md) — as a provider author you are on the causing end of it.

### 12.6.4–12.6.6 Read, update, delete

- **`Read`** is the data source `Read` with `req.State` as its source instead of `req.Config`, looking the object up by the stored ID. Same normalisation.
- **`Update`** reads the **plan**, calls `UpdateStatus` with the existing ID, and writes the response back. It only ever runs on a resource that exists.
- **`Delete`** reads the state, calls `DeleteStatus(id)`, and returns. No state write — the framework removes the object once the function completes without error.

### 12.6.7–12.6.8 Registration and testing

Register the constructor in `Resources`, `go install`. Then the test, which shows why resources need multiple steps:

```go
Steps: []resource.TestStep{
    {Config: testAccPostResourceConfig("First Test Post"), Check: /* content + default visibility */},
    {ResourceName: "mastodon_post.test", ImportState: true, ImportStateVerify: true},
    {Config: testAccPostResourceConfig("Post After Update"), Check: /* new content */},
}
```

Create → import → update, in one case, with cleanup handled for you. And rather than hardcoding a config string per variant, generate it:

```go
func testAccPostResourceConfig(content string) string {
    return fmt.Sprintf(`resource "mastodon_post" "test" { content = %[1]q }`, content)
}
```

`%[1]q` is the detail worth keeping — `%q` quotes and escapes the value into valid HCL, so a post containing a quotation mark does not produce a broken configuration.

---

## 12.7 Functions

Provider-defined functions take arguments, transform them, return a result. No client, no state, no CRUD — which makes them the simplest thing in the chapter. Three methods: `Metadata`, `Definition`, `Run`.

```go
// Definition: a schema, but simpler — summary, description, parameters, return type.
resp.Definition = function.Definition{
    Summary:    "Identity function",
    Parameters: []function.Parameter{
        function.StringParameter{Name: "username", MarkdownDescription: "The username to generate the identity from."},
        function.StringParameter{Name: "server",   MarkdownDescription: "The server the user is hosted on."},
    },
    Return: function.StringReturn{},
}

// Run: load arguments, transform, set result — each step through ConcatFuncErrors.
resp.Error = function.ConcatFuncErrors(req.Arguments.Get(ctx, &username, &server))
if resp.Error != nil { return }
resp.Error = function.ConcatFuncErrors(resp.Result.Set(ctx, "@"+username+"@"+server))
```

Register the constructor in the provider's `Functions`, and users call it as **`provider::mastodon::identity("tedivm", "hachyderm.io")`** — the `provider::` namespace, then the provider's *local* name, then the function.

A compatibility note the chapter gets right: **an older Terraform simply ignores the functions in your provider** and errors only if someone calls one. Shipping functions does not fork your provider's support matrix.

### 12.7.4 Testing functions

Counterintuitively the fiddliest tests in the chapter, because there are more cases than a happy path: known values, **null** arguments, and **unknown** arguments. Use `resource.UnitTest` (no `PreCheck` needed — nothing external is touched), and gate on the engine version:

```go
TerraformVersionChecks: []tfversion.TerraformVersionCheck{tfversion.SkipBelow(tfversion.Version1_8_0)},
```

Functions store nothing in state, so assertions go through an **output**: `resource.TestCheckOutput("test", "@tedivm@hachyderm.com")`. The null case asserts a diagnostic instead, with `ExpectError: regexp.MustCompile("argument must not be null")`. The unknown case is the interesting one — it needs a real dependency to make the value unknown at plan time, and reaches for `terraform_data` to get one:

```hcl
resource "terraform_data" "test" { input = "tedivm" }
output "test" { value = provider::mastodon::identity(terraform_data.test.output, "hachyderm.com") }
```

Same trick as [Ch10 §10.5](10-advanced-topics.md) and [Ch11 §11.1.4](11-alternative-interfaces.md#1113-init-and-1114-testing): a state-only resource is the cheapest way to manufacture an unknown value.

!!! info "OpenTofu — functions arrived a release *earlier*, and support provider aliases"
    Provider-defined functions landed in **OpenTofu 1.7.0**, ahead of Terraform's 1.8. The 1.7.0 changelog credits [opentofu#1439](https://github.com/opentofu/opentofu/pull/1439) ("Integrate provider functions", commit `b868012192`). So `tfversion.SkipBelow(tfversion.Version1_8_0)` is the correct gate for Terraform and conservative for OpenTofu.

    A real syntax divergence shipped in the same release. A second PR, [opentofu#1491](https://github.com/opentofu/opentofu/pull/1491) ("Allow configured providers to provide additional functions", commit `a69d19d9f3`, also contained in `v1.7.0`), added `internal/addrs/provider_function.go` with a **`ProviderAlias`** field and the four-segment form `provider::<name>::<alias>::<function>` — functions from an *aliased* provider configuration. Terraform has no equivalent: `internal/lang/functions.go` at `v1.15.8` builds exactly one name per function, `fmt.Sprintf("provider::%s::%s", providerLocalName, funcName)`, and anything else falls through to its "Unknown provider function" diagnostic. Alias-qualified calls are OpenTofu-only, so keep them out of code meant to run on both.

---

## 12.8 Publishing

### 12.8.1 Updating documentation

`go generate` runs **`tfplugindocs`**, which reads your schemas — including every `MarkdownDescription` — and generates docs for the provider and all of its types. Same division of labour as `terraform-docs` in [Ch7](07-code-quality-ci.md): the tool writes the reference, **you** still write the examples. Anything under `examples/`, following the layout in `examples/README.md`, gets folded into the generated pages. Wiring this into `pre-commit` keeps the docs from drifting.

### 12.8.2 Creating a GPG key

Both registries require signed releases; the key pair is created once and reused for every provider you publish.

```bash
gpg --full-generate-key
```

Choose **RSA and RSA**, key size **4096**, accept the defaults, then supply a name/company and email. Record the **USER-ID**, and store the passphrase somewhere safe. Export both halves:

```bash
gpg --armor --export "USER-ID" > public.pem
gpg --armor --export-secret-keys "USER-ID" > private.pem
```

The template's release workflow expects the private key as the GitHub secret **`GPG_PRIVATE_KEY`** and its passphrase as **`PASSPHRASE`**.

> 📌 The registry's actual rule is slightly wider than "RSA only": HashiCorp's publishing docs say it accepts **RSA and DSA keys, but not the default ECC type** — so ECDSA and Ed25519 are out, and RSA remains the safe choice the chapter recommends.

### 12.8.3 Registering the provider

This is where the two ecosystems genuinely differ, and the chapter documents both. Re-verified 2026-08-16:

- **Terraform Registry** — add the ASCII-armored public key under **User Settings → Signing Keys** on `registry.terraform.io` (your own namespace, or an organization you administer), then **Publish → Provider** and point it at the repository. New releases then appear automatically.
- **OpenTofu Registry** — submissions go through **GitHub issue forms** on [`opentofu/registry`](https://github.com/opentofu/registry): one form for the signing key, one for the provider. The README is emphatic that this is the only accepted route — no pull requests, no `gh` CLI, no hand-written issues — because the validation automation parses the structured form data. The OpenTofu team then approves or denies.

### 12.8.4 Creating a release

Tag a semantic version through GitHub Releases and the template's `.github/workflows/release.yml` does the rest: it reads `.goreleaser.yml`, cross-compiles every architecture, signs, and uploads the artifacts. Those are what `terraform init` downloads.

For the record, what a release must contain: the per-platform zips, a `_manifest.json` declaring the protocol version, a `SHA256SUMS` file, and a **binary (not ASCII-armored)** `SHA256SUMS.sig`. GoReleaser produces exactly that set, which is the reason to use the template's workflow rather than assembling it by hand.

---

## Summary

- **Design the HCL first.** A provider's blast radius is every module that uses it, so the interface — resources, data sources, functions — is the thing to get right before any Go exists.
- **Start from the scaffolding template**, but treat its cleanup list as version-specific: the `go:generate` directives now live in `tools/tools.go`, and one of them depends on the `.copywrite.hcl` the chapter tells you to delete.
- **`dev_overrides` + `go install` is the whole local loop.** Keep `direct {}` or you lose every other provider; expect `init` to fail and `apply` to work. On OpenTofu the file is `.tofurc` unless no `.tofurc` exists.
- **Schemas are typed contracts with three booleans.** At least one of `Required`, `Optional`, `Computed` must be true; `Default` needs `Computed` and exists only on resource schemas, never on provider ones.
- **Collect diagnostics, never `Fatal`.** Validate every attribute, append every error, check `HasError()` once. A dead plugin process returns no errors and can corrupt state.
- **Read from the right source:** `req.Config` in a data source, `req.Plan` in create/update, `req.State` in read/delete.
- **Normalise anything the server rewrites, in all three of create/read/update** — that, not the API call, is what separates a provider from a drift generator.
- **Test with the real binary.** `resource.Test` for anything touching the service (gated on `TF_ACC=1`, `make testacc`), `resource.UnitTest` for functions, `ComposeAggregateTestCheckFunc` so one failure does not hide the rest.
- **Publishing is signing.** One RSA key, reused forever; Terraform takes it through the registry web UI, OpenTofu through issue forms on `opentofu/registry`.
- **The interface has outgrown the chapter.** Ephemeral resources, write-only attributes, resource identity, list resources, actions and state stores all arrived after it — and the last two are Terraform-only today.
- **Verify listings before typing them.** In this chapter: a provider `Default` that has no field to live in, a data source where nothing is `Computed`, `make acctest`, `port_resource.go`, and a `status` parameter that is really called `content`.

---

## References

- The chapter's provider — <https://github.com/TerraformInDepth/terraform-provider-mastodon>
- Scaffolding template — <https://github.com/hashicorp/terraform-provider-scaffolding-framework>
- Terraform Plugin Framework — <https://developer.hashicorp.com/terraform/plugin/framework> · <https://pkg.go.dev/github.com/hashicorp/terraform-plugin-framework>
- Plugin testing framework — <https://developer.hashicorp.com/terraform/plugin/testing> · state checks: <https://developer.hashicorp.com/terraform/plugin/testing/acceptance-tests/state-checks>
- `tfplugindocs` — <https://github.com/hashicorp/terraform-plugin-docs>
- `corefunc`, the functions-only provider — <https://github.com/northwood-labs/terraform-provider-corefunc>
- Publishing providers (Terraform) — <https://developer.hashicorp.com/terraform/registry/providers/publishing>
- OpenTofu registry submissions — <https://github.com/opentofu/registry>
- CLI configuration and `dev_overrides` — <https://developer.hashicorp.com/terraform/cli/config/config-file>
- `mattn/go-mastodon` (client library) · `microcosm-cc/bluemonday` (HTML sanitiser)
- Engine version state — [[version-facts]]
