class OSMPlace {
  final String displayName;
  final double lat;
  final double lon;

  OSMPlace({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory OSMPlace.fromJson(Map<String, dynamic> json) {
    return OSMPlace(
      displayName: json['display_name'],
      lat: double.parse(json['lat']),
      lon: double.parse(json['lon']),
    );
  }
}
