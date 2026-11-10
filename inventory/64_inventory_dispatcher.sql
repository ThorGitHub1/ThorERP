-- =====================================================
-- ThorERP
-- inventory/64_inventory_dispatcher.sql
-- Inventory Event Dispatcher
-- PostgreSQL 16
-- =====================================================

BEGIN;

SET search_path TO erp, public;

-- =====================================================
-- EVENT TYPE
-- =====================================================

CREATE TABLE IF NOT EXISTS inventory_event_type
(
    inventory_event_type_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    event_type_code VARCHAR(50)
        NOT NULL,

    event_type_name VARCHAR(100)
        NOT NULL,

    active_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_inventory_event_type
        PRIMARY KEY
        (
            inventory_event_type_id
        ),

    CONSTRAINT uq_inventory_event_type
        UNIQUE
        (
            event_type_code
        )
);

-- =====================================================
-- INVENTORY EVENT
-- =====================================================

CREATE TABLE IF NOT EXISTS inventory_event
(
    inventory_event_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    inventory_event_type_id BIGINT
        NOT NULL,

    source_document_type VARCHAR(50)
        NOT NULL,

    source_document_id BIGINT
        NOT NULL,

    product_id BIGINT
        NOT NULL,

    inventory_dimension_id BIGINT
        NOT NULL,

    quantity NUMERIC(18,4)
        NOT NULL,

    unit_cost NUMERIC(18,6),

    processed_flag BOOLEAN
        NOT NULL DEFAULT FALSE,

    processing_timestamp TIMESTAMPTZ,

    created_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_inventory_event
        PRIMARY KEY
        (
            inventory_event_id
        )
);

-- =====================================================
-- EVENT ERROR LOG
-- =====================================================

CREATE TABLE IF NOT EXISTS inventory_event_error
(
    inventory_event_error_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    inventory_event_id BIGINT
        NOT NULL,

    error_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    error_message TEXT
        NOT NULL,

    CONSTRAINT pk_inventory_event_error
        PRIMARY KEY
        (
            inventory_event_error_id
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
    WHERE conname =
          'fk_inventory_event_type'
)
THEN

    ALTER TABLE inventory_event
    ADD CONSTRAINT
        fk_inventory_event_type

    FOREIGN KEY
    (
        inventory_event_type_id
    )
    REFERENCES inventory_event_type
    (
        inventory_event_type_id
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
    WHERE conname =
          'fk_inventory_event_error'
)
THEN

    ALTER TABLE inventory_event_error
    ADD CONSTRAINT
        fk_inventory_event_error

    FOREIGN KEY
    (
        inventory_event_id
    )
    REFERENCES inventory_event
    (
        inventory_event_id
    )
    ON DELETE CASCADE;

END IF;

END;
$$;

-- =====================================================
-- CREATE EVENT
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_create_inventory_event
(
    p_event_type_code VARCHAR,
    p_source_document_type VARCHAR,
    p_source_document_id BIGINT,
    p_product_id BIGINT,
    p_inventory_dimension_id BIGINT,
    p_quantity NUMERIC,
    p_unit_cost NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS
$$
DECLARE

    v_event_type_id BIGINT;
    v_event_id BIGINT;

BEGIN

    SELECT
        inventory_event_type_id
    INTO
        v_event_type_id
    FROM inventory_event_type
    WHERE event_type_code =
          p_event_type_code;

    INSERT INTO inventory_event
    (
        inventory_event_type_id,
        source_document_type,
        source_document_id,
        product_id,
        inventory_dimension_id,
        quantity,
        unit_cost
    )
    VALUES
    (
        v_event_type_id,
        p_source_document_type,
        p_source_document_id,
        p_product_id,
        p_inventory_dimension_id,
        p_quantity,
        p_unit_cost
    )
    RETURNING inventory_event_id
    INTO v_event_id;

    RETURN v_event_id;

END;
$$;

-- =====================================================
-- PROCESS SINGLE EVENT
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_process_inventory_event
(
    p_inventory_event_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS
$$
DECLARE

    v_event RECORD;
    v_transaction_id BIGINT;

BEGIN

    SELECT *
    INTO v_event
    FROM inventory_event
    WHERE inventory_event_id =
          p_inventory_event_id
    FOR UPDATE;

    IF v_event.processed_flag THEN
        RETURN FALSE;
    END IF;

    v_transaction_id :=
    fn_create_inventory_transaction
    (
        CASE
            WHEN v_event.quantity >= 0
            THEN 'RECEIPT'
            ELSE 'ISSUE'
        END,

        v_event.product_id,

        v_event.inventory_dimension_id,

        v_event.quantity,

        COALESCE(v_event.unit_cost,0),

        v_event.source_document_type,

        v_event.source_document_id
    );

    UPDATE inventory_event
       SET processed_flag = TRUE,
           processing_timestamp =
               CURRENT_TIMESTAMP
     WHERE inventory_event_id =
           p_inventory_event_id;

    RETURN TRUE;

EXCEPTION
WHEN OTHERS THEN

    INSERT INTO inventory_event_error
    (
        inventory_event_id,
        error_message
    )
    VALUES
    (
        p_inventory_event_id,
        SQLERRM
    );

    RETURN FALSE;

END;
$$;

-- =====================================================
-- DISPATCH ENGINE
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_dispatch_inventory_events()
RETURNS INTEGER
LANGUAGE plpgsql
AS
$$
DECLARE

    v_event RECORD;
    v_counter INTEGER := 0;

BEGIN

    FOR v_event IN

        SELECT inventory_event_id

        FROM inventory_event

        WHERE processed_flag = FALSE

        ORDER BY created_timestamp

    LOOP

        PERFORM
        fn_process_inventory_event
        (
            v_event.inventory_event_id
        );

        v_counter :=
            v_counter + 1;

    END LOOP;

    RETURN v_counter;

END;
$$;

-- =====================================================
-- RETRY FAILED EVENTS
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_retry_failed_inventory_events()
RETURNS INTEGER
LANGUAGE plpgsql
AS
$$
DECLARE
    v_count INTEGER := 0;
BEGIN

    UPDATE inventory_event
       SET processed_flag = FALSE
     WHERE inventory_event_id IN
    (
        SELECT inventory_event_id
        FROM inventory_event_error
    );

    GET DIAGNOSTICS
        v_count = ROW_COUNT;

    RETURN v_count;

END;
$$;

-- =====================================================
-- DASHBOARD VIEWS
-- =====================================================

CREATE OR REPLACE VIEW
vw_inventory_pending_events
AS
SELECT *
FROM inventory_event
WHERE processed_flag = FALSE;

CREATE OR REPLACE VIEW
vw_inventory_event_errors
AS
SELECT

    e.inventory_event_id,

    e.source_document_type,

    e.source_document_id,

    er.error_timestamp,

    er.error_message

FROM inventory_event_error er

INNER JOIN inventory_event e
ON e.inventory_event_id =
   er.inventory_event_id;

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS
ix_inventory_event_processed
ON inventory_event
(
    processed_flag
);

CREATE INDEX IF NOT EXISTS
ix_inventory_event_created
ON inventory_event
(
    created_timestamp
);

CREATE INDEX IF NOT EXISTS
ix_inventory_event_source
ON inventory_event
(
    source_document_type,
    source_document_id
);

CREATE INDEX IF NOT EXISTS
ix_inventory_event_error_event
ON inventory_event_error
(
    inventory_event_id
);

-- =====================================================
-- SEED DATA
-- =====================================================

INSERT INTO inventory_event_type
(
    event_type_code,
    event_type_name
)
VALUES
('RECEIPT','Inventory Receipt'),
('ISSUE','Inventory Issue'),
('TRANSFER','Inventory Transfer'),
('ADJUSTMENT','Inventory Adjustment'),
('SHIPMENT','Customer Shipment'),
('PURCHASE_RECEIPT','Purchase Receipt')
ON CONFLICT (event_type_code)
DO NOTHING;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE inventory_event IS
'Inventory event queue';

COMMENT ON TABLE inventory_event_error IS
'Inventory processing errors';

COMMENT ON FUNCTION fn_dispatch_inventory_events IS
'Processes all pending inventory events';

COMMENT ON FUNCTION fn_process_inventory_event IS
'Converts event into inventory transaction';

COMMENT ON VIEW vw_inventory_pending_events IS
'Pending inventory events';

COMMENT ON VIEW vw_inventory_event_errors IS
'Failed inventory events';

COMMIT;