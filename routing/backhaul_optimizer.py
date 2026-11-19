"""
ASSET ID: IP-02 | Haversine Multi-Constraint Backhaul Engine (BackhaulOpt-Py)
AUTHOR:   Shah Khalid, Principal Systems Architect
ENTITY:   Daughters logistics LLC (Providence, RI)
"""

import math
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import List, Optional

AVG_CORRIDOR_SPEED_MPH = 55.0
DEFAULT_MAX_DEADHEAD_MILES = 75.0


@dataclass
class FleetAsset:
    asset_id: str
    unit_number: str
    equipment_type: str
    max_payload_lbs: int
    status: str


@dataclass
class Driver:
    driver_id: str
    full_name: str
    remaining_hos_hours: float


@dataclass
class FreightOrder:
    order_id: str
    corridor: str
    origin_hub: str
    origin_lat: float
    origin_lon: float
    dest_hub: str
    dest_lat: float
    dest_lon: float
    required_equipment: str
    weight_lbs: int
    pickup_start: datetime
    pickup_end: datetime
    delivery_deadline: datetime


def haversine_miles(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Compute great-circle distance in miles between two WGS84 coordinates."""
    earth_radius_mi = 3958.8
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * earth_radius_mi * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def check_operational_feasibility(
    asset: FleetAsset, driver: Driver, order: FreightOrder, deadhead_miles: float
) -> tuple[bool, str]:
    """Validate equipment, payload, and federal DOT 11-hour driving limits."""
    if asset.status != "AVAILABLE":
        return False, "Asset locked or unavailable"
    if asset.equipment_type != order.required_equipment:
        return False, "Equipment type mismatch"
    if order.weight_lbs > asset.max_payload_lbs:
        return False, "Cargo exceeds maximum axle/payload weight"

    loaded_miles = haversine_miles(order.origin_lat, order.origin_lon, order.dest_lat, order.dest_lon)
    total_drive_hours = (deadhead_miles + loaded_miles) / AVG_CORRIDOR_SPEED_MPH

    if total_drive_hours > driver.remaining_hos_hours:
        return False, f"DOT HOS violation ({total_drive_hours:.2f}h required > {driver.remaining_hos_hours:.2f}h available)"

    return True, "FEASIBLE"


def find_optimal_backhaul(
    outbound: FreightOrder,
    open_pool: List[FreightOrder],
    asset: FleetAsset,
    driver: Driver,
    max_radius_miles: float = DEFAULT_MAX_DEADHEAD_MILES,
) -> Optional[dict]:
    """Match an outbound delivery with the lowest-deadhead return order across partner brokers."""
    best_match = None
    lowest_deadhead = max_radius_miles

    for candidate in open_pool:
        if candidate.order_id == outbound.order_id:
            continue

        deadhead = haversine_miles(
            outbound.dest_lat, outbound.dest_lon, candidate.origin_lat, candidate.origin_lon
        )

        if deadhead <= lowest_deadhead:
            reposition_time = timedelta(hours=(deadhead / AVG_CORRIDOR_SPEED_MPH))
            earliest_arrival = outbound.delivery_deadline + reposition_time

            if earliest_arrival <= candidate.pickup_end:
                feasible, _ = check_operational_feasibility(asset, driver, candidate, deadhead)
                if feasible:
                    lowest_deadhead = deadhead
                    loaded_mi = haversine_miles(
                        candidate.origin_lat, candidate.origin_lon, candidate.dest_lat, candidate.dest_lon
                    )
                    best_match = {
                        "outbound_id": outbound.order_id,
                        "backhaul_id": candidate.order_id,
                        "backhaul_lane": f"{candidate.origin_hub} -> {candidate.dest_hub}",
                        "deadhead_miles": round(deadhead, 2),
                        "loaded_miles": round(loaded_mi, 2),
                        "utilization_ratio": round(loaded_mi / (loaded_mi + deadhead), 4),
                    }

    return best_match
