-- =============================================================================
-- 03_index_improvements.sql
-- Targeted Index Creation Based on Execution Plan Analysis
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

-- =============================================================================
-- PROBLEM ANALYSIS (from 02_explain_analyze_before.sql):
--
-- 1. Seq Scan on orders: WHERE order_date >= ... AND status NOT IN (...)
--    → Need: composite index on (order_date, status) with included columns
--
-- 2. Seq Scan on transactions: JOIN on order_id
--    → Need: index on (order_id) with included columns for coverage
--
-- 3. DATE_TRUNC('month', order_date) computed per row
--    → Need: expression index for pre-computed date truncation
-- =============================================================================

-- -----------------------------------------------------------------------------
-- FIX 1: Composite covering index on orders for date range + status filter
-- Strategy: Put the range-scanned column first, filter column second,
--           and INCLUDE frequently selected columns to enable index-only scan
-- -----------------------------------------------------------------------------
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_date_status_covering
    ON app.orders (order_date, status)
    INCLUDE (order_id, customer_id, net_amount)
    WHERE status NOT IN ('CANCELLED', 'REFUNDED');

COMMENT ON INDEX app.idx_orders_date_status_covering IS
    'Covering index for revenue reports: date range scan + status filter with included columns for index-only access';

-- -----------------------------------------------------------------------------
-- FIX 2: Index on transactions for join acceleration + payment channel
-- Strategy: order_id for join, include payment_channel, amount, status for coverage
-- -----------------------------------------------------------------------------
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transactions_order_covering
    ON app.transactions (order_id)
    INCLUDE (payment_channel, amount, status, customer_id);

COMMENT ON INDEX app.idx_transactions_order_covering IS
    'Covering index for order-transaction joins with included columns for revenue aggregation queries';

-- -----------------------------------------------------------------------------
-- FIX 3: Expression index on DATE_TRUNC for monthly grouping
-- Strategy: Pre-compute the date truncation so GROUP BY can use the index
-- -----------------------------------------------------------------------------
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_month_trunc
    ON app.orders (DATE_TRUNC('month', order_date));

COMMENT ON INDEX app.idx_orders_month_trunc IS
    'Expression index for monthly DATE_TRUNC grouping: eliminates per-row computation during GROUP BY';

-- -----------------------------------------------------------------------------
-- FIX 4: Partial index for active (non-cancelled) orders only
-- Strategy: Exclude cancelled/refunded orders from the index entirely
-- -----------------------------------------------------------------------------
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_active_date
    ON app.orders (order_date DESC)
    WHERE status NOT IN ('CANCELLED', 'REFUNDED');

COMMENT ON INDEX app.idx_orders_active_date IS
    'Partial index on non-cancelled orders: smaller index, faster scans for revenue queries';

-- =============================================================================
-- FORCE STATISTICS UPDATE (ensure planner knows about new indexes)
-- =============================================================================
ANALYZE app.orders;
ANALYZE app.transactions;

-- =============================================================================
-- VERIFY NEW INDEXES
-- =============================================================================
SELECT
    indexname,
    indexdef,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'app'
  AND tablename IN ('orders', 'transactions')
  AND indexname LIKE '%covering%' OR indexname LIKE '%trunc%' OR indexname LIKE '%active%'
ORDER BY tablename, indexname;
