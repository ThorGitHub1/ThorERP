-- =====================================================
-- ThorERP
-- masterdata/22_supplier.sql
-- Supplier Master Data
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
        WHERE table_schema = 'erp'
          AND table_name = 'party'
    )
    THEN
        RAISE EXCEPTION
        '20_party.sql must be installed first';
    END IF;

END;
$$;

-- =====================================================
-- SUPPLIER GROUP
-- =====================================================

CREATE TABLE IF NOT EXISTS supplier_group
(
    supplier_group_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    supplier_group_code VARCHAR(30)
        NOT NULL,

    supplier_group_name VARCHAR(100)
        NOT NULL,

    active_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_supplier_group
        PRIMARY KEY
        (
            supplier_group_id
        ),

    CONSTRAINT uq_supplier_group_code
        UNIQUE
        (
            supplier_group_code
        )
);

-- =====================================================
-- SUPPLIER STATUS
-- =====================================================

CREATE TABLE IF NOT EXISTS supplier_status
(
    supplier_status_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    status_code VARCHAR(30)
        NOT NULL,

    status_name VARCHAR(100)
        NOT NULL,

    active_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_supplier_status
        PRIMARY KEY
        (
            supplier_status_id
        ),

    CONSTRAINT uq_supplier_status_code
        UNIQUE
        (
            status_code
        )
);

-- =====================================================
-- SUPPLIER
-- =====================================================

CREATE TABLE IF NOT EXISTS supplier
(
    supplier_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    party_id BIGINT
        NOT NULL,

    supplier_no VARCHAR(50)
        NOT NULL,

    supplier_group_id BIGINT,

    supplier_status_id BIGINT
        NOT NULL,

    payment_terms_code VARCHAR(30),

    currency_code VARCHAR(10),

    lead_time_days INTEGER
        NOT NULL DEFAULT 0,

    supplier_rating NUMERIC(5,2),

    approved_supplier_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    blocked_flag BOOLEAN
        NOT NULL DEFAULT FALSE,

    created_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_supplier
        PRIMARY KEY
        (
            supplier_id
        ),

    CONSTRAINT uq_supplier_no
        UNIQUE
        (
            supplier_no
        ),

    CONSTRAINT uq_supplier_party
        UNIQUE
        (
            party_id
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
          'fk_supplier_party'
)
THEN

    ALTER TABLE supplier
    ADD CONSTRAINT
        fk_supplier_party

    FOREIGN KEY
    (
        party_id
    )
    REFERENCES party
    (
        party_id
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
          'fk_supplier_group'
)
THEN

    ALTER TABLE supplier
    ADD CONSTRAINT
        fk_supplier_group

    FOREIGN KEY
    (
        supplier_group_id
    )
    REFERENCES supplier_group
    (
        supplier_group_id
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
          'fk_supplier_status'
)
THEN

    ALTER TABLE supplier
    ADD CONSTRAINT
        fk_supplier_status

    FOREIGN KEY
    (
        supplier_status_id
    )
    REFERENCES supplier_status
    (
        supplier_status_id
    );

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
    WHERE conname =
          'ck_supplier_rating'
)
THEN

    ALTER TABLE supplier
    ADD CONSTRAINT
        ck_supplier_rating

    CHECK
    (
        supplier_rating IS NULL
        OR
        (
            supplier_rating >= 0
            AND supplier_rating <= 100
        )
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
          'ck_supplier_lead_time'
)
THEN

    ALTER TABLE supplier
    ADD CONSTRAINT
        ck_supplier_lead_time

    CHECK
    (
        lead_time_days >= 0
    );

END IF;

END;
$$;

-- =====================================================
-- UPDATE TIMESTAMP
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_supplier_set_updated_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN

    NEW.updated_timestamp :=
        CURRENT_TIMESTAMP;

    RETURN NEW;

END;
$$;

DROP TRIGGER IF EXISTS
trg_supplier_updated_timestamp
ON supplier;

CREATE TRIGGER
trg_supplier_updated_timestamp
BEFORE UPDATE
ON supplier
FOR EACH ROW
EXECUTE FUNCTION
fn_supplier_set_updated_timestamp();

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS
ix_supplier_party
ON supplier
(
    party_id
);

CREATE INDEX IF NOT EXISTS
ix_supplier_group
ON supplier
(
    supplier_group_id
);

CREATE INDEX IF NOT EXISTS
ix_supplier_status
ON supplier
(
    supplier_status_id
);

CREATE INDEX IF NOT EXISTS
ix_supplier_blocked
ON supplier
(
    blocked_flag
);

CREATE INDEX IF NOT EXISTS
ix_supplier_approved
ON supplier
(
    approved_supplier_flag
);

-- =====================================================
-- VIEW
-- =====================================================

CREATE OR REPLACE VIEW
vw_supplier
AS
SELECT

    s.supplier_id,

    s.supplier_no,

    p.party_id,

    p.legal_name,

    p.display_name,

    p.organization_number,

    s.lead_time_days,

    s.supplier_rating,

    s.approved_supplier_flag,

    s.blocked_flag,

    st.status_code,

    sg.supplier_group_code

FROM supplier s

INNER JOIN party p
    ON p.party_id =
       s.party_id

INNER JOIN supplier_status st
    ON st.supplier_status_id =
       s.supplier_status_id

LEFT JOIN supplier_group sg
    ON sg.supplier_group_id =
       s.supplier_group_id;

-- =====================================================
-- SEED DATA
-- =====================================================

INSERT INTO supplier_status
(
    status_code,
    status_name
)
VALUES
('ACTIVE','Active'),
('ONHOLD','On Hold'),
('BLOCKED','Blocked')
ON CONFLICT (status_code)
DO NOTHING;

INSERT INTO supplier_group
(
    supplier_group_code,
    supplier_group_name
)
VALUES
('RAW','Raw Materials'),
('TRADE','Trading Goods'),
('SERVICE','Services'),
('LOGISTICS','Logistics')
ON CONFLICT (supplier_group_code)
DO NOTHING;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE supplier IS
'Supplier master data';

COMMENT ON VIEW vw_supplier IS
'Supplier overview joined with party data';

COMMIT;