from ..core.geo import (
    angle_difference,
    bearing_degrees,
    haversine_distance_meters,
)
from ..schemas.route_schemas import BarSchema, CoordinateSchema
from .external_maps_service import ExternalMapsService, external_maps_service


class RouteEngineService:
    """Motor de Heurística dos 10 Bares (Alvo: 10km) e Substituição Individual (Swap)."""

    def __init__(self, maps_service: ExternalMapsService | None = None) -> None:
        self.maps_service = maps_service or external_maps_service

    def select_bars_heuristic(
        self,
        origin: CoordinateSchema,
        pool: list[BarSchema],
        target_count: int = 10,
        min_leg_m: float = 600.0,
        max_leg_m: float = 1400.0,
    ) -> list[BarSchema]:
        """Seleciona até `target_count` bares evitando retornos na contramão."""
        selected: list[BarSchema] = []
        used_ids: set[str] = set()
        cur_lat = origin.latitude
        cur_lng = origin.longitude
        last_bearing: float | None = None

        cur_min = min_leg_m
        cur_max = max_leg_m

        while len(selected) < target_count and len(used_ids) < len(pool):
            best_candidate: BarSchema | None = None
            best_score = float("inf")

            for candidate in pool:
                if candidate.id in used_ids:
                    continue

                dist = haversine_distance_meters(
                    cur_lat, cur_lng, candidate.latitude, candidate.longitude
                )
                if dist < (cur_min * 0.6) or dist > (cur_max * 1.5):
                    continue

                bearing = bearing_degrees(
                    cur_lat, cur_lng, candidate.latitude, candidate.longitude
                )
                angle_penalty = 0.0
                if last_bearing is not None:
                    diff = angle_difference(last_bearing, bearing)
                    if diff > 120.0:
                        angle_penalty = (diff - 120.0) * 8.0

                target_leg = (cur_min + cur_max) / 2.0
                score = abs(dist - target_leg) + angle_penalty
                if score < best_score:
                    best_score = score
                    best_candidate = candidate

            if best_candidate is not None:
                selected.append(best_candidate)
                used_ids.add(best_candidate.id)
                last_bearing = bearing_degrees(
                    cur_lat,
                    cur_lng,
                    best_candidate.latitude,
                    best_candidate.longitude,
                )
                cur_lat = best_candidate.latitude
                cur_lng = best_candidate.longitude
            else:
                if cur_min > 300.0:
                    cur_min -= 150.0
                    cur_max += 300.0
                else:
                    # Fallback para o mais próximo ainda não visitado
                    remaining = [c for c in pool if c.id not in used_ids]
                    if not remaining:
                        break
                    closest = min(
                        remaining,
                        key=lambda c: haversine_distance_meters(
                            cur_lat, cur_lng, c.latitude, c.longitude
                        ),
                    )
                    selected.append(closest)
                    used_ids.add(closest.id)
                    cur_lat = closest.latitude
                    cur_lng = closest.longitude

        return selected

    async def compute_route_metrics(
        self, origin: CoordinateSchema, selected_bars: list[BarSchema]
    ) -> tuple[list[BarSchema], list[CoordinateSchema], float, float]:
        """Calcula distâncias reais por trecho via OSRM com fallback Haversine compensado."""
        waypoints = [origin] + [
            CoordinateSchema(latitude=b.latitude, longitude=b.longitude)
            for b in selected_bars
        ]
        osrm_data = await self.maps_service.calculate_foot_route(waypoints)

        finalized_bars: list[BarSchema] = []
        if osrm_data is not None:
            leg_distances: list[float] = osrm_data["leg_distances"]
            for i, bar in enumerate(selected_bars):
                prev_coord = (
                    origin
                    if i == 0
                    else CoordinateSchema(
                        latitude=selected_bars[i - 1].latitude,
                        longitude=selected_bars[i - 1].longitude,
                    )
                )
                leg_dist = (
                    leg_distances[i]
                    if i < len(leg_distances)
                    else haversine_distance_meters(
                        prev_coord.latitude,
                        prev_coord.longitude,
                        bar.latitude,
                        bar.longitude,
                    )
                )
                finalized_bars.append(
                    bar.model_copy(
                        update={
                            "order": i + 1,
                            "distanceFromPrevious": round(leg_dist, 1),
                        }
                    )
                )
            return (
                finalized_bars,
                osrm_data["polyline"],
                round(osrm_data["distance_meters"], 1),
                round(osrm_data["duration_seconds"], 1),
            )

        # Fallback offline / compensado (~1.28x para curvas de ruas)
        total_dist = 0.0
        polyline: list[CoordinateSchema] = [origin]
        prev_lat, prev_lng = origin.latitude, origin.longitude

        for i, bar in enumerate(selected_bars):
            dist = (
                haversine_distance_meters(
                    prev_lat, prev_lng, bar.latitude, bar.longitude
                )
                * 1.28
            )
            total_dist += dist
            finalized_bars.append(
                bar.model_copy(
                    update={
                        "order": i + 1,
                        "distanceFromPrevious": round(dist, 1),
                    }
                )
            )
            polyline.append(
                CoordinateSchema(latitude=bar.latitude, longitude=bar.longitude)
            )
            prev_lat, prev_lng = bar.latitude, bar.longitude

        duration_seconds = total_dist / 1.25
        return (
            finalized_bars,
            polyline,
            round(total_dist, 1),
            round(duration_seconds, 1),
        )

    async def swap_single_bar(
        self,
        origin: CoordinateSchema,
        current_bars: list[BarSchema],
        candidate_pool: list[BarSchema],
        rejected_ids: set[str],
        bar_index: int,
    ) -> tuple[
        list[BarSchema], list[CoordinateSchema], float, float, set[str]
    ]:
        """Substitui o bar na posição `bar_index` pelo melhor candidato próximo ao ponto médio."""
        if bar_index < 0 or bar_index >= len(current_bars):
            raise ValueError("Índice de bar inválido para substituição.")

        bar_to_replace = current_bars[bar_index]
        updated_rejected = set(rejected_ids)
        updated_rejected.add(bar_to_replace.id)

        current_ids = {b.id for b in current_bars}

        prev_lat = (
            origin.latitude
            if bar_index == 0
            else current_bars[bar_index - 1].latitude
        )
        prev_lng = (
            origin.longitude
            if bar_index == 0
            else current_bars[bar_index - 1].longitude
        )

        next_lat = (
            current_bars[bar_index + 1].latitude
            if bar_index < len(current_bars) - 1
            else prev_lat
        )
        next_lng = (
            current_bars[bar_index + 1].longitude
            if bar_index < len(current_bars) - 1
            else prev_lng
        )

        mid_lat = (prev_lat + next_lat) / 2.0
        mid_lng = (prev_lng + next_lng) / 2.0

        viable = [
            c
            for c in candidate_pool
            if c.id not in current_ids and c.id not in updated_rejected
        ]
        if not viable:
            raise ValueError(
                "Não há outros bares disponíveis no pool para substituição."
            )

        viable.sort(
            key=lambda c: haversine_distance_meters(
                mid_lat, mid_lng, c.latitude, c.longitude
            )
        )
        replacement = viable[0]

        new_bars = list(current_bars)
        new_bars[bar_index] = replacement

        final_bars, polyline, total_dist, total_dur = (
            await self.compute_route_metrics(origin, new_bars)
        )
        return final_bars, polyline, total_dist, total_dur, updated_rejected


route_engine_service = RouteEngineService()
