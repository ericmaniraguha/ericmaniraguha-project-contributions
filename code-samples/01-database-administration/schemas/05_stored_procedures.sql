-- =============================================================================
-- 05_stored_procedures.sql
-- PL/pgSQL Stored Procedures for Business Logic and Maintenance
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

SET search_path TO app, public;

-- =============================================================================
-- 1. CREATE ORDER — Full transactional order creation with line items
-- =============================================================================
CREATE OR REPLACE PROCEDURE app.sp_create_order(
    p_customer_id   UUID,
    p_payment_method VARCHAR(30),
    p_items         JSONB,        -- Array of {product_id, quantity, unit_price}
    p_notes         TEXT DEFAULT NULL,
    OUT p_order_id  UUID,
    OUT p_order_number VARCHAR(30)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_item          JSONB;
    v_total         NUMERIC(15,2) := 0;
    v_tax           NUMERIC(15,2) := 0;
    v_product_tax   NUMERIC(5,4);
    v_line_total    NUMERIC(15,2);
BEGIN
    -- Validate customer exists and is active
    IF NOT EXISTS (
        SELECT 1 FROM app.customers
        WHERE customer_id = p_customer_id AND status = 'ACTIVE'
    ) THEN
        RAISE EXCEPTION 'Customer % not found or not active', p_customer_id;
    END IF;

    -- Generate order number
    p_order_number := app.generate_order_number();

    -- Insert order header
    INSERT INTO app.orders (
        order_number, customer_id, payment_method, notes, status
    ) VALUES (
        p_order_number, p_customer_id, p_payment_method, p_notes, 'CONFIRMED'
    ) RETURNING order_id INTO p_order_id;

    -- Process each line item
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        -- Validate product exists and is active
        SELECT tax_rate INTO v_product_tax
        FROM app.products
        WHERE product_id = (v_item->>'product_id')::UUID AND is_active = TRUE;

        IF v_product_tax IS NULL THEN
            RAISE EXCEPTION 'Product % not found or inactive', v_item->>'product_id';
        END IF;

        v_line_total := (v_item->>'quantity')::INTEGER * (v_item->>'unit_price')::NUMERIC;
        v_total := v_total + v_line_total;
        v_tax := v_tax + (v_line_total * v_product_tax);

        -- Insert line item
        INSERT INTO app.order_items (order_id, product_id, quantity, unit_price)
        VALUES (
            p_order_id,
            (v_item->>'product_id')::UUID,
            (v_item->>'quantity')::INTEGER,
            (v_item->>'unit_price')::NUMERIC
        );
    END LOOP;

    -- Update order totals
    UPDATE app.orders
    SET total_amount = v_total,
        tax_amount = ROUND(v_tax, 2),
        updated_at = NOW()
    WHERE order_id = p_order_id;

    RAISE NOTICE 'Order % created successfully. Total: % RWF', p_order_number, v_total + ROUND(v_tax, 2);
END;
$$;

COMMENT ON PROCEDURE app.sp_create_order IS 'Creates a complete order with line items from JSONB input, calculates taxes, and validates all references';

-- =============================================================================
-- 2. PROCESS PAYMENT — Record payment transaction with idempotency
-- =============================================================================
CREATE OR REPLACE PROCEDURE app.sp_process_payment(
    p_order_id          UUID,
    p_payment_channel   VARCHAR(30),
    p_amount            NUMERIC(15,2),
    p_idempotency_key   VARCHAR(128),
    p_external_ref      VARCHAR(128) DEFAULT NULL,
    OUT p_transaction_id UUID,
    OUT p_status         VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_status  VARCHAR(20);
    v_customer_id   UUID;
    v_order_amount  NUMERIC(15,2);
BEGIN
    -- Check for duplicate using idempotency key
    SELECT transaction_id, status INTO p_transaction_id, p_status
    FROM app.transactions
    WHERE idempotency_key = p_idempotency_key;

    IF FOUND THEN
        RAISE NOTICE 'Idempotent hit: Transaction % already exists with status %', p_transaction_id, p_status;
        RETURN;
    END IF;

    -- Validate order
    SELECT status, customer_id, net_amount
    INTO v_order_status, v_customer_id, v_order_amount
    FROM app.orders
    WHERE order_id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_order_id;
    END IF;

    IF v_order_status NOT IN ('CONFIRMED', 'PROCESSING') THEN
        RAISE EXCEPTION 'Order % is in status %, cannot process payment', p_order_id, v_order_status;
    END IF;

    IF p_amount <> v_order_amount THEN
        RAISE WARNING 'Payment amount % does not match order amount %. Proceeding with recording.', p_amount, v_order_amount;
    END IF;

    -- Insert transaction
    INSERT INTO app.transactions (
        transaction_ref, order_id, customer_id, transaction_type,
        amount, payment_channel, status, external_ref,
        idempotency_key, processed_at
    ) VALUES (
        app.generate_transaction_ref(),
        p_order_id, v_customer_id, 'PAYMENT',
        p_amount, p_payment_channel, 'COMPLETED', p_external_ref,
        p_idempotency_key, NOW()
    ) RETURNING transaction_id, status INTO p_transaction_id, p_status;

    -- Update order status to PROCESSING
    UPDATE app.orders
    SET status = 'PROCESSING', updated_at = NOW()
    WHERE order_id = p_order_id AND status = 'CONFIRMED';

    RAISE NOTICE 'Payment % recorded for order %', p_transaction_id, p_order_id;
END;
$$;

COMMENT ON PROCEDURE app.sp_process_payment IS 'Records a payment transaction with idempotency protection, validates order state, and updates order status';

-- =============================================================================
-- 3. CANCEL ORDER — Transactional order cancellation with refund recording
-- =============================================================================
CREATE OR REPLACE PROCEDURE app.sp_cancel_order(
    p_order_id      UUID,
    p_reason        TEXT,
    p_refund         BOOLEAN DEFAULT TRUE,
    OUT p_refund_txn_id UUID
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_order         RECORD;
    v_payment       RECORD;
BEGIN
    -- Lock and fetch the order
    SELECT * INTO v_order
    FROM app.orders
    WHERE order_id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_order_id;
    END IF;

    IF v_order.status IN ('CANCELLED', 'REFUNDED') THEN
        RAISE EXCEPTION 'Order % is already %', p_order_id, v_order.status;
    END IF;

    -- Cancel the order
    UPDATE app.orders
    SET status = 'CANCELLED',
        cancelled_at = NOW(),
        notes = COALESCE(notes, '') || E'\n[CANCELLED] ' || p_reason,
        updated_at = NOW()
    WHERE order_id = p_order_id;

    -- If refund requested, record a reversal for each completed payment
    IF p_refund THEN
        FOR v_payment IN
            SELECT * FROM app.transactions
            WHERE order_id = p_order_id AND status = 'COMPLETED' AND transaction_type = 'PAYMENT'
        LOOP
            INSERT INTO app.transactions (
                transaction_ref, order_id, customer_id, transaction_type,
                amount, currency, payment_channel, status, processed_at
            ) VALUES (
                app.generate_transaction_ref(),
                p_order_id, v_payment.customer_id, 'REFUND',
                v_payment.amount, v_payment.currency, v_payment.payment_channel,
                'COMPLETED', NOW()
            ) RETURNING transaction_id INTO p_refund_txn_id;
        END LOOP;

        UPDATE app.orders
        SET status = 'REFUNDED', updated_at = NOW()
        WHERE order_id = p_order_id;
    END IF;

    RAISE NOTICE 'Order % cancelled. Reason: %', p_order_id, p_reason;
END;
$$;

COMMENT ON PROCEDURE app.sp_cancel_order IS 'Cancels an order with optional refund recording for all completed payments';

-- =============================================================================
-- 4. REFRESH ALL MATERIALIZED VIEWS — Maintenance procedure
-- =============================================================================
CREATE OR REPLACE PROCEDURE analytics.sp_refresh_materialized_views()
LANGUAGE plpgsql
AS $$
DECLARE
    v_start     TIMESTAMPTZ;
    v_end       TIMESTAMPTZ;
    v_view_name TEXT;
BEGIN
    FOR v_view_name IN
        SELECT schemaname || '.' || matviewname
        FROM pg_matviews
        WHERE schemaname = 'analytics'
    LOOP
        v_start := clock_timestamp();
        EXECUTE 'REFRESH MATERIALIZED VIEW CONCURRENTLY ' || v_view_name;
        v_end := clock_timestamp();
        RAISE NOTICE 'Refreshed % in % ms', v_view_name, EXTRACT(MILLISECOND FROM v_end - v_start)::INT;
    END LOOP;
END;
$$;

COMMENT ON PROCEDURE analytics.sp_refresh_materialized_views IS 'Refreshes all materialized views in the analytics schema concurrently with timing logs';

-- =============================================================================
-- 5. DATABASE MAINTENANCE — VACUUM, ANALYZE, and bloat cleanup
-- =============================================================================
CREATE OR REPLACE PROCEDURE app.sp_database_maintenance(
    p_schema_name VARCHAR DEFAULT 'app',
    p_verbose     BOOLEAN DEFAULT FALSE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_table     RECORD;
    v_start     TIMESTAMPTZ;
BEGIN
    v_start := clock_timestamp();

    FOR v_table IN
        SELECT schemaname, tablename
        FROM pg_tables
        WHERE schemaname = p_schema_name
        ORDER BY tablename
    LOOP
        IF p_verbose THEN
            RAISE NOTICE 'Analyzing %.%', v_table.schemaname, v_table.tablename;
        END IF;

        EXECUTE format('ANALYZE %I.%I', v_table.schemaname, v_table.tablename);
    END LOOP;

    RAISE NOTICE 'Maintenance completed for schema % in % ms',
        p_schema_name,
        EXTRACT(MILLISECOND FROM clock_timestamp() - v_start)::INT;
END;
$$;

COMMENT ON PROCEDURE app.sp_database_maintenance IS 'Runs ANALYZE on all tables in the specified schema for statistics refresh';
