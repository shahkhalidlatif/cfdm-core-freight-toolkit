-- ============================================================================
-- ASSET ID: IP-01 | Canonical Freight Data Model (CFDM-Core v2.1)
-- AUTHOR:   Shah Khalid, Principal Systems Architect
-- ENTITY:   Daughters logistics LLC (Providence, RI)
-- LICENSE:  Proprietary / Open-Core Validation Schema
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE carriers_and_partners (
    partner_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    legal_name VARCHAR(150) NOT NULL,
    usdot_number VARCHAR(20) UNIQUE,
    mc_number VARCHAR(20),
    partner_role VARCHAR(25) NOT NULL CHECK (partner_role IN ('CARRIER', 'BROKER_3PL', 'SHIPPER_TERMINAL')),
    corridor_hub VARCHAR(50) NOT NULL, -- e.g., 'I-95_ProvPort', 'I-95_Newark', 'I-80_Chicago'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE fleet_assets (
    asset_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    partner_id UUID REFERENCES carriers_and_partners(partner_id),
    unit_number VARCHAR(30) NOT NULL,
    equipment_type VARCHAR(30) NOT NULL CHECK (equipment_type IN ('Dry Van', 'Reefer', 'Flatbed', 'Chassis_40ft')),
    max_payload_lbs INT NOT NULL CHECK (max_payload_lbs > 0),
    current_odometer_miles DECIMAL(10,1) DEFAULT 0.0,
    engine_operating_hours DECIMAL(10,1) DEFAULT 0.0,
    current_lat DECIMAL(9,6),
    current_lon DECIMAL(9,6),
    permit_expiry_date DATE NOT NULL,
    operational_status VARCHAR(20) DEFAULT 'AVAILABLE'
        CHECK (operational_status IN ('AVAILABLE', 'DISPATCHED', 'IN_TRANSIT', 'MAINTENANCE')),
    UNIQUE (partner_id, unit_number)
);

CREATE TABLE drivers (
    driver_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    partner_id UUID REFERENCES carriers_and_partners(partner_id),
    full_name VARCHAR(100) NOT NULL,
    cdl_license_number VARCHAR(35) UNIQUE NOT NULL,
    remaining_dot_hos_hours DECIMAL(4,2) NOT NULL CHECK (remaining_dot_hos_hours BETWEEN 0.00 AND 11.00),
    home_terminal_city VARCHAR(60) NOT NULL,
    driver_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (driver_status IN ('ACTIVE', 'OFF_DUTY', 'SUSPENDED'))
);

CREATE TABLE canonical_freight_orders (
    order_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipper_or_broker_id UUID REFERENCES carriers_and_partners(partner_id),
    corridor_code VARCHAR(15) NOT NULL, -- e.g., 'I-95', 'I-80'
    origin_hub VARCHAR(60) NOT NULL,
    origin_lat DECIMAL(9,6) NOT NULL,
    origin_lon DECIMAL(9,6) NOT NULL,
    destination_hub VARCHAR(60) NOT NULL,
    dest_lat DECIMAL(9,6) NOT NULL,
    dest_lon DECIMAL(9,6) NOT NULL,
    required_equipment VARCHAR(30) NOT NULL,
    cargo_weight_lbs INT NOT NULL,
    pickup_window_start TIMESTAMP NOT NULL,
    pickup_window_end TIMESTAMP NOT NULL,
    delivery_deadline TIMESTAMP NOT NULL,
    order_status VARCHAR(20) DEFAULT 'OPEN' CHECK (order_status IN ('OPEN', 'MATCHED', 'IN_TRANSIT', 'DELIVERED'))
);

CREATE INDEX idx_cfdm_open_orders_geo ON canonical_freight_orders (origin_lat, origin_lon) WHERE order_status = 'OPEN';
CREATE INDEX idx_cfdm_asset_status ON fleet_assets (operational_status, equipment_type);
