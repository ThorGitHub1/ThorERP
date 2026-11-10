-- =====================================================
-- ThorERP Master Install Script
-- =====================================================

\i 01_extensions.sql

-- =====================================================
-- CORE
-- =====================================================

\i core/10_core_reference_data.sql
\i core/11_organization.sql
\i core/12_security.sql
\i core/13_audit.sql

-- =====================================================
-- MASTER DATA
-- =====================================================

\i masterdata/20_party.sql
\i masterdata/21_customer.sql
\i masterdata/22_supplier.sql
\i masterdata/23_product.sql

-- =====================================================
-- INVENTORY
-- =====================================================

\i inventory/60_warehouse.sql
\i inventory/61_inventory_balance.sql
\i inventory/62_inventory_transaction.sql
\i inventory/63_inventory_posting_engine.sql
\i inventory/64_inventory_dispatcher.sql

-- =====================================================
-- PROCUREMENT
-- =====================================================

\i procurement/50_purchase_requisition.sql
\i procurement/51_purchase_order.sql
\i procurement/52_goods_receipt.sql

-- =====================================================
-- SALES
-- =====================================================

\i sales/39_sales_opportunity.sql
\i sales/40_sales_quotation.sql
\i sales/41_sales_order.sql
\i sales/42_shipping.sql
\i sales/43_customer_invoice.sql

-- =====================================================
-- PLANNING
-- =====================================================

\i planning/80_forecasting.sql
\i planning/81_mps.sql
\i planning/82_mrp.sql
\i planning/83_capacity_planning.sql
\i planning/84_exception_messages.sql

-- =====================================================
-- INVENTORY EVENT ENGINE MIGRATIONS
-- =====================================================

\i migrations/V001_event_queue.sql
\i migrations/V002_inventory_ledger.sql
\i migrations/V003_inventory_event_posting.sql
\i migrations/V004_inventory_transaction_source.sql
\i migrations/V005_inventory_balance_snapshot.sql
\i migrations/V006_inventory_posting_engine.sql
\i migrations/V007_inventory_processors.sql
\i migrations/V008_inventory_dispatcher.sql
\i migrations/V009_rebuild_inventory_balance.sql