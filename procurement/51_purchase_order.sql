-- =====================================================
-- ThorERP
-- procurement/51_purchase_order.sql
-- Purchase Order Management
-- PostgreSQL 16
-- =====================================================

BEGIN;

SET search_path TO erp, public;

-- =====================================================
-- VALIDATION
-- =====================================================

DO $$
BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema='erp'
          AND table_name='supplier'
    )
    THEN
        RAISE EXCEPTION
        '22_supplier.sql must be installed first';
    END IF;

END;
$$;

-- =====================================================
-- PURCHASE ORDER STATUS
-- =====================================================

CREATE TABLE IF NOT EXISTS purchase_order_status
(
    purchase_order_status_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    status_code VARCHAR(30)
        NOT NULL,

    status_name VARCHAR(100)
        NOT NULL,

    CONSTRAINT pk_purchase_order_status
        PRIMARY KEY
        (
            purchase_order_status_id
        ),

    CONSTRAINT uq_purchase_order_status
        UNIQUE
        (
            status_code
        )
);

-- =====================================================
-- PURCHASE ORDER HEADER
-- =====================================================

CREATE TABLE IF NOT EXISTS purchase_order
(
    purchase_order_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    purchase_order_number VARCHAR(50)
        NOT NULL,

    supplier_id BIGINT
        NOT NULL,

    purchase_order_status_id BIGINT
        NOT NULL,

    purchase_requisition_id BIGINT,

    order_date DATE
        NOT NULL
        DEFAULT CURRENT_DATE,

    requested_delivery_date DATE,

    total_amount NUMERIC(18,2)
        NOT NULL DEFAULT 0,

    currency_code VARCHAR(10),

    comments TEXT,

    created_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_purchase_order
        PRIMARY KEY
        (
            purchase_order_id
        ),

    CONSTRAINT uq_purchase_order_number
        UNIQUE
        (
            purchase_order_number
        )
);

-- =====================================================
-- PURCHASE ORDER LINE
-- =====================================================

CREATE TABLE IF NOT EXISTS purchase_order_line
(
    purchase_order_line_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    purchase_order_id BIGINT
        NOT NULL,

    line_no INTEGER
        NOT NULL,

    product_id BIGINT
        NOT NULL,

    inventory_dimension_id BIGINT,

    quantity_ordered NUMERIC(18,4)
        NOT NULL,

    quantity_received NUMERIC(18,4)
        NOT NULL DEFAULT 0,

    unit_cost NUMERIC(18,6)
        NOT NULL,

    line_amount NUMERIC(18,2)
        NOT NULL,

    requested_delivery_date DATE,

    CONSTRAINT pk_purchase_order_line
        PRIMARY KEY
        (
            purchase_order_line_id
        ),

    CONSTRAINT uq_purchase_order_line
        UNIQUE
        (
            purchase_order_id,
            line_no
        )
);

-- =====================================================
-- PURCHASE ORDER HISTORY
-- =====================================================

CREATE TABLE IF NOT EXISTS purchase_order_history
(
    purchase_order_history_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    purchase_order_id BIGINT
        NOT NULL,

    event_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    event_type VARCHAR(50)
        NOT NULL,

    event_comment VARCHAR(2000),

    CONSTRAINT pk_purchase_order_history
        PRIMARY KEY
        (
            purchase_order_history_id
        )
);

-- =====================================================
-- FOREIGN KEYS
-- =====================================================

DO $$
BEGIN

IF NOT EXISTS
(
    SELECT 1
    FROM pg_constraint
    WHERE conname='fk_po_supplier'
)
THEN

    ALTER TABLE purchase_order
    ADD CONSTRAINT fk_po_supplier

    FOREIGN KEY
    (
        supplier_id
    )
    REFERENCES supplier
    (
        supplier_id
    );

END IF;

END;
$$;

DO $$
BEGIN

IF NOT EXISTS
(
    SELECT 1
    FROM pg_constraint
    WHERE conname='fk_po_status'
)
THEN

    ALTER TABLE purchase_order
    ADD CONSTRAINT fk_po_status

    FOREIGN KEY
    (
        purchase_order_status_id
    )
    REFERENCES purchase_order_status
    (
        purchase_order_status_id
    );

END IF;

END;
$$;

DO $$
BEGIN

IF EXISTS
(
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema='erp'
      AND table_name='purchase_requisition'
)
AND NOT EXISTS
(
    SELECT 1
    FROM pg_constraint
    WHERE conname='fk_po_requisition'
)
THEN

    ALTER TABLE purchase_order
    ADD CONSTRAINT fk_po_requisition

    FOREIGN KEY
    (
        purchase_requisition_id
    )
    REFERENCES purchase_requisition
    (
        purchase_requisition_id
    );

END IF;

END;
$$;

DO $$
BEGIN

IF NOT EXISTS
(
    SELECT 1
    FROM pg_constraint
    WHERE conname='fk_po_line_header'
)
THEN

    ALTER TABLE purchase_order_line
    ADD CONSTRAINT fk_po_line_header

    FOREIGN KEY
    (
        purchase_order_id
    )
    REFERENCES purchase_order
    (
        purchase_order_id
    )
    ON DELETE CASCADE;

END IF;

END;
$$;

DO $$
BEGIN

IF EXISTS
(
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema='erp'
      AND table_name='product'
)
AND NOT EXISTS
(
    SELECT 1
    FROM pg_constraint
    WHERE conname='fk_po_line_product'
)
THEN

    ALTER TABLE purchase_order_line
    ADD CONSTRAINT fk_po_line_product

    FOREIGN KEY
    (
        product_id
    )
    REFERENCES product
    (
        product_id
    );

END IF;

END;
$$;

-- =====================================================
-- CONSTRAINTS
-- =====================================================

DO $$
BEGIN

IF NOT EXISTS
(
    SELECT 1
    FROM pg_constraint
    WHERE conname='ck_po_quantity'
)
THEN

    ALTER TABLE purchase_order_line
    ADD 