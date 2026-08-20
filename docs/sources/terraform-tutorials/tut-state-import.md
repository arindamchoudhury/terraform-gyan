# Import Terraform configuration

> **Source:** [developer.hashicorp.com/terraform/tutorials/state/state-import](https://developer.hashicorp.com/terraform/tutorials/state/state-import)
> **Added:** 2026-08-20
> **Source updated:** undated tutorial (~18 min); captured 2026-08-20
> **Tags:** import-block, config-driven-import, generate-config-out, state, docker-provider, terraform-1.5, adoption
> **Type:** documentation

First page of the **State** collection. The one tutorial that runs *backwards* through the workflow: infrastructure exists first, and the configuration and state have to be made to describe it. `git clone https://github.com/hashicorp-education/learn-terraform-import`. Requires Terraform **v1.5+** and a running Docker daemon; both Community Edition and HCP Terraform variants captured.

The example resource is a Docker container, so there is **no cloud account and no cost** — the same property that makes [[tut-cloud-migrate]] cheap to run.

## Why config-driven import replaced the command

The page states the version boundary plainly:

> As of Terraform 1.5, you can use configuration to import existing resources into your state file with the plan-and-apply workflow.

The `terraform import` command still works. Three reasons the tutorial gives for preferring the block:

- it is **safer** — the import goes through `plan`, so you preview it before state changes;
- it **works with CI/CD pipelines**, because nothing is typed at a terminal;
- it can **generate an initial configuration** for the resources you adopt.

This matters against [[tf-state-purpose]]'s one-to-one mapping rule. `terraform import` is one of the two operations that page names as breaking the binding between config, state and remote object. Config-driven import restores the ordinary three-way plan as the thing that decides what happens.

The five steps, in the page's order:

1. Identify the existing infrastructure to import.
2. Define an `import` block for the resources.
3. Run `terraform plan` to review the import plan, optionally generating configuration.
4. **Prune** the generated configuration to only the required arguments.
5. Apply, bringing the resource into state.

## Create something to adopt

```shell
docker run --name hashicorp-learn --detach --publish "0.0.0.0:8080:80" nginx:latest
docker ps --filter="name=hashicorp-learn"
```

The container serves the NGINX default page at `localhost:8080`. Nothing about it is known to Terraform.

The repository splits configuration across three files: `terraform.tf` (Terraform and provider versions), `main.tf` (the Docker provider), and `docker.tf`, which starts empty and holds everything you write.

## The `import` block

Two required arguments:

- **`id`** — the *provider-specific* identifier for the existing infrastructure;
- **`to`** — the address Terraform will give the resource in state, as resource type plus name.

Get the container's full SHA256 ID, then write the block:

```shell
docker inspect --format="{{.ID}}" hashicorp-learn
```

```hcl
import {
  id = "FULL_CONTAINER_ID"
  to = docker_container.web
}
```

!!! note "The `id` format is per-resource, and only the provider docs know it"
    > The identifier you use for the `id` argument in the import block is resource-specific. You can find the required ID in the provider documentation for the resource you wish to import.

    A Docker container wants a full SHA256; an S3 bucket wants its name; an IAM role wants its name, not its ARN. There is no general rule to learn, only a per-resource lookup.

The `to` side is an address, and an address **is** an identity in state — the same fact [[tut-move-config]] builds its whole tutorial on. Import is that relationship established for the first time; `moved` is it being renamed.

## Generating configuration

Importing needs two things, not one: the object in state, **and** a matching `resource` block in configuration. You may write the block by hand. `-generate-config-out` writes a first draft instead:

```shell
terraform plan -generate-config-out=generated.tf
```

```text
docker_container.web: Preparing import... [id=72d53edc...]
docker_container.web: Refreshing state... [id=72d53edc...]

  # docker_container.web must be replaced
  # (imported from "72d53edc...")
  # Warning: this will destroy the imported resource
-/+ resource "docker_container" "web" {
      ## ...
      + env               = (known after apply) # forces replacement
      ## ...
    }

Plan: 1 to import, 1 to add, 0 to change, 1 to destroy.

Terraform has generated configuration and written it to generated.tf. Please
review the configuration and edit it as necessary before adding it to version
control.
```

Two things happened at once, and both matter.

**The generated file is a draft, not an answer.** The page is explicit about its shape:

> The generated configuration contains all possible arguments for the imported resources, including those set to default values and those without values. We recommend that you prune the generated configuration to only required arguments and arguments whose values differ from defaults, to reduce the size of your configuration.

**The first plan is destructive.** `1 to destroy` on a resource you are adopting is exactly the outcome import exists to avoid.

## The `env = null` trap

The cause is one line of the generated file:

```hcl
# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "371e85d4..."
resource "docker_container" "web" {
## ...
  env  = null
## ...
}
```

The provider's schema types `env` as a **set of strings**. `null` is not an empty set, so the plan reads it as a change, and `env` forces replacement. Fix it with an empty set:

```hcl
env = []
```

This is the generalizable lesson of the tutorial: the generated configuration reproduces the provider's *null* defaults, and a null is not always the same as the resource's real current value. Check any generated attribute that forces replacement against the resource schema.

## Prune to what the resource actually needs

`image` and `name` are required by the schema. The port mapping was set at `docker run`, so a matching `ports` block is required too, or the plan would propose removing it.

```hcl
resource "docker_container" "web" {
  env   = []
  image = "..."
  name  = "hashicorp-learn"
  ports {
    external = 8080
    internal = 80
    ip       = "0.0.0.0"
    protocol = "tcp"
  }
}
```

Re-plan:

```text
  # docker_container.web will be updated in-place
  # (imported from "72d53edc...")
  ~ resource "docker_container" "web" {
      + attach                                      = false
      + container_read_refresh_timeout_milliseconds = 15000
      + logs                                        = false
      + must_run                                    = true
      + remove_volumes                              = true
      + start                                       = true
      + wait                                        = false
      + wait_timeout                                = 60
    }

Plan: 1 to import, 0 to add, 1 to change, 0 to destroy.
```

`1 to import, 0 to add, 1 to change, 0 to destroy` — the shape you want before applying an adoption.

Those eight added attributes are non-destructive, and the reason is specific:

> Terraform uses these attributes to create Docker containers, but Docker does not store them. Since Docker does not track these attributes, Terraform did not include them in the generated configuration. When you apply your configuration, the Docker provider will assign the default values for these attributes and save them in state, but they will not affect the running container.

So the generated draft omits attributes the remote API cannot report, and the apply fills them in as state-only values.

!!! warning "Nothing in the plan tells you which changes are safe"
    > Provider documentation may not indicate if a change is safe. You must understand the lifecycle of the underlying resource to know if a given change is safe to apply.

    Terraform prints `~ update in-place` for both a harmless default and a change that restarts a database. The judgement is yours, and it needs knowledge of the resource that neither the plan nor the provider docs supply.

## Import and modify in one apply

The stated recommendation:

> When importing a resource, we recommend limiting any destructive changes and making the first operation on the resource a no-op.

Config-driven import does not enforce that, and the tutorial deliberately demonstrates the other path — change the external port to `8081` before the first apply:

```hcl
ports {
  external = 8081
  internal = 80
  ip       = "0.0.0.0"
  protocol = "tcp"
}
```

```text
  # docker_container.web must be replaced
  # (imported from "76fc3728...")
  # Warning: this will destroy the imported resource
-/+ resource "docker_container" "web" {
      ~ ports {
          ~ external = 8080 -> 8081 # forces replacement
        }
    }

Plan: 1 to import, 1 to add, 0 to change, 1 to destroy.
```

Applying imports the container, destroys it, and creates a replacement — a new container ID, reachable at `localhost:8081`:

```text
docker_container.web: Import complete [id=76fc3728...]
docker_container.web: Destroying... [id=76fc3728...]
docker_container.web: Creating...
docker_container.web: Creation complete after 0s [id=c30d6bc7...]

Apply complete! Resources: 1 imported, 1 added, 0 changed, 1 destroyed.
```

Import and destroy in the same run is legal, which is precisely why the recommendation exists. `terraform show` afterwards confirms configuration, state and container agree.

## Adopting a resource *without* an `import` block

Not everything needs importing:

> You can bring some resources under Terraform's management without using the import block. This is often the case for resources defined by a single unique ID or tag, such as Docker images.

The generated container config hardcodes the image's SHA256 hash, because that is how Docker stores it internally. A tag reads better. Declare the image as a resource:

```shell
docker image inspect -f {{.RepoTags}} `docker inspect --format="{{.Image}}" hashicorp-learn`
# [nginx:latest]
```

```hcl
resource "docker_image" "nginx" {
  name = "nginx:latest"
}
```

!!! danger "Apply the image resource *before* referencing it"
    > Do not replace the `image` value in the `docker_container.web` resource yet, or Terraform will destroy and recreate your container. Since Terraform did not yet load the `docker_image.nginx` resource into state, it does not have an image ID to compare with the hardcoded one, which will force replacement. The image resource must exist in state before you can reference it.

    Two applies, in order. First `terraform apply` creates `docker_image.nginx` (`1 to add`). Only then change the container:

    ```hcl
    image = docker_image.nginx.image_id
    ```

    Because the resolved ID matches the hardcoded one, the next apply is a clean **no-op** — "No changes. Your infrastructure matches the configuration."

This is the [[tut-dependencies]] rule in an adoption setting: a reference is only comparable once the referenced object is in state. Before that, Terraform has an unknown on one side of the diff, and unknown forces replacement.

!!! note "The no-op holds only while the tag points at the same digest"
    > If the image ID for the tag `nginx:latest` changes between the time you first create the Docker container and when you update the configuration to reference the new image, Terraform will destroy the container and then recreate it with the new image.

    A mutable tag is a moving target. Swapping a hash for a tag trades legibility for a replacement that can fire on someone else's push.

## Destroy, and what adoption committed you to

`terraform destroy` removes both — `Plan: 0 to add, 0 to change, 2 to destroy` — and `docker ps` comes back empty.

!!! warning "Import is a commitment to the whole lifecycle"
    > Since you added both the image and the container to your Terraform configuration, Terraform will remove both from Docker. If another container uses the same image, the destroy step will fail. Remember that importing a resource into Terraform means that Terraform will manage the entire lifecycle of the resource, including destruction.

    The exit is not symmetric with the entrance: leaving Terraform's management without destroying the object needs the `removed` block with `lifecycle { destroy = false }` — see [[tf-block-removed]] and [[tf-state-remove]], where the reverse trip is also named ("re-adopting the resource later requires an import").

## HCP Terraform variant

The `cloud` block replaces the local backend, and `init` creates the workspace:

```hcl
terraform {
  cloud {
    organization = "organization-name"
    workspaces {
      name = "learn-terraform-import"
    }
  }

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.2.0"
    }
  }

  required_version = "~> 1.5"
}
```

One extra step this tutorial needs and [[tut-cloud-migrate]] does not: the resource is a **container on your laptop**, which HCP's remote runners cannot reach. Set **Execution Mode → Local** in the workspace's General settings and save. Operations then run on your machine while the state file lives in HCP Terraform, keeping versioning and collaboration. Delete the workspace after destroying.

That is a general rule for adoption work, not a Docker quirk. Remote execution can only import what the runner can reach.

## Limitations the page states

Terraform import works from **the current state of the infrastructure as the provider reports it**, so it cannot determine:

- the health of the infrastructure;
- the intent of the infrastructure;
- changes outside Terraform's control, such as the state of a container's filesystem.

And the rest of the list:

- Importing involves **manual, error-prone steps**, especially when the operator lacks context about the infrastructure's purpose and history. Review plan output carefully to avoid destructive changes.
- Importing **manipulates the state file during apply**. Consider taking a backup first.
- Import **does not detect or generate relationships** between infrastructure. Add them to the configuration by hand before applying.
- Import **does not detect which default attributes you can skip setting** — hence the pruning step.
- **Not all providers and resources support import.**
- An imported resource is **not necessarily one Terraform can destroy and recreate**; it may depend on unmanaged infrastructure or configuration.

Following IaC practices such as immutable infrastructure prevents many of these.

## What the tutorial does not cover

The page is a Terraform 1.5 tutorial and stops at the 1.5 feature set. Three later additions belong to this workflow and are recorded elsewhere:

- **`for_each` on `import` blocks** (TF/OpenTofu 1.7) — adopt many similar resources from a map instead of writing a block each.
- **`identity` instead of `id`** (Terraform 1.12) — mutually exclusive with `id`, for providers that identify an object by a structured identity rather than one opaque string.
- **`terraform query` and list resources** (Terraform 1.14) — enumerating what a provider can see, which is the discovery step this tutorial performs by hand with `docker inspect`.

See [[feature-history]] for all three.

---
Related: [[tf-state-purpose]] — names `terraform import` as one of the two operations that break the one-to-one mapping; this tutorial is the config-driven replacement that keeps the plan in charge. · [[tut-move-config]] — the other half of address-as-identity: import creates the binding, `moved` renames it. · [[tf-state-remove]] · [[tf-block-removed]] — the exit path, and why re-entry needs an import. · [[tut-dependencies]] — why a reference to a not-yet-created resource is unknown, and unknown forces replacement. · [[tut-cloud-migrate]] — the sibling HCP tutorial; this one additionally needs Local execution mode. · [[feature-history]] — the post-1.5 import features this page predates.
