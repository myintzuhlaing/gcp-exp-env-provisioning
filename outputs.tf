/**
 * Outputs
 */

output "project_id" {
  description = "The Experiment Project Id"
  value       = google_project.project.project_id
}

output "project_number" {
  description = "The Experiment Project Number"
  value       = google_project.project.number
}