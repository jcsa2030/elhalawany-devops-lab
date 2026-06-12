output "project_name" {
  value = var.project_name
}

output "environment" {
  value = var.environment
}

output "lab_id" {
  value = random_id.lab_id.hex
}

output "inventory_file" {
  value = local_file.devops_lab_inventory.filename
}

output "network_design_file" {
  value = local_file.network_design.filename
}

output "security_design_file" {
  value = local_file.security_design.filename
}

output "compute_design_file" {
  value = local_file.compute_design.filename
}

output "monitoring_design_file" {
  value = local_file.monitoring_design.filename
}
