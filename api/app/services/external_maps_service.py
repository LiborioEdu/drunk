import httpx
from ..core.config import settings
from ..schemas.route_schemas import BarSchema, CoordinateSchema


class ExternalMapsService:
    """Serviço de integração com Overpass API, OSRM e Nominatim (Custo Zero)."""

    def __init__(self) -> None:
        self.headers = {
            "User-Agent": settings.USER_AGENT,
            "Accept": "application/json",
        }

    async def fetch_bars_around(
        self, lat: float, lng: float, radius_meters: float = 3500.0
    ) -> list[BarSchema]:
        """Consulta estabelecimentos amenity=bar|pub|biergarten na Overpass API."""
        r_int = int(radius_meters)
        query = f"""
[out:json][timeout:25];
(
  node["amenity"~"^(bar|pub|biergarten)$"](around:{r_int},{lat},{lng});
  way["amenity"~"^(bar|pub|biergarten)$"](around:{r_int},{lat},{lng});
);
out center;
"""
        async with httpx.AsyncClient(timeout=20.0, headers=self.headers) as client:
            for endpoint in settings.OVERPASS_URLS:
                try:
                    resp = await client.post(endpoint, data={"data": query})
                    if resp.status_code == 200:
                        data = resp.json()
                        elements = data.get("elements", [])
                        return self._parse_overpass_elements(elements)
                except Exception:
                    continue

        return []

    def _parse_overpass_elements(self, elements: list[dict]) -> list[BarSchema]:
        bars: list[BarSchema] = []
        seen_ids: set[str] = set()

        for elem in elements:
            b_lat = elem.get("lat")
            b_lon = elem.get("lon")
            if b_lat is None or b_lon is None:
                center = elem.get("center") or {}
                b_lat = center.get("lat")
                b_lon = center.get("lon")

            if b_lat is None or b_lon is None:
                continue

            bar_id = str(elem.get("id", ""))
            if not bar_id or bar_id in seen_ids:
                continue
            seen_ids.add(bar_id)

            tags = elem.get("tags") or {}
            name = (
                tags.get("name")
                or tags.get("name:pt")
                or tags.get("brand")
                or "Bar sem nome"
            )
            street = tags.get("addr:street")
            number = tags.get("addr:housenumber")
            address = f"{street}, {number}" if street and number else street
            amenity = tags.get("amenity", "bar")

            bars.append(
                BarSchema(
                    id=bar_id,
                    name=name,
                    latitude=float(b_lat),
                    longitude=float(b_lon),
                    address=address,
                    amenity=amenity,
                )
            )

        return bars

    async def calculate_foot_route(
        self, waypoints: list[CoordinateSchema]
    ) -> dict | None:
        """Calcula rota real pelas calçadas via OSRM."""
        if len(waypoints) < 2:
            return None

        coords_str = ";".join(
            f"{pt.longitude:.6f},{pt.latitude:.6f}" for pt in waypoints
        )
        url = (
            f"{settings.OSRM_FOOT_BASE_URL}/{coords_str}"
            "?overview=full&geometries=geojson&steps=false"
        )

        try:
            async with httpx.AsyncClient(
                timeout=15.0, headers=self.headers
            ) as client:
                resp = await client.get(url)
                if resp.status_code != 200:
                    return None
                data = resp.json()
                if data.get("code") != "Ok":
                    return None
                routes = data.get("routes") or []
                if not routes:
                    return None

                primary = routes[0]
                raw_coords = (primary.get("geometry") or {}).get(
                    "coordinates", []
                )
                polyline = [
                    CoordinateSchema(
                        latitude=float(c[1]), longitude=float(c[0])
                    )
                    for c in raw_coords
                    if isinstance(c, list) and len(c) >= 2
                ]
                legs = primary.get("legs") or []
                leg_distances = [
                    float(leg.get("distance", 0.0)) for leg in legs
                ]

                return {
                    "distance_meters": float(primary.get("distance", 0.0)),
                    "duration_seconds": float(primary.get("duration", 0.0)),
                    "polyline": polyline,
                    "leg_distances": leg_distances,
                }
        except Exception:
            return None

    async def reverse_geocode(self, lat: float, lng: float) -> str:
        """Resolve endereço amigável via Nominatim."""
        params = {
            "format": "jsonv2",
            "lat": f"{lat:.6f}",
            "lon": f"{lng:.6f}",
            "zoom": "18",
            "addressdetails": "1",
        }
        try:
            async with httpx.AsyncClient(
                timeout=8.0,
                headers={**self.headers, "Accept-Language": "pt-BR,pt;q=0.9"},
            ) as client:
                resp = await client.get(
                    settings.NOMINATIM_REVERSE_URL, params=params
                )
                if resp.status_code == 200:
                    data = resp.json()
                    addr = data.get("address") or {}
                    road = (
                        addr.get("road")
                        or addr.get("pedestrian")
                        or addr.get("suburb")
                    )
                    suburb = addr.get("suburb") or addr.get("neighbourhood")
                    parts = [p for p in [road, suburb] if p]
                    if parts:
                        return " • ".join(dict.fromkeys(parts))
        except Exception:
            pass
        return f"{lat:.4f}, {lng:.4f}"


external_maps_service = ExternalMapsService()
