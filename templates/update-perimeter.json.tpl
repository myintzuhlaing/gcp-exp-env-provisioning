{
  "steps": [
    {
      "id": "Git clone Core Org Repo",
      "name": "gcr.io/cloud-builders/gcloud",
      "args": [
        "source", "repos", "clone", "$_CORE_ORG_REPO_NAME", ".", 
        "--project", "$_CORE_AUTOMATION_PROJECT_ID"
      ]
    },
    {
      "id": "Git Checkout",
      "name": "gcr.io/cloud-builders/git",
      "args": [
        "checkout",
        "master"
      ]
    },
    {
      "id": "Configure Git user.name",
      "name": "gcr.io/cloud-builders/git",
      "args": [
        "config",
        "--global",
        "user.name",
        "$_GIT_USER_NAME"
      ]
    },
    {
      "id": "Configure Git user.email",
      "name": "gcr.io/cloud-builders/git",
      "args": [
        "config",
        "--global",
        "user.email",
        "$_GIT_USER_EMAIL"
      ]
    },
    {
      "id": "Experiment Project update Perimeter",
      "name": "gcr.io/$PROJECT_ID/hcl-mutator:latest",
      "args": [
        "--file", "$_ROOT_CONFIG_DIR/$_EXPERIMENT_RESOURCE_TFVARS_FILE",
        "--key", "$_EXPERIMENT_RESOURCE_TFVARS_KEY",
        "--operation", "$_HCL_MUTATOR_OPERATION",
        "--data", "projects/$_EXPERIMENT_PROJECT_NUMBER"
      ],
      "env": [
        "LOG_LEVEL=DEBUG"
      ]
    },
    {
      "id": "Stage Perimeter Changes",
      "name": "gcr.io/cloud-builders/git",
      "args": [
        "add",
        "$_ROOT_CONFIG_DIR/$_EXPERIMENT_RESOURCE_TFVARS_FILE"
      ]
    },
    {
      "id": "Commit Perimeter Update",
      "name": "gcr.io/cloud-builders/git",
      "args": [
        "commit",
        "-m",
        "$_GIT_COMMIT_MESSAGE"
      ]
    },
    {
      "id": "Push changes to master",
      "name": "gcr.io/cloud-builders/git",
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