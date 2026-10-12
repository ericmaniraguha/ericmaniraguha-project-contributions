-- =============================================================================
-- window_functions.sql
-- ROW_NUMBER, RANK, LEAD/LAG, Running Totals, Moving Averages
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

SET search_path TO app, analytics, public;

-- =============================================================================
-- 1. ROW_NUMBER — Deduplicate or Select Latest Record Per Group
-- =============================================================================

-- Find the most recent order per customer
SELECT * FROM (
    SELECT
        o.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        o.order_number,
        o.order_date,
        o.net_amount,
        o.status,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id
            ORDER BY o.order_date DESC
        ) AS rn
    FROM app.orders o
    JOIN app.customers c ON o.customer_id = c.customer_id
) ranked
WHERE rn = 1
ORDER BY net_amount DESC;

-- =============================================================================
-- 2. RANK and DENSE_RANK — Top Products by Revenue with Tie Handling
-- =============================================================================
SELECT
    p.product_code,
    p.product_name,
    p.category,
    SUM(oi.line_total) AS total_revenue,
    RANK() OVER (ORDER BY SUM(oi.line_total) DESC) AS revenue_rank,
    DENSE_RANK() OVER (
        PARTITION BY p.category
        ORDER BY SUM(oi.line_total) DESC
    ) AS category_rank
FROM app.products p
JOIN app.order_items oi ON p.product_id = oi.product_id
JOIN app.orders o ON oi.order_id = o.order_id
WHERE o.status NOT IN ('CANCELLED', 'REFUNDED')
GROUP BY p.product_id, p.product_code, p.product_name, p.category
ORDER BY total_revenue DESC;

-- =============================================================================
-- 3. LAG / LEAD — Month-over-Month Revenue Comparison
-- =============================================================================
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month,
        SUM(net_amount) AS revenue,
        COUNT(*) AS order_count
    FROM app.orders
    WHERE status NOT IN ('CANCELLED', 'REFUNDED')
    GROUP BY DATE_TRUNC('month', order_date)::DATE
)
SELECT
    month,
    revenue,
    order_count,
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
    LEAD(revenue) OVER (ORDER BY month) AS next_month_revenue,
    revenue - LAG(revenue) OVER (ORDER BY month) AS mom_change,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) /
        NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100, 2
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY month;

-- =============================================================================
-- 4. RUNNING TOTAL — Cumulative Revenue Over Time
-- =============================================================================
SELECT
    DATE(order_date) AS order_day,
    SUM(net_amount) AS daily_revenue,
    SUM(SUM(net_amount)) OVER (ORDER BY DATE(order_date)) AS cumulative_revenue,
    COUNT(*) AS daily_orders,
    SUM(COUNT(*)) OVER (ORDER BY DATE(order_date)) AS cumulative_orders
FROM app.orders
WHERE status NOT IN ('CANCELLED', 'REFUNDED')
  AND order_date >= '2025-01-01'
GROUP BY DATE(order_date)
ORDER BY order_day;

-- =============================================================================
-- 5. MOVING AVERAGE — 7-Day Rolling Average Order Value
-- =============================================================================
WITH daily_stats AS (
    SELECT
        DATE(order_date) AS order_day,
        AVG(net_amount) AS avg_order_value,
        COUNT(*) AS order_count
    FROM app.orders
    WHERE status NOT IN ('CANCELLED', 'REFUNDED')
    GROUP BY DATE(order_date)
)
SELECT
    order_day,
    avg_order_value,
    order_count,
    ROUND(
        AVG(avg_order_value) OVER (
            ORDER BY order_day
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2
    ) AS moving_avg_7d,
    ROUND(
        AVG(avg_order_value) OVER (
            ORDER BY order_day
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ), 2
    ) AS moving_avg_30d
FROM daily_stats
ORDER BY order_day;

-- =============================================================================
-- 6. NTILE — Customer Quartile Segmentation by Spending
-- =============================================================================
SELECT
    customer_code,
    first_name || ' ' || last_name AS customer_name,
    lifetime_value,
    NTILE(4) OVER (ORDER BY lifetime_value DESC) AS spending_quartile,
    CASE NTILE(4) OVER (ORDER BY lifetime_value DESC)
        WHEN 1 THEN 'Top 25% — VIP'
        WHEN 2 THEN 'Above Average'
        WHEN 3 THEN 'Below Average'
        WHEN 4 THEN 'Bottom 25% — At Risk'
    END AS segment_label
FROM (
    SELECT
        c.customer_code,
        c.first_name,
        c.last_name,
        COALESCE(SUM(o.net_amount), 0) AS lifetime_value
    FROM app.customers c
    LEFT JOIN app.orders o ON c.customer_id = o.customer_id
        AND o.status NOT IN ('CANCELLED', 'REFUNDED')
    WHERE c.status = 'ACTIVE'
    GROUP BY c.customer_code, c.first_name, c.last_name
) customer_ltv
ORDER BY lifetime_value DESC;

-- =============================================================================
-- 7. PERCENT_RANK and CUME_DIST — Statistical Distribution
-- =============================================================================
SELECT
    order_number,
    net_amount,
    ROUND(PERCENT_RANK() OVER (ORDER BY net_amount) * 100, 2) AS percentile_rank,
    ROUND(CUME_DIST() OVER (ORDER BY net_amount) * 100, 2) AS cumulative_dist,
    CASE
        WHEN PERCENT_RANK() OVER (ORDER BY net_amount) >= 0.95 THEN 'P95+ (Outlier High)'
        WHEN PERCENT_RANK() OVER (ORDER BY net_amount) >= 0.75 THEN 'P75-P95 (High)'
        WHEN PERCENT_RANK() OVER (ORDER BY net_amount) >= 0.50 THEN 'P50-P75 (Above Median)'
        WHEN PERCENT_RANK() OVER (ORDER BY net_amount) >= 0.25 THEN 'P25-P50 (Below Median)'
        ELSE 'P0-P25 (Low)'
    END AS value_band
FROM app.orders
WHERE status NOT IN ('CANCELLED', 'REFUNDED')
ORDER BY net_amount DESC
LIMIT 50;

-- =============================================================================
-- 8. FIRST_VALUE / LAST_VALUE — Transaction Timeline per Customer
-- =============================================================================
SELECT DISTINCT
    c.customer_code,
    c.first_name || ' ' || c.last_name AS customer_name,
    FIRST_VALUE(t.transaction_ref) OVER w AS first_transaction,
    FIRST_VALUE(t.created_at) OVER w AS first_transaction_date,
    LAST_VALUE(t.transaction_ref) OVER w AS last_transaction,
    LAST_VALUE(t.created_at) OVER w AS last_transaction_date,
    COUNT(*) OVER (PARTITION BY t.customer_id) AS total_transactions,
    SUM(t.amount) OVER (PARTITION BY t.customer_id) AS total_spent
FROM app.transactions t
JOIN app.customers c ON t.customer_id = c.customer_id
WHERE t.status = 'COMPLETED'
WINDOW w AS (
    PARTITION BY t.customer_id
    ORDER BY t.created_at
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
ORDER BY total_spent DESC;
