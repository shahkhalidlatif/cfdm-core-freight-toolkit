"""
ASSET ID: IP-04 | Universal ERP & Telemetry Edge-Adapter Kit (FreightSync-ETL)
AUTHOR:   Shah Khalid, Principal Systems Architect
PURPOSE:  20% Configurable Edge Layer normalizing legacy ERP/ELD records into CFDM-Core
"""

import csv
import json
from datetime import datetime
from typing import Dict, List


def normalize_legacy_erp_order(raw_row: Dict[str, str], partner_id: str) -> Dict:
    """Transform heterogeneous legacy ERP/WMS CSV or JSON rows into Canonical Freight Order schema."""
    return {
        "shipper_or_broker_id": partner_id,
        "corridor_code": raw_row.get("corridor", "I-95").strip().upper(),
        "origin_hub": raw_row["pickup_city"].strip(),
        "origin_lat": round(float(raw_row["pickup_lat"]), 6),
        "origin_lon": round(float(raw_row["pickup_lon"]), 6),
        "destination_hub": raw_row["dropoff_city"].strip(),
        "dest_lat": round(float(raw_row["dropoff_lat"]), 6),
        "dest_lon": round(float(raw_row["dropoff_lon"]), 6),
        "required_equipment": raw_row.get("trailer_type", "Dry Van").strip(),
        "cargo_weight_lbs": int(float(raw_row["weight_lbs"])),
        "pickup_window_start": datetime.fromisoformat(raw_row["pickup_start"]).isoformat(),
        "pickup_window_end": datetime.fromisoformat(raw_row["pickup_end"]).isoformat(),
        "delivery_deadline": datetime.fromisoformat(raw_row["delivery_due"]).isoformat(),
        "order_status": "OPEN",
    }


def export_usdot_flow_payload(canonical_orders: List[Dict]) -> str:
    """Format canonical logistics events into standardized JSON compatible with USDOT FLOW data exchange."""
    flow_envelope = {
        "schema_standard": "CFDM-Core-v2.1 / USDOT-FLOW-Aligned",
        "generated_utc": datetime.utcnow().isoformat() + "Z",
        "record_count": len(canonical_orders),
        "freight_events": canonical_orders,
    }
    return json.dumps(flow_envelope, indent=2)
