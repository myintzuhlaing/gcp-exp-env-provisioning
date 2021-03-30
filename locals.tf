/**
 * Hierarchy, Billing and GSuite Group Configuration
 */
locals {
  /**
   * To add another Department or Team, update this mapping below.
   * The root key corresponds to a Department and the inner keys correspond to the Teams
   */
  // not obtaining from core statefile to enforce separation
  hierarchy_lookup = {
    ARCH = {
      team_a = "xxx"
    }
  }

  // not obtaining from core statefile to enforce separation
  project_refs = {
    monitoring = {
      id     = "core-monitoring-xxx"
      number = "xxx"
    }
    exp_automation = {
      id     = "exp-automation-xxx"
      number = "xxx"
    }
    core_automation = {
      id     = "core-automation-xxx"
      number = "yyy"
    }
  }

  billing_account = "ABCD-EFGH"

  iam_group_identifier = format("group:%s", var.group)

  global_labels = {
    purpose     = "experiment-provisioning",
    environment = "gcp-lab-experiments"
  }
}

/**
 * Project Configuration
 */
locals {
  project_identifier_replacements = {
    name   = ["/_+/", "-"],
    id     = ["/[_\\s]/", "-"]
    module = ["/[-\\s]/", "_"]
  }

  project_identifiers = {
    department = var.department
    team       = var.team
    code       = var.code
  }

  // values(local.project_identifiers)... is in lexographical order based on the keys
  project_prefix = format("Exp %s %s %s", var.department, var.team, var.code)

  project_identifier_prefixes = {
    for prefix, replacement in local.project_identifier_replacements
    : prefix => replace(local.project_prefix, replacement...)
  }

  project_id_prefix = lower(local.project_identifier_prefixes.id)

  labels = merge(var.labels, {
    for label, value in local.project_identifiers
    : label => lower(replace(value, local.project_identifier_replacements.id...))
  }, local.global_labels)

  project_name = local.project_identifier_prefixes.name

  // experiment config file naming convention: exp-<department-name>-<team-name>-<experiment-code>.tf`
  experiment_config_file_template = format("exp-%s-%s-%s.tf", var.department, var.team, var.code)
  expected_experiment_config_file = lower(replace(local.experiment_config_file_template, local.project_identifier_replacements.id...))

  // experiment config module name convention: `module.exp_<department_name>_<team_name>_<experiment_code>`
  experiment_config_module_name_template = format("module.exp_%s_%s_%s", var.department, var.team, var.code)
  experiment_config_module_name          = lower(replace(local.experiment_config_module_name_template, local.project_identifier_replacements.module...))

  /**
   * Department and Team should *always* be validated during PR process
   *
   * Validation rules are currently `experimental`, see: https://www.terraform.io/docs/configuration/variables.html#custom-validation-rules
   * and should be implemented in a future release.
   */

  /**
   * When adding additional levels in the Experiment hierarchy, the below lookups may need to be adjusted to cater for
   * nesting of Departments and Teams
   */
  root_folder   = lookup(local.hierarchy_lookup, var.department, {}) // default value should never be returned!
  parent_folder = lookup(local.root_folder, var.team, "INVALID")     // default value should never be returned!

  default_gce_sa = format("%s-compute@developer.gserviceaccount.com", google_project.project.number)
}

/**
 * Periemeter Joining Configuration
 */
locals {
  org_access_policy_number = "xxx"
  org_perimeter_name       = "default_perimeter"

  perimeter_updater_git_email    = format("%s@cloudbuild.gserviceaccount.com", local.project_refs.core_automation.id)
  perimeter_updater_git_username = "GCB Automation"

  perimeter_update_config = templatefile("${path.module}/templates/update-perimeter.json.tpl", {
    options = {
      substitutionOption = "MUST_MATCH"
      logging            = "LEGACY"
      env                = []
    },
    substitutions = {
      "_CORE_ORG_REPO_NAME"              = "tf-core-organisation"
      "_ROOT_CONFIG_DIR"                 = "org-perimeter"
      "_EXPERIMENT_RESOURCE_TFVARS_FILE" = "vars/experiment-perimeter-resources.tfvars.json"
      "_EXPERIMENT_RESOURCE_TFVARS_KEY"  = "experiment_perimeter_resources"
      "_HCL_MUTATOR_OPERATION"           = "INSERT"
      # _EXPERIMENT_PROJECT_NUMBER set directly via gcloud
      # _GIT_COMMIT_MESSAGE set directly via gcloud, as referencing the Project Id here would create a cyclic dependency
      "_GIT_USER_EMAIL"             = local.perimeter_updater_git_email
      "_GIT_USER_NAME"              = local.perimeter_updater_git_username
      "_CORE_AUTOMATION_PROJECT_ID" = local.project_refs.core_automation.id
    },
    tags = ["experiment", "update-perimeter"]
  })
}

/**
 * De-provisioning Experiment Configuration
 */
locals {
  deprovisioner_http_request = base64encode(templatefile("${path.module}/templates/deprovisioner.json.tpl", {
    source = {
      "repoName"   = "tf-experiment-config",
      "branchName" = "master",
      "projectId"  = local.project_refs.exp_automation.id
    },
    options = {
      substitutionOption = "MUST_MATCH"
      logging            = "LEGACY"
      env                = []
    },
    substitutions = {
      "_EXPERIMENT_CONFIG_FILE"            = local.expected_experiment_config_file,
      "_EXPERIMENT_CONFIG_ROOT_DIR"        = local.experiment_config_root_dir,
      "_CONFIG_REMOVAL_GIT_COMMIT_MESSAGE" = format("System deprovisioning of %s", google_project.project.project_id),
      "_GIT_USER_EMAIL"                    = local.deprovisioner_git_email,
      "_GIT_USER_NAME"                     = local.deprovisioner_git_username,
      "_HCL_MUTATOR_OPERATION"             = "REMOVE",
      "_EXPERIMENT_PROJECT_NUMBER"         = google_project.project.number,
      "_PERIM_REMOVAL_GIT_COMMIT_MESSAGE"  = format("System removal from perimeter %s", google_project.project.project_id),
      "_CORE_AUTOMATION_PROJECT_ID"        = local.project_refs.core_automation.id,
      "_CORE_ORG_REPO_NAME"                = "tf-core-organisation",
      "_PERIM_ROOT_CONFIG_DIR"             = "org-perimeter",
      "_EXPERIMENT_RESOURCE_TFVARS_FILE"   = "vars/experiment-perimeter-resources.tfvars.json",
      "_EXPERIMENT_RESOURCE_TFVARS_KEY"    = "experiment_perimeter_resources",
    },
    tags = ["experiment", "deprovisioning", "removal-from-perimeter"]
  }))

  has_provided_expiry_timestamp = var.expiry_timestamp != ""
  // initial implementation uses generated timestamp, which results in schedule not being explicity tracked as part of the Cloud Scheduler Job resource
  // future work should obtain the creation timestamp from the created project resource, which should enable the schedule to be tracked as part of the Job resource
  expiry_timestamp           = local.has_provided_expiry_timestamp ? var.expiry_timestamp : timeadd(timestamp(), "240h") // default to 10 days
  formatted_expiry_timestamp = formatdate("mm hh DD MM", local.expiry_timestamp)
  deprovisioner_schedule     = format("%s *", local.formatted_expiry_timestamp)

  deprovisioner_region       = "australia-southeast1"
  deprovisioner_timezone     = "Australia/Melbourne"
  deprovisioner_deadline     = "320s"
  deprovisioner_scopes       = "https://www.googleapis.com/auth/cloud-platform"
  deprovisioner_sa_email     = format("exp-deprovisioning-xxx@%s.iam.gserviceaccount.com", local.project_refs.exp_automation.id)
  deprovisioner_git_email    = format("%s@cloudbuild.gserviceaccount.com", local.project_refs.core_automation.id)
  deprovisioner_git_username = "GCB Automation"

  cloud_build_endpoint       = format("https://cloudbuild.googleapis.com/v1/projects/%s/builds", local.project_refs.core_automation.id)
  experiment_config_root_dir = "live-experiments"
}

/**
 * Billing Budget Configuration
 */
locals {
  billing_budget_thresholds = toset([
    {
      threshold = 0.4,
      basis     = "CURRENT_SPEND"
    },
    {
      threshold = 0.6,
      basis     = "CURRENT_SPEND"
    },
    {
      threshold = 0.8,
      basis     = "CURRENT_SPEND"
    },
    {
      threshold = 1.0,
      basis     = "CURRENT_SPEND"
    },
    {
      threshold = 1.1,
      basis     = "CURRENT_SPEND"
    }
  ])

  billing_budget_credit_types_treatment = "EXCLUDE_ALL_CREDITS"

  billing_budget_topic = format("projects/%s/topics/billing-budget-notifications", local.project_refs.monitoring.id)
}