# State and Plan Encryption

> **Source:** [opentofu.org/docs/language/state/encryption](https://opentofu.org/docs/language/state/encryption/)
> **Added:** 2026-08-19
> **Source updated:** undated language reference; captured 2026-08-18 against OpenTofu 1.12.x, re-fetched 2026-08-19 byte-identical
> **Tags:** opentofu, state-encryption, plan-encryption, encryption-block, key-provider, aes-gcm, pbkdf2, kms, openbao, fallback, migration
> **Type:** documentation

*The OpenTofu Language › State › State and Plan Encryption*

**The largest single divergence from Terraform in this collection, and Terraform has no equivalent at any version.** Terraform's answer to secrets in state is to restrict who can read the bucket ([[tf-remote-state-data]], [[tf-manage-sensitive-data]]). OpenTofu's is to encrypt the artifacts themselves.

Scope is wider than the name suggests. It covers state, **plan files**, and **`terraform_remote_state` reads**, for local storage and every backend. Introduced in OpenTofu **1.7**; the version-by-version growth is in [[opentofu-release-feature-map]].

## Read the threat model before adopting

The page leads with limits rather than features, and the limits are the part that decides whether this solves your problem.

!!! danger "Three things it explicitly does not do"
    > "encryption **does not protect against data loss** (your state file getting damaged) and it also **does not protect against replay attack** (an attacker using an older state or plan file and tricking you into running it). Additionally, OpenTofu **does not and cannot protect the sensitive values in the state file from the person running the `tofu` command**."

    So it is at-rest protection against someone who obtains the file. It is not integrity, not freshness, and not protection from the operator. That third clause matters most for the case people reach for this in: it does **not** let you hand state access to someone you would not trust with the secrets inside it.

The page's own mitigation for the operator gap is organisational: "If you have more than a very small number of people with access needs, you may want to consider running your production plan and apply runs from a continuous integration system to protect both the encryption key and the sensitive values in your state."

**And the irreversibility warning is blunt.** "Once you enable encryption, OpenTofu cannot read your state file without the correct key." Before enabling: exercise the disaster-recovery plan, take a temporary backup of the unencrypted state, and back up the keys.

!!! warning "The support promise is +1 minor version"
    > "We will support all key providers and methods as documented for **+1 minor version**, but may introduce new versions of the same key providers and methods (e.g. `aes_gcm_v2`), or new key providers and methods in any minor version."

    Deprecation surfaces as a console warning on `tofu plan` or `tofu apply`, and the instruction is to switch **before** upgrading to the next version. A narrow window by the standards of the v1.x compatibility promises, and it is the reason to read release notes rather than let this configuration sit untouched for a year.

## The block

```hcl
terraform {
  encryption {
    key_provider "some_key_provider" "some_key_provider_name" {
      # Key provider options here
    }

    method "some_method_type" "some_method_name" {
      # Method options here
      keys = key_provider.some_key_provider.some_key_provider_name
    }

    state {
      # Encryption/decryption for state data
      method = method.some_method_type.some_method_name
    }

    plan {
      # Encryption/decryption for plan data
      method = method.some_method_type.some_method_name
    }

    remote_state_data_sources {
      # See below
    }
  }
}
```

Two layers, always. A **key provider** produces key material, a **method** does the cryptography with it, and `state`, `plan` and `remote_state_data_sources` each select a method. Nothing is encrypted by naming a key provider alone.

**The whole thing can live in an environment variable instead**, as bare HCL with no wrapping `terraform` or `encryption` block. The page gives a POSIX-shell here-document form and a PowerShell here-string form, both assigning the same body to `TF_ENCRYPTION`:

```powershell
$Env:TF_ENCRYPTION = @"
key_provider "some_key_provider" "some_name" {
  # Key provider options here
}

method "some_method_type" "some_method_name" {
  keys = key_provider.some_key_provider.some_name
}

state {
  method = method.some_method_type.some_method_name
}
"@
```

> "Both solutions are equivalent and if you use both, OpenTofu will merge the two configurations, **overriding any code-based settings with the environment ones**."

Environment wins on conflict. That is the CI shape: commit the structure, inject the key material at run time.

!!! tip "`enforced` is the guard against a missing environment variable"
    If the encryption configuration arrives by environment variable, an unset variable means OpenTofu writes plaintext and says nothing. The page's fix is to keep a stub in code:

    ```hcl
    terraform {
      encryption {
        state { enforced = true }
        plan  { enforced = true }
      }
    }
    ```

    This is a failure mode worth naming, because it is the encryption equivalent of `use_lockfile` defaulting to `false` in [[tf-backend-s3]]: configuration that looks present but silently is not.

!!! warning "Never rename a key provider or method after data is encrypted"
    > "The encrypted data stored in the backend contains **metadata related to their specific names**."

    Two escapes. Use a `fallback` block to move between them, or set `encrypted_metadata_alias` on the key provider up front, which pins the metadata key so the block's own name becomes free to change. The alias is also the answer when two projects need different local names for the same key, which the cross-project example below uses.

JSON syntax works too, in place of HCL.

## Migration is deliberately not seamless

**OpenTofu refuses to read plaintext once encryption is configured.** "Simply enabling encryption is not enough as OpenTofu will refuse to read plain text data. This is a protection mechanism to prevent OpenTofu from reading manipulated, unencrypted data."

So an existing project needs the **`unencrypted` method** as an explicit, temporary fallback. The method takes no configuration and exists only for this.

```hcl
terraform {
  encryption {
    method "unencrypted" "migrate" {}

    key_provider "pbkdf2" "my_key_provider_name" {
      passphrase = var.passphrase
    }

    method "aes_gcm" "my_method_name" {
      keys = key_provider.pbkdf2.my_key_provider_name
    }

    state {
      method = method.aes_gcm.my_method_name

      fallback {
        method = method.unencrypted.migrate
      }
      # Run "tofu apply", then remove the fallback block
      # and consider adding:
      # enforced = true
    }
  }
}
```

**Rolling back is the same manoeuvre reversed.** Keep the old method defined, add `method "unencrypted" "migrate" {}`, set `enforced = false`, move the old method into `fallback`, point `method` at the unencrypted one, apply, then delete the `state` block. The page's warning: "Do not remove or modify the original encryption method until you have finished the migration."

**A new project skips all of this.** Key provider, method, a `state` block naming the method, apply.

!!! note "Encryption config is resolved at `init`, before state exists"
    > "Variables and locals can be used in configuration, but **may not contain any references to data in the state or provider defined functions**. All values must be able to be resolved during `tofu init` before the state is available."

    Same evaluation phase as [[ot-early-eval-backend]], and the same reason: this configuration is needed to read state, so it cannot depend on state. Passing key material by variable is what OpenTofu 1.8 made possible at all.

## Key and method rollover

The `fallback` block is the general mechanism, not just a migration tool. It covers renaming a provider or method, changing a passphrase, and switching key-management systems.

```hcl
state {
  method = method.some_method.new_method_name
  fallback {
    method = method.some_method.old_method_name
  }
}
```

> "If OpenTofu fails to read your state or plan file with the new method, it will automatically try the fallback method. When OpenTofu saves your state or plan file, it will **always use the new method and not the fallback**."

Read with either, write with the new one. So one apply migrates the artifact, and the fallback can be deleted on the next change.

## Encrypting remote state reads

`remote_state_data_sources` configures the *consumer* side, and it can use different keys from the consumer's own state:

```hcl
remote_state_data_sources {
  default {
    method = method.method_type.my_method_name
  }
  remote_state_data_source "my_state" {
    method = method.method_type.my_other_method_name
  }
}
```

Targeting syntax: `myname` for a data source in the root, `mymodule.myname` inside a module, `mymodule.myname[0]` for an indexed one.

**The cross-project case is where `encrypted_metadata_alias` earns its place.** Project A encrypts its state with a key provider named `my_key_provider_name`, and project B wants to read it but already uses that name for something else. Both set `encrypted_metadata_alias = "certificates"`, and B is then free to call its provider `my_key_renamed`. Without the alias the metadata key is derived from the block name and the two would not match.

This is the piece Terraform has no analogue for at all. A `terraform_remote_state` read there is a plaintext fetch of a plaintext object ([[tf-remote-state-data]]).

## Key providers

| Provider | Key material from | Required options |
| --- | --- | --- |
| `pbkdf2` | a passphrase, derived locally | `passphrase` (min 16 chars) **or** `chain` |
| `aws_kms` | AWS KMS | `kms_key_id`, `key_spec` |
| `gcp_kms` | Google Cloud KMS | `kms_encryption_key`, `key_length` (1–1024) |
| `azure_vault` | Azure Key Vault | `vault_uri`, `vault_key_name`, `key_length` |
| `openbao` | OpenBao Transit Secret Engine | `key_name` |
| `external` | an external program (**experimental**) | `command` |

Every one of them accepts `encrypted_metadata_alias`.

**Authentication is inherited from the matching backend.** AWS KMS uses "authentication options … identical to the S3 backend excluding any deprecated options" ([[tf-backend-s3]]), and GCP KMS the same against the GCS backend ([[tf-backend-gcs]]). Azure Vault is the exception worth noting: "unlike the state backend, this key provider will **always use Entra ID**."

**PBKDF2 defaults** are `iterations = 600000` (minimum 200,000), `salt_length = 32`, `hash_function = "sha512"` with `sha256` the only alternative and `sha1` unsupported, and `key_length = 32`. Its `chain` option takes a passphrase from another key provider, which is how the experimental `external` provider is meant to feed it.

!!! warning "Azure Vault symmetric and asymmetric keys use different algorithms"
    An asymmetric RSA key means RSA-OAEP-256. A symmetric AES key means AES-GCM, and then `symmetric = true` plus `symmetric_key_size` (128, 192 or 256) are required and must match the key as created. Managed HSM only.

    The consequence is that a `fallback` does not work for this particular change: "OpenTofu will attempt to both encrypt and decrypt with the fallback; unlike other providers where a fallback is recommended, **this will fail if the key version changed**, because the fallback cannot encrypt with the now-current key version." Change the key provider **in place** instead.

!!! note "OpenBao's compatibility stops at Vault 1.14"
    > "The OpenBao key provider is compatible with the last MPL-licensed version of HashiCorp Vault (1.14) but **does not support the subsequent BUSL-licensed versions**."

    The licence split reaches into the feature. A shop on current Vault cannot point this at it.

## Methods

**`aes_gcm` is the only real one.** It needs a 16, 24 or 32-byte key, so the key provider must be configured to produce exactly that length.

!!! warning "Key saturation is the reason a static key is not enough"
    > "AES-GCM is a secure, industry-standard encryption algorithm, but suffers from “key saturation”. In order to configure a secure setup, you should either use a key-derivation key provider (such as PBKDF2) with a long and complex passphrase, or use a key management system that **automatically rotates keys** regularly. Using short, static keys will degrade your encryption."

    This is why the guidance section calls automatic key rotation "imperative" for some methods. A hard-coded 32-byte key in a `.tf` file is the configuration to avoid, and not only for the obvious reason that it is in the file.

`unencrypted` takes no configuration and exists for migration in both directions. `external` (experimental) runs `encrypt_command` and `decrypt_command`.

**Both `external` extension points are frozen by design**, and the page says so in the same words for the key provider and the method: with no feedback to act on, "for the foreseeable future … this will remain in the experimental phase." Each speaks a three-step stdin/stdout protocol opening with a magic header line, `{"magic":"OpenTofu-External-Key-Provider","version":1}` or `{"magic":"OpenTofu-External-Encryption-Method","version":1}`, with Go, Python and POSIX shell examples and a published JSON schema.

---
Related: [[ot-early-eval-backend]] — the same `init`-phase evaluation rule, and the 1.8 feature that made variables usable here. · [[opentofu-release-feature-map]] — which OpenTofu version added which key provider. · [[tf-manage-sensitive-data]] — Terraform's position on the same problem, which is access control rather than encryption. · [[tf-remote-state-data]] — the data source this page can encrypt and Terraform cannot. · [[tf-backend-s3]] · [[tf-backend-gcs]] — the backends whose authentication the KMS key providers reuse, and whose own server-side encryption this sits beneath rather than replaces. · [[tf-state-backends]] — where state lives once encrypted.
