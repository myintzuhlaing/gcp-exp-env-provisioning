/**
 * Variables
 */

variable "department" {
  type        = string
  description = "The Department to Provision the Experiment for. E.g ARCH"
}

variable "team" {
  type        = string
  description = "The Team to Provision the Experiment for. E.g. team_a"
}

variable "code" {
  type        = string
  description = "The Experimnent Code or Identitifer. E.g. kakfa-hybrid"
}

variable "group" {
  type        = string
  description = "The GSuite Group for IAM Permissions assignment"
}

variable "budget" {
  type        = string
  description = "The amount in AUD that the Experiment has been assigned"
  default     = "100"
}

variable "labels" {
  type        = map(string)
  description = "Custom labels to apply to the Experiment project"
  default     = {}
}

variable "expiry_timestamp" {
  type        = string
  description = "Project Expiry timestamp. Will default to +10 days if not specified"
  default     = ""
}

variable "apis" {
  type        = list(string)
  description = "The permitted APIs for the Experiment Project. These should all be covered by VPC Service Controls."
  default     = []
}

variable "group_roles" {
  type        = list(string)
  description = "The IAM Roles to assign to the GSuite Group"
  default = [
    "roles/viewer",
    "roles/iap.tunnelResourceAccessor"
  ]
}

variable "service_account_roles" {
  type        = list(string)
  description = "The IAM Roles to assign to the Default experiment Service Account"
  default = [
    "roles/viewer"
  ]
}