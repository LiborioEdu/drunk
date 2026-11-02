import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'ip_location_datasource.dart';

/// Origem técnica da coordenada obtida para o usuário
enum LocationSource {
  gpsHardware,
  ipNetwork,
  fallbackDefault,
}

/// Snapshot da localização do usuário em tempo real (estilo Google Maps)
class UserLocationResult {
  final LatLng coordinates;
  final double? accuracyMeters;
  final double? headingDegrees;
  final LocationSource source;
  final String? suggestedLabel;
  final bool permissionDenied;

  const UserLocationResult({
    required this.coordinates,
    required this.source,
    this.accuracyMeters,
    this.headingDegrees,
    this.suggestedLabel,
    this.permissionDenied = false,
  });
}

/// Serviço unificado de Localização do Usuário:
/// 1. Tenta GPS de alta precisão (`Geolocator` — Android, iOS, Browser HTML5 `localhost`/`https`).
/// 2. Tenta última posição conhecida / precisão média se indoor.
/// 3. Faz fallback automático para Geolocalização real por IP (`BigDataCloud` / `GeoJS` / `ipwho.is`).
class UserLocationService {
  final IpLocationDatasource _ipDatasource;

  UserLocationService({IpLocationDatasource? ipDatasource})
      : _ipDatasource = ipDatasource ?? IpLocationDatasource();

  static const LatLng defaultCoordinates = LatLng(-23.5535, -46.6575);

  /// Obtém a localização atual do usuário com cascata GPS -> IP -> Fallback
  Future<UserLocationResult> obtainCurrentLocation() async {
    bool wasPermissionDenied = false;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          wasPermissionDenied = true;
        } else {
          final gpsPos = await _tryFetchGeolocatorPosition();
          if (gpsPos != null) {
            return UserLocationResult(
              coordinates: LatLng(gpsPos.latitude, gpsPos.longitude),
              accuracyMeters:
                  gpsPos.accuracy.isFinite && gpsPos.accuracy > 0
                      ? gpsPos.accuracy
                      : 12.0,
              headingDegrees:
                  gpsPos.heading.isFinite && gpsPos.heading >= 0
                      ? gpsPos.heading
                      : null,
              source: LocationSource.gpsHardware,
            );
          }
        }
      }
    } catch (_) {
      // No Linux Desktop sem GeoClue ou Web em origem não-HTTPS/não-localhost, cai para IP real
    }

    // Fallback inteligente por IP (descobre a cidade/região real do usuário)
    final ipResult = await _ipDatasource.fetchIpLocation();
    if (ipResult != null) {
      return UserLocationResult(
        coordinates: ipResult.coordinates,
        accuracyMeters: 950.0,
        source: LocationSource.ipNetwork,
        suggestedLabel: ipResult.label,
        permissionDenied: wasPermissionDenied,
      );
    }

    return UserLocationResult(
      coordinates: defaultCoordinates,
      source: LocationSource.fallbackDefault,
      suggestedLabel: 'Rua Augusta • Consolação, SP',
      permissionDenied: wasPermissionDenied,
    );
  }

  Future<Position?> _tryFetchGeolocatorPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 7),
        ),
      );
    } catch (_) {
      // Tenta precisão média rápida (ex.: Wi-Fi indoor em notebooks/celulares)
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {
        if (!kIsWeb) {
          try {
            return await Geolocator.getLastKnownPosition();
          } catch (_) {
            return null;
          }
        }
        return null;
      }
    }
  }

  /// Stream contínuo da posição GPS real do usuário para atualizar o ponto azul/ciano pulsante no mapa
  Stream<UserLocationResult> watchLivePosition() async* {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      await for (final pos
          in Geolocator.getPositionStream(locationSettings: settings)) {
        yield UserLocationResult(
          coordinates: LatLng(pos.latitude, pos.longitude),
          accuracyMeters:
              pos.accuracy.isFinite && pos.accuracy > 0 ? pos.accuracy : 10.0,
          headingDegrees:
              pos.heading.isFinite && pos.heading >= 0 ? pos.heading : null,
          source: LocationSource.gpsHardware,
        );
      }
    } catch (_) {
      return;
    }
  }
}
