import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ─────────────────────────────────────────────────────────────
/// MapStyles — Thème de carte professionnel pour l'app pharmacie
/// ─────────────────────────────────────────────────────────────
///
/// Ce fichier centralise tous les styles de carte utilisés dans l'app :
/// - Plusieurs styles Mapbox (Streets, Light, Dark, Satellite, Navigation)
/// - Bascule automatique jour/nuit (clair/sombre) selon le thème système
/// - Fallback CartoDB (sans clé API) si Mapbox est indisponible
/// - Fallback OSM standard en dernier recours
/// - Attribution correcte et cliquable (obligatoire pour Mapbox)
///
/// Pour changer le style visuel de l'app, il suffit de modifier
/// [MapStyles.defaultVariant] ci-dessous, ou de choisir un style
/// personnalisé créé dans Mapbox Studio (voir [MapStyleVariant.custom]).
class MapStyles {
  MapStyles._();

  // ─────────────────────────────────────────────
  // Style par défaut de l'application
  // ─────────────────────────────────────────────
  /// Style utilisé partout où aucun style spécifique n'est demandé.
  /// `streets` affiche les noms de quartiers, rues et établissements
  /// (pharmacies, commerces...) — c'est le rendu le plus lisible et
  /// professionnel pour une app de géolocalisation.
  static const MapStyleVariant defaultVariant = MapStyleVariant.streets;

  /// Si un style personnalisé a été créé dans Mapbox Studio
  /// (Styles > ton style > Share/Develop > Style URL), colle son ID ici,
  /// au format "username/styleid" tel qu'il apparaît dans l'URL du studio.
  /// Exemple : 'jdoe/clxyz1234000001qk7f3g8h2a'
  static const String customStyleId = '';

  // ─────────────────────────────────────────────
  // Token Mapbox
  // ─────────────────────────────────────────────
  /// Chargé depuis le fichier .env (clé MAPBOX_ACCESS_TOKEN).
  /// Utilise un token PUBLIC (commence par "pk.") — jamais un token secret
  /// ("sk.") côté client.
  static String get _mapboxAccessToken =>
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  /// Permet de vérifier si un token Mapbox est bien configuré,
  /// pour basculer proprement sur le fallback si besoin.
  static bool get isMapboxConfigured => _mapboxAccessToken.trim().isNotEmpty;

  // ─────────────────────────────────────────────
  // Résolution des IDs de style Mapbox
  // ─────────────────────────────────────────────
  static String _styleIdFor(MapStyleVariant variant) {
    switch (variant) {
      case MapStyleVariant.streets:
        return 'mapbox/streets-v12';
      case MapStyleVariant.light:
        return 'mapbox/light-v11';
      case MapStyleVariant.dark:
        return 'mapbox/dark-v11';
      case MapStyleVariant.outdoors:
        return 'mapbox/outdoors-v12';
      case MapStyleVariant.satelliteStreets:
        return 'mapbox/satellite-streets-v12';
      case MapStyleVariant.navigationDay:
        return 'mapbox/navigation-day-v1';
      case MapStyleVariant.navigationNight:
        return 'mapbox/navigation-night-v1';
      case MapStyleVariant.custom:
        return customStyleId.isNotEmpty ? customStyleId : 'mapbox/streets-v12';
    }
  }

  /// URL de tuiles raster Mapbox (haute résolution @2x) pour un style donné.
  static String mapboxUrlFor(MapStyleVariant variant) {
    final styleId = _styleIdFor(variant);
    return 'https://api.mapbox.com/styles/v1/$styleId/tiles/256/{z}/{x}/{y}@2x'
        '?access_token=$_mapboxAccessToken';
  }

  /// URL Mapbox du style par défaut de l'app.
  /// Conservé pour compatibilité avec le code existant (MapStyles.mapboxUrl).
  static String get mapboxUrl => mapboxUrlFor(defaultVariant);

  /// Choisit automatiquement un style clair ou sombre selon le thème
  /// système de l'utilisateur — un vrai plus "pro" sans configuration.
  static MapStyleVariant adaptiveVariant(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.dark
        ? MapStyleVariant.dark
        : MapStyleVariant.light;
  }

  /// URL Mapbox adaptée au thème clair/sombre du téléphone.
  static String adaptiveMapboxUrl(BuildContext context) =>
      mapboxUrlFor(adaptiveVariant(context));

  // ─────────────────────────────────────────────
  // Fallbacks sans clé API (si Mapbox indisponible)
  // ─────────────────────────────────────────────

  /// CartoDB Voyager — style moderne et lisible, bon fallback "pro".
  static const String cartoVoyagerUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';

  /// CartoDB Positron — minimaliste et clair.
  static const String cartoPositronUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';

  /// CartoDB Dark Matter — sombre.
  static const String cartoDarkUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';

  /// Sous-domaines pour les tuiles CartoDB (répartition de charge).
  static const List<String> cartoSubdomains = ['a', 'b', 'c', 'd'];

  /// Tuiles OpenStreetMap standard — dernier recours, sans clé API.
  static const String osmStandardUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Fallback recommandé : CartoDB Voyager en priorité (plus soigné),
  /// OSM standard en tout dernier recours.
  static String get recommendedFallbackUrl => cartoVoyagerUrl;

  // ─────────────────────────────────────────────
  // Attribution (obligatoire pour Mapbox + OSM/Carto)
  // ─────────────────────────────────────────────
  /// Attribution correcte et cliquable, conforme aux conditions
  /// d'utilisation de Mapbox (lien vers mapbox.com/about/maps) et OSM.
  static const List<String> attributionUrls = <String>[
    'https://www.mapbox.com/about/maps/',
    'https://www.openstreetmap.org/copyright',
  ];

  // ─────────────────────────────────────────────
  // Style vectoriel sombre custom (exemple, non utilisé par défaut)
  // ─────────────────────────────────────────────
  /// Exemple de style JSON minimal (utile si migration vers un moteur
  /// de rendu vectoriel plus tard, ex: maplibre_gl).
  static const String darkYangoStyle = '''
{
  "version": 8,
  "sources": {
    "osm": {
      "type": "raster",
      "tiles": ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
      "tileSize": 256
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": { "background-color": "#0F172A" }
    },
    {
      "id": "osm-tiles",
      "type": "raster",
      "source": "osm",
      "minzoom": 0,
      "maxzoom": 19,
      "paint": { "raster-opacity": 0.7 }
    }
  ]
}
''';
}

/// Styles Mapbox disponibles dans l'app.
enum MapStyleVariant {
  streets,
  light,
  dark,
  outdoors,
  satelliteStreets,
  navigationDay,
  navigationNight,

  /// Style créé sur mesure dans Mapbox Studio — voir [MapStyles.customStyleId].
  custom,
}