-- =====================================================
-- ThorERP
-- procurement/52_goods_receipt.sql
-- Goods Receipt Processing
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
          AND table_name='purchase_order'
    )
    THEN
        RAISE EXCEPTION
        '51_purchase_order.sql must be installed first';
    END IF;

END;
$$;

-- =====================================================
-- GOODS RECEIPT STATUS
-- =====================================================

CREATE TABLE IF NOT EXISTS goods_receipt_status
(
    goods_receipt_status_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    status_code VARCHAR(30)
        NOT NULL,

    status_name VARCHAR(100)
        NOT NULL,

    CONSTRAINT pk_goods_receipt_status
        PRIMARY KEY
        (
            goods_receipt_status_id
        ),

    CONSTRAINT uq_goods_receipt_status
        UNIQUE
        (
            status_code
        )
);

-- =====================================================
-- GOODS RECEIPT HEADER
-- =====================================================

CREATE TABLE IF NOT EXISTS goods_receipt
(
    goods_receipt_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    goods_receipt_number VARCHAR(50)
        NOT NULL,

    purchase_order_id BIGINT
        NOT NULL,

    goods_receipt_status_id BIGINT
        NOT NULL,

    receipt_date DATE
        NOT NULL
        DEFAULT CURRENT_DATE,

    supplier_delivery_note VARCHAR(100),

    comments TEXT,

    created_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_goods_receipt
        PRIMARY KEY
        (
            goods_receipt_id
        ),

    CONSTRAINT uq_goods_receipt_number
        UNIQUE
        (
            goods_receipt_number
        )
);

-- =====================================================
-- GOODS RECEIPT LINE
-- =====================================================

CREATE TABLE IF NOT EXISTS goods_receipt_line
(
    goods_receipt_line_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    goods_receipt_id BIGINT
        NOT NULL,

    purchase_order_line_id BIGINT
        NOT NULL,

    product_id BIGINT
        NOT NULL,

    inventory_dimension_id BIGINT
        NOT NULL,

    received_quantity NUMERIC(18,4)
        NOT NULL,

    unit_cost NUMERIC(18,6)
        NOT NULL,

    inventory_event_id BIGINT,

    CONSTRAINT pk_goods_receipt_line
        PRIMARY KEY
        (
            goods_receipt_line_id
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
    WHERE conname='fk_gr_status'
)
THEN

    ALTER TABLE goods_receipt
    ADD CONSTRAINT fk_gr_status

    FOREIGN KEY
    (
        goods_receipt_status_id
    )
    REFERENCES goods_receipt_status
    (
        goods_receipt_status_id
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
    WHERE conname='fk_gr_purchase_order'
)
THEN

    ALTER TABLE goods_receipt
    ADD CONSTRAINT fk_gr_purchase_order

    FOREIGN KEY
    (
        purchase_order_id
    )
    REFERENCES purchase_order
    (
        purchase_order_id
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
    WHERE conname='fk_gr_line_header'
)
THEN

    ALTER TABLE goods_receipt_line
    ADD CONSTRAINT fk_gr_line_header

    FOREIGN KEY
    (
        goods_receipt_id
    )
    REFERENCES goods_receipt
    (
        goods_receipt_id
    )
    ON DELETE CASCADE;

END IF;

END;
$$;

-- =====================================================
-- DATA QUALITY
-- =====================================================

DO $$
BEGIN

IF NOT EXISTS
(
    SELECT 1
    FROM pg_constraint
    WHERE conname='ck_gr_received_qty'
)
THEN

    ALTER TABLE goods_receipt_line
    ADD CONSTRAINT ck_gr_received_qty

    CHECK
    (
        received_quantity > 0
    );

END IF;

END;
$$;

-- =====================================================
-- CREATE INVENTORY EVENTS
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_post_goods_receipt
(
    p_goods_receipt_id BIGINT
)
RETURNS INTEGER
LANGUAGE plpgsql
AS
$$
DECLARE

    v_line RECORD;

    v_event_id BIGINT;

    v_counter INTEGER := 0;

BEGIN

    FOR v_line IN

        SELECT *
        FROM goods_receipt_line
        WHERE goods_receipt_id =
              p_goods_receipt_id

    LOOP

        v_event_id :=
        fn_create_inventory_event
        (
            'PURCHASE_RECEIPT',

            'GOODS_RECEIPT',

            p_goods_receipt_id,

            v_line.product_id,

            v_line.inventory_dimension_id,

            v_line.received_quantity,

            v_line.unit_cost
        );

        UPDATE goods_receipt_line
           SET inventory_event_id =
               v_event_id
         WHERE goods_receipt_line_id =
               v_line.goods_receipt_line_id;

        v_counter :=
            v_counter + 1;

    END LOOP;

    UPDATE goods_receipt
       SET goods_receipt_status_id =
       (
            SELECT goods_receipt_status_id
            FROM goods_receipt_status
            WHERE status_code =
                  'POSTED'
       )
     WHERE goods_receipt_id =
           p_goods_receipt_id;

    RETURN v_counter;

END;
$$;

-- =====================================================
-- COMPLETE RECEIPT
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_complete_goods_receipt
(
    p_goods_receipt_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS
$$
BEGIN

    PERFORM
    fn_post_goods_receipt
    (
        p_goods_receipt_id
    );

    PERFORM
    fn_dispatch_inventory_events();

    PERFORM
    fn_run_inventory_posting_engine();

    RETURN TRUE;

END;
$$;

-- =====================================================
-- VIEW
-- =====================================================

CREATE OR REPLACE VIEW
vw_goods_receipt
AS
SELECT

    g.goods_receipt_id,

    g.goods_receipt_number,

    g.purchase_order_id,

    s.status_code,

    g.receipt_date,

    COUNT(l.goods_receipt_line_id)
        AS line_count

FROM goods_receipt g

INNER JOIN goods_receipt_status s
ON s.goods_receipt_status_id =
   g.goods_receipt_status_id

LEFT JOIN goods_receipt_line l
ON l.goods_receipt_id =
   g.goods_receipt_id

GROUP BY

    g.goods_receipt_id,
    g.goods_receipt_number,
    g.purchase_order_id,
    s.status_code,
    g.receipt_date;

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS
ix_gr_purchase_order
ON goods_receipt
(
    purchase_order_id
);

CREATE INDEX IF NOT EXISTS
ix_gr_receipt_date
ON goods_receipt
(
    receipt_date
);

CREATE INDEX IF NOT EXISTS
ix_gr_line_product
ON goods_receipt_line
(
    product_id
);

CREATE INDEX IF NOT EXISTS
ix_gr_inventory_event
ON goods_receipt_line
(
    inventory_event_id
);

-- =====================================================
-- SEED DATA
-- =====================================================

INSERT INTO goods_receipt_status
(
    status_code,
    status_name
)
VALUES
('DRAFT','Draft'),
('RECEIVED','Received'),
('POSTED','Posted'),
('CANCELLED','Cancelled')
ON CONFLICT (status_code)
DO NOTHING;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE goods_receipt IS
'Goods receipt header';

COMMENT ON TABLE goods_receipt_line IS
'Goods receipt lines';

COMMENT ON FUNCTION fn_post_goods_receipt IS
'Creates inventory events from receipt';

COMMENT ON FUNCTION fn_complete_goods_receipt IS
'Completes receipt and updates inventory';

COMMENT ON VIEW vw_goods_receipt IS
'Goods receipt overview';

COMMIT;