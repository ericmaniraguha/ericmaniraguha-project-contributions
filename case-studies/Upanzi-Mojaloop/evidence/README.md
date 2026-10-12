# 📸 Upanzi Mojaloop Evidence & Artifacts Guide

This directory holds technical evidence and screenshots demonstrating your contributions to the **Upanzi Mojaloop** financial inclusion project.

---

## 📁 Folders & Recommended Proof Assets

### 1. `grafana-dashboards/`
Add screenshots of your observability setup:
- `grafana-transaction-overview.png`: Real-time transaction throughput, active connections, and latency metrics.
- `grafana-logs-tracking.png`: Centralized log exploration (Loki/Prometheus) showing search filtering by `transactionId` or `traceId`.
- `grafana-alert-rules.png`: Configured alerting rules for system failure thresholds and latency spikes.

### 2. `database-design/`
Add screenshots and schema models:
- `mojaloop-db-schema-erd.png`: Entity-Relationship Diagram (ERD) of participant ledgers, currency tables, and transaction records.
- `sql-indexing-optimization.png`: Query execution plans (`EXPLAIN ANALYZE`) showing performance optimization.

### 3. `reporting-dashboard/`
Add UI screenshots of the reporting interfaces:
- `reporting-dashboard-main.png`: Overview dashboard showing volume by currency, success/failure distribution, and settlement batches.
- `financial-reports-export.png`: Detailed statement export / settlement report interface.

### 4. `contributions/`
Add direct proof of personal commits and PRs:
- `pull-requests.png`: Key merged pull requests authored by you on the Mojaloop / Upanzi repositories.
- `github-contributions.png`: Commit frequency, code reviews, and issue triage.

---
> [!NOTE]
> Ensure all proprietary participant credentials, live API secrets, and sensitive financial identifiers are masked or sanitized.
