-- ============================================================================
-- ASSET ID: IP-03 | ACID Dispatch Concurrency & Compliance Kernel (DispatchGuard-SQL)
-- AUTHOR:   Shah Khalid, Principal Systems Architect
-- ============================================================================

CREATE TABLE dispatch_schedule (
    dispatch_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_id UUID NOT NULL REFERENCES fleet_assets(asset_id),
    driver_id UUID NOT NULL REFERENCES drivers(driver_id),
    outbound_order_id UUID NOT NULL REFERENCES canonical_freight_orders(order_id),
    backhaul_order_id UUID NULL REFERENCES canonical_freight_orders(order_id),
    deadhead_miles DECIMAL(7,2) NOT NULL DEFAULT 0.00,
    loaded_miles DECIMAL(7,2) NOT NULL,
    scheduled_departure TIMESTAMP NOT NULL,
    scheduled_arrival TIMESTAMP NOT NULL,
    committed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Kernel-level ACID concurrency locks preventing double-booking across dispatchers
    CONSTRAINT lock_unique_asset_window UNIQUE (asset_id, scheduled_departure),
    CONSTRAINT lock_unique_driver_window UNIQUE (driver_id, scheduled_departure),
    CONSTRAINT chk_valid_time_sequence CHECK (scheduled_arrival > scheduled_departure)
);

CREATE OR REPLACE FUNCTION enforce_dispatch_compliance() RETURNS TRIGGER AS $$
DECLARE
    v_status VARCHAR(20);
    v_permit_expiry DATE;
    v_hos_hours DECIMAL(4,2);
    v_required_hours DECIMAL(4,2);
BEGIN
    SELECT operational_status, permit_expiry_date
      INTO v_status, v_permit_expiry
      FROM fleet_assets WHERE asset_id = NEW.asset_id;

    IF v_status <> 'AVAILABLE' THEN
        RAISE EXCEPTION 'DISPATCH_KERNEL_BLOCK: Asset % is locked in status %.', NEW.asset_id, v_status;
    END IF;

    IF v_permit_expiry < DATE(NEW.scheduled_arrival) THEN
        RAISE EXCEPTION 'DISPATCH_KERNEL_BLOCK: Commercial permit expires (%) prior to route completion.', v_permit_expiry;
    END IF;

    SELECT remaining_dot_hos_hours INTO v_hos_hours FROM drivers WHERE driver_id = NEW.driver_id;
    v_required_hours := (NEW.deadhead_miles + NEW.loaded_miles) / 55.0;

    IF v_required_hours > v_hos_hours THEN
        RAISE EXCEPTION 'DISPATCH_KERNEL_BLOCK: Required drive time (% hrs) exceeds DOT HOS (% hrs).',
            ROUND(v_required_hours, 2), v_hos_hours;
    END IF;

    UPDATE fleet_assets SET operational_status = 'DISPATCHED' WHERE asset_id = NEW.asset_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_acid_dispatch_guard
BEFORE INSERT ON dispatch_schedule
FOR EACH ROW EXECUTE FUNCTION enforce_dispatch_compliance();
