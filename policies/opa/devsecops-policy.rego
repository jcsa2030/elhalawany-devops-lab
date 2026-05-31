package devsecops

deny contains msg if {
  input.image_tag == "latest"
  msg := "Docker image tag must not be latest"
}

deny contains msg if {
  input.environment == "production"
  not input.approved
  msg := "Production deployment requires approval"
}

deny contains msg if {
  input.security_headers_enabled == false
  msg := "Security headers must be enabled"
}

deny contains msg if {
  input.trivy_scan_enabled == false
  msg := "Trivy scan must be enabled"
}
