-- =====================================================
-- ThorERP
-- inventory/63_inventory_posting_engine.sql
-- Inventory Posting Engine
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
          AND table_name='inventory_transaction'
    )
    THEN
        RAISE EXCEPTION
        '62_inventory_transaction.sql must be installed first';
    END IF;

END;
$$;

-- =====================================================
-- POSTING STATUS
-- =====================================================

CREATE TABLE IF NOT EXISTS inventory_posting_batch
(
    inventory_posting_batch_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    batch_number VARCHAR(50)
        NOT NULL,

    started_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    completed_timestamp TIMESTAMPTZ,

    transactions_processed INTEGER
        NOT NULL DEFAULT 0,

    status_code VARCHAR(30)
        NOT NULL DEFAULT 'OPEN',

    CONSTRAINT pk_inventory_posting_batch
        PRIMARY KEY
        (
            inventory_posting_batch_id
        ),

    CONSTRAINT uq_inventory_posting_batch
        UNIQUE
        (
            batch_number
        )
);

-- =====================================================
-- POSTING LOG
-- =====================================================

CREATE TABLE IF NOT EXISTS inventory_posting_log
(
    inventory_posting_log_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    inventory_posting_batch_id BIGINT
        NOT NULL,

    inventory_transaction_id BIGINT
        NOT NULL,

    posting_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    success_flag BOOLEAN
        NOT NULL,

    message_text VARCHAR(2000),

    CONSTRAINT pk_inventory_posting_log
        PRIMARY KEY
        (
            inventory_posting_log_id
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
          'fk_posting_log_batch'
)
THEN

    ALTER TABLE inventory_posting_log
    ADD CONSTRAINT
        fk_posting_log_batch

    FOREIGN KEY
    (
        inventory_posting_batch_id
    )
    REFERENCES inventory_posting_batch
    (
        inventory_posting_batch_id
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
          'fk_posting_log_transaction'
)
THEN

    ALTER TABLE inventory_posting_log
    ADD CONSTRAINT
        fk_posting_log_transaction

    FOREIGN KEY
    (
        inventory_transaction_id
    )
    REFERENCES inventory_transaction
    (
        inventory_transaction_id
    );

END IF;

END;
$$;

-- =====================================================
-- CREATE BATCH
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_create_inventory_posting_batch()
RETURNS BIGINT
LANGUAGE plpgsql
AS
$$
DECLARE
    v_batch_id BIGINT;
BEGIN

    INSERT INTO inventory_posting_batch
    (
        batch_number
    )
    VALUES
    (
        'BATCH-' ||
        EXTRACT(EPOCH FROM clock_timestamp())::BIGINT
    )
    RETURNING inventory_posting_batch_id
    INTO v_batch_id;

    RETURN v_batch_id;

END;
$$;

-- =====================================================
-- POST SINGLE TRANSACTION
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_post_inventory_transaction
(
    p_inventory_transaction_id BIGINT,
    p_batch_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS
$$
DECLARE

    v_success BOOLEAN := FALSE;

BEGIN

    BEGIN

        v_success :=
        fn_apply_inventory_transaction
        (
            p_inventory_transaction_id
        );

        INSERT INTO inventory_posting_log
        (
            inventory_posting_batch_id,
            inventory_transaction_id,
            success_flag,
            message_text
        )
        VALUES
        (
            p_batch_id,
            p_inventory_transaction_id,
            TRUE,
            'Transaction successfully posted'
        );

    EXCEPTION
        WHEN OTHERS THEN

            INSERT INTO inventory_posting_log
            (
                inventory_posting_batch_id,
                inventory_transaction_id,
                success_flag,
                message_text
            )
            VALUES
            (
                p_batch_id,
                p_inventory_transaction_id,
                FALSE,
                SQLERRM
            );

            RAISE;

    END;

    RETURN v_success;

END;
$$;

-- =====================================================
-- RUN POSTING ENGINE
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_run_inventory_posting_engine()
RETURNS BIGINT
LANGUAGE plpgsql
AS
$$
DECLARE

    v_batch_id BIGINT;

    v_transaction RECORD;

    v_counter INTEGER := 0;

BEGIN

    v_batch_id :=
    fn_create_inventory_posting_batch();

    FOR v_transaction IN

        SELECT inventory_transaction_id

        FROM inventory_transaction

        WHERE posted_flag = FALSE

        ORDER BY transaction_timestamp

    LOOP

        PERFORM
        fn_post_inventory_transaction
        (
            v_transaction.inventory_transaction_id,
            v_batch_id
        );

        v_counter :=
            v_counter + 1;

    END LOOP;

    UPDATE inventory_posting_batch
       SET completed_timestamp =
               CURRENT_TIMESTAMP,

           transactions_processed =
               v_counter,

           status_code =
               'COMPLETED'

     WHERE inventory_posting_batch_id =
           v_batch_id;

    RETURN v_batch_id;

END;
$$;

-- =====================================================
-- REPOST VALIDATION
-- =====================================================

CREATE OR REPLACE VIEW
vw_inventory_unposted_transactions
AS
SELECT
    *
FROM inventory_transaction
WHERE posted_flag = FALSE;

-- =====================================================
-- RECONCILIATION
-- =====================================================

CREATE OR REPLACE VIEW
vw_inventory_posting_reconciliation
AS
SELECT

    COUNT(*)
        AS total_transactions,

    COUNT(*)
    FILTER
    (
        WHERE posted_flag
    )
        AS posted_transactions,

    COUNT(*)
    FILTER
    (
        WHERE NOT posted_flag
    )
        AS pending_transactions

FROM inventory_transaction;

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS
ix_posting_log_batch
ON inventory_posting_log
(
    inventory_posting_batch_id
);

CREATE INDEX IF NOT EXISTS
ix_posting_log_transaction
ON inventory_posting_log
(
    inventory_transaction_id
);

CREATE INDEX IF NOT EXISTS
ix_posting_batch_status
ON inventory_posting_batch
(
    status_code
);

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE inventory_posting_batch IS
'Inventory posting engine execution batches';

COMMENT ON TABLE inventory_posting_log IS
'Posting audit trail';

COMMENT ON FUNCTION fn_run_inventory_posting_engine IS
'Posts all pending inventory transactions';

COMMENT ON VIEW vw_inventory_unposted_transactions IS
'Pending inventory transactions';

COMMENT ON VIEW vw_inventory_posting_reconciliation IS
'Reconciliation between posted and unposted transactions';

COMMIT;