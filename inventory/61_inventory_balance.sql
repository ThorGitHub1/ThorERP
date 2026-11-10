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
'Current inventory position';

COMMENT ON TABLE inventory_reservation IS
'Inventory reservations';

COMMENT ON VIEW vw_inventory_availability IS
'Available-to-promise inventory';

COMMENT ON FUNCTION fn_available_to_promise IS
'Returns ATP quantity';

COMMIT;