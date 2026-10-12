-- =============================================================================
-- 06_functions.sql
-- Custom Functions: Scalar, Table-Returning, and Aggregate Helpers
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

SET search_path TO app, public;

-- =============================================================================
-- SCALAR FUNCTIONS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Calculate real-time account balance from transaction history
--    (Immutable ledger pattern: balance derived, never stored directly)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.fn_customer_balance(
    p_customer_id UUID,
    p_currency    VARCHAR(3) DEFAULT 'RWF'
)
RETURNS NUMERIC(15,2)
LANGUAGE plpgsql
STABLE  -- does not modify data; safe for use in queries
AS $$
DECLARE
    v_balance NUMERIC(15,2);
BEGIN
    SELECT COALESCE(
        SUM(CASE
            WHEN transaction_type = 'PAYMENT' AND status = 'COMPLETED' THEN amount
            WHEN transaction_type = 'FEE' AND status = 'COMPLETED' THEN amount
            ELSE 0
        END) -
        SUM(CASE
            WHEN transaction_type = 'REFUND' AND status = 'COMPLETED' THEN amount
            WHEN transaction_type = 'REVERSAL' AND status = 'COMPLETED' THEN amount
            ELSE 0
        END),
        0
    )
    INTO v_balance
    FROM app.transactions
    WHERE customer_id = p_customer_id AND currency = p_currency;

    RETURN v_balance;
END;
$$;

COMMENT ON FUNCTION app.fn_customer_balance IS 'Calculates real-time customer balance from completed transactions (immutable ledger pattern)';

-- -----------------------------------------------------------------------------
-- 2. Format currency amounts for display
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.fn_format_currency(
    p_amount   NUMERIC,
    p_currency VARCHAR(3) DEFAULT 'RWF'
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN p_currency || ' ' || TO_CHAR(p_amount, 'FM999,999,999,990.00');
END;
$$;

COMMENT ON FUNCTION app.fn_format_currency IS 'Formats a numeric amount as a currency string (e.g., RWF 1,250,000.00)';

-- -----------------------------------------------------------------------------
-- 3. Calculate business days between two dates (exclude weekends)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.fn_business_days(
    p_start_date DATE,
    p_end_date   DATE
)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_count INTEGER := 0;
    v_current DATE := p_start_date;
BEGIN
    IF p_start_date > p_end_date THEN
        RETURN 0;
    END IF;

    WHILE v_current <= p_end_date LOOP
        IF EXTRACT(DOW FROM v_current) NOT IN (0, 6) THEN  -- 0=Sunday, 6=Saturday
            v_count := v_count + 1;
        END IF;
        v_current := v_current + INTERVAL '1 day';
    END LOOP;

    RETURN v_count;
END;
$$;

COMMENT ON FUNCTION app.fn_business_days IS 'Counts business days (Mon-Fri) between two dates, excluding weekends';

-- -----------------------------------------------------------------------------
-- 4. Mask sensitive data (e.g., national ID, email)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.fn_mask_value(
    p_value   TEXT,
    p_type    VARCHAR(20) DEFAULT 'DEFAULT'
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_value IS NULL THEN RETURN NULL; END IF;

    CASE p_type
        WHEN 'EMAIL' THEN
            -- Show first 2 chars + domain: er***@gmail.com
            RETURN LEFT(p_value, 2) || '***' || SUBSTRING(p_value FROM '@.*$');
        WHEN 'PHONE' THEN
            -- Show last 4 digits: ***746 696
            RETURN '***' || RIGHT(p_value, 7);
        WHEN 'NATIONAL_ID' THEN
            -- Show last 4: *************1234
            RETURN REPEAT('*', LENGTH(p_value) - 4) || RIGHT(p_value, 4);
        ELSE
            -- Generic mask: first 2 + *** + last 2
            IF LENGTH(p_value) <= 4 THEN RETURN '****'; END IF;
            RETURN LEFT(p_value, 2) || REPEAT('*', LENGTH(p_value) - 4) || RIGHT(p_value, 2);
    END CASE;
END;
$$;

COMMENT ON FUNCTION app.fn_mask_value IS 'Masks sensitive data for display: email, phone, national ID, or generic text';

-- =============================================================================
-- TABLE-RETURNING FUNCTIONS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 5. Customer Order History (returns table with full detail)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.fn_customer_orders(
    p_customer_id UUID,
    p_limit       INTEGER DEFAULT 50,
    p_status      VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    order_number    VARCHAR,
    order_date      TIMESTAMPTZ,
    status          VARCHAR,
    items_count     BIGINT,
    total_amount    NUMERIC,
    tax_amount      NUMERIC,
    net_amount      NUMERIC,
    payment_method  VARCHAR,
    currency        VARCHAR
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        o.order_number,
        o.order_date,
        o.status,
        COUNT(oi.item_id) AS items_count,
        o.total_amount,
        o.tax_amount,
        o.net_amount,
        o.payment_method,
        o.currency
    FROM app.orders o
    LEFT JOIN app.order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = p_customer_id
      AND (p_status IS NULL OR o.status = p_status)
    GROUP BY o.order_id, o.order_number, o.order_date, o.status,
             o.total_amount, o.tax_amount, o.net_amount, o.payment_method, o.currency
    ORDER BY o.order_date DESC
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION app.fn_customer_orders IS 'Returns a customer order history with line item counts, optionally filtered by status';

-- -----------------------------------------------------------------------------
-- 6. Revenue by Period (parameterized time-series report)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION analytics.fn_revenue_by_period(
    p_start_date DATE,
    p_end_date   DATE,
    p_granularity VARCHAR DEFAULT 'month'  -- 'day', 'week', 'month', 'quarter', 'year'
)
RETURNS TABLE (
    period          DATE,
    total_orders    BIGINT,
    gross_revenue   NUMERIC,
    tax_collected   NUMERIC,
    net_revenue     NUMERIC,
    avg_order_value NUMERIC,
    unique_customers BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        DATE_TRUNC(p_granularity, o.order_date)::DATE AS period,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.total_amount) AS gross_revenue,
        SUM(o.tax_amount) AS tax_collected,
        SUM(o.net_amount) AS net_revenue,
        ROUND(AVG(o.net_amount), 2) AS avg_order_value,
        COUNT(DISTINCT o.customer_id) AS unique_customers
    FROM app.orders o
    WHERE o.order_date >= p_start_date
      AND o.order_date < p_end_date + INTERVAL '1 day'
      AND o.status NOT IN ('CANCELLED', 'REFUNDED')
    GROUP BY DATE_TRUNC(p_granularity, o.order_date)::DATE
    ORDER BY period;
END;
$$;

COMMENT ON FUNCTION analytics.fn_revenue_by_period IS 'Time-series revenue report with configurable granularity (day/week/month/quarter/year)';

-- -----------------------------------------------------------------------------
-- 7. Top Customers by Revenue
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION analytics.fn_top_customers(
    p_top_n     INTEGER DEFAULT 10,
    p_start_date DATE DEFAULT NULL,
    p_end_date   DATE DEFAULT NULL
)
RETURNS TABLE (
    rank            BIGINT,
    customer_code   VARCHAR,
    customer_name   TEXT,
    total_orders    BIGINT,
    total_revenue   NUMERIC,
    avg_order_value NUMERIC,
    last_order_date TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY SUM(o.net_amount) DESC) AS rank,
        c.customer_code,
        c.first_name || ' ' || c.last_name AS customer_name,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.net_amount) AS total_revenue,
        ROUND(AVG(o.net_amount), 2) AS avg_order_value,
        MAX(o.order_date) AS last_order_date
    FROM app.customers c
    JOIN app.orders o ON c.customer_id = o.customer_id
    WHERE o.status NOT IN ('CANCELLED', 'REFUNDED')
      AND (p_start_date IS NULL OR o.order_date >= p_start_date)
      AND (p_end_date IS NULL OR o.order_date < p_end_date + INTERVAL '1 day')
    GROUP BY c.customer_id, c.customer_code, c.first_name, c.last_name
    ORDER BY total_revenue DESC
    LIMIT p_top_n;
END;
$$;

COMMENT ON FUNCTION analytics.fn_top_customers IS 'Returns top N customers ranked by revenue with optional date range filter';
