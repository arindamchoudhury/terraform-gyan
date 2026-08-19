# Chapter 15 — the backend-credential leak

Evidence for Chapter 15, section 11, *Backend configuration leaks harder than provider configuration*.

The two strings in `config.leak.tfbackend` are **canaries**, not credentials. A canary is a fake value planted so it can be searched for afterwards: `AKIALEAKCANARY01` has the shape of a real AWS access key ID (the `AKIA` prefix, 20 characters) so ordinary secret scanners react to it the way they would to the real thing, and `s3cr3t-canary-value-9f2a` carries a random suffix so a hit cannot be a coincidence.

## Run it

The bucket comes from Lab 2's bootstrap, so run that first if `tf-state-lab` does not exist yet.

```bash
source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"
cd labs/chapter15/leak

terraform init -backend-config=config.leak.tfbackend
terraform plan -out=tfplan

grep -c AKIALEAKCANARY01 tfplan                                    # 0 — the false negative
python scan-plan.py tfplan AKIALEAKCANARY01 s3cr3t-canary-value-9f2a
grep -o 'AKIALEAKCANARY01' .terraform/terraform.tfstate            # plaintext, every time
```

Then the control, which is the documented fix:

```bash
export AWS_ACCESS_KEY_ID=AKIALEAKCANARY01
export AWS_SECRET_ACCESS_KEY=s3cr3t-canary-value-9f2a
terraform init -reconfigure -backend-config=config.env.tfbackend
terraform plan -out=tfplan-env
python scan-plan.py tfplan-env AKIALEAKCANARY01 s3cr3t-canary-value-9f2a
```

Nothing is ever applied, so there is nothing to destroy. Clean up with `rm -rf .terraform tfplan tfplan-env`.

## Files

| File | |
| --- | --- |
| `main.tf` | empty `backend "s3" {}`, so the configuration file itself never sees the canaries |
| `config.leak.tfbackend` | the leaking case: credentials passed with `-backend-config` |
| `config.env.tfbackend` | the control: same backend, credentials left to the environment |
| `main.tf.inline` | variant with the canaries hardcoded in the configuration file |
| `scan-plan.py` | unzips a plan file and searches each entry separately |

## Measured

Terraform 1.15.8 and OpenTofu 1.12.5, against the lab emulator. Both leak identically.

| | raw `grep` of the plan | `tfplan` entry | `.terraform/terraform.tfstate` |
| --- | --- | --- | --- |
| `-backend-config` | nothing | **both canaries** | **both canaries** |
| hardcoded in `main.tf` | nothing | **both canaries**, plus `tfconfig/m-/main.tf` | **both canaries** |
| environment variables | nothing | clean | clean |
