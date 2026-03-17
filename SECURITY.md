# Security Policy

## Reporting Vulnerabilities

This is a demo repository. If you find a security issue, open a GitHub issue or contact the maintainer directly.

## Sensitive Data

- Never commit `.tfstate`, `.tfvars`, or credential files
- Use Secret Manager for all secrets (not environment variables in production)
- Use `user-managed` replication for secrets inside Assured Workloads
- Rotate Cloud KMS keys on a 90-day schedule

## Compliance

This repo targets FedRAMP High / DoD IL5 controls mapped to NIST 800-53 Rev 5. See `main.tf` for control annotations on each resource.
