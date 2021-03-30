/**
 * # Terraform Experiment Provisioning Module
 *
 * Highly Opinionated and encapsulated experiment provisioning module
 *
 * Goal is to enable experiment requestors to invoke this module, which results in a self-contained,
 * isolated experiment environment.
 *
 * This module is *not* intended to follow standards set for other modules, as it needs to abstract away
 * alot of the underlying resources to prevent an experiment requestor from manipulating any values that
 * should not be changed and are considered to some degree to be 'enforced'.
 *
 * Example Usage:
 * ```hcl
 *   module "exp_arch_team_a_phoenix" {
 *     source = "git::https://source.developers.google.com/p/core-automation-xxx/r/tf-module-experiment-provisioning?ref=vRELEASE"
 *
 *     department = "ARCH"
 *     team = "team_a"
 *     code = "phoenix"
 *     group = "gcp-lab-exp-arch-team-a-phoenix@client.com.au"
 *     budget = "100"
 *     expiry_timestamp = "2020-03-18T20:06:00Z"
 *
 *     apis = [ "compute.googleapis.com", "cloudkms.googleapis.com" ]
 *     group_roles = [ "roles/viewer", "roles/iap.tunnelResourceAccessor" ]
 *     service_account_roles = [ "roles/viewer" ]
 *  }
 * ```
 *
 * Ensure that any invocation of this module provides a check that `gcloud` binary is installed and configured on the host machine.
 *
 * Shell interactions utilised in this Module:
 * - Joining Perimeter
 *   - Submitting CloudBuild build to include the Experiment Project in the Org. Perimeter
 *   - Checking Projct has joined the Perimeter
 * - Gracefully Disabling API Services
 * - Deleting Default GCE Service Account
 * - Handling Expiry Schedule Update
 */

terraform {
  required_version = "= 0.12.23"
  required_providers {
    google      = "~> 3.9.0"
    google-beta = "~> 3.9.0"
    random      = "~> 2.2.1"
    null        = "~> 2.1"
  }
}

/*
 * Ensure unique Project id
 */
resource "random_id" "project_identifier_suffix" {
  byte_length = 2
}

/**
 * Construct the project id
 */
locals {
  project_id = format("%s-%s", local.project_id_prefix, random_id.project_identifier_suffix.hex)
}

/**
 * Provision the Project
 */
resource "google_project" "project" {
  name                = local.project_name
  project_id          = local.project_id
  billing_account     = local.billing_account
  folder_id           = local.parent_folder
  auto_create_network = true
  skip_delete         = false
  labels              = local.labels

  /**
   * The Experiment Project needs to join the Org. Perimeter on provisioning (VPC Service Controls)
   * This is done via Automated GitOps, with the updating of the Org Repository.
   *
   * Substitutions are inline to avoid dependency cycles
   *
   * Removal from Perimeter is handled via the DeProvisioning Job, invoked by CloudScheduler
   */
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    when        = create
    on_failure  = fail
    command     = <<CMD
      echo '${local.perimeter_update_config}' > ${path.module}/join-perimeter-config-${self.number}.json; 
      gcloud builds submit --no-source --config ${path.module}/join-perimeter-config-${self.number}.json --substitutions=_EXPERIMENT_PROJECT_NUMBER=${self.number},_GIT_COMMIT_MESSAGE='System joining of Perimeter ${self.project_id}' --project ${local.project_refs.core_automation.id}; 
      rm -f ${path.module}/join-perimeter-config-${self.number}.json;
    CMD
  }

  depends_on = [random_id.project_identifier_suffix, local.perimeter_update_config, local.project_refs]
}

/**
 * Check the Project has Joined the Perimeter, then proceed with the rest of provisioning
 */
resource "null_resource" "joined_perimeter" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    on_failure  = fail
    command     = "${path.module}/scripts/check-perimeter-joined.sh ${local.org_access_policy_number} ${local.org_perimeter_name} ${format("projects/%s", google_project.project.number)}"
  }

  depends_on = [google_project.project]
}

/**
 * Enable the APIs
 *
 * `count` is used instead of `for_each` to overcome two functional issues, outlined below...
 */
resource "google_project_service" "api" {
  count                      = length(var.apis)
  project                    = google_project.project.project_id
  service                    = element(var.apis, count.index)
  disable_on_destroy         = false
  disable_dependent_services = false

  /**
   * 1. Default case for deprovisioning a project (having numerous apis enabled) will likely result in a failure, 
   * and the project not being terminated *if* we rely on the default behavior of the Google provider.
   * The default behaviour results in a `FAILED_PRECONDITION`, where the cause is one of the following cases:
   * - `disable_dependent_services` disabling services that are also queued up to be disabled, which results in a 
   *  precondition failure when the queued up services are attempted to be disabled.
   * - `disable_dependent_services` or `--force` not being respected and failing as the service has dependencies
   *
   * The below `local-exec` block is to handle the disabling of a service with configurable retries.
   * 
   * 2. Relying on the new `for_each` iterator, inconsistent behavior is seen where destroy provisioner fails to execute,
   * causing apply failures, hence, defaulting to the original `count` iterator.
   */

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    on_failure  = fail
    when        = destroy
    command     = "${path.module}/scripts/disable-api-service.sh ${self.service} ${self.project}"
  }

  depends_on = [google_project.project, null_resource.joined_perimeter]
}

/**
 * Provision the Experiment Service Account
 */
resource "google_service_account" "default" {
  account_id   = "experiment-default-sa"
  display_name = "Provided Experiment Service Account"
  description  = "Permissive Service Account for use within the GCP Ecosystem"
  project      = google_project.project.project_id

  depends_on = [google_project.project, null_resource.joined_perimeter]
}

/**
 * Assign non-authoritative Project
 * Note: Setting iam bindings here has the potential to revoke default Google API permissions
 */
resource "google_project_iam_member" "group" {
  for_each = toset(var.group_roles)
  project  = google_project.project.project_id
  role     = each.value
  member   = local.iam_group_identifier

  depends_on = [google_project.project, null_resource.joined_perimeter]
}

resource "google_project_iam_member" "default_service_account" {
  for_each = toset(var.service_account_roles)
  project  = google_project.project.project_id
  role     = each.value
  member   = format("serviceAccount:%s", google_service_account.default.email)

  depends_on = [google_project.project, google_service_account.default, null_resource.joined_perimeter]
}

/**
 * Allow Experiment users to use the Service Account
 */
resource "google_service_account_iam_binding" "default" {
  service_account_id = google_service_account.default.name
  role               = "roles/iam.serviceAccountUser"

  members = [
    local.iam_group_identifier
  ]

  depends_on = [google_service_account.default, null_resource.joined_perimeter]
}

/**
 * Apply the Billing Budgets
 */
resource "google_billing_budget" "budget" {
  provider = google-beta

  billing_account = local.billing_account
  display_name    = format("Budget for %s", google_project.project.project_id)

  budget_filter {
    projects               = [format("projects/%s", google_project.project.project_id)]
    credit_types_treatment = local.billing_budget_credit_types_treatment
    services               = [] # `services` should remain empty, unless a budget should target only a subset of services
  }

  amount {
    specified_amount {
      currency_code = "AUD"
      units         = var.budget
    }
  }

  dynamic "threshold_rules" {
    for_each = local.billing_budget_thresholds
    content {
      threshold_percent = threshold_rules.value.threshold
      spend_basis       = threshold_rules.value.basis
    }
  }

  all_updates_rule {
    pubsub_topic   = local.billing_budget_topic
    schema_version = "1.0"
  }

  depends_on = [google_project.project, null_resource.joined_perimeter]
}

/**
 * Provision the Scheduled Job to De-provision the Experiment
 */
resource "google_cloud_scheduler_job" "deprovisioner" {
  name        = format("deprovision-%s", google_project.project.project_id)
  description = format("Once-off Schedule to Deprovision %s", google_project.project.project_id)
  project     = local.project_refs.exp_automation.id
  schedule    = local.deprovisioner_schedule

  time_zone        = local.deprovisioner_timezone
  attempt_deadline = local.deprovisioner_deadline
  region           = local.deprovisioner_region

  retry_config {
    retry_count          = 3
    max_backoff_duration = "3600s"
    max_doublings        = 5
    max_retry_duration   = "0s"
    min_backoff_duration = "5s"
  }

  http_target {
    http_method = "POST"
    headers     = {}
    uri         = local.cloud_build_endpoint
    body        = local.deprovisioner_http_request

    oauth_token {
      scope                 = local.deprovisioner_scopes
      service_account_email = local.deprovisioner_sa_email
    }
  }

  /**
   * To cater for default expiry and provided expiry with updates, the schedule has to be treated separately to ensure 
   * default expiry doesn't cause continual in-place updates to the scheduler
   */
  lifecycle {
    ignore_changes = [
      schedule
    ]
  }

  depends_on = [google_project.project, null_resource.joined_perimeter]
}

/**
 * Handles updates to the Scheduler's schedule
 */
resource "null_resource" "expiry_timestamp_trigger" {
  triggers = {
    provided_expiry_timestamp = var.expiry_timestamp
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    on_failure  = fail
    command     = "gcloud scheduler jobs update http ${google_cloud_scheduler_job.deprovisioner.id} --schedule='${local.deprovisioner_schedule}' --project='${local.project_refs.exp_automation.id}'"
  }

  depends_on = [google_cloud_scheduler_job.deprovisioner]
}

/**
 * Handles deletion of default gce sa, which has roles/editor on the Project.
 * SA may still be visible in the console but should not be usable. Validation can also be done via `gcloud service-accounts get-iam-policy ${local.default_gce_sa} --project=${google_project.project.project_id}`,
 * which should fail with a permissions error (given you have adequate permissions to view the service account, which platform-admins should have)
 */
resource "null_resource" "delete_default_gce_sa" {
  triggers = {
    run_once = true
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    on_failure  = fail
    command     = "gcloud iam service-accounts delete ${local.default_gce_sa} --project=${google_project.project.project_id}"
  }

  depends_on = [google_project_service.api]
}