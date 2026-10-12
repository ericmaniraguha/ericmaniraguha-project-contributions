-- =============================================================================
-- 04_query_rewrite.sql
-- Optimized Query Version with Structural Improvements
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

-- =============================================================================
-- ORIGINAL QUERY ISSUES:
-- 1. Joins full tables before filtering → wasteful I/O
-- 2. COUNT(DISTINCT) on large sets is expensive
-- 3. FILTER clauses computed over the full join result
-- 4. No CTE to pre-filter or pre-aggregate
-- =============================================================================

-- =============================================================================
-- OPTIMIZED VERSION: CTE-based approach with pre-filtered subsets
-- =============================================================================
WITH active_orders AS (
    -- Pre-filter orders using the partial/covering index
    SELECT
        order_id,
        customer_id,
        DATE_TRUNC('month', order_date) AS revenue_month,
        net_amount
    FROM app.orders
    WHERE order_date >= '2025-01-01'
      AND order_date < '2026-01-01'
      AND status NOT IN ('CANCELLED', 'REFUNDED')
),
order_transactions AS (
    -- Join only the pre-filtered order set with transactions
    SELECT
        ao.revenue_month,
        ao.order_id,
        ao.customer_id,
        t.payment_channel,
        t.amount,
        t.status AS txn_status
    FROM active_orders ao
    JOIN app.transactions t ON t.order_id = ao.order_id
)
SELECT
    ot.revenue_month,
    ot.payment_channel,
    COUNT(DISTINCT ot.order_id) AS total_orders,
    COUNT(DISTINCT ot.customer_id) AS unique_customers,
    SUM(ot.amount) AS total_revenue,
    ROUND(AVG(ot.amount), 2) AS avg_transaction,
    COUNT(*) FILTER (WHERE ot.txn_status = 'FAILED') AS failed_count,
    COUNT(*) FILTER (WHERE ot.txn_status = 'COMPLETED') AS success_count,
    -- Additional insight: success rate
    ROUND(
        COUNT(*) FILTER (WHERE ot.txn_status = 'COMPLETED')::NUMERIC /
        NULLIF(COUNT(*), 0) * 100, 2
    ) AS success_rate_pct
FROM order_transactions ot
GROUP BY ot.revenue_month, ot.payment_channel
ORDER BY ot.revenue_month, total_revenue DESC;

-- =============================================================================
-- KEY IMPROVEMENTS:
--
-- 1. CTE `active_orders`:
--    - Pre-filters orders before the join → dramatically reduces join input
--    - Uses the new partial covering index (idx_orders_date_status_covering)
--    - Pre-computes DATE_TRUNC once, not per-row in the GROUP BY
--
-- 2. CTE `order_transactions`:
--    - Joins only the filtered subset → smaller hash table
--    - Uses the new covering index (idx_transactions_order_covering)
--
-- 3. Final SELECT:
--    - Operates on a much smaller intermediate result set
--    - Added success_rate_pct for richer insight
--
-- 4. Index utilization:
--    - active_orders → idx_orders_date_status_covering (Index Only Scan)
--    - JOIN → idx_transactions_order_covering (Index Scan)
-- =============================================================================
