# Install Terraform (AWS Get Started)

> **Source:** [developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
> **Added:** 2026-07-04
> **Source updated:** undated tutorial (~7 min); captured 2026-07-04
> **Tags:** install, cli, package-manager, setup, getting-started
> **Type:** documentation

First lesson of the AWS "Get Started" track. Installs the Terraform CLI, verifies it, and turns on shell completion. Terraform ships as a single binary; you can install it via a package manager or by hand.

> 📌 **Version note:** The page doesn't pin a version. Current stable is Terraform CLI **1.15.7** as of 2026-07-04 (see [[version-facts]]). HashiCorp's compatibility promise means config written for one version keeps working on later minor versions.

## Install Terraform

Distributed as an executable CLI for Windows, macOS, and several Linux distros. Can also be compiled from source if no pre-compiled binary exists. Two routes: a package manager, or manual install.

### Package manager

**Homebrew (macOS)** — add the HashiCorp tap, then install:

```shell
$ brew tap hashicorp/tap
$ brew install hashicorp/tap/terraform
```

**Chocolatey (Windows):**

```shell
$ choco install terraform
```

> ⚠️ HashiCorp does **not** maintain the Chocolatey package. (Note the licensing angle from [[terraform-intro]]/Ch1 context: post-BSL, community package managers may lag or stop shipping newer Terraform — Homebrew caps at v1.5.7. This tutorial's `hashicorp/tap` is HashiCorp's own, so it stays current.)

**Linux (Ubuntu/Debian)** — HashiCorp maintains signed packages; add the GPG key + apt repo:

```shell
$ sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
$ wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
$ echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
$ sudo apt update
$ sudo apt-get install terraform
```

RHEL/CentOS and Amazon Linux use `yum-config-manager --add-repo https://rpm.releases.hashicorp.com/...` then `yum -y install terraform`; Fedora uses `dnf config-manager` + `dnf -y install terraform`.

### Manual installation

**Pre-compiled binary** — download the zip for your OS, unzip, and put the single `terraform` executable on your `PATH` (other files in the archive can be deleted).

```shell
$ echo $PATH                              # list PATH locations (macOS/Linux)
$ mv ~/Downloads/terraform /usr/local/bin/
```

On Windows, list `PATH` with `path` and move the binary into one of the listed dirs.

**Compile from source:**

```shell
$ git clone https://github.com/hashicorp/terraform
$ cd terraform
$ go install                              # binary lands in $GOPATH/bin/terraform
```

## Terraform versions and compatibility

HashiCorp releases new versions regularly and maintains compatibility: a config written for one version should keep working on any later **minor** version update. See the "Terraform compatibility promise" for detail.

## Verify the installation

Open a new terminal and list the subcommands:

```shell
$ terraform -help
Usage: terraform [global options] <subcommand> [args]
```

Add `-help` to any command for its options, e.g. `terraform plan -help`.

## Enable tab completion

For Bash or Zsh, ensure a shell config file exists, then install completion:

```shell
$ touch ~/.bashrc                 # or the Zsh equivalent
$ terraform -install-autocomplete
```

Restart the shell afterward to enable it.

## Next steps

The AWS Get Started track continues with **Create** (provision infrastructure). Sibling Get Started tracks exist for Azure, Google Cloud, Docker, and OCI — same tutorial flow, different provider.

---
Related: this is the hands-on companion to [[terraform-intro]] (the conceptual intro). Feeds learning-path topic **B2 — Install, providers & your first project**. The BSL-vs-package-manager wrinkle is the practical side of the OpenTofu fork story in [[01-brief-overview]] §1.6.6.
