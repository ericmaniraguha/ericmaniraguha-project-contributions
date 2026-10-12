# 📸 Evidence & Artifacts Guide

This directory holds verified technical artifacts and evidence proving your engineering contributions to the financial project.

---

## 📁 Directory Structure & Checklist

### 1. `architecture/`
Place visual proof of system designs:
- `system-architecture.png`: High-level diagram showing API gateway, microservices, database, cache, and external payment rails.
- `payment-flow-diagram.png`: Sequence flow demonstrating transaction lifecycle, idempotency check, and rollback paths.
- `double-entry-ledger-model.png`: Entity-Relationship (ER) diagram or DB schema visualization showing the ledger tables.

### 2. `performance-and-testing/`
Place verification of high availability and correctness:
- `stress-load-test-report.png`: Screenshots from k6, JMeter, or Grafana showing TPS, low latency (e.g. P99 < 200ms), and 0% HTTP 500 error rates.
- `test-coverage-report.png`: Jest / Istanbul HTML coverage report demonstrating high test coverage (>90%) across financial calculation and ledger modules.
- `fuzz-testing-output.png`: Logs proving concurrency testing with hundreds of simultaneous parallel transfers.

### 3. `security-and-compliance/`
Demonstrate enterprise-grade security rigor:
- `security-audit-report.png`: Clean scan results from Snyk, SonarQube, or OWASP ZAP showing zero high/critical vulnerabilities.
- `audit-trail-sample.png`: Screenshot of sanitized tamper-evident audit logs showing cryptographic hash chaining.

### 4. `contributions/`
Direct evidence of your personal contributions:
- `pull-requests.png`: Key PRs authored by you (e.g., implementing idempotency lock, ledger reconciliation, payment rail integrations).
- `code-review-contributions.png`: High-value code reviews you provided to teammates focusing on security, performance, or edge-case handling.
- `git-activity-graph.png`: Git contribution frequency or commit history graph.

---

> [!TIP]
> **Sanitization Reminder:** Always blur or mask real customer names, live API tokens, proprietary database connection strings, or merchant credentials before saving images here.
