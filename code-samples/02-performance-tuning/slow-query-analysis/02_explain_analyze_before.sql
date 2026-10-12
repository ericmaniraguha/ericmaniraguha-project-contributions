-- =============================================================================
-- 02_explain_analyze_before.sql
-- EXPLAIN ANALYZE of Unoptimized Query (BEFORE Tuning)
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

-- =============================================================================
-- SCENARIO: Monthly revenue report query
-- This query calculates monthly revenue grouped by payment channel.
-- Without proper indexes, it performs sequential scans on large tables.
-- =============================================================================

-- The problematic query (unoptimized)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    DATE_TRUNC('month', o.order_date) AS revenue_month,
    t.payment_channel,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    SUM(t.amount) AS total_revenue,
    AVG(t.amount) AS avg_transaction,
    COUNT(*) FILTER (WHERE t.status = 'FAILED') AS failed_count,
    COUNT(*) FILTER (WHERE t.status = 'COMPLETED') AS success_count
FROM app.orders o
JOIN app.transactions t ON t.order_id = o.order_id
WHERE o.order_date >= '2025-01-01'
  AND o.order_date < '2026-01-01'
  AND o.status NOT IN ('CANCELLED', 'REFUNDED')
GROUP BY DATE_TRUNC('month', o.order_date), t.payment_channel
ORDER BY revenue_month, total_revenue DESC;

-- =============================================================================
-- EXPECTED EXECUTION PLAN (BEFORE optimization):
--
-- Sort  (cost=45230.12..45231.45 rows=532 width=72)
--   Sort Key: (date_trunc('month', o.order_date)), (sum(t.amount)) DESC
--   ->  HashAggregate  (cost=45180.00..45225.00 rows=532 width=72)
--         Group Key: date_trunc('month', o.order_date), t.payment_channel
--         ->  Hash Join  (cost=18500.00..42100.00 rows=185000 width=56)
--               Hash Cond: (t.order_id = o.order_id)
--               ->  Seq Scan on transactions t  (cost=0.00..21500.00 rows=500000 width=44)
--                     ◀ PROBLEM: Full sequential scan on transactions table
--               ->  Hash  (cost=15200.00..15200.00 rows=185000 width=24)
--                     ->  Seq Scan on orders o  (cost=0.00..15200.00 rows=185000 width=24)
--                           Filter: ((order_date >= '2025-01-01') AND (order_date < '2026-01-01')
--                                    AND (status NOT IN ('CANCELLED','REFUNDED')))
--                           ◀ PROBLEM: Sequential scan on orders with filter
--                           Rows Removed by Filter: 315000
--
-- Planning Time: 1.2 ms
-- Execution Time: 4,218 ms  ◀ SLOW!
-- =============================================================================

-- =============================================================================
-- DIAGNOSIS:
-- 1. Sequential scan on orders table: no index on (order_date, status)
-- 2. Sequential scan on transactions: no index on (order_id)
-- 3. Large hash join between unfiltered result sets
-- 4. DATE_TRUNC computed at runtime for every row
--
-- See 03_index_improvements.sql for the solution.
-- =============================================================================
