# Terraform Experiment Provisioning Module

Highly Opinionated and encapsulated experiment provisioning module

Goal is to enable experiment requestors to invoke this module, which results in a self-contained,  
isolated experiment environment.

This module is *not* intended to follow standards set for other modules, as it needs to abstract away  
alot of the underlying resources to prevent an experiment requestor from manipulating any values that  
should not be changed and are considered to some degree to be 'enforced'.

Example Usage:
```hcl
  module "exp_arch_team_a_phoenix" {
    source = "git::https://source.developers.google.com/p/core-automation-xxx/r/tf-module-experiment-provisioning?ref=vRELEASE"

    department = "ARCH"
    team = "team_a"
    code = "phoenix"
    group = "gcp-lab-exp-arch-team-a-phoenix@client.com.au"
    budget = "100"
    expiry_timestamp = "2020-03-18T20:06:00Z"

    apis = [ "compute.googleapis.com", "cloudkms.googleapis.com" ]
    group_roles = [ "roles/viewer", "roles/iap.tunnelResourceAccessor" ]
    service_account_roles = [ "roles/viewer" ]
 }
```

Ensure that any invocation of this module provides a check that `gcloud` binary is installed and configured on the host machine.

Shell interactions utilised in this Module:
- Joining Perimeter
  - Submitting CloudBuild build to include the Experiment Project in the Org. Perimeter
  - Checking Projct has joined the Perimeter
- Gracefully Disabling API Services
- Deleting Default GCE Service Account
- Handling Expiry Schedule Update

## Providers

| Name | Version |
|------|---------|
| google | ~> 3.9.0 |
| google-beta | ~> 3.9.0 |
| null | ~> 2.1 |
| random | ~> 2.2.1 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| apis | The permitted APIs for the Experiment Project. These should all be covered by VPC Service Controls. | `list(string)` | `[]` | no |
| budget | The amount in AUD that the Experiment has been assigned | `string` | `"100"` | no |
| code | The Experimnent Code or Identitifer. E.g. kakfa-hybrid | `string` | n/a | yes |
| department | The Department to Provision the Experiment for. E.g ARCH | `string` | n/a | yes |
| expiry\_timestamp | Project Expiry timestamp. Will default to +10 days if not specified | `string` | `""` | no |
| group | The GSuite Group for IAM Permissions assignment | `string` | n/a | yes |
| group\_roles | The IAM Roles to assign to the GSuite Group | `list(string)` | <pre>[<br>  "roles/viewer",<br>  "roles/iap.tunnelResourceAccessor"<br>]</pre> | no |
| labels | Custom labels to apply to the Experiment project | `map(string)` | `{}` | no |
| service\_account\_roles | The IAM Roles to assign to the Default experiment Service Account | `list(string)` | <pre>[<br>  "roles/viewer"<br>]</pre> | no |
| team | The Team to Provision the Experiment for. E.g. Z\_AXIS | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| project\_id | The Experiment Project Id |
| project\_number | The Experiment Project Number |

