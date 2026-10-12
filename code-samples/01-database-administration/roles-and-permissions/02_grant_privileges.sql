-- =============================================================================
-- 02_grant_privileges.sql
-- Granular GRANT/REVOKE on Schemas, Tables, Sequences, and Functions
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

-- =============================================================================
-- 1. SCHEMA-LEVEL PRIVILEGES
-- =============================================================================

-- app_readonly: can access app and analytics schemas
GRANT USAGE ON SCHEMA app TO app_readonly;
GRANT USAGE ON SCHEMA analytics TO app_readonly;

-- app_readwrite: can access app schema for DML operations
GRANT USAGE ON SCHEMA app TO app_readwrite;
GRANT USAGE ON SCHEMA staging TO app_readwrite;

-- dba_admin: full access to all schemas
GRANT ALL PRIVILEGES ON SCHEMA app TO dba_admin;
GRANT ALL PRIVILEGES ON SCHEMA audit TO dba_admin;
GRANT ALL PRIVILEGES ON SCHEMA analytics TO dba_admin;
GRANT ALL PRIVILEGES ON SCHEMA staging TO dba_admin;
GRANT ALL PRIVILEGES ON SCHEMA archive TO dba_admin;

-- backup_operator: read-only on all schemas (for pg_dump)
GRANT USAGE ON SCHEMA app TO backup_operator;
GRANT USAGE ON SCHEMA audit TO backup_operator;
GRANT USAGE ON SCHEMA analytics TO backup_operator;

-- monitoring_agent: only system views (no application schemas needed)
GRANT USAGE ON SCHEMA app TO monitoring_agent;

-- =============================================================================
-- 2. TABLE-LEVEL PRIVILEGES
-- =============================================================================

-- app_readonly: SELECT only on app tables and materialized views
GRANT SELECT ON ALL TABLES IN SCHEMA app TO app_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO app_readonly;

-- Ensure future tables in these schemas also get SELECT
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT ON TABLES TO app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics GRANT SELECT ON TABLES TO app_readonly;

-- app_readwrite: SELECT, INSERT, UPDATE on app tables (no DELETE, no TRUNCATE)
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA app TO app_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT, INSERT, UPDATE ON TABLES TO app_readwrite;

-- Staging: full DML for ETL operations
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA staging TO app_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLES TO app_readwrite;

-- dba_admin: full control on all tables in all schemas
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app TO dba_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA audit TO dba_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA analytics TO dba_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA staging TO dba_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA archive TO dba_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL PRIVILEGES ON TABLES TO dba_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT ALL PRIVILEGES ON TABLES TO dba_admin;

-- backup_operator: SELECT only for dump operations
GRANT SELECT ON ALL TABLES IN SCHEMA app TO backup_operator;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO backup_operator;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO backup_operator;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT ON TABLES TO backup_operator;

-- monitoring_agent: no table access needed (uses pg_stat views)
-- Optionally grant SELECT on specific monitoring views if created

-- =============================================================================
-- 3. SEQUENCE PRIVILEGES
-- =============================================================================

-- app_readwrite: needs USAGE on sequences for INSERT operations
GRANT USAGE ON ALL SEQUENCES IN SCHEMA app TO app_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT USAGE ON SEQUENCES TO app_readwrite;

-- dba_admin: full control
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA app TO dba_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL PRIVILEGES ON SEQUENCES TO dba_admin;

-- =============================================================================
-- 4. FUNCTION / PROCEDURE PRIVILEGES
-- =============================================================================

-- app_readonly: can execute reporting functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO app_readonly;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA analytics TO app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics GRANT EXECUTE ON FUNCTIONS TO app_readonly;

-- app_readwrite: can execute business logic procedures and functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO app_readwrite;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA app TO app_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT EXECUTE ON FUNCTIONS TO app_readwrite;

-- dba_admin: full execute on all schemas
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO dba_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA audit TO dba_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA analytics TO dba_admin;

-- =============================================================================
-- 5. EXPLICIT REVOCATIONS (defense in depth)
-- =============================================================================

-- Remove default PUBLIC privileges from schemas
REVOKE ALL ON SCHEMA app FROM PUBLIC;
REVOKE ALL ON SCHEMA audit FROM PUBLIC;
REVOKE ALL ON SCHEMA analytics FROM PUBLIC;
REVOKE ALL ON SCHEMA staging FROM PUBLIC;
REVOKE ALL ON SCHEMA archive FROM PUBLIC;

-- Prevent app_readonly from any DML
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA app FROM app_readonly;

-- Prevent app_readwrite from DELETE on critical tables
REVOKE DELETE ON app.transactions FROM app_readwrite;
REVOKE DELETE ON app.customers FROM app_readwrite;

-- =============================================================================
-- 6. VERIFY GRANTS
-- =============================================================================
SELECT
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('app_readonly', 'app_readwrite', 'dba_admin', 'backup_operator')
ORDER BY grantee, table_schema, table_name, privilege_type;
