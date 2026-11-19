"""
ASSET ID: IP-06 | EPA SmartWay & Corridor Benchmark Reporter (SmartWayMetrics-Export)
AUTHOR:   Shah Khalid, Principal Systems Architect
PURPOSE:  Generates EPA SmartWay carrier efficiency metrics & public corridor benchmarks
"""

EPA_DIESEL_CO2_LBS_PER_GAL = 22.44
DEFAULT_CLASS8_MPG = 6.5
BASELINE_DEADHEAD_RATE = 0.167  # 16.7% U.S. industry baseline


def generate_smartway_corridor_report(
    corridor_name: str,
    total_fleet_miles: float,
    actual_deadhead_miles: float,
    fleet_mpg: float = DEFAULT_CLASS8_MPG,
    diesel_price_per_gal: float = 3.85,
) -> dict:
    """Compute empty-mile reduction, fuel conserved, and CO2 short tons eliminated."""
    baseline_empty_miles = total_fleet_miles * BASELINE_DEADHEAD_RATE
    eliminated_empty_miles = max(0.0, baseline_empty_miles - actual_deadhead_miles)

    gallons_conserved = eliminated_empty_miles / fleet_mpg
    fuel_cost_saved_usd = gallons_conserved * diesel_price_per_gal
    co2_short_tons_eliminated = (gallons_conserved * EPA_DIESEL_CO2_LBS_PER_GAL) / 2000.0

    return {
        "corridor": corridor_name,
        "total_miles_tracked": round(total_fleet_miles, 1),
        "actual_deadhead_pct": round((actual_deadhead_miles / total_fleet_miles) * 100, 2),
        "eliminated_empty_miles": round(eliminated_empty_miles, 1),
        "diesel_gallons_conserved": round(gallons_conserved, 1),
        "direct_fuel_savings_usd": round(fuel_cost_saved_usd, 2),
        "epa_smartway_co2_tons_reduced": round(co2_short_tons_eliminated, 2),
    }
