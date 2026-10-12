-- =============================================================================
-- 02_tables_constraints.sql
-- Production Tables with Comprehensive Constraints
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

SET search_path TO app, public;

-- -----------------------------------------------------------------------------
-- 1. Customers Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.customers (
    customer_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_code   VARCHAR(20) NOT NULL,
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(255) NOT NULL,
    phone           VARCHAR(20),
    date_of_birth   DATE,
    customer_type   VARCHAR(20) NOT NULL DEFAULT 'INDIVIDUAL'
                    CHECK (customer_type IN ('INDIVIDUAL', 'CORPORATE', 'GOVERNMENT')),
    status          VARCHAR(15) NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CLOSED', 'PENDING_VERIFICATION')),
    credit_limit    NUMERIC(15, 2) DEFAULT 0.00
                    CHECK (credit_limit >= 0),
    national_id     VARCHAR(30),
    address_line1   VARCHAR(255),
    address_line2   VARCHAR(255),
    city            VARCHAR(100),
    province        VARCHAR(100),
    country         VARCHAR(3) DEFAULT 'RWA',  -- ISO 3166-1 alpha-3
    postal_code     VARCHAR(20),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      VARCHAR(100) NOT NULL DEFAULT CURRENT_USER,

    -- Unique constraints
    CONSTRAINT uq_customers_email UNIQUE (email),
    CONSTRAINT uq_customers_code UNIQUE (customer_code),
    CONSTRAINT uq_customers_national_id UNIQUE (national_id),

    -- Business rule: date of birth must be in the past
    CONSTRAINT chk_customers_dob CHECK (date_of_birth < CURRENT_DATE),

    -- Business rule: email format validation
    CONSTRAINT chk_customers_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

COMMENT ON TABLE app.customers IS 'Master customer registry with KYC and contact information';
COMMENT ON COLUMN app.customers.customer_code IS 'Human-readable unique customer identifier (e.g., CUST-00001)';
COMMENT ON COLUMN app.customers.credit_limit IS 'Maximum credit amount in RWF';

-- -----------------------------------------------------------------------------
-- 2. Products / Services Catalog
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.products (
    product_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_code    VARCHAR(30) NOT NULL UNIQUE,
    product_name    VARCHAR(200) NOT NULL,
    category        VARCHAR(50) NOT NULL
                    CHECK (category IN ('SUBSCRIPTION', 'ONE_TIME', 'RECURRING', 'DEPOSIT', 'LOAN')),
    description     TEXT,
    unit_price      NUMERIC(15, 2) NOT NULL CHECK (unit_price >= 0),
    currency        VARCHAR(3) NOT NULL DEFAULT 'RWF',  -- ISO 4217
    tax_rate        NUMERIC(5, 4) DEFAULT 0.1800,        -- 18% VAT in Rwanda
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    min_quantity    INTEGER DEFAULT 1 CHECK (min_quantity >= 1),
    max_quantity    INTEGER DEFAULT 999999,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_products_max_gte_min CHECK (max_quantity >= min_quantity)
);

COMMENT ON TABLE app.products IS 'Product and service catalog with pricing and tax configuration';

-- -----------------------------------------------------------------------------
-- 3. Orders Table (header)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.orders (
    order_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number    VARCHAR(30) NOT NULL UNIQUE,
    customer_id     UUID NOT NULL
                    REFERENCES app.customers(customer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    order_date      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING', 'CONFIRMED', 'PROCESSING', 'SHIPPED',
                                      'DELIVERED', 'CANCELLED', 'REFUNDED')),
    total_amount    NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0),
    tax_amount      NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (tax_amount >= 0),
    discount_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (discount_amount >= 0),
    net_amount      NUMERIC(15, 2) GENERATED ALWAYS AS (total_amount + tax_amount - discount_amount) STORED,
    currency        VARCHAR(3) NOT NULL DEFAULT 'RWF',
    payment_method  VARCHAR(30)
                    CHECK (payment_method IN ('CASH', 'BANK_TRANSFER', 'MOBILE_MONEY',
                                               'CREDIT_CARD', 'CHEQUE', 'DEFERRED')),
    notes           TEXT,
    shipped_at      TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      VARCHAR(100) NOT NULL DEFAULT CURRENT_USER,

    -- Business rule: delivery must be after shipping
    CONSTRAINT chk_orders_delivery_after_ship CHECK (
        delivered_at IS NULL OR shipped_at IS NULL OR delivered_at >= shipped_at
    )
);

COMMENT ON TABLE app.orders IS 'Order headers with status tracking, amounts, and payment info';

-- -----------------------------------------------------------------------------
-- 4. Order Line Items (detail)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.order_items (
    item_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID NOT NULL
                    REFERENCES app.orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE,
    product_id      UUID NOT NULL
                    REFERENCES app.products(product_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    quantity        INTEGER NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(15, 2) NOT NULL CHECK (unit_price >= 0),
    line_total      NUMERIC(15, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    discount_pct    NUMERIC(5, 2) DEFAULT 0.00 CHECK (discount_pct BETWEEN 0 AND 100),
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Prevent duplicate product lines on the same order
    CONSTRAINT uq_order_items_order_product UNIQUE (order_id, product_id)
);

COMMENT ON TABLE app.order_items IS 'Order line items with per-product pricing and quantities';

-- -----------------------------------------------------------------------------
-- 5. Financial Transactions / Payments
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.transactions (
    transaction_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_ref     VARCHAR(64) NOT NULL UNIQUE,
    order_id            UUID REFERENCES app.orders(order_id) ON DELETE SET NULL,
    customer_id         UUID NOT NULL
                        REFERENCES app.customers(customer_id) ON DELETE RESTRICT,
    transaction_type    VARCHAR(20) NOT NULL
                        CHECK (transaction_type IN ('PAYMENT', 'REFUND', 'ADJUSTMENT', 'FEE', 'REVERSAL')),
    amount              NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    currency            VARCHAR(3) NOT NULL DEFAULT 'RWF',
    payment_channel     VARCHAR(30)
                        CHECK (payment_channel IN ('MTN_MOMO', 'AIRTEL_MONEY', 'BANK_TRANSFER',
                                                    'VISA', 'MASTERCARD', 'CASH', 'CHEQUE')),
    status              VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED', 'TIMEOUT')),
    external_ref        VARCHAR(128),  -- Gateway/provider reference
    processed_at        TIMESTAMPTZ,
    failure_reason      TEXT,
    idempotency_key     VARCHAR(128) UNIQUE,  -- Prevent duplicate processing
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE app.transactions IS 'Financial transaction records with payment channel tracking and idempotency';

-- -----------------------------------------------------------------------------
-- 6. Employees / System Users (for RBAC demonstration)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.employees (
    employee_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_code   VARCHAR(20) NOT NULL UNIQUE,
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(255) NOT NULL UNIQUE,
    department      VARCHAR(50) NOT NULL
                    CHECK (department IN ('ENGINEERING', 'FINANCE', 'OPERATIONS',
                                          'HR', 'SALES', 'MANAGEMENT', 'IT_SUPPORT')),
    job_title       VARCHAR(100),
    hire_date       DATE NOT NULL DEFAULT CURRENT_DATE,
    termination_date DATE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    manager_id      UUID REFERENCES app.employees(employee_id),  -- Self-referencing FK
    salary          NUMERIC(15, 2) CHECK (salary > 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Business rule: termination must be after hire
    CONSTRAINT chk_employees_termination CHECK (
        termination_date IS NULL OR termination_date >= hire_date
    )
);

COMMENT ON TABLE app.employees IS 'Employee registry with organizational hierarchy and HR data';

-- -----------------------------------------------------------------------------
-- 7. System Configuration / Key-Value Store
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.system_config (
    config_key      VARCHAR(100) PRIMARY KEY,
    config_value    TEXT NOT NULL,
    description     TEXT,
    is_sensitive    BOOLEAN DEFAULT FALSE,
    last_modified_by VARCHAR(100) NOT NULL DEFAULT CURRENT_USER,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE app.system_config IS 'Application configuration parameters and feature flags';

-- =============================================================================
-- Verify all tables created
-- =============================================================================
SELECT
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE schemaname = 'app'
ORDER BY tablename;
