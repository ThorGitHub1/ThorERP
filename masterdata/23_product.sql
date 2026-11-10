-- =====================================================
-- ThorERP
-- masterdata/23_product.sql
-- Product Master Data
-- PostgreSQL 16
-- =====================================================

BEGIN;

SET search_path TO erp, public;

-- =====================================================
-- PRODUCT TYPE
-- =====================================================

CREATE TABLE IF NOT EXISTS product_type
(
    product_type_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    product_type_code VARCHAR(30)
        NOT NULL,

    product_type_name VARCHAR(100)
        NOT NULL,

    active_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_product_type
        PRIMARY KEY
        (
            product_type_id
        ),

    CONSTRAINT uq_product_type_code
        UNIQUE
        (
            product_type_code
        )
);

-- =====================================================
-- UNIT OF MEASURE
-- =====================================================

CREATE TABLE IF NOT EXISTS unit_of_measure
(
    unit_of_measure_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    uom_code VARCHAR(20)
        NOT NULL,

    uom_name VARCHAR(100)
        NOT NULL,

    CONSTRAINT pk_unit_of_measure
        PRIMARY KEY
        (
            unit_of_measure_id
        ),

    CONSTRAINT uq_unit_of_measure_code
        UNIQUE
        (
            uom_code
        )
);

-- =====================================================
-- PRODUCT
-- =====================================================

CREATE TABLE IF NOT EXISTS product
(
    product_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    product_no VARCHAR(50)
        NOT NULL,

    product_name VARCHAR(250)
        NOT NULL,

    description TEXT,

    product_type_id BIGINT
        NOT NULL,

    inventory_uom_id BIGINT
        NOT NULL,

    sales_uom_id BIGINT,

    purchase_uom_id BIGINT,

    active_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    inventory_controlled_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    purchasable_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    sellable_flag BOOLEAN
        NOT NULL DEFAULT TRUE,

    standard_cost NUMERIC(18,6)
        DEFAULT 0,

    list_price NUMERIC(18,6)
        DEFAULT 0,

    created_timestamp TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_timestamp TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_product
        PRIMARY KEY
        (
            product_id
        ),

    CONSTRAINT uq_product_no
        UNIQUE
        (
            product_no
        )
);

-- =====================================================
-- PRODUCT CATEGORY
-- =====================================================

CREATE TABLE IF NOT EXISTS product_category
(
    product_category_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    category_code VARCHAR(50)
        NOT NULL,

    category_name VARCHAR(100)
        NOT NULL,

    parent_category_id BIGINT,

    CONSTRAINT pk_product_category
        PRIMARY KEY
        (
            product_category_id
        ),

    CONSTRAINT uq_product_category_code
        UNIQUE
        (
            category_code
        )
);

-- =====================================================
-- PRODUCT CATEGORY ASSIGNMENT
-- =====================================================

CREATE TABLE IF NOT EXISTS product_category_assignment
(
    product_id BIGINT NOT NULL,
    product_category_id BIGINT NOT NULL,

    CONSTRAINT pk_product_category_assignment
        PRIMARY KEY
        (
            product_id,
            product_category_id
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
              'fk_product_type'
    )
    THEN

        ALTER TABLE product
        ADD CONSTRAINT
            fk_product_type

        FOREIGN KEY
        (
            product_type_id
        )
        REFERENCES product_type
        (
            product_type_id
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
              'fk_product_inventory_uom'
    )
    THEN

        ALTER TABLE product
        ADD CONSTRAINT
            fk_product_inventory_uom

        FOREIGN KEY
        (
            inventory_uom_id
        )
        REFERENCES unit_of_measure
        (
            unit_of_measure_id
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
              'fk_product_sales_uom'
    )
    THEN

        ALTER TABLE product
        ADD CONSTRAINT
            fk_product_sales_uom

        FOREIGN KEY
        (
            sales_uom_id
        )
        REFERENCES unit_of_measure
        (
            unit_of_measure_id
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
              'fk_product_purchase_uom'
    )
    THEN

        ALTER TABLE product
        ADD CONSTRAINT
            fk_product_purchase_uom

        FOREIGN KEY
        (
            purchase_uom_id
        )
        REFERENCES unit_of_measure
        (
            unit_of_measure_id
        );

    END IF;

END;
$$;

-- =====================================================
-- VALIDATION
-- =====================================================

DO $$
BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conname =
              'ck_product_standard_cost'
    )
    THEN

        ALTER TABLE product
        ADD CONSTRAINT
            ck_product_standard_cost

        CHECK
        (
            standard_cost >= 0
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
              'ck_product_list_price'
    )
    THEN

        ALTER TABLE product
        ADD CONSTRAINT
            ck_product_list_price

        CHECK
        (
            list_price >= 0
        );

    END IF;

END;
$$;

-- =====================================================
-- UPDATE TIMESTAMP
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_product_set_updated_timestamp()
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
trg_product_updated_timestamp
ON product;

CREATE TRIGGER
trg_product_updated_timestamp
BEFORE UPDATE
ON product
FOR EACH ROW
EXECUTE FUNCTION
fn_product_set_updated_timestamp();

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS
ix_product_type
ON product
(
    product_type_id
);

CREATE INDEX IF NOT EXISTS
ix_product_active
ON product
(
    active_flag
);

CREATE INDEX IF NOT EXISTS
ix_product_name
ON product
(
    product_name
);

-- =====================================================
-- VIEW
-- =====================================================

CREATE OR REPLACE VIEW
vw_product
AS
SELECT

    p.product_id,

    p.product_no,

    p.product_name,

    pt.product_type_code,

    p.standard_cost,

    p.list_price,

    p.inventory_controlled_flag,

    p.purchasable_flag,

    p.sellable_flag,

    p.active_flag

FROM product p

INNER JOIN product_type pt
ON pt.product_type_id =
   p.product_type_id;

-- =====================================================
-- SEED DATA
-- =====================================================

INSERT INTO product_type
(
    product_type_code,
    product_type_name
)
VALUES
('INVENTORY','Inventory Item'),
('SERVICE','Service'),
('NONSTOCK','Non Stock Item'),
('RESOURCE','Resource')
ON CONFLICT (product_type_code)
DO NOTHING;

INSERT INTO unit_of_measure
(
    uom_code,
    uom_name
)
VALUES
('EA','Each'),
('KG','Kilogram'),
('M','Meter'),
('L','Liter'),
('H','Hour')
ON CONFLICT (uom_code)
DO NOTHING;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE product IS
'Product master data';

COMMENT ON VIEW vw_product IS
'Product overview';

COMMIT;