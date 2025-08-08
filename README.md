# Automated AWS Security Lab – Terraform & AWS CLI

## Overview
This project provisions a **security-focused AWS lab** entirely through Infrastructure as Code (Terraform) and AWS CLI validation.  
It is adapted from a manual AWS lab and rebuilt to follow **AWS Well-Architected best practices**, with a focus on **security-by-design**, repeatability, and event-driven incident response.

---

## Architecture
- **Networking Layer**
  - Custom VPC, subnets, and routing
  - Internet Gateway for outbound traffic
- **Security Layer**
  - Security groups with least-privilege rules
  - Default deny posture
- **Core Assets**
  - **EC2 A** – Intentionally assigned a **blacklisted Elastic IP** to simulate malicious actor activity.
  - **EC2 B** – Simulated **user-owned asset** for legitimate operations.
  - **Admin S3 bucket** – Stores threatlist for automation.
  - **Test S3 bucket** – General lab storage.
- **Security Monitoring**
  - AWS GuardDuty and Security Hub enabled at deployment.
- **Automated Response**
  - Lambda function triggers when GuardDuty detects IP addresses listed in the Admin S3 threatlist.

---

## Key Features
- **Fully Automated Deployment** – All resources provisioned via Terraform.
- **Security-First Sequencing** – Networking and access control deployed before workloads.
- **Integrated Threat Simulation** – EC2 A triggers GuardDuty by design.
- **Event-Driven Incident Response** – Lambda acts automatically on GuardDuty findings.
- **Repeatable & Extensible** – Ideal for red team/blue team exercises and cloud security training.

---

## Use Case
This environment is designed for:
- Testing AWS threat detection and automated response workflows.
- Practicing secure cloud architecture deployment.
- Simulating malicious activity and verifying monitoring effectiveness.
- Rapid redeployment for training or CTF scenarios.

---

## Author
**Cuong "cu5t05" Nguyen** – Cybersecurity & Cloud Security Engineer  
[LinkedIn](https://www.linkedin.com/in/cu5t05) | [GitHub](https://github.com/cu5t05)
