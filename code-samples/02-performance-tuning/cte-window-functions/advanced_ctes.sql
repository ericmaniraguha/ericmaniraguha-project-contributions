-- =============================================================================
-- advanced_ctes.sql
-- Recursive CTEs, Data Generation, and Hierarchical Queries
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

SET search_path TO app, analytics, public;

-- =============================================================================
-- 1. RECURSIVE CTE: Employee Organizational Hierarchy
-- =============================================================================
WITH RECURSIVE org_hierarchy AS (
    -- Base case: top-level managers (no manager_id)
    SELECT
        employee_id,
        employee_code,
        first_name || ' ' || last_name AS employee_name,
        department,
        job_title,
        manager_id,
        1 AS hierarchy_level,
        ARRAY[first_name || ' ' || last_name] AS path,
        employee_code AS org_path
    FROM app.employees
    WHERE manager_id IS NULL AND is_active = TRUE

    UNION ALL

    -- Recursive case: subordinates
    SELECT
        e.employee_id,
        e.employee_code,
        e.first_name || ' ' || e.last_name,
        e.department,
        e.job_title,
        e.manager_id,
        oh.hierarchy_level + 1,
        oh.path || (e.first_name || ' ' || e.last_name),
        oh.org_path || ' → ' || e.employee_code
    FROM app.employees e
    JOIN org_hierarchy oh ON e.manager_id = oh.employee_id
    WHERE e.is_active = TRUE
)
SELECT
    REPEAT('  ', hierarchy_level - 1) || employee_name AS org_chart,
    department,
    job_title,
    hierarchy_level,
    org_path
FROM org_hierarchy
ORDER BY path;

-- =============================================================================
-- 2. RECURSIVE CTE: Generate Date Series for Gap Analysis
-- =============================================================================
WITH RECURSIVE date_series AS (
    SELECT DATE '2025-01-01' AS report_date
    UNION ALL
    SELECT report_date + INTERVAL '1 day'
    FROM date_series
    WHERE report_date < DATE '2025-12-31'
)
SELECT
    ds.report_date,
    COALESCE(COUNT(o.order_id), 0) AS orders_placed,
    COALESCE(SUM(o.net_amount), 0) AS daily_revenue,
    CASE
        WHEN COUNT(o.order_id) = 0 THEN '⚠️ No orders'
        WHEN COUNT(o.order_id) < 5 THEN '🔶 Low volume'
        ELSE '✅ Normal'
    END AS status
FROM date_series ds
LEFT JOIN app.orders o ON DATE(o.order_date) = ds.report_date
    AND o.status NOT IN ('CANCELLED', 'REFUNDED')
GROUP BY ds.report_date
ORDER BY ds.report_date;

-- =============================================================================
-- 3. CTE: Running Balance Calculation (Ledger-Style)
-- =============================================================================
WITH daily_transactions AS (
    SELECT
        DATE(created_at) AS txn_date,
        SUM(CASE WHEN transaction_type = 'PAYMENT' THEN amount ELSE 0 END) AS inflows,
        SUM(CASE WHEN transaction_type IN ('REFUND', 'REVERSAL') THEN amount ELSE 0 END) AS outflows
    FROM app.transactions
    WHERE status = 'COMPLETED'
    GROUP BY DATE(created_at)
),
running_balance AS (
    SELECT
        txn_date,
        inflows,
        outflows,
        inflows - outflows AS net_flow,
        SUM(inflows - outflows) OVER (ORDER BY txn_date) AS cumulative_balance
    FROM daily_transactions
)
SELECT
    txn_date,
    inflows,
    outflows,
    net_flow,
    cumulative_balance,
    CASE
        WHEN net_flow > 0 THEN '📈 Surplus'
        WHEN net_flow < 0 THEN '📉 Deficit'
        ELSE '➡️ Neutral'
    END AS flow_direction
FROM running_balance
ORDER BY txn_date;

-- =============================================================================
-- 4. CTE: Customer Cohort Analysis (First Purchase Month)
-- =============================================================================
WITH first_purchase AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(order_date))::DATE AS cohort_month
    FROM app.orders
    WHERE status NOT IN ('CANCELLED', 'REFUNDED')
    GROUP BY customer_id
),
cohort_data AS (
    SELECT
        fp.cohort_month,
        DATE_TRUNC('month', o.order_date)::DATE AS activity_month,
        COUNT(DISTINCT o.customer_id) AS active_customers,
        SUM(o.net_amount) AS cohort_revenue
    FROM first_purchase fp
    JOIN app.orders o ON fp.customer_id = o.customer_id
    WHERE o.status NOT IN ('CANCELLED', 'REFUNDED')
    GROUP BY fp.cohort_month, DATE_TRUNC('month', o.order_date)::DATE
)
SELECT
    cohort_month,
    activity_month,
    EXTRACT(MONTH FROM AGE(activity_month, cohort_month))::INT AS months_since_first,
    active_customers,
    cohort_revenue
FROM cohort_data
ORDER BY cohort_month, activity_month;

-- =============================================================================
-- 5. CTE WITH MULTIPLE NAMED SUBQUERIES (Data Pipeline Pattern)
-- =============================================================================
WITH
customer_metrics AS (
    SELECT
        c.customer_id,
        c.customer_code,
        c.first_name || ' ' || c.last_name AS name,
        c.customer_type,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.net_amount) AS lifetime_value,
        MAX(o.order_date) AS last_order
    FROM app.customers c
    LEFT JOIN app.orders o ON c.customer_id = o.customer_id
        AND o.status NOT IN ('CANCELLED', 'REFUNDED')
    WHERE c.status = 'ACTIVE'
    GROUP BY c.customer_id, c.customer_code, c.first_name, c.last_name, c.customer_type
),
segmentation AS (
    SELECT
        *,
        CASE
            WHEN lifetime_value >= 5000000 THEN 'PLATINUM'
            WHEN lifetime_value >= 1000000 THEN 'GOLD'
            WHEN lifetime_value >= 100000 THEN 'SILVER'
            WHEN total_orders > 0 THEN 'BRONZE'
            ELSE 'PROSPECT'
        END AS segment,
        CASE
            WHEN last_order >= NOW() - INTERVAL '30 days' THEN 'ACTIVE'
            WHEN last_order >= NOW() - INTERVAL '90 days' THEN 'AT_RISK'
            WHEN last_order IS NOT NULL THEN 'CHURNED'
            ELSE 'NEVER_PURCHASED'
        END AS engagement_status
    FROM customer_metrics
)
SELECT
    segment,
    engagement_status,
    COUNT(*) AS customer_count,
    SUM(lifetime_value) AS segment_revenue,
    ROUND(AVG(lifetime_value), 2) AS avg_ltv,
    ROUND(AVG(total_orders), 1) AS avg_orders
FROM segmentation
GROUP BY segment, engagement_status
ORDER BY
    CASE segment
        WHEN 'PLATINUM' THEN 1 WHEN 'GOLD' THEN 2
        WHEN 'SILVER' THEN 3 WHEN 'BRONZE' THEN 4
        ELSE 5
    END,
    engagement_status;
