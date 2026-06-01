# Elhalawany DevSecOps Lab

Enterprise DevSecOps Platform built for learning, security automation, CI/CD governance, software supply chain security, and cloud-native deployment.

## Overview

This project demonstrates a complete DevSecOps workflow integrating:

* GitHub
* Jenkins CI/CD
* SonarQube SAST
* SonarQube Quality Gate
* GitLeaks Secret Scanning
* Trivy Vulnerability Scanning
* Syft SBOM Generation
* Dependency-Track SCA
* HashiCorp Vault
* Open Policy Agent (OPA)
* Docker & Docker Compose
* Prometheus Monitoring
* Grafana Dashboards
* AlertManager
* Blackbox Exporter
* Node Exporter
* cAdvisor
* GitHub Container Registry (GHCR)

---

## Architecture

Developer
↓
GitHub
↓
Jenkins Pipeline
↓
GitLeaks
↓
SBOM (Syft)
↓
Dependency-Track
↓
Vault Secrets
↓
OPA Policy Gate
↓
SonarQube SAST
↓
Quality Gate
↓
Trivy Filesystem Scan
↓
Docker Build
↓
Trivy Image Scan
↓
GitHub Container Registry (GHCR)
↓
Production Approval
↓
Deployment
↓
Monitoring & Alerting

---

## Security Controls

### Secret Management

* HashiCorp Vault
* No hardcoded secrets
* Secure API key retrieval

### Code Security

* SonarQube SAST
* Quality Gate Enforcement

### Supply Chain Security

* Syft SBOM
* Dependency-Track
* Trivy Vulnerability Scanning

### Policy Enforcement

* Open Policy Agent (OPA)

### Secret Detection

* GitLeaks

---

## Monitoring Stack

### Infrastructure Monitoring

* Prometheus
* Grafana
* Node Exporter
* cAdvisor

### Service Monitoring

* Blackbox Exporter
* AlertManager

### Alert Channels

* Slack Notifications

---

## Container Registry

Images are automatically published to:

ghcr.io/jcsa2030/elhalawany-devops-lab

Available Tags:

* latest
* security
* build number tags

---

## Pipeline Gates

Deployment is blocked when:

* SonarQube Quality Gate fails
* OPA Policy Validation fails
* Critical security findings are detected
* Manual approval is not granted

---

## Current Version

DevSecOps Lab v1.0.0

Features:

* Secure CI/CD
* Software Supply Chain Security
* Secrets Management
* Security Monitoring
* Security Governance
* Container Registry Integration

---

## Author

Dr. Eng. Mohamed Elhalawany

Cybersecurity | DevSecOps | Data Protection | Digital Transformation

Saudi Arabia
