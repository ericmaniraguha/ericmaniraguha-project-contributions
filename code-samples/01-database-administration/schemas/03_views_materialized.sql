-- =============================================================================
-- 03_views_materialized.sql
-- Standard Views and Materialized Views with Refresh Strategies
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

SET search_path TO app, analytics, public;

-- =============================================================================
-- PART A: STANDARD VIEWS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Customer Summary View
--    Purpose: Unified customer profile with order history aggregations
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW app.vw_customer_summary AS
SELECT
    c.customer_id,
    c.customer_code,
    c.first_name || ' ' || c.last_name AS full_name,
    c.email,
    c.phone,
    c.customer_type,
    c.status,
    c.credit_limit,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COALESCE(SUM(o.net_amount), 0) AS lifetime_revenue,
    MAX(o.order_date) AS last_order_date,
    EXTRACT(DAY FROM NOW() - MAX(o.order_date)) AS days_since_last_order,
    MIN(o.order_date) AS first_order_date,
    c.created_at AS customer_since
FROM app.customers c
LEFT JOIN app.orders o ON c.customer_id = o.customer_id
    AND o.status NOT IN ('CANCELLED', 'REFUNDED')
GROUP BY c.customer_id, c.customer_code, c.first_name, c.last_name,
         c.email, c.phone, c.customer_type, c.status, c.credit_limit, c.created_at;

COMMENT ON VIEW app.vw_customer_summary IS 'Aggregated customer profile with order history and lifetime revenue';

-- -----------------------------------------------------------------------------
-- 2. Order Details View (Flattened order + line items)
--    Purpose: Single view joining orders with line items and product names
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW app.vw_order_details AS
SELECT
    o.order_id,
    o.order_number,
    c.customer_code,
    c.first_name || ' ' || c.last_name AS customer_name,
    o.order_date,
    o.status AS order_status,
    p.product_code,
    p.product_name,
    p.category AS product_category,
    oi.quantity,
    oi.unit_price,
    oi.line_total,
    oi.discount_pct,
    o.total_amount,
    o.tax_amount,
    o.net_amount,
    o.payment_method,
    o.currency
FROM app.orders o
JOIN app.customers c ON o.customer_id = c.customer_id
JOIN app.order_items oi ON o.order_id = oi.order_id
JOIN app.products p ON oi.product_id = p.product_id;

COMMENT ON VIEW app.vw_order_details IS 'Flattened order detail view joining orders, customers, items, and products';

-- -----------------------------------------------------------------------------
-- 3. Transaction Ledger View
--    Purpose: Financial transaction view with customer context
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW app.vw_transaction_ledger AS
SELECT
    t.transaction_id,
    t.transaction_ref,
    t.transaction_type,
    t.amount,
    t.currency,
    t.payment_channel,
    t.status AS transaction_status,
    t.external_ref,
    t.processed_at,
    t.failure_reason,
    c.customer_code,
    c.first_name || ' ' || c.last_name AS customer_name,
    o.order_number,
    t.created_at
FROM app.transactions t
JOIN app.customers c ON t.customer_id = c.customer_id
LEFT JOIN app.orders o ON t.order_id = o.order_id;

COMMENT ON VIEW app.vw_transaction_ledger IS 'Financial transactions with customer and order context';

-- -----------------------------------------------------------------------------
-- 4. Active Employees Hierarchy View
--    Purpose: Employee directory with manager names
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW app.vw_employee_directory AS
SELECT
    e.employee_id,
    e.employee_code,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.email,
    e.department,
    e.job_title,
    e.hire_date,
    EXTRACT(YEAR FROM AGE(NOW(), e.hire_date))::INT AS years_of_service,
    m.first_name || ' ' || m.last_name AS manager_name,
    e.is_active
FROM app.employees e
LEFT JOIN app.employees m ON e.manager_id = m.employee_id
WHERE e.is_active = TRUE;

COMMENT ON VIEW app.vw_employee_directory IS 'Active employee directory with manager hierarchy and tenure';

-- =============================================================================
-- PART B: MATERIALIZED VIEWS (with refresh strategies)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 5. Monthly Revenue Summary (Materialized)
--    Purpose: Pre-aggregated monthly revenue for dashboard performance
--    Refresh: Scheduled via cron every 15 minutes during business hours
-- -----------------------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.mv_monthly_revenue AS
SELECT
    DATE_TRUNC('month', o.order_date)::DATE AS revenue_month,
    o.currency,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    SUM(o.total_amount) AS gross_revenue,
    SUM(o.tax_amount) AS total_tax,
    SUM(o.discount_amount) AS total_discounts,
    SUM(o.net_amount) AS net_revenue,
    AVG(o.net_amount) AS avg_order_value,
    MAX(o.net_amount) AS max_order_value,
    MIN(o.net_amount) AS min_order_value
FROM app.orders o
WHERE o.status NOT IN ('CANCELLED', 'REFUNDED')
GROUP BY DATE_TRUNC('month', o.order_date)::DATE, o.currency
ORDER BY revenue_month DESC;

-- Unique index required for CONCURRENTLY refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_monthly_revenue_pk
    ON analytics.mv_monthly_revenue (revenue_month, currency);

COMMENT ON MATERIALIZED VIEW analytics.mv_monthly_revenue IS
    'Pre-aggregated monthly revenue metrics — refresh every 15 min with CONCURRENTLY';

-- -----------------------------------------------------------------------------
-- 6. Product Performance Summary (Materialized)
--    Purpose: Pre-aggregated product sales metrics for catalog analytics
-- -----------------------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.mv_product_performance AS
SELECT
    p.product_id,
    p.product_code,
    p.product_name,
    p.category,
    COUNT(DISTINCT oi.order_id) AS times_ordered,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.line_total) AS total_revenue,
    AVG(oi.unit_price) AS avg_selling_price,
    MAX(o.order_date) AS last_ordered_date,
    MIN(o.order_date) AS first_ordered_date
FROM app.products p
LEFT JOIN app.order_items oi ON p.product_id = oi.product_id
LEFT JOIN app.orders o ON oi.order_id = o.order_id
    AND o.status NOT IN ('CANCELLED', 'REFUNDED')
GROUP BY p.product_id, p.product_code, p.product_name, p.category;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_product_performance_pk
    ON analytics.mv_product_performance (product_id);

COMMENT ON MATERIALIZED VIEW analytics.mv_product_performance IS
    'Pre-aggregated product sales metrics — refresh daily at 02:00 CAT';

-- -----------------------------------------------------------------------------
-- 7. Daily Transaction Summary (Materialized)
--    Purpose: Daily transaction volumes by channel and status
-- -----------------------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.mv_daily_transactions AS
SELECT
    DATE_TRUNC('day', t.created_at)::DATE AS transaction_date,
    t.transaction_type,
    t.payment_channel,
    t.status,
    t.currency,
    COUNT(*) AS transaction_count,
    SUM(t.amount) AS total_amount,
    AVG(t.amount) AS avg_amount,
    COUNT(*) FILTER (WHERE t.status = 'FAILED') AS failed_count,
    COUNT(*) FILTER (WHERE t.status = 'COMPLETED') AS success_count
FROM app.transactions t
GROUP BY DATE_TRUNC('day', t.created_at)::DATE,
         t.transaction_type, t.payment_channel, t.status, t.currency
ORDER BY transaction_date DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_daily_txns_pk
    ON analytics.mv_daily_transactions (transaction_date, transaction_type,
                                         payment_channel, status, currency);

COMMENT ON MATERIALIZED VIEW analytics.mv_daily_transactions IS
    'Daily transaction volume metrics by channel and status — refresh hourly';

-- =============================================================================
-- Materialized View Refresh Commands (used by cron or maintenance scripts)
-- =============================================================================

-- Concurrent refresh (non-blocking, requires unique index)
-- REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_monthly_revenue;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_product_performance;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_daily_transactions;

-- Verify materialized views
SELECT
    schemaname,
    matviewname,
    matviewowner,
    ispopulated
FROM pg_matviews
WHERE schemaname = 'analytics'
ORDER BY matviewname;
