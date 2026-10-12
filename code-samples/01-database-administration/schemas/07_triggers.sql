-- =============================================================================
-- 07_triggers.sql
-- Audit Triggers, Data Integrity Triggers, and Event-Driven Automation
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

SET search_path TO app, audit, public;

-- =============================================================================
-- PART A: AUDIT INFRASTRUCTURE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Generic Audit Log Table (captures all DML changes across tables)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit.change_log (
    log_id          BIGSERIAL PRIMARY KEY,
    table_schema    VARCHAR(63) NOT NULL,
    table_name      VARCHAR(63) NOT NULL,
    operation       VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    row_id          TEXT,                    -- Primary key value of affected row
    old_values      JSONB,                   -- Previous state (UPDATE, DELETE)
    new_values      JSONB,                   -- New state (INSERT, UPDATE)
    changed_columns TEXT[],                  -- List of columns changed (UPDATE only)
    changed_by      VARCHAR(100) NOT NULL DEFAULT CURRENT_USER,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    client_ip       INET DEFAULT inet_client_addr(),
    application     VARCHAR(100) DEFAULT current_setting('application_name', true)
);

CREATE INDEX IF NOT EXISTS idx_audit_change_log_table
    ON audit.change_log (table_schema, table_name, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_change_log_user
    ON audit.change_log (changed_by, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_change_log_operation
    ON audit.change_log (operation, changed_at DESC);

COMMENT ON TABLE audit.change_log IS 'Centralized audit trail capturing all INSERT, UPDATE, DELETE operations with before/after state';

-- -----------------------------------------------------------------------------
-- 2. Generic Audit Trigger Function
--    Attach this to any table to capture all DML changes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION audit.fn_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER  -- Runs with owner privileges to write to audit schema
AS $$
DECLARE
    v_row_id        TEXT;
    v_old_values    JSONB := NULL;
    v_new_values    JSONB := NULL;
    v_changed_cols  TEXT[] := '{}';
    v_col           TEXT;
BEGIN
    -- Determine the primary key value for identification
    IF TG_OP = 'DELETE' THEN
        v_row_id := OLD.*)::TEXT;  -- Fallback: use row text representation
        v_old_values := to_jsonb(OLD.*);
    ELSIF TG_OP = 'INSERT' THEN
        v_new_values := to_jsonb(NEW.*);
        v_row_id := (NEW.*)::TEXT;
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_values := to_jsonb(OLD.*);
        v_new_values := to_jsonb(NEW.*);
        v_row_id := (NEW.*)::TEXT;

        -- Identify which columns actually changed
        FOR v_col IN
            SELECT key FROM jsonb_each(v_new_values)
            WHERE v_new_values->key IS DISTINCT FROM v_old_values->key
        LOOP
            v_changed_cols := array_append(v_changed_cols, v_col);
        END LOOP;

        -- Skip if no actual data change (e.g., UPDATE with same values)
        IF array_length(v_changed_cols, 1) IS NULL THEN
            RETURN NEW;
        END IF;
    END IF;

    -- Insert audit record
    INSERT INTO audit.change_log (
        table_schema, table_name, operation,
        row_id, old_values, new_values, changed_columns
    ) VALUES (
        TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP,
        v_row_id, v_old_values, v_new_values, v_changed_cols
    );

    -- Return appropriate row
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

COMMENT ON FUNCTION audit.fn_audit_trigger IS 'Generic audit trigger function — captures old/new row values, changed columns, user, timestamp, and client IP';

-- =============================================================================
-- PART B: ATTACH AUDIT TRIGGERS TO KEY TABLES
-- =============================================================================

-- Customers audit
DROP TRIGGER IF EXISTS trg_audit_customers ON app.customers;
CREATE TRIGGER trg_audit_customers
    AFTER INSERT OR UPDATE OR DELETE ON app.customers
    FOR EACH ROW
    EXECUTE FUNCTION audit.fn_audit_trigger();

-- Orders audit
DROP TRIGGER IF EXISTS trg_audit_orders ON app.orders;
CREATE TRIGGER trg_audit_orders
    AFTER INSERT OR UPDATE OR DELETE ON app.orders
    FOR EACH ROW
    EXECUTE FUNCTION audit.fn_audit_trigger();

-- Transactions audit
DROP TRIGGER IF EXISTS trg_audit_transactions ON app.transactions;
CREATE TRIGGER trg_audit_transactions
    AFTER INSERT OR UPDATE OR DELETE ON app.transactions
    FOR EACH ROW
    EXECUTE FUNCTION audit.fn_audit_trigger();

-- Employees audit
DROP TRIGGER IF EXISTS trg_audit_employees ON app.employees;
CREATE TRIGGER trg_audit_employees
    AFTER INSERT OR UPDATE OR DELETE ON app.employees
    FOR EACH ROW
    EXECUTE FUNCTION audit.fn_audit_trigger();

-- System config audit
DROP TRIGGER IF EXISTS trg_audit_system_config ON app.system_config;
CREATE TRIGGER trg_audit_system_config
    AFTER INSERT OR UPDATE OR DELETE ON app.system_config
    FOR EACH ROW
    EXECUTE FUNCTION audit.fn_audit_trigger();

-- =============================================================================
-- PART C: DATA INTEGRITY TRIGGERS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 3. Auto-update `updated_at` timestamp on row modification
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

-- Apply to all tables with updated_at column
DROP TRIGGER IF EXISTS trg_updated_at_customers ON app.customers;
CREATE TRIGGER trg_updated_at_customers
    BEFORE UPDATE ON app.customers
    FOR EACH ROW
    EXECUTE FUNCTION app.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_updated_at_orders ON app.orders;
CREATE TRIGGER trg_updated_at_orders
    BEFORE UPDATE ON app.orders
    FOR EACH ROW
    EXECUTE FUNCTION app.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_updated_at_transactions ON app.transactions;
CREATE TRIGGER trg_updated_at_transactions
    BEFORE UPDATE ON app.transactions
    FOR EACH ROW
    EXECUTE FUNCTION app.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_updated_at_products ON app.products;
CREATE TRIGGER trg_updated_at_products
    BEFORE UPDATE ON app.products
    FOR EACH ROW
    EXECUTE FUNCTION app.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_updated_at_employees ON app.employees;
CREATE TRIGGER trg_updated_at_employees
    BEFORE UPDATE ON app.employees
    FOR EACH ROW
    EXECUTE FUNCTION app.fn_set_updated_at();

-- -----------------------------------------------------------------------------
-- 4. Prevent deletion of completed transactions (immutability)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.fn_prevent_transaction_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status = 'COMPLETED' THEN
        RAISE EXCEPTION 'Cannot delete completed transaction %. Use REVERSAL instead.',
            OLD.transaction_ref;
    END IF;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_txn_delete ON app.transactions;
CREATE TRIGGER trg_prevent_txn_delete
    BEFORE DELETE ON app.transactions
    FOR EACH ROW
    EXECUTE FUNCTION app.fn_prevent_transaction_delete();

-- -----------------------------------------------------------------------------
-- 5. Validate order status transitions (state machine enforcement)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.fn_validate_order_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_valid_transitions JSONB := '{
        "PENDING":     ["CONFIRMED", "CANCELLED"],
        "CONFIRMED":   ["PROCESSING", "CANCELLED"],
        "PROCESSING":  ["SHIPPED", "CANCELLED"],
        "SHIPPED":     ["DELIVERED"],
        "DELIVERED":   ["REFUNDED"],
        "CANCELLED":   [],
        "REFUNDED":    []
    }'::JSONB;
    v_allowed JSONB;
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    v_allowed := v_valid_transitions->OLD.status;

    IF v_allowed IS NULL OR NOT v_allowed ? NEW.status THEN
        RAISE EXCEPTION 'Invalid order status transition: % → %. Allowed transitions from %: %',
            OLD.status, NEW.status, OLD.status,
            COALESCE(v_allowed::TEXT, 'none');
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_order_status ON app.orders;
CREATE TRIGGER trg_validate_order_status
    BEFORE UPDATE OF status ON app.orders
    FOR EACH ROW
    EXECUTE FUNCTION app.fn_validate_order_status();

COMMENT ON FUNCTION app.fn_validate_order_status IS 'Enforces valid order status transitions using a state machine pattern stored in JSONB';

-- =============================================================================
-- Verify all triggers
-- =============================================================================
SELECT
    trigger_schema,
    trigger_name,
    event_manipulation,
    event_object_schema || '.' || event_object_table AS target_table,
    action_timing,
    action_orientation
FROM information_schema.triggers
WHERE trigger_schema IN ('app', 'audit')
ORDER BY event_object_table, trigger_name;
