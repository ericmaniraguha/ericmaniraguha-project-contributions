# 🏢 Project Case Studies

Work I delivered for organizations, written up as consulting-style case studies.

> 🔒 **Confidentiality:** The source code and repositories behind these projects belong to the organizations involved and are private. Each case study describes **my role, the problem, the design decisions, and the outcomes**. Supporting screenshots in each `evidence/` folder are sanitized. I'm happy to walk through any of these in detail during an interview.

| Case Study | Domain | Data Engineering Focus |
|:-----------|:-------|:-----------------------|
| [Upanzi Network: Mojaloop](./Upanzi-Mojaloop/) | Financial inclusion | Ledger data modelling, reporting dashboards, Grafana observability |
| [FinTech Core & Payment Engine](./FinTech-Core-Banking-Engine/) | Payments | Double-entry ledger, reconciliation pipelines, data integrity |
| [CyLab Africa](./CyLab-Africa/) | Cybersecurity research | Telemetry ingestion & categorization pipeline |
| [BrightSeed Hub](./BrightSeed-Hub/) | Community platform | Multi-tenant data model, intake pipelines |
| [Tech-Connect Business Park](./Tech-Connect-Business-Park/) | Enterprise platform | RBAC data access, workflow automation |

⬅️ [Back to portfolio overview](../README.md)

---

## 📝 Case Study Template

Use this structure when adding a new project so every write-up reads the same way:

```markdown
# <Project Name>

> One-sentence description of the system and who it serves.

## 📌 Engagement Summary
- **Organization / client type:** (name, or "Regional bank": anonymize if required)
- **My role:** e.g. Data Engineering Consultant / Lead Data Engineer
- **Period:** YYYY – YYYY
- **Team:** e.g. 4 engineers, 1 analyst
- **Stack:** ...

## 🎯 Problem
What was broken, slow, manual, or missing, and why it mattered to the business.

## 🛠️ What I Delivered
1. Data model / pipeline / dashboard / process (be specific about *your* part)
2. ...

## 🏗️ Architecture
Sanitized Mermaid diagram of the data flow.

## 📈 Outcomes
| Metric | Before | After |
|:--|:--|:--|

## 🗂️ Evidence
Sanitized screenshots in `evidence/` (dashboards, ERDs, query plans, PR lists with private details blurred).

## 🔒 Confidentiality
What was withheld and why. Available for walkthrough on request.
```

### Sanitization checklist before adding screenshots
- [ ] Blur customer names, account numbers, phone numbers, and emails
- [ ] Remove API keys, tokens, connection strings, and internal hostnames/IPs
- [ ] Hide private repository names/URLs if the organization requires it
- [ ] Confirm the organization allows mentioning the project at all
