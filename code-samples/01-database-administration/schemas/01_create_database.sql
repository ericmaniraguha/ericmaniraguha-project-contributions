-- =============================================================================
-- 01_create_database.sql
-- Database and Schema Creation for Enterprise Application
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Create the main application database
-- -----------------------------------------------------------------------------
CREATE DATABASE enterprise_db
    WITH
    OWNER = dba_admin
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = 200
    IS_TEMPLATE = false;

COMMENT ON DATABASE enterprise_db IS 'Primary enterprise application database — production environment';

-- -----------------------------------------------------------------------------
-- 2. Connect to the new database and create schemas
-- -----------------------------------------------------------------------------
\connect enterprise_db;

-- Core application schema
CREATE SCHEMA IF NOT EXISTS app
    AUTHORIZATION dba_admin;

COMMENT ON SCHEMA app IS 'Core application tables: customers, orders, products, transactions';

-- Audit and compliance schema
CREATE SCHEMA IF NOT EXISTS audit
    AUTHORIZATION dba_admin;

COMMENT ON SCHEMA audit IS 'Audit trail tables and compliance logging';

-- Analytics and reporting schema
CREATE SCHEMA IF NOT EXISTS analytics
    AUTHORIZATION dba_admin;

COMMENT ON SCHEMA analytics IS 'Materialized views, aggregations, and reporting tables';

-- Staging schema for data migration and ETL
CREATE SCHEMA IF NOT EXISTS staging
    AUTHORIZATION dba_admin;

COMMENT ON SCHEMA staging IS 'Temporary staging tables for data migration, ETL, and bulk loads';

-- Archive schema for historical data
CREATE SCHEMA IF NOT EXISTS archive
    AUTHORIZATION dba_admin;

COMMENT ON SCHEMA archive IS 'Archived and partitioned historical data with retention policies';

-- -----------------------------------------------------------------------------
-- 3. Set the default search path
-- -----------------------------------------------------------------------------
ALTER DATABASE enterprise_db SET search_path TO app, audit, analytics, public;

-- -----------------------------------------------------------------------------
-- 4. Enable required extensions
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";          -- UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";           -- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";  -- Query performance statistics
CREATE EXTENSION IF NOT EXISTS "pg_trgm";            -- Trigram text similarity
CREATE EXTENSION IF NOT EXISTS "btree_gist";         -- GiST index support
CREATE EXTENSION IF NOT EXISTS "tablefunc";          -- Crosstab / pivot functionality

-- -----------------------------------------------------------------------------
-- 5. Configure database-level parameters
-- -----------------------------------------------------------------------------
ALTER DATABASE enterprise_db SET timezone TO 'Africa/Kigali';
ALTER DATABASE enterprise_db SET statement_timeout TO '30s';
ALTER DATABASE enterprise_db SET idle_in_transaction_session_timeout TO '300s';
ALTER DATABASE enterprise_db SET log_min_duration_statement TO 500;  -- Log queries > 500ms

-- Verify creation
SELECT
    datname AS database_name,
    pg_encoding_to_char(encoding) AS encoding,
    datcollate AS collation,
    datconnlimit AS connection_limit
FROM pg_database
WHERE datname = 'enterprise_db';
