import 'package:flutter/foundation.dart';

/// API base URL. Set at build time with `--dart-define=API_URL=https://api.example/`.
/// Defaults: the web build talks to `/api/` on its own origin (served behind the same nginx);
/// the Android emulator reaches the host machine at 10.0.2.2; desktop/iOS simulator use localhost.
Uri apiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return Uri.parse(fromEnv.endsWith('/') ? fromEnv : '$fromEnv/');
  if (kIsWeb) return Uri.base.resolve('/api/');
  if (defaultTargetPlatform == TargetPlatform.android) return Uri.parse('http://10.0.2.2:3000/');
  return Uri.parse('http://localhost:3000/');
}

/// Demo / test builds (`--dart-define=DEMO=true`): the server address can be changed in the app,
/// so one APK works against any computer running `docker compose`.
const demoBuild = bool.fromEnvironment('DEMO');

/// Map tiles (raster `{z}/{x}/{y}` template). OpenStreetMap needs no key and is fine for the pilot;
/// its policy forbids heavy use, so set a provider with a key before full launch, e.g.
/// `--dart-define=MAP_TILES=https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=…`.
/// An empty value (an unset CI secret) keeps the default.
const mapTilesUrl = _mapTiles == '' ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png' : _mapTiles;
const _mapTiles = String.fromEnvironment('MAP_TILES');

/// Credit shown on the map; must match the provider (OpenStreetMap requires it).
const mapAttribution = _mapAttribution == '' ? '© OpenStreetMap contributors' : _mapAttribution;
const _mapAttribution = String.fromEnvironment('MAP_ATTRIBUTION');
