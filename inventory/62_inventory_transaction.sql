-- =====================================================
-- VIEW
-- =====================================================

CREATE OR REPLACE VIEW
vw_inventory_transactions
AS
SELECT

    t.inventory_transaction_id,

    t.transaction_number,

    tt.transaction_type_code,

    p.product_no,

    p.product_name,

    t.quantity,

    t.transaction_amount,

    t.transaction_timestamp,

    t.posted_flag

FROM inventory_transaction t

INNER JOIN inventory_transaction_type tt
ON tt.inventory_transaction_type_id =
   t.inventory_transaction_type_id

INNER JOIN product p
ON p.product_id =
   t.product_id;

-- =====================================================
-- SEED DATA
-- =====================================================

INSERT INTO inventory_transaction_type
(
    transaction_type_code,
    transaction_type_name,
    inventory_effect
)
VALUES
('RECEIPT','Inventory Receipt',1),
('ISSUE','Inventory Issue',-1),
('TRANSFER_IN','Transfer In',1),
('TRANSFER_OUT','Transfer Out',-1),
('ADJUSTMENT_PLUS','Positive Adjustment',1),
('ADJUSTMENT_MINUS','Negative Adjustment',-1)
ON CONFLICT (transaction_type_code)
DO NOTHING;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE inventory_transaction IS
'Inventory movement transactions';

COMMENT ON VIEW vw_inventory_transactions IS
'Inventory transaction overview';

COMMENT ON FUNCTION fn_create_inventory_transaction IS
'Creates an inventory transaction';

COMMENT ON FUNCTION fn_apply_inventory_transaction IS
'Posts inventory transaction to inventory balance';

COMMIT;