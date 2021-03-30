{
  "source": {
    "repoSource": ${jsonencode(source)}
  },
  "steps": [
    {
      "id": "Configure Global Git Credential Helper",
      "name": "gcr.io/cloud-builders/git",
      "args": [
        "config",
        "--global",
        "credential.helper",
        "gcloud.sh"
      ]
    },
    {
      "id": "Configure Global Git user.name",
      "name": "gcr.io/cloud-builders/git",
      "args": [
        "config",
        "--global",
        "user.name",
        "$_GIT_USER_NAME"
      ]
    },
    {
      "id": "Configure Global Git user.email",
      "name": "gcr.io/cloud-builders/git",
      "args": [
        "config",
        "--global",
        "user.email",
        "$_GIT_USER_EMAIL"
      ]
    },
    {
      "id": "Remove Experiment Terraform Configuration",
      "name": "gcr.io/cloud-builders/gcloud",
      "entrypoint": "rm",
      "args": [
        "$_EXPERIMENT_CONFIG_ROOT_DIR/$_EXPERIMENT_CONFIG_FILE"
      ]
    },
    {
      "id": "Stage Experiment Removal",
      "name": "gcr.io/cloud-builders/git",
      "args": [
        "add",
        "$_EXPERIMENT_CONFIG_ROOT_DIR/$_EXPERIMENT_CONFIG_FILE"
      ]
    },
    {
      "id": "Commit Experiment Removal",
      "name": "gcr.io/cloud-builders/git",
      "args": [
        "commit",
        "-m",
        "$_CONFIG_REMOVAL_GIT_COMMIT_MESSAGE"
      ]
    },
    {
      "id": "Push Experiment Removal changes to Master",
      "name": "gcr.io/cloud-builders/git",
      "args": [
        "push",
        "origin",
        "master",
        "--force"
      ]
    },

    {
      "id": "Git clone Core Org Repo",
      "name": "gcr.io/cloud-builders/gcloud",
      "args": [
        "source", "repos", "clone", "$_CORE_ORG_REPO_NAME", 
        "--project", "$_CORE_AUTOMATION_PROJECT_ID"
      ]
    },
    {
      "id": "Git Checkout Core Org Master",
      "name": "gcr.io/cloud-builders/git",
      "dir": "$_CORE_ORG_REPO_NAME",
      "args": [
        "checkout",
        "master"
      ]
    },
    {
      "id": "Remove Experiment Project from Perimeter",
      "name": "gcr.io/$PROJECT_ID/hcl-mutator:latest",
      "dir": "$_CORE_ORG_REPO_NAME",
      "args": [
        "--file", "$_PERIM_ROOT_CONFIG_DIR/$_EXPERIMENT_RESOURCE_TFVARS_FILE",
        "--key", "$_EXPERIMENT_RESOURCE_TFVARS_KEY",
        "--operation", "$_HCL_MUTATOR_OPERATION",
        "--data", "projects/$_EXPERIMENT_PROJECT_NUMBER"
      ],
      "env": [
        "LOG_LEVEL=DEBUG"
      ]
    },
    {
      "id": "Stage Experiment Project Removal from Perimeter",
      "name": "gcr.io/cloud-builders/git",
      "dir": "$_CORE_ORG_REPO_NAME",
      "args": [
        "add",
        "$_PERIM_ROOT_CONFIG_DIR/$_EXPERIMENT_RESOURCE_TFVARS_FILE"
      ]
    },
    {
      "id": "Commit Perimeter Update",
      "name": "gcr.io/cloud-builders/git",
      "dir": "$_CORE_ORG_REPO_NAME",
      "args": [
        "commit",
        "-m",
        "$_PERIM_REMOVAL_GIT_COMMIT_MESSAGE"
      ]
    },
    {
      "id": "Push Perimeter changes to Core Org Master",
      "name": "gcr.io/cloud-builders/git",
      "dir": "$_CORE_ORG_REPO_NAME",
      "args": [
        "push",
        "origin",
        "master",
        "--force"
      ]
    }
  ],
  "timeout": "600s",
  "options": ${jsonencode(options)},
  "substitutions": ${jsonencode(substitutions)},
  "tags": ${jsonencode(tags)}
}