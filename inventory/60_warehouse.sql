-- =====================================================
-- ThorERP
-- inventory/60_warehouse.sql
-- Warehouse Master Data
-- PostgreSQL 16
-- =====================================================

BEGIN;

SET search_path TO erp, public;

-- =====================================================
-- WAREHOUSE STATUS
-- =====================================================

CREATE TABLE IF NOT EXISTS warehouse_status
(
    warehouse_status_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    status_code VARCHAR(30)
        NOT NULL,

    status_name VARCHAR(100)
        NOT NULL,

    active_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_warehouse_status
        PRIMARY KEY
        (
            warehouse_status_id
        ),

    CONSTRAINT uq_warehouse_status_code
        UNIQUE
        (
            status_code
        )
);

-- =====================================================
-- WAREHOUSE
-- =====================================================

CREATE TABLE IF NOT EXISTS warehouse
(
    warehouse_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    warehouse_code VARCHAR(30)
        NOT NULL,

    warehouse_name VARCHAR(150)
        NOT NULL,

    warehouse_status_id BIGINT
        NOT NULL,

    party_id BIGINT,

    default_flag BOOLEAN
        NOT NULL DEFAULT FALSE,

    active_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    created_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_warehouse
        PRIMARY KEY
        (
            warehouse_id
        ),

    CONSTRAINT uq_warehouse_code
        UNIQUE
        (
            warehouse_code
        )
);

-- =====================================================
-- WAREHOUSE LOCATION
-- =====================================================

CREATE TABLE IF NOT EXISTS warehouse_location
(
    warehouse_location_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    warehouse_id BIGINT
        NOT NULL,

    location_code VARCHAR(50)
        NOT NULL,

    location_name VARCHAR(150)
        NOT NULL,

    pickable_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    receivable_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    active_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_warehouse_location
        PRIMARY KEY
        (
            warehouse_location_id
        ),

    CONSTRAINT uq_warehouse_location
        UNIQUE
        (
            warehouse_id,
            location_code
        )
);

-- =====================================================
-- INVENTORY DIMENSION
-- =====================================================

CREATE TABLE IF NOT EXISTS inventory_dimension
(
    inventory_dimension_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    warehouse_id BIGINT
        NOT NULL,

    warehouse_location_id BIGINT,

    lot_number VARCHAR(100),

    serial_number VARCHAR(100),

    inventory_status_code VARCHAR(30)
        DEFAULT 'AVAILABLE',

    created_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_inventory_dimension
        PRIMARY KEY
        (
            inventory_dimension_id
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
          'fk_warehouse_status'
)
THEN

    ALTER TABLE warehouse
    ADD CONSTRAINT
        fk_warehouse_status

    FOREIGN KEY
    (
        warehouse_status_id
    )
    REFERENCES warehouse_status
    (
        warehouse_status_id
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
      AND table_name='party'
)
AND NOT EXISTS
(
    SELECT 1
    FROM pg_constraint
    WHERE conname =
          'fk_warehouse_party'
)
THEN

    ALTER TABLE warehouse
    ADD CONSTRAINT
        fk_warehouse_party

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
          'fk_location_warehouse'
)
THEN

    ALTER TABLE warehouse_location
    ADD CONSTRAINT
        fk_location_warehouse

    FOREIGN KEY
    (
        warehouse_id
    )
    REFERENCES warehouse
    (
        warehouse_id
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
          'fk_dimension_warehouse'
)
THEN

    ALTER TABLE inventory_dimension
    ADD CONSTRAINT
        fk_dimension_warehouse

    FOREIGN KEY
    (
        warehouse_id
    )
    REFERENCES warehouse
    (
        warehouse_id
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
          'fk_dimension_location'
)
THEN

    ALTER TABLE inventory_dimension
    ADD CONSTRAINT
        fk_dimension_location

    FOREIGN KEY
    (
        warehouse_location_id
    )
    REFERENCES warehouse_location
    (
        warehouse_location_id
    );

END IF;

END;
$$;

-- =====================================================
-- UPDATE TIMESTAMP
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_warehouse_set_updated_timestamp()
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
trg_warehouse_updated_timestamp
ON warehouse;

CREATE TRIGGER
trg_warehouse_updated_timestamp
BEFORE UPDATE
ON warehouse
FOR EACH ROW
EXECUTE FUNCTION
fn_warehouse_set_updated_timestamp();

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS
ix_warehouse_status
ON warehouse
(
    warehouse_status_id
);

CREATE INDEX IF NOT EXISTS
ix_location_warehouse
ON warehouse_location
(
    warehouse_id
);

CREATE INDEX IF NOT EXISTS
ix_dimension_warehouse
ON inventory_dimension
(
    warehouse_id
);

CREATE INDEX IF NOT EXISTS
ix_dimension_lot
ON inventory_dimension
(
    lot_number
);

CREATE INDEX IF NOT EXISTS
ix_dimension_serial
ON inventory_dimension
(
    serial_number
);

-- =====================================================
-- VIEW
-- =====================================================

CREATE OR REPLACE VIEW
vw_warehouse
AS
SELECT

    w.warehouse_id,

    w.warehouse_code,

    w.warehouse_name,

    ws.status_code,

    w.default_flag,

    w.active_flag

FROM warehouse w

INNER JOIN warehouse_status ws
ON ws.warehouse_status_id =
   w.warehouse_status_id;

-- =====================================================
-- SEED DATA
-- =====================================================

INSERT INTO warehouse_status
(
    status_code,
    status_name
)
VALUES
('ACTIVE','Active'),
('INACTIVE','Inactive'),
('BLOCKED','Blocked')
ON CONFLICT (status_code)
DO NOTHING;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE warehouse IS
'Inventory warehouse master';

COMMENT ON TABLE warehouse_location IS
'Storage locations within warehouse';

COMMENT ON TABLE inventory_dimension IS
'Inventory tracking dimensions';

COMMENT ON VIEW vw_warehouse IS
'Warehouse overview';

COMMIT;