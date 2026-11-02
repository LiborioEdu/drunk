import math

EARTH_RADIUS_METERS = 6371000.0


def haversine_distance_meters(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> float:
    """Calcula a distância esférica (Haversine) em metros entre dois pontos."""
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_lat / 2.0) ** 2
        + math.cos(lat1_rad)
        * math.cos(lat2_rad)
        * math.sin(delta_lon / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return EARTH_RADIUS_METERS * c


def bearing_degrees(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> float:
    """Calcula o azimute inicial (0° a 360°) do ponto 1 para o ponto 2."""
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    d_lon = math.radians(lon2 - lon1)

    y = math.sin(d_lon) * math.cos(lat2_rad)
    x = math.cos(lat1_rad) * math.sin(lat2_rad) - math.sin(lat1_rad) * math.cos(
        lat2_rad
    ) * math.cos(d_lon)
    initial_bearing = math.degrees(math.atan2(y, x))
    return (initial_bearing + 360.0) % 360.0


def angle_difference(angle1: float, angle2: float) -> float:
    """Retorna a menor diferença angular (0° a 180°) entre dois azimutes."""
    diff = abs(angle1 - angle2) % 360.0
    return 360.0 - diff if diff > 180.0 else diff
