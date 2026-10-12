-- =============================================================================
-- 03_row_level_security.sql
-- Row-Level Security (RLS) Policies for Multi-Tenant Data Isolation
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

SET search_path TO app, public;

-- =============================================================================
-- SCENARIO: Multi-tenant SaaS application where different departments
-- can only see their own employees and orders. DBA/admin users see everything.
-- =============================================================================

-- =============================================================================
-- 1. ENABLE RLS ON TARGET TABLES
-- =============================================================================

ALTER TABLE app.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.transactions ENABLE ROW LEVEL SECURITY;

-- Force RLS for table owners too (important for testing)
ALTER TABLE app.employees FORCE ROW LEVEL SECURITY;
ALTER TABLE app.orders FORCE ROW LEVEL SECURITY;
ALTER TABLE app.transactions FORCE ROW LEVEL SECURITY;

-- =============================================================================
-- 2. RLS POLICIES — EMPLOYEES TABLE
-- =============================================================================

-- Policy: Department managers can see only their department's employees
CREATE POLICY pol_employees_department_read
    ON app.employees
    FOR SELECT
    TO app_readonly, app_readwrite
    USING (
        department = current_setting('app.current_department', true)
        OR current_setting('app.user_role', true) = 'ADMIN'
    );

-- Policy: HR and managers can insert/update employees in their department
CREATE POLICY pol_employees_department_write
    ON app.employees
    FOR ALL
    TO app_readwrite
    USING (
        department = current_setting('app.current_department', true)
        OR current_setting('app.user_role', true) IN ('ADMIN', 'HR')
    )
    WITH CHECK (
        department = current_setting('app.current_department', true)
        OR current_setting('app.user_role', true) IN ('ADMIN', 'HR')
    );

-- Policy: DBA admin bypasses all RLS
CREATE POLICY pol_employees_admin_bypass
    ON app.employees
    FOR ALL
    TO dba_admin
    USING (TRUE)
    WITH CHECK (TRUE);

-- =============================================================================
-- 3. RLS POLICIES — ORDERS TABLE
-- =============================================================================

-- Policy: Users see orders only from their assigned customers/region
CREATE POLICY pol_orders_department_read
    ON app.orders
    FOR SELECT
    TO app_readonly, app_readwrite
    USING (
        created_by = CURRENT_USER
        OR current_setting('app.user_role', true) = 'ADMIN'
    );

CREATE POLICY pol_orders_admin_bypass
    ON app.orders
    FOR ALL
    TO dba_admin
    USING (TRUE)
    WITH CHECK (TRUE);

-- =============================================================================
-- 4. RLS POLICIES — TRANSACTIONS TABLE
-- =============================================================================

-- Policy: Finance staff see all transactions; others see their own
CREATE POLICY pol_transactions_finance_read
    ON app.transactions
    FOR SELECT
    TO app_readonly, app_readwrite
    USING (
        current_setting('app.current_department', true) = 'FINANCE'
        OR current_setting('app.user_role', true) = 'ADMIN'
    );

CREATE POLICY pol_transactions_admin_bypass
    ON app.transactions
    FOR ALL
    TO dba_admin
    USING (TRUE)
    WITH CHECK (TRUE);

-- =============================================================================
-- 5. HOW TO USE: Set session variables before queries
-- =============================================================================

-- Example: A finance department manager logs in
-- SET app.current_department = 'FINANCE';
-- SET app.user_role = 'MANAGER';
-- SELECT * FROM app.employees;  -- sees only FINANCE employees

-- Example: An admin user
-- SET app.user_role = 'ADMIN';
-- SELECT * FROM app.employees;  -- sees all employees

-- Example: An engineering team member
-- SET app.current_department = 'ENGINEERING';
-- SET app.user_role = 'MEMBER';
-- SELECT * FROM app.employees;  -- sees only ENGINEERING employees

-- =============================================================================
-- 6. VERIFY RLS STATUS
-- =============================================================================
SELECT
    schemaname,
    tablename,
    rowsecurity AS rls_enabled,
    forcerowsecurity AS rls_forced
FROM pg_tables
WHERE schemaname = 'app'
  AND tablename IN ('employees', 'orders', 'transactions')
ORDER BY tablename;

-- List all policies
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual AS using_expression,
    with_check
FROM pg_policies
WHERE schemaname = 'app'
ORDER BY tablename, policyname;
