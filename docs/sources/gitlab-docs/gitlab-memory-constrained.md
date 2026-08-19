# Running GitLab in a memory-constrained environment

> **Source:** [docs.gitlab.com/omnibus/settings/memory_constrained_envs](https://docs.gitlab.com/omnibus/settings/memory_constrained_envs/)
> **Added:** 2026-08-18
> **Source updated:** undated; captured 2026-08-18 (docs 19.3 upcoming / 19.2 current)
> **Tags:** gitlab, self-managed, memory, puma, sidekiq, gitaly, jemalloc, swap, omnibus, lab-infrastructure
> **Type:** documentation

Captured for one practical reason: it decides whether a **self-hosted GitLab is runnable as a lab** beside the book's other containers, which in turn decides whether [[gitlab-tf-state]] can be exercised without a gitlab.com account. The answer is yes, and by a wide margin — but only because this page contradicts the headline requirements page.

> "Tier: Free, Premium, Ultimate · Offering: GitLab Self-Managed"

Scope stated up front, and worth respecting: the settings below target *"up to 5 developers with individual Git repositories no larger than 100 MB"*, and GitLab warns you *"may experience unexpected degradation of both product functionality and performance."*

!!! danger "📌 The two requirement pages disagree by a factor of four"
    [Installation requirements](https://docs.gitlab.com/install/requirements/) says: *"For a single-node installation, **16 GB** is the baseline… For single-node installations in memory-constrained environments, GitLab can run with at least **8 GB** of memory. For more information, see running GitLab in a memory-constrained environment."*

    That link lands here, and this page says the minimum is:

    > "Minimum **2 GB of RAM + 1 GB of SWAP**, optimally 2.5 GB of RAM + 1 GB of swap"

    Both captured 2026-08-18. The 8 GB figure is the one people quote when they conclude GitLab cannot be run locally; the page it points at says 2 GB. Take the lower number as what the tuned configuration actually needs — the page backs it with a measured `free -h` at the end — and the 8 GB as the untuned single-node figure.

## The floor

- Linux-based system, ideally Debian- or RedHat-based
- **4 ARM7/ARM64 cores, or 1 AMD64 core**
- **2 GB RAM + 1 GB swap** (2.5 GB + 1 GB preferred)
- **20 GB** available storage
- Storage with good **random I/O** — SSD, then eMMC, then HDD, then a high-performance A1 SD card

> "Of the above list, the single-core performance of the CPU and the random I/O performance of the storage have the highest impact."

Named systems that work: Raspberry Pi 4 2 GB, DigitalOcean Basic 2 GB with SSD, Scaleway DEV1-S, GCS e2-small.

!!! note "Swap is expected, not a fallback"
    > "With these minimal settings, the system should use swap during regular operation. Since not all components are used at the same time, it should provide acceptable performance."

    GitLab's argument is that much of what it allocates is rarely touched, so paging it out costs little. Guideline: swap ≈ 50% of RAM, at least 1 GB, and lower the kernel's eagerness with `vm.swappiness=10`.

    This is the opposite of the advice on the main requirements page — *"Disable swap where possible"* — because that page is sizing for throughput and this one for survival. Note the contradiction rather than picking a side blind.

## The tuning, and what each item buys

Everything goes in `/etc/gitlab/gitlab.rb`, or — for a container — into `GITLAB_OMNIBUS_CONFIG`, which takes the same Ruby lines.

**Choose CE over EE.** *"When memory consumption is the primary concern, install GitLab CE. You can always upgrade to GitLab EE later."*

**Puma — single process.** Clustered mode is built for concurrency you do not have:

```ruby
puma['worker_processes'] = 0
```

> "We observed **100-400 MB** of memory usage reduction with this optimization."

**Sidekiq — cut concurrency from the default 20:**

```ruby
sidekiq['concurrency'] = 10
```

**Gitaly — cap parallelism:**

```ruby
gitaly['configuration'] = {
    concurrency: [
      { 'rpc' => "/gitaly.SmartHTTPService/PostReceivePack", 'max_per_repo' => 3 },
      { 'rpc' => "/gitaly.SSHService/SSHUploadPack",         'max_per_repo' => 3 },
    ],
}

gitaly['env'] = {
  'GITALY_COMMAND_SPAWN_MAX_PARALLEL' => '2'
}
```

**Disable the monitoring stack** — ten switches, and the biggest single win after Puma:

```ruby
alertmanager['enable'] = false
gitlab_exporter['enable'] = false
gitlab_kas['enable'] = false
node_exporter['enable'] = false
postgres_exporter['enable'] = false
prometheus_monitoring['enable'] = false
prometheus['enable'] = false
puma['exporter_enabled'] = false
redis_exporter['enable'] = false
sidekiq['metrics_enabled'] = false
```

> "We observed **300 MB** of memory usage reduction configuring GitLab this way."

**Make jemalloc give memory back.** GitLab Rails and Gitaly are the two large consumers, and jemalloc holds freed chunks by default:

```ruby
gitlab_rails['env'] = {
  'MALLOC_CONF' => 'dirty_decay_ms:1000,muzzy_decay_ms:1000'
}
```

The same `MALLOC_CONF` goes on `gitaly['env']`. The claimed effect is stability rather than a number: *"We observed much more stable memory usage during the execution of the application."*

**Then, in the UI**, *Admin › Settings › Metrics and profiling › Metrics - Prometheus*, disable **Enable Prometheus Metrics** — the in-application half of the monitoring that the switches above turned off at the process level.

Apply with `sudo gitlab-ctl reconfigure`, and expect it to be slow: *"This operation could take a while, since GitLab did not work with memory conservative settings up-to this point."*

## The measured result

```
              total        used        free      shared  buff/cache   available
Mem:          1.9Gi       1.7Gi       151Mi        31Mi       132Mi       102Mi
Swap:         1.0Gi       153Mi       870Mi
```

A 2 GB machine running GitLab with 153 MB of swap in use. That is the number to size a container against — allow ~2.5 GB and it is comfortable.

!!! note "Reading this for a container rather than a VM"
    The page is written for the Linux package on a host, but the `gitlab/gitlab-ce` image is the same omnibus stack, and the [Docker installation docs](https://docs.gitlab.com/install/docker/installation/) pass exactly these settings through `GITLAB_OMNIBUS_CONFIG` in `docker-compose.yml`, alongside `shm_size: '256m'` and volumes for `/etc/gitlab`, `/var/log/gitlab` and `/var/opt/gitlab`. Two things do not transfer directly: swap belongs to the **host or the Docker VM**, not the container (on Docker Desktop for Windows that is `.wslconfig`), and `vm.swappiness` is a host kernel setting.

---
Related: [[gitlab-tf-state]] — the reason to run one of these at all: the state backend it documents needs a real GitLab. · [[tf-backend-http]] — the protocol underneath that feature, which a lab can also exercise without any GitLab at all.
