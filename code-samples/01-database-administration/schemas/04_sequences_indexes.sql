-- =============================================================================
-- 04_sequences_indexes.sql
-- Custom Sequences and Composite/Partial/Expression Indexes
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

SET search_path TO app, public;

-- =============================================================================
-- PART A: CUSTOM SEQUENCES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Customer Code Sequence (CUST-00001, CUST-00002, ...)
-- -----------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS app.seq_customer_code
    START WITH 1
    INCREMENT BY 1
    MINVALUE 1
    MAXVALUE 9999999
    NO CYCLE
    CACHE 10;

COMMENT ON SEQUENCE app.seq_customer_code IS 'Auto-incrementing sequence for human-readable customer codes';

-- Helper function to generate formatted customer codes
CREATE OR REPLACE FUNCTION app.generate_customer_code()
RETURNS VARCHAR(20)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN 'CUST-' || LPAD(nextval('app.seq_customer_code')::TEXT, 5, '0');
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. Order Number Sequence (ORD-2026-000001, ...)
-- -----------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS app.seq_order_number
    START WITH 1
    INCREMENT BY 1
    NO CYCLE
    CACHE 20;

COMMENT ON SEQUENCE app.seq_order_number IS 'Auto-incrementing sequence for order numbers with year prefix';

CREATE OR REPLACE FUNCTION app.generate_order_number()
RETURNS VARCHAR(30)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN 'ORD-' || EXTRACT(YEAR FROM CURRENT_DATE)::TEXT || '-' ||
           LPAD(nextval('app.seq_order_number')::TEXT, 6, '0');
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. Transaction Reference Sequence (TXN-20261013-000001, ...)
-- -----------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS app.seq_transaction_ref
    START WITH 1
    INCREMENT BY 1
    NO CYCLE
    CACHE 50;

CREATE OR REPLACE FUNCTION app.generate_transaction_ref()
RETURNS VARCHAR(64)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN 'TXN-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' ||
           LPAD(nextval('app.seq_transaction_ref')::TEXT, 6, '0');
END;
$$;

-- =============================================================================
-- PART B: INDEX STRATEGIES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- B-Tree Indexes (default, most common)
-- -----------------------------------------------------------------------------

-- Customers: fast lookup by status and type for dashboards
CREATE INDEX IF NOT EXISTS idx_customers_status_type
    ON app.customers (status, customer_type);

-- Customers: fast full-name search for support lookups
CREATE INDEX IF NOT EXISTS idx_customers_name
    ON app.customers (last_name, first_name);

-- Orders: fast range scans by date for reporting
CREATE INDEX IF NOT EXISTS idx_orders_date_status
    ON app.orders (order_date DESC, status);

-- Orders: customer order history lookups
CREATE INDEX IF NOT EXISTS idx_orders_customer_date
    ON app.orders (customer_id, order_date DESC);

-- Transactions: payment reconciliation queries
CREATE INDEX IF NOT EXISTS idx_transactions_channel_status
    ON app.transactions (payment_channel, status, created_at DESC);

-- Transactions: external reference lookup (gateway matching)
CREATE INDEX IF NOT EXISTS idx_transactions_external_ref
    ON app.transactions (external_ref)
    WHERE external_ref IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Composite Indexes (multi-column for common query patterns)
-- -----------------------------------------------------------------------------

-- Order items: join acceleration for order detail queries
CREATE INDEX IF NOT EXISTS idx_order_items_order_product
    ON app.order_items (order_id, product_id);

-- Transactions: customer transaction history with date range
CREATE INDEX IF NOT EXISTS idx_transactions_customer_date
    ON app.transactions (customer_id, created_at DESC);

-- -----------------------------------------------------------------------------
-- Partial Indexes (conditional — smaller, faster)
-- -----------------------------------------------------------------------------

-- Only active customers (skip CLOSED/SUSPENDED for most queries)
CREATE INDEX IF NOT EXISTS idx_customers_active_email
    ON app.customers (email)
    WHERE status = 'ACTIVE';

-- Only pending orders (operational dashboard, small subset)
CREATE INDEX IF NOT EXISTS idx_orders_pending
    ON app.orders (order_date DESC)
    WHERE status IN ('PENDING', 'PROCESSING');

-- Failed transactions (for reconciliation and error investigation)
CREATE INDEX IF NOT EXISTS idx_transactions_failed
    ON app.transactions (created_at DESC, payment_channel)
    WHERE status = 'FAILED';

-- Pending transactions (for retry processing)
CREATE INDEX IF NOT EXISTS idx_transactions_pending
    ON app.transactions (created_at)
    WHERE status = 'PENDING';

-- -----------------------------------------------------------------------------
-- Expression Indexes (computed values)
-- -----------------------------------------------------------------------------

-- Case-insensitive email search
CREATE INDEX IF NOT EXISTS idx_customers_email_lower
    ON app.customers (LOWER(email));

-- Year-month extraction for monthly reporting without date_trunc at query time
CREATE INDEX IF NOT EXISTS idx_orders_year_month
    ON app.orders (DATE_TRUNC('month', order_date));

-- Full-name search (concatenated)
CREATE INDEX IF NOT EXISTS idx_customers_fullname
    ON app.customers ((first_name || ' ' || last_name));

-- -----------------------------------------------------------------------------
-- GIN Indexes (for text search / LIKE patterns using pg_trgm)
-- -----------------------------------------------------------------------------

-- Trigram index for fuzzy customer name search (%pattern%)
CREATE INDEX IF NOT EXISTS idx_customers_name_trgm
    ON app.customers USING gin (first_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_customers_lastname_trgm
    ON app.customers USING gin (last_name gin_trgm_ops);

-- Trigram index for product name search
CREATE INDEX IF NOT EXISTS idx_products_name_trgm
    ON app.products USING gin (product_name gin_trgm_ops);

-- =============================================================================
-- Verify indexes
-- =============================================================================
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'app'
ORDER BY tablename, indexname;
