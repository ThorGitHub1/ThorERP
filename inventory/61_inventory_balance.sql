-- =====================================================
-- ThorERP
-- inventory/61_inventory_balance.sql
-- Inventory Balance & Reservations
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
          AND table_name='product'
    )
    THEN
        RAISE EXCEPTION
        '23_product.sql must be installed first';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema='erp'
          AND table_name='inventory_dimension'
    )
    THEN
        RAISE EXCEPTION
        '60_warehouse.sql must be installed first';
    END IF;

END;
$$;

-- =====================================================
-- INVENTORY BALANCE
-- =====================================================

CREATE TABLE IF NOT EXISTS inventory_balance
(
    inventory_balance_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    product_id BIGINT
        NOT NULL,

    inventory_dimension_id BIGINT
        NOT NULL,

    quantity_on_hand NUMERIC(18,4)
        NOT NULL DEFAULT 0,

    quantity_reserved NUMERIC(18,4)
        NOT NULL DEFAULT 0,

    quantity_available NUMERIC(18,4)
        NOT NULL DEFAULT 0,

    last_transaction_timestamp TIMESTAMPTZ,

    created_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_inventory_balance
        PRIMARY KEY
        (
            inventory_balance_id
        ),

    CONSTRAINT uq_inventory_balance
        UNIQUE
        (
            product_id,
            inventory_dimension_id
        )
);

-- =====================================================
-- INVENTORY RESERVATION
-- =====================================================

CREATE TABLE IF NOT EXISTS inventory_reservation
(
    inventory_reservation_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    reservation_reference_type VARCHAR(50)
        NOT NULL,

    reservation_reference_id BIGINT
        NOT NULL,

    product_id BIGINT
        NOT NULL,

    inventory_dimension_id BIGINT
        NOT NULL,

    reserved_quantity NUMERIC(18,4)
        NOT NULL,

    reservation_date TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    released_flag BOOLEAN
        NOT NULL DEFAULT FALSE,

    released_timestamp TIMESTAMPTZ,

    CONSTRAINT pk_inventory_reservation
        PRIMARY KEY
        (
            inventory_reservation_id
        )
);

-- =====================================================
-- FOREIGN KEYS
-- =====================================================

ALTER TABLE inventory_balance
ADD CONSTRAINT fk_inventory_balance_product
FOREIGN KEY (product_id)
REFERENCES product(product_id);

ALTER TABLE inventory_balance
ADD CONSTRAINT fk_inventory_balance_dimension
FOREIGN KEY (inventory_dimension_id)
REFERENCES inventory_dimension(inventory_dimension_id);

ALTER TABLE inventory_reservation
ADD CONSTRAINT fk_inventory_reservation_product
FOREIGN KEY (product_id)
REFERENCES product(product_id);

ALTER TABLE inventory_reservation
ADD CONSTRAINT fk_inventory_reservation_dimension
FOREIGN KEY (inventory_dimension_id)
REFERENCES inventory_dimension(inventory_dimension_id);

-- =====================================================
-- ATP RECALCULATION
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_recalculate_inventory_balance
(
    p_product_id BIGINT,
    p_inventory_dimension_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS
$$
BEGIN

    UPDATE inventory_balance
       SET quantity_available =
           quantity_on_hand
           - quantity_reserved,

           updated_timestamp =
               CURRENT_TIMESTAMP

     WHERE product_id =
           p_product_id

       AND inventory_dimension_id =
           p_inventory_dimension_id;

END;
$$;

-- =====================================================
-- ATP VIEW
-- =====================================================

CREATE OR REPLACE VIEW
vw_inventory_availability
AS
SELECT

    b.inventory_balance_id,
    b.product_id,
    p.product_no,
    p.product_name,
    b.inventory_dimension_id,
    b.quantity_on_hand,
    b.quantity_reserved,
    b.quantity_available

FROM inventory_balance b

INNER JOIN product p
        ON p.product_id =
           b.product_id;

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS
ix_inventory_balance_product
ON inventory_balance
(
    product_id
);

CREATE INDEX IF NOT EXISTS
ix_inventory_balance_dimension
ON inventory_balance
(
    inventory_dimension_id
);

CREATE INDEX IF NOT EXISTS
ix_inventory_reservation_reference
ON inventory_reservation
(
    reservation_reference_type,
    reservation_reference_id
);

CREATE INDEX IF NOT EXISTS
ix_inventory_reservation_product
ON inventory_reservation
(
    product_id
);

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE inventory_balance IS
'Current inventory balance';

COMMENT ON TABLE inventory_reservation IS
'Inventory reservations';

COMMENT ON VIEW vw_inventory_availability IS
'Available inventory quantities';

COMMIT;