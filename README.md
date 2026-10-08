# 🚀 Engineering Contributions & Portfolio

Welcome to the central repository showcasing technical contributions, system architecture case studies, and engineering deliverables across production projects.

Each project directory includes:
- **Case Study (`README.md`):** Problem context, architecture decisions, engineering challenges, and business impact.
- **Evidence Dossier (`evidence/`):** Verified pull requests, git activity, architecture diagrams, test suites, and performance reports.
- **Architectural & Security Docs (`docs/`):** Deep dives into data models, security compliance, and API specifications.

---

## 📂 Project Index

| Project Name | Domain & Scope | Core Technologies | Key Focus Areas |
| :--- | :--- | :--- | :--- |
| [**FinTech Core & Payment Engine**](./FinTech-Core-Banking-Engine/) | Financial Services / Payments | Node.js, PostgreSQL, Redis, Docker | Double-entry ledger, Idempotency, Zero balance discrepancy |
| [**Tech-Connect Business Park**](./Tech-Connect-Business-Park/) | Enterprise Management System | React, TypeScript, REST API, Tailwind | High-throughput portal, Role-Based Access, Workflows |
| [**CyLab Africa**](./CyLab-Africa/) | Cybersecurity & Research Platform | Python, Fastify/Django, Cloud Infra | Security benchmarking, Threat intelligence, Analytics |
| [**BrightSeed Hub**](./BrightSeed-Hub/) | Innovation & Community Platform | Next.js, GraphQL, PostgreSQL | Multi-tenant platform, Real-time collaboration |

---

## 💼 Financial Project Highlights
For hiring managers and technical interviewers assessing financial software engineering:
- **Double-Entry General Ledger:** Immutable ledger schema with ACID transactions (`∑ Debits = ∑ Credits`).
- **Distributed Concurrency & Idempotency:** Atomic Redis locking and unique idempotency keys preventing race conditions and double charges.
- **Reconciliation Engine:** Automated batch settlement verification matching internal transactions against third-party financial rails (Mobile Money / Cards / Bank APIs).
- **Compliance & Security:** Tamper-evident audit trails, role-based controls, and PCI-DSS aligned data masking.

👉 [**Explore the FinTech Case Study & Architecture →**](./FinTech-Core-Banking-Engine/)

---

## 📌 Evidence Verification Guidelines
All evidence assets in the respective `evidence/` directories have been sanitized to remove proprietary client credentials, sensitive PII, and production access tokens while maintaining full architectural and verification integrity.

---
*Maintained by Eric Maniraguha • Software Engineer*
