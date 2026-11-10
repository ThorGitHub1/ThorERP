-- =====================================================
-- ThorERP
-- procurement/50_purchase_requisition.sql
-- Purchase Requisition
-- PostgreSQL 16
-- =====================================================

BEGIN;

SET search_path TO erp, public;

-- =====================================================
-- REQUISITION STATUS
-- =====================================================

CREATE TABLE IF NOT EXISTS purchase_requisition_status
(
    purchase_requisition_status_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    status_code VARCHAR(30) NOT NULL,
    status_name VARCHAR(100) NOT NULL,

    CONSTRAINT pk_purchase_requisition_status
        PRIMARY KEY
        (
            purchase_requisition_status_id
        ),

    CONSTRAINT uq_purchase_requisition_status
        UNIQUE
        (
            status_code
        )
);

-- =====================================================
-- REQUISITION HEADER
-- =====================================================

CREATE TABLE IF NOT EXISTS purchase_requisition
(
    purchase_requisition_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    requisition_number VARCHAR(50)
        NOT NULL,

    purchase_requisition_status_id BIGINT
        NOT NULL,

    requested_date DATE
        NOT NULL
        DEFAULT CURRENT_DATE,

    requested_by VARCHAR(100),

    justification TEXT,

    total_amount NUMERIC(18,2)
        NOT NULL DEFAULT 0,

    created_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_timestamp TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_purchase_requisition
        PRIMARY KEY
        (
            purchase_requisition_id
        ),

    CONSTRAINT uq_purchase_requisition_number
        UNIQUE
        (
            requisition_number
        )
);

-- =====================================================
-- REQUISITION LINE
-- =====================================================

CREATE TABLE IF NOT EXISTS purchase_requisition_line
(
    purchase_requisition_line_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    purchase_requisition_id BIGINT
        NOT NULL,

    line_no INTEGER
        NOT NULL,

    product_id BIGINT
        NOT NULL,

    quantity NUMERIC(18,4)
        NOT NULL,

    required_date DATE,

    estimated_unit_cost NUMERIC(18,6),

    line_amount NUMERIC(18,2),

    inventory_dimension_id BIGINT,

    CONSTRAINT pk_purchase_requisition_line
        PRIMARY KEY
        (
            purchase_requisition_line_id
        ),

    CONSTRAINT uq_purchase_requisition_line
        UNIQUE
        (
            purchase_requisition_id,
            line_no
        )
);

-- =====================================================
-- APPROVAL
-- =====================================================

CREATE TABLE IF NOT EXISTS purchase_requisition_approval
(
    purchase_requisition_approval_id BIGINT
        GENERATED ALWAYS AS IDENTITY,

    purchase_requisition_id BIGINT
        NOT NULL,

    approver_name VARCHAR(100)
        NOT NULL,

    approval_status VARCHAR(30)
        NOT NULL,

    approval_timestamp TIMESTAMPTZ,

    comments VARCHAR(2000),

    CONSTRAINT pk_purchase_requisition_approval
        PRIMARY KEY
        (
            purchase_requisition_approval_id
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
         'fk_pr_header_status'
)
THEN

   ALTER TABLE purchase_requisition
   ADD CONSTRAINT
       fk_pr_header_status

   FOREIGN KEY
   (
       purchase_requisition_status_id
   )
   REFERENCES purchase_requisition_status
   (
       purchase_requisition_status_id
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
         'fk_pr_line_header'
)
THEN

   ALTER TABLE purchase_requisition_line
   ADD CONSTRAINT
       fk_pr_line_header

   FOREIGN KEY
   (
       purchase_requisition_id
   )
   REFERENCES purchase_requisition
   (
       purchase_requisition_id
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
   WHERE conname =
         'fk_pr_line_product'
)
THEN

   ALTER TABLE purchase_requisition_line
   ADD CONSTRAINT
       fk_pr_line_product

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
   WHERE conname =
         'ck_pr_line_quantity'
)
THEN

   ALTER TABLE purchase_requisition_line
   ADD CONSTRAINT
       ck_pr_line_quantity

   CHECK
   (
       quantity > 0
   );

END IF;

END;
$$;

-- =====================================================
-- RECALCULATION
-- =====================================================

CREATE OR REPLACE FUNCTION
fn_recalculate_purchase_requisition
(
    p_purchase_requisition_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS
$$
BEGIN

    UPDATE purchase_requisition h
       SET total_amount =
       (
           SELECT
               COALESCE(
                    SUM(line_amount),
                    0
               )
           FROM purchase_requisition_line l
           WHERE l.purchase_requisition_id =
                 h.purchase_requisition_id
       ),
       updated_timestamp =
           CURRENT_TIMESTAMP
     WHERE h.purchase_requisition_id =
           p_purchase_requisition_id;

END;
$$;

-- =====================================================
-- VIEW
-- =====================================================

CREATE OR REPLACE VIEW
vw_purchase_requisition
AS
SELECT

    h.purchase_requisition_id,
    h.requisition_number,

    s.status_code,

    h.requested_date,

    h.total_amount,

    COUNT(l.purchase_requisition_line_id)
        AS line_count

FROM purchase_requisition h

INNER JOIN purchase_requisition_status s
ON s.purchase_requisition_status_id =
   h.purchase_requisition_status_id

LEFT JOIN purchase_requisition_line l
ON l.purchase_requisition_id =
   h.purchase_requisition_id

GROUP BY

    h.purchase_requisition_id,
    h.requisition_number,
    s.status_code,
    h.requested_date,
    h.total_amount;

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS
ix_pr_status
ON purchase_requisition
(
    purchase_requisition_status_id
);

CREATE 