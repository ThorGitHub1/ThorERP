-- =====================================================
-- ThorERP
-- masterdata/20_party.sql
-- Party Foundation
-- PostgreSQL 16
-- =====================================================

BEGIN;

SET search_path TO erp, public;

-- =====================================================
-- PARTY TYPE
-- =====================================================

CREATE TABLE IF NOT EXISTS party_type
(
    party_type_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    type_code VARCHAR(30)
        NOT NULL,

    type_name VARCHAR(100)
        NOT NULL,

    active_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_party_type
        PRIMARY KEY
        (
            party_type_id
        ),

    CONSTRAINT uq_party_type_code
        UNIQUE
        (
            type_code
        )
);

-- =====================================================
-- PARTY
-- =====================================================

CREATE TABLE IF NOT EXISTS party
(
    party_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    party_no VARCHAR(50)
        NOT NULL,

    party_type_id BIGINT
        NOT NULL,

    legal_name VARCHAR(250)
        NOT NULL,

    display_name VARCHAR(250)
        NOT NULL,

    organization_number VARCHAR(50),

    tax_registration_number VARCHAR(50),

    active_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    created_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_party
        PRIMARY KEY
        (
            party_id
        ),

    CONSTRAINT uq_party_no
        UNIQUE
        (
            party_no
        )
);

-- =====================================================
-- PARTY ADDRESS
-- =====================================================

CREATE TABLE IF NOT EXISTS party_address
(
    party_address_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    party_id BIGINT
        NOT NULL,

    address_type VARCHAR(30)
        NOT NULL,

    address_line_1 VARCHAR(250)
        NOT NULL,

    address_line_2 VARCHAR(250),

    postal_code VARCHAR(30),

    city VARCHAR(100),

    state_region VARCHAR(100),

    country_code VARCHAR(10)
        NOT NULL,

    primary_flag BOOLEAN
        NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_party_address
        PRIMARY KEY
        (
            party_address_id
        )
);

-- =====================================================
-- PARTY CONTACT
-- =====================================================

CREATE TABLE IF NOT EXISTS party_contact
(
    party_contact_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    party_id BIGINT
        NOT NULL,

    contact_type VARCHAR(30)
        NOT NULL,

    contact_value VARCHAR(250)
        NOT NULL,

    primary_flag BOOLEAN
        NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_party_contact
        PRIMARY KEY
        (
            party_contact_id
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
          'fk_party_party_type'
)
THEN

    ALTER TABLE party
    ADD CONSTRAINT
        fk_party_party_type

    FOREIGN KEY
    (
        party_type_id
    )
    REFERENCES party_type
    (
        party_type_id
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
          'fk_party_address_party'
)
THEN

    ALTER TABLE party_address
    ADD CONSTRAINT
        fk_party_address_party

    FOREIGN KEY
    (
        party_id
    )
    REFERENCES party
    (
        party_id
    )
    ON DELETE CASCADE;

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
          'fk_party_contact_party'
)
THEN

    ALTER TABLE party_contact
    ADD CONSTRAINT
        fk_party_contact_party

    FOREIGN KEY
    (
        party_id
    )
    REFERENCES party
    (
        party_id
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
    WHERE conname =
          'ck_party_legal_name'
)
THEN

    ALTER TABLE party
    ADD CONSTRAINT
        ck_party_legal_name

    CHECK
    (
        length(trim(legal_name)) > 0
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
          'ck_party_display_name'
)
THEN

    ALTER TABLE party
    ADD CONSTRAINT
        ck_party_display_name

    CHECK
    (
        length(trim(display_name)) > 0
    );

END IF;

END;
$$;

-- =====================================================
-- UPDATE TIMESTAMP
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_party_set_updated_timestamp()
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
trg_party_updated_timestamp
ON party;

CREATE TRIGGER
trg_party_updated_timestamp
BEFORE UPDATE
ON party
FOR EACH ROW
EXECUTE FUNCTION
fn_party_set_updated_timestamp();

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS
ix_party_name
ON party
(
    display_name
);

CREATE INDEX IF NOT EXISTS
ix_party_type
ON party
(
    party_type_id
);

CREATE INDEX IF NOT EXISTS
ix_party_address_party
ON party_address
(
    party_id
);

CREATE INDEX IF NOT EXISTS
ix_party_contact_party
ON party_contact
(
    party_id
);

-- =====================================================
-- SEED DATA
-- =====================================================

INSERT INTO party_type
(
    type_code,
    type_name
)
VALUES
('CUSTOMER','Customer'),
('SUPPLIER','Supplier'),
('EMPLOYEE','Employee'),
('CONTACT','Contact'),
('WAREHOUSE','Warehouse')
ON CONFLICT (type_code)
DO NOTHING;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE party IS
'Common business entity used by customers, suppliers and other legal entities';

COMMENT ON TABLE party_address IS
'Addresses for parties';

COMMENT ON TABLE party_contact IS
'Electronic and phone contact information';

COMMIT;