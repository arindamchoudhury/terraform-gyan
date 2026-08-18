# Integrate Pipelines with resource servers using OIDC

> **Source:** [support.atlassian.com/bitbucket-cloud/docs/integrate-pipelines-with-resource-servers-using-oidc](https://support.atlassian.com/bitbucket-cloud/docs/integrate-pipelines-with-resource-servers-using-oidc/)
> **Added:** 2026-08-18
> **Source updated:** undated support article; captured 2026-08-18
> **Tags:** bitbucket, pipelines, oidc, short-lived-credentials, aws, assume-role-with-web-identity, ci-cd, audiences
> **Type:** documentation

Bitbucket's position on Terraform state is the same as GitHub's and for the same reason: there is no Bitbucket backend in the catalogue ([[tf-backend-configure]]), so state lives in **S3, GCS or Azure Blob** and the forge's job is to prove the pipeline's identity to that store. Only [[gitlab-tf-state]] does otherwise.

> "You can use Bitbucket Pipelines OpenID Connect Provider (OIDC IDP) to allow your pipelines to access your resource server, such as AWS, GCP, or Vault. This means that you and your team can access the resource server without storing credentials in Bitbucket."

## Enabling it

Two facts that make this shorter to set up than the GitHub equivalent, and one that makes it easier to get wrong.

> "OpenID Connect (OIDC) with Pipelines is set to '**true**' by default in the Bitbucket Pipelines YAML file. To disable OpenID Connect, set `oidc` to '`false`'."

The token arrives in the step as **`$BITBUCKET_STEP_OIDC_TOKEN`**, and you exchange it yourself — there is no equivalent of GitHub's official per-cloud login actions:

```yaml
image: amazon/aws-cli

pipelines:
  default:
    - step:
        oidc: true
        max-time: 5
        script:
          - aws sts assume-role-with-web-identity --role-arn arn:aws:iam::XXXXXX:role/projectx-build --role-session-name build-session  --web-identity-token "$BITBUCKET_STEP_OIDC_TOKEN" --duration-seconds 1000
```

For a Terraform job the same exchange is what the `s3` backend's `assume_role_with_web_identity` block does natively, so the backend can consume the token directly rather than going through `aws sts` first.

The identity provider URL and audience come from **repository Settings › Pipelines › OpenID Connect**, along with an example payload showing the claims, and the workspace, repository and deployment-environment **UUIDs** you need on the cloud side.

## Audiences

Configurable per step or globally:

```yaml
options:
  oidc:
    audiences:
      - https://your.service0.com
      - https://your.service1.com
```

Limits: **maximum 10 audiences**, and **150 characters** per audience name.

## Access policies live on the resource server

The article's own list of what you can restrict, and it is worth noting that all but the last are configured in AWS/GCP/Vault rather than in Bitbucket:

- per **repository**
- per **deployment environment**
- to **Bitbucket Pipelines IP ranges**
- by **step duration** — the one Bitbucket-side control

!!! note "`max-time` is a real security control here, not just a build-minutes knob"
    The step's `max-time` bounds how long the assumed role can be in use, which is why the article files it under access policies. One caveat stated plainly: *"By default, the system adds extra 5 minutes as buffer in case of any delays when starting the step."* So the effective window is `max-time + 5`, not `max-time`.

    Pair it with `--duration-seconds` on the role assumption. The 1000 seconds in the example is well under the 5-minute step, which is the right direction: the cloud-side credential should expire before the step can.

!!! note "Claim scoping is by UUID, not by path"
    Where GitHub's `sub` reads `repo:octo-org/octo-repo:environment:prod` ([[gha-oidc]]), Bitbucket identifies workspace, repository and environment by **UUID**, which is why the setup page exists to hand you those values. Less readable in a trust policy, but immune to a repository rename.

Atlassian's per-cloud follow-ups: *Deploy on AWS using Bitbucket Pipelines OpenID Connect*, and *Accessing Google cloud resources from an OIDC identity provider*.

---
Related: [[gha-oidc]] — the same mechanism on GitHub, with a richer claim set and official login actions. · [[gitlab-tf-state]] — the forge that stores state instead of only issuing identities. · [[tf-backend-configure]] — the backend catalogue neither Bitbucket nor GitHub appears in.
