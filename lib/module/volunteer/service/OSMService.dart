import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/OSMPlace.dart';

class OSMService {
  static Future<List<OSMPlace>> searchPlaces(String query) async {
    final url = Uri.parse(
        'https://photon.komoot.io/api/?q=$query&limit=5');

    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'Pawhub/1.0 (wongweixin116@gmail.com)', // Identify your app
      },
    );
    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      final List features = data['features'];

      return features.map((e) {
        final props = e['properties'];
        final coords = e['geometry']['coordinates'];

        return OSMPlace(
          displayName: _buildName(props),
          lat: coords[1],  // latitude
          lon: coords[0],  // longitude
        );
      }).toList();
    } else {
      throw Exception('Failed to load places');
    }
  }

  static String _buildName(Map props) {
    return [
      props['name'],
      props['city'],
      props['state'],
      props['country']
    ].where((e) => e != null).join(', ');
  }
}
