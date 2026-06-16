/// Professional map tile styles for the pharmacy app.
class MapStyles {
  /// CartoDB Voyager – clean, modern map style ideal for healthcare apps.
  static const String cartoVoyagerUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';

  /// CartoDB Positron – light minimalist style.
  static const String cartoPositronUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';

  /// CartoDB Dark Matter – dark mode style.
  static const String cartoDarkUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';

  /// Standard OpenStreetMap tiles (fallback).
  static const String osmStandardUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Subdomains for CartoDB tiles.
  static const List<String> cartoSubdomains = ['a', 'b', 'c', 'd'];

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
      "paint": {
        "background-color": "#0F172A"
      }
    },
    {
      "id": "osm-tiles",
      "type": "raster",
      "source": "osm",
      "minzoom": 0,
      "maxzoom": 19,
      "paint": {
        "raster-opacity": 0.7
      }
    }
  ]
}
''';
}
