-- =============================================================================
-- 01_create_roles.sql
-- Role Hierarchy: app_readonly, app_readwrite, dba_admin, backup_operator
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

-- =============================================================================
-- 1. CREATE ROLE HIERARCHY (Principle of Least Privilege)
-- =============================================================================

-- Base role: read-only access for analysts and reporting tools
CREATE ROLE app_readonly
    NOSUPERUSER NOINHERIT NOCREATEDB NOCREATEROLE NOREPLICATION
    CONNECTION LIMIT 20;

COMMENT ON ROLE app_readonly IS 'Read-only access for analysts, BI tools, and reporting dashboards';

-- Application role: read-write for the application service layer
CREATE ROLE app_readwrite
    NOSUPERUSER NOINHERIT NOCREATEDB NOCREATEROLE NOREPLICATION
    CONNECTION LIMIT 50;

COMMENT ON ROLE app_readwrite IS 'Read-write access for application services (API backends)';

-- DBA administrator: full schema management (no superuser)
CREATE ROLE dba_admin
    NOSUPERUSER INHERIT CREATEDB CREATEROLE NOREPLICATION
    CONNECTION LIMIT 5;

COMMENT ON ROLE dba_admin IS 'Database administrator with schema management and role administration privileges';

-- Backup operator: minimal privileges for backup/restore operations
CREATE ROLE backup_operator
    NOSUPERUSER NOINHERIT NOCREATEDB NOCREATEROLE NOREPLICATION
    CONNECTION LIMIT 3;

COMMENT ON ROLE backup_operator IS 'Dedicated role for automated backup and restore operations with minimal privileges';

-- Monitoring role: read-only access to system views
CREATE ROLE monitoring_agent
    NOSUPERUSER NOINHERIT NOCREATEDB NOCREATEROLE NOREPLICATION
    CONNECTION LIMIT 5;

COMMENT ON ROLE monitoring_agent IS 'Monitoring agent with read access to pg_stat views and system catalogs';

-- =============================================================================
-- 2. CREATE LOGIN USERS (inherit from roles)
-- =============================================================================

-- Analyst user
CREATE USER analyst_user WITH
    PASSWORD 'CHANGE_ME_IN_PRODUCTION'
    IN ROLE app_readonly
    VALID UNTIL '2027-12-31';

-- Application service account
CREATE USER app_service WITH
    PASSWORD 'CHANGE_ME_IN_PRODUCTION'
    IN ROLE app_readwrite
    VALID UNTIL '2027-12-31';

-- DBA user
CREATE USER eric_dba WITH
    PASSWORD 'CHANGE_ME_IN_PRODUCTION'
    IN ROLE dba_admin;

-- Backup service account
CREATE USER backup_service WITH
    PASSWORD 'CHANGE_ME_IN_PRODUCTION'
    IN ROLE backup_operator;

-- Monitoring agent
CREATE USER grafana_monitor WITH
    PASSWORD 'CHANGE_ME_IN_PRODUCTION'
    IN ROLE monitoring_agent
    VALID UNTIL '2027-12-31';

-- =============================================================================
-- 3. VERIFY ROLES AND MEMBERSHIPS
-- =============================================================================
SELECT
    r.rolname AS role_name,
    r.rolcanlogin AS can_login,
    r.rolcreatedb AS can_create_db,
    r.rolcreaterole AS can_create_role,
    r.rolconnlimit AS connection_limit,
    r.rolvaliduntil AS valid_until,
    ARRAY_AGG(m.rolname) FILTER (WHERE m.rolname IS NOT NULL) AS member_of
FROM pg_roles r
LEFT JOIN pg_auth_members am ON r.oid = am.member
LEFT JOIN pg_roles m ON am.roleid = m.oid
WHERE r.rolname IN ('app_readonly', 'app_readwrite', 'dba_admin',
                     'backup_operator', 'monitoring_agent',
                     'analyst_user', 'app_service', 'eric_dba',
                     'backup_service', 'grafana_monitor')
GROUP BY r.rolname, r.rolcanlogin, r.rolcreatedb, r.rolcreaterole,
         r.rolconnlimit, r.rolvaliduntil
ORDER BY r.rolcanlogin, r.rolname;
