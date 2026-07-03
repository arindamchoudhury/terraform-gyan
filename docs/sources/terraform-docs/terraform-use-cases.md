# Terraform Use Cases

> **Source:** [developer.hashicorp.com/terraform/intro/use-cases](https://developer.hashicorp.com/terraform/intro/use-cases)
> **Added:** 2026-07-03
> **Source updated:** covers Terraform v1.15.x (latest at capture)
> **Tags:** iac, terraform, use-cases, sentinel, kubernetes, hcp-terraform, sdn
> **Type:** documentation

The official page of popular Terraform use cases, each with a short rationale and linked tutorials. Confirms [[terraform-intro]]'s framing — same "human-readable config files, versioned/reused/shared, consistent workflow" opener — then applies it across nine scenarios.

## Multi-Cloud Deployment

Provisioning infrastructure across multiple clouds increases fault-tolerance, allowing more graceful recovery from cloud provider outages. Multi-cloud adds complexity because each provider has its own interfaces, tools, and workflows. Terraform's single workflow manages multiple providers and handles cross-cloud dependencies, simplifying orchestration for large-scale multi-cloud infrastructure.

- Tutorial: *Deploy Federated Multi-Cloud Kubernetes Clusters* — provision Kubernetes clusters in both Azure and AWS, configure Consul federation with mesh gateways across the two clusters, deploy microservices across both to verify federation.
- Terraform Registry — thousands of publicly available providers.

## Application Infrastructure Deployment, Scaling, and Monitoring Tools

Terraform efficiently deploys, releases, scales, and monitors infrastructure for multi-tier applications. N-tier architecture scales components independently with separation of concerns — e.g. web server pool + database tier + API/caching/routing-mesh tiers. Terraform manages resources in each tier together and **automatically handles dependencies between tiers**: it deploys a database tier before provisioning the web servers that depend on it.

- Tutorial: *Automate Monitoring with the Terraform Datadog Provider* — deploy a demo Nginx app to Kubernetes with Helm, install the Datadog agent cluster-wide; the agent reports cluster health to a Datadog dashboard.
- Tutorial: *Use Application Load Balancers for Blue-Green and Canary Deployments* — provision blue/green environments, add feature toggles defining deployment strategies, run a canary test, incrementally promote the green environment.

## Self-Service Clusters

At a large org, a centralized ops team can get swamped with repetitive infrastructure requests. Terraform can build a "self-serve" model letting product teams manage their own infrastructure independently. Modules codify org standards for deploying/managing services, so teams deploy in compliance without ops involvement. HCP Terraform can integrate with ticketing systems like ServiceNow to auto-generate new infrastructure requests.

- Tutorial: *Use Modules from the Registry* — get started with public modules.
- Tutorial: *Build and Use a Local Module* — create a module to manage AWS S3 buckets.
- *ServiceNow Service Catalog Integration Setup Instructions* — connect ServiceNow to HCP Terraform.

## Policy Compliance and Management

Terraform can enforce policies on what resource types teams may provision. Ticket-based review is a bottleneck that slows development. **Sentinel**, a policy-as-code framework, automatically enforces compliance/governance policies *before* Terraform makes infrastructure changes.

> Sentinel policies are available in Terraform Enterprise and HCP Terraform.

- Cost estimation docs — describes the cost-estimation feature and how to define policies limiting cost-related infrastructure changes.
- Sentinel docs — in-depth reference plus example policies to adapt.

## PaaS Application Setup

PaaS vendors like Heroku let you create web apps and attach add-ons (databases, email providers). Heroku can elastically scale dynos/workers, but most non-trivial apps need many add-ons and external services. Terraform can codify the setup for a Heroku application, configure DNSimple to set a CNAME, and set up Cloudflare as a CDN for the app — **quickly and consistently, without a web interface**.

- Tutorial: *Deploy, Manage, and Scale an Application on Heroku* — manage an app's lifecycle with Terraform.

## Software Defined Networking

Terraform interacts with Software Defined Networks (SDNs) to automatically configure the network according to the needs of applications running in it, moving from a ticket-based workflow to an automated one and reducing deployment times.

> For example, when a service registers with HashiCorp Consul, **Consul-Terraform-Sync** can automatically generate Terraform configuration to expose appropriate ports and adjust network settings for any SDN with an associated Terraform provider. **Network Infrastructure Automation (NIA)** lets you safely approve the changes your applications require without manually translating developer tickets into the changes you think their applications need.

- Tutorial: *Network Infrastructure Automation with Consul-Terraform-Sync Intro* — install Consul-Terraform-Sync on a node, configure it to talk to a Consul datacenter, react to service changes, execute an example task.
- Tutorial: *Consul-Terraform-Sync and Terraform Enterprise/Cloud Integration* — configure Consul-Terraform-Sync to interact with Terraform Enterprise and HCP Terraform.

## Kubernetes

Kubernetes is an open-source workload scheduler for containerized applications. Terraform can both **deploy** a Kubernetes cluster and **manage its resources** (pods, deployments, services, etc.). The **HCP Terraform Operator** manages cloud and on-prem infrastructure through a Kubernetes Custom Resource Definition (CRD) plus HCP Terraform.

- Tutorial: *Manage Kubernetes Resources via Terraform* — schedule and expose an NGINX deployment on a Kubernetes cluster.
- Tutorial: *Deploy Infrastructure with the HCP Terraform Operator for Kubernetes* — configure and deploy the Operator to a Kubernetes cluster, use it to create an HCP Terraform workspace and provision a message queue.

## Parallel Environments

Staging/QA environments test new applications before production release. As production grows larger and more complex, keeping every stage's environment up to date gets harder. Terraform lets you rapidly spin up and decommission infrastructure for dev, test, QA, and production. Disposable environments created on demand are more cost-efficient than maintaining each one indefinitely.

## Software Demos

Terraform can create, provision, and bootstrap a demo across various cloud providers, letting end users try the software on their own infrastructure and adjust parameters (e.g. cluster size) to test tools at any scale.

---
Related: [[terraform-intro]] — shares the same opening IaC framing; this page is the applied "when would I actually use this" companion. Feeds the **B1 — Infrastructure as Code** milestone alongside it, and forward-references topics not yet covered: Sentinel/policy-as-code (**A5**), HCP Terraform (**A4**), Kubernetes Operator, and Consul-Terraform-Sync/NIA (SDN automation, not yet in the path).
