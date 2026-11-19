-- ============================================================================
-- ASSET ID: IP-05 | Deterministic Asset & Preventive Maintenance Engine (MaintLock-Core)
-- AUTHOR:   Shah Khalid, Principal Systems Architect
-- ============================================================================

CREATE TABLE maintenance_thresholds (
    threshold_id SERIAL PRIMARY KEY,
    equipment_type VARCHAR(30) UNIQUE NOT NULL,
    service_interval_miles DECIMAL(8,1) NOT NULL DEFAULT 15000.0,
    service_interval_engine_hours DECIMAL(8,1) NOT NULL DEFAULT 500.0
);

CREATE TABLE asset_telemetry_logs (
    log_id BIGSERIAL PRIMARY KEY,
    asset_id UUID REFERENCES fleet_assets(asset_id),
    miles_since_last_service DECIMAL(8,1) NOT NULL,
    hours_since_last_service DECIMAL(8,1) NOT NULL,
    active_fault_code VARCHAR(20) NULL,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION trigger_preventive_maintenance_lock() RETURNS TRIGGER AS $$
DECLARE
    v_max_miles DECIMAL(8,1);
    v_max_hours DECIMAL(8,1);
    v_equip VARCHAR(30);
BEGIN
    SELECT equipment_type INTO v_equip FROM fleet_assets WHERE asset_id = NEW.asset_id;
    SELECT service_interval_miles, service_interval_engine_hours
      INTO v_max_miles, v_max_hours
      FROM maintenance_thresholds WHERE equipment_type = v_equip;

    IF NEW.active_fault_code IS NOT NULL
       OR NEW.miles_since_last_service >= COALESCE(v_max_miles, 15000.0)
       OR NEW.hours_since_last_service >= COALESCE(v_max_hours, 500.0) THEN
        UPDATE fleet_assets
           SET operational_status = 'MAINTENANCE'
         WHERE asset_id = NEW.asset_id
           AND operational_status = 'AVAILABLE';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_maint_lock_on_telemetry
AFTER INSERT ON asset_telemetry_logs
FOR EACH ROW EXECUTE FUNCTION trigger_preventive_maintenance_lock();
