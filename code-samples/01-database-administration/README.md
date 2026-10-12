# 01 — Database Administration

> PostgreSQL schema management, roles, permissions, stored procedures, triggers, and production monitoring.

---

## 📋 Contents

### `schemas/` — DDL & Database Objects
| File | Description |
|:-----|:------------|
| `01_create_database.sql` | Database and schema creation with encoding, locale, and tablespace configuration |
| `02_tables_constraints.sql` | Production tables with PK, FK, CHECK, UNIQUE, NOT NULL, and DEFAULT constraints |
| `03_views_materialized.sql` | Standard views and materialized views with refresh strategies |
| `04_sequences_indexes.sql` | Custom sequences and composite/partial/expression indexes |
| `05_stored_procedures.sql` | PL/pgSQL stored procedures for business logic and maintenance |
| `06_functions.sql` | Scalar functions, table-returning functions, and aggregate helpers |
| `07_triggers.sql` | Audit triggers, data integrity triggers, and event-driven automation |

### `roles-and-permissions/` — Access Management
| File | Description |
|:-----|:------------|
| `01_create_roles.sql` | Role hierarchy: `app_readonly`, `app_readwrite`, `dba_admin`, `backup_operator` |
| `02_grant_privileges.sql` | Granular GRANT/REVOKE on schemas, tables, sequences, and functions |
| `03_row_level_security.sql` | Row-Level Security (RLS) policies for multi-tenant data isolation |

### `monitoring/` — Health & Diagnostics
| File | Description |
|:-----|:------------|
| `connection_monitor.sql` | Active connections, idle-in-transaction, connection pool usage |
| `table_stats.sql` | Table bloat, dead tuples, autovacuum statistics, and storage analysis |
| `lock_investigation.sql` | Lock detection, blocking queries, and deadlock investigation |

---

## 🚀 Usage

```bash
# Connect to PostgreSQL
psql -U postgres -h localhost

# Execute schema creation
psql -U postgres -d postgres -f schemas/01_create_database.sql
psql -U dba_admin -d enterprise_db -f schemas/02_tables_constraints.sql
psql -U dba_admin -d enterprise_db -f schemas/03_views_materialized.sql
# ... and so on

# Run monitoring queries
psql -U dba_admin -d enterprise_db -f monitoring/connection_monitor.sql
```

---

## 🔗 Related Sections
- Performance tuning: [02-performance-tuning](../02-performance-tuning/)
- Applied on client work: [FinTech double-entry ledger](../../case-studies/FinTech-Core-Banking-Engine/ARCHITECTURE.md)
- ⬅️ [Back to portfolio overview](../../README.md)
