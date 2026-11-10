-- =====================================================
-- ThorERP
-- masterdata/21_customer.sql
-- Customer Master Data
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
-- CUSTOMER GROUP
-- =====================================================

CREATE TABLE IF NOT EXISTS customer_group
(
    customer_group_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    customer_group_code VARCHAR(30)
        NOT NULL,

    customer_group_name VARCHAR(100)
        NOT NULL,

    active_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_customer_group
        PRIMARY KEY
        (
            customer_group_id
        ),

    CONSTRAINT uq_customer_group_code
        UNIQUE
        (
            customer_group_code
        )
);

-- =====================================================
-- CUSTOMER STATUS
-- =====================================================

CREATE TABLE IF NOT EXISTS customer_status
(
    customer_status_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    status_code VARCHAR(30)
        NOT NULL,

    status_name VARCHAR(100)
        NOT NULL,

    active_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_customer_status
        PRIMARY KEY
        (
            customer_status_id
        ),

    CONSTRAINT uq_customer_status_code
        UNIQUE
        (
            status_code
        )
);

-- =====================================================
-- CUSTOMER
-- =====================================================

CREATE TABLE IF NOT EXISTS customer
(
    customer_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    party_id BIGINT
        NOT NULL,

    customer_no VARCHAR(50)
        NOT NULL,

    customer_group_id BIGINT,

    customer_status_id BIGINT
        NOT NULL,

    credit_limit NUMERIC(18,2)
        NOT NULL DEFAULT 0,

    payment_terms_code VARCHAR(30),

    currency_code VARCHAR(10),

    customer_since_date DATE
        DEFAULT CURRENT_DATE,

    blocked_flag BOOLEAN
        NOT NULL DEFAULT FALSE,

    created_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_customer
        PRIMARY KEY
        (
            customer_id
        ),

    CONSTRAINT uq_customer_no
        UNIQUE
        (
            customer_no
        ),

    CONSTRAINT uq_customer_party
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
          'fk_customer_party'
)
THEN

    ALTER TABLE customer
    ADD CONSTRAINT
        fk_customer_party

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
          'fk_customer_group'
)
THEN

    ALTER TABLE customer
    ADD CONSTRAINT
        fk_customer_group

    FOREIGN KEY
    (
        customer_group_id
    )
    REFERENCES customer_group
    (
        customer_group_id
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
          'fk_customer_status'
)
THEN

    ALTER TABLE customer
    ADD CONSTRAINT
        fk_customer_status

    FOREIGN KEY
    (
        customer_status_id
    )
    REFERENCES customer_status
    (
        customer_status_id
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
          'ck_customer_credit_limit'
)
THEN

    ALTER TABLE customer
    ADD CONSTRAINT
        ck_customer_credit_limit

    CHECK
    (
        credit_limit >= 0
    );

END IF;

END;
$$;

-- =====================================================
-- UPDATE TIMESTAMP
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_customer_set_updated_timestamp()
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
trg_customer_updated_timestamp
ON customer;

CREATE TRIGGER
trg_customer_updated_timestamp
BEFORE UPDATE
ON customer
FOR EACH ROW
EXECUTE FUNCTION
fn_customer_set_updated_timestamp();

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS
ix_customer_party
ON customer
(
    party_id
);

CREATE INDEX IF NOT EXISTS
ix_customer_group
ON customer
(
    customer_group_id
);

CREATE INDEX IF NOT EXISTS
ix_customer_status
ON customer
(
    customer_status_id
);

CREATE INDEX IF NOT EXISTS
ix_customer_blocked
ON customer
(
    blocked_flag
);

-- =====================================================
-- VIEW
-- =====================================================

CREATE OR REPLACE VIEW
vw_customer
AS
SELECT

    c.customer_id,

    c.customer_no,

    p.party_id,

    p.legal_name,

    p.display_name,

    p.organization_number,

    c.credit_limit,

    c.blocked_flag,

    s.status_code,

    g.customer_group_code

FROM customer c

INNER JOIN party p
    ON p.party_id =
       c.party_id

INNER JOIN customer_status s
    ON s.customer_status_id =
       c.customer_status_id

LEFT JOIN customer_group g
    ON g.customer_group_id =
       c.customer_group_id;

-- =====================================================
-- SEED DATA
-- =====================================================

INSERT INTO customer_status
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

INSERT INTO customer_group
(
    customer_group_code,
    customer_group_name
)
VALUES
('STANDARD','Standard'),
('WHOLESALE','Wholesale'),
('RETAIL','Retail'),
('EXPORT','Export')
ON CONFLICT (customer_group_code)
DO NOTHING;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE customer IS
'Customer master data';

COMMENT ON VIEW vw_customer IS
'Customer overview joined with party data';

COMMIT;