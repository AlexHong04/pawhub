import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/module/volunteer/service/volunteerService.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../history/my_events.dart';

class EventDetailsPage extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailsPage({super.key, required this.event});

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  bool _isJoined = false;
  bool _isLoadingStatus = true;
  String _distanceText = "Calculating distance...";
  LatLng? _eventLocation;
  bool _mapInitialized = false;
  String _userId = "";
  bool _isUserLoaded = true;
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = true;
  String _weatherError = "";

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    _loadUser();

    try {
      final double lat = (widget.event['latitude'] as num?)?.toDouble() ?? 0.0;
      final double lng = (widget.event['longitude'] as num?)?.toDouble() ?? 0.0;

      print("✅ Event coordinates - Lat: $lat, Lng: $lng");

      if (lat != 0.0 && lng != 0.0) {
        _eventLocation = LatLng(lat, lng);
        _mapInitialized = true;
        _calculateUserDistance();
      } else {
        setState(() {
          _distanceText = "Location not available";
          _mapInitialized = false;
        });
      }
    } catch (e) {
      print("❌ Error initializing location: $e");
      setState(() {
        _distanceText = "Error loading location";
        _mapInitialized = false;
      });
    }
  }

  Future<void> _fetchWeather() async {
    try {
      final double lat = (widget.event['latitude'] as num?)?.toDouble() ?? 0.0;
      final double lng = (widget.event['longitude'] as num?)?.toDouble() ?? 0.0;

      if (lat == 0.0 || lng == 0.0) {
        setState(() {
          _isLoadingWeather = false;
          _weatherError = "Location not available";
        });
        return;
      }

      // Using your active key
      const String apiKey = 'dbfdb87ff70cb0175ee9cf4ee0e29018';
      final String url =
          'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lng&appid=$apiKey&units=metric';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Get the date string: 2026-04-12
        final String eventDateStr = widget.event['event_date'] ?? '';

        // Attempt to find the specific day in the list
        final weatherForDay = _getWeatherForDate(data, eventDateStr);

        if (mounted) {
          setState(() {
            _weatherData = weatherForDay;
            _isLoadingWeather = false;
            _weatherError = (weatherForDay == null) ? "No data found" : "";
          });
        }
      } else {
        print("❌ Weather API error: ${response.statusCode} - ${response.body}");
        setState(() {
          _isLoadingWeather = false;
          _weatherError = "API Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      print("❌ Weather Catch Error: $e");
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
          _weatherError = "Connection failed";
        });
      }
    }
  }

  Map<String, dynamic>? _getWeatherForDate(Map<String, dynamic> data, String eventDate) {
    try {
      final list = data['list'] as List?;
      if (list == null || list.isEmpty) return null;

      // Parse '2026-04-12' into a DateTime object
      DateTime eventDateTime = DateTime.parse(eventDate);

      // Filter to find the forecast for that specific day
      for (var forecast in list) {
        // API provides 'dt' in seconds
        final dt = DateTime.fromMillisecondsSinceEpoch((forecast['dt'] as int) * 1000);

        // Compare ONLY year, month, and day (ignore hours/minutes)
        if (dt.year == eventDateTime.year &&
            dt.month == eventDateTime.month &&
            dt.day == eventDateTime.day) {
          return forecast;
        }
      }

      return list[0];
    } catch (e) {
      return null;
    }
  }
  IconData _getWeatherIcon(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'clear':
      case 'sunny':
        return Icons.wb_sunny;
      case 'clouds':
      case 'cloudy':
        return Icons.wb_cloudy;
      case 'rain':
      case 'rainy':
        return Icons.cloud_queue;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      case 'mist':
      case 'fog':
        return Icons.cloud;
      default:
        return Icons.wb_sunny;
    }
  }

  // ✅ NEW: Get weather color
  Color _getWeatherColor(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'clear':
      case 'sunny':
        return Colors.orange;
      case 'clouds':
      case 'cloudy':
        return Colors.grey;
      case 'rain':
      case 'rainy':
        return Colors.blue;
      case 'thunderstorm':
        return Colors.purple;
      case 'snow':
        return Colors.cyan;
      default:
        return Colors.orange;
    }
  }

  Future<void> _loadUser() async {
    final userId = await EventService.getCurrentUserId();
    if (!mounted) return;
    setState(() {
      _userId = userId;
      _isUserLoaded = true;
    });

    await _checkJoinStatus();
  }

  Future<bool> _assetImageExists(String filename) async {
    try {
      await DefaultAssetBundle.of(context).load('assets/images/$filename');
      return true;
    } catch (e) {
      print("❌ Asset not found: $e");
      return false;
    }
  }

  Future<String?> _getLocalImagePath(String filename, String folderName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/$folderName/$filename';
      final file = File(filePath);

      if (await file.exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _calculateUserDistance() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        try {
          Position userPos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 5));

          if (_eventLocation != null) {
            double distanceInMeters = Geolocator.distanceBetween(
              userPos.latitude,
              userPos.longitude,
              _eventLocation!.latitude,
              _eventLocation!.longitude,
            );

            if (mounted) {
              setState(() {
                _distanceText =
                "${(distanceInMeters / 1000).toStringAsFixed(1)} km away";
              });
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() => _distanceText = "Distance unavailable");
          }
        }
      } else {
        if (mounted) {
          setState(() => _distanceText = "Location permission denied");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _distanceText = "Distance unavailable");
      }
    }
  }

  Future<void> _openMapApp() async {
    try {
      if (_eventLocation == null || _eventLocation!.latitude == 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid coordinates")),
        );
        return;
      }

      final double lat = _eventLocation!.latitude;
      final double lng = _eventLocation!.longitude;

      final Uri geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng");
      final Uri webUri =
      Uri.parse("https://www.google.com/maps?q=$lat,$lng");

      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not open map")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open map")),
        );
      }
    }
  }

  Future<void> _checkJoinStatus() async {
    try {
      if (!_isUserLoaded || _userId.isEmpty || _userId == "GUEST") {
        if (mounted) {
          setState(() {
            _isJoined = false;
            _isLoadingStatus = false;
          });
        }
        return;
      }

      final status = await EventService.checkIfUserJoined(
        widget.event['event_id'].toString(),
        _userId,
      );

      if (mounted) {
        setState(() {
          _isJoined = status;
          _isLoadingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStatus = false);
      }
    }
  }

  void _showParticipantsPopup() {
    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(
            child: Text("Volunteers Joined",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: EventService.getEventParticipants(
                  widget.event['event_id'].toString()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                  );
                }

                if (snapshot.hasError) {
                  return Text("Error: ${snapshot.error}");
                }

                final participants = snapshot.data ?? [];
                if (participants.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("No one has joined yet.",
                        textAlign: TextAlign.center),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight:
                      MediaQuery.of(context).size.height * 0.4),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: participants.length,
                    itemBuilder: (context, i) {
                      final userData = participants[i]['User'];
                      if (userData == null) return const SizedBox.shrink();

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                          AppColors.primary.withOpacity(0.1),
                          backgroundImage: (userData['avatar_url'] !=
                              null &&
                              userData['avatar_url'].isNotEmpty)
                              ? NetworkImage(userData['avatar_url'])
                              : null,
                          child: userData['avatar_url'] == null
                              ? const Icon(Icons.person,
                              color: AppColors.primary)
                              : null,
                        ),
                        title: Text(
                            userData['name'] ?? 'Volunteer',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close",
                  style: TextStyle(color: AppColors.primary)),
            )
          ],
        ),
      );
    } catch (e) {
    }
  }

  Widget _buildWeatherWidget() {
    if (_isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 12),
            Text("Loading weather...",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    if (_weatherError.isNotEmpty || _weatherData == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Text(_weatherError,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    // Extract weather data
    final main = _weatherData?['main'] ?? {};
    final weather = (_weatherData?['weather'] as List?)?[0] ?? {};
    final temp = main['temp']?.toStringAsFixed(1) ?? 'N/A';
    final condition = weather['main'] ?? 'Clear';
    final humidity = main['humidity'] ?? 0;
    final windSpeed = _weatherData?['wind']?['speed']?.toStringAsFixed(1) ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getWeatherColor(condition).withOpacity(0.1),
            _getWeatherColor(condition).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getWeatherColor(condition).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getWeatherIcon(condition),
                    color: _getWeatherColor(condition),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        condition,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$temp°C',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Icon(
                Icons.info_outline,
                color: _getWeatherColor(condition),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildWeatherDetail(
                  "💧", "Humidity", "$humidity%"),
              _buildWeatherDetail(
                  "💨", "Wind", "$windSpeed m/s"),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "📢 Remember to dress appropriately for the weather!",
              style: TextStyle(
                fontSize: 12,
                color: _getWeatherColor(condition),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Build weather detail item
  Widget _buildWeatherDetail(String icon, String label, String value) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Event Details"),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailImage(widget.event['flyer_url']),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.event['title'] ?? 'Event Title',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // ✅ NEW: Weather widget
                  _buildWeatherWidget(),
                  const SizedBox(height: 20),

                  const Text("VOLUNTEERS",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  _buildVolunteerStack(),

                  const Divider(height: 40),
                  const Text("About Event",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      widget.event['description'] ??
                          'No description provided.',
                      style: const TextStyle(
                          color: AppColors.textSecondary, height: 1.5)),

                  const SizedBox(height: 25),
                  const Text("Location",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(widget.event['address'] ??
                      'Location details not available.'),
                  const SizedBox(height: 12),

                  if (_mapInitialized)
                    _buildInteractiveMap()
                  else
                    _buildLocationUnavailable(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomAction(),
    );
  }

  Widget _buildInteractiveMap() {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.directions_car,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _distanceText,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _openMapApp,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                color: Colors.grey[100],
              ),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                    target: _eventLocation!, zoom: 14),
                zoomControlsEnabled: false,
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                myLocationButtonEnabled: false,
                markers: {
                  Marker(
                      markerId: const MarkerId('event_loc'),
                      position: _eventLocation!),
                },
                onMapCreated: (controller) {
                  print("✅ Google Map created successfully");
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _openMapApp,
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text("Open in Navigation App"),
        )
      ],
    );
  }

  Widget _buildLocationUnavailable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(15),
        color: Colors.grey[50],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _distanceText,
              style:
              const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolunteerStack() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: EventService.getEventParticipants(
          widget.event['event_id'].toString()),
      builder: (context, snapshot) {
        final participants = snapshot.data ?? [];

        return InkWell(
          onTap: _showParticipantsPopup,
          child: Row(
            children: [
              SizedBox(
                height: 40,
                width: 150,
                child: Stack(
                  children: List.generate(
                    participants.length > 3 ? 4 : participants.length,
                        (index) {
                      bool isMore = index == 3;
                      final user = isMore
                          ? null
                          : participants[index]['User'];

                      return Positioned(
                        left: index * 28.0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: isMore
                                ? Colors.grey[300]
                                : AppColors.primary,
                            backgroundImage: (user != null &&
                                user['avatar_url'] != null)
                                ? NetworkImage(user['avatar_url'])
                                : null,
                            child: isMore
                                ? const Icon(Icons.more_horiz,
                                color: Colors.black54)
                                : (user != null &&
                                user['avatar_url'] == null)
                                ? const Icon(Icons.person,
                                color: Colors.white, size: 20)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailImage(String? filename) {
    if (filename == null || filename.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.image, size: 40, color: Colors.grey),
      );
    }

    if (filename.startsWith('http')) {
      return Center(
        child: Container(
          margin: const EdgeInsets.only(top: 20, bottom: 10),
          width: MediaQuery.of(context).size.width * 0.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                blurRadius: 5,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              filename,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print("❌ Network image error: $error");
                return _buildPlaceholder();
              },
            ),
          ),
        ),
      );
    }

    return FutureBuilder<bool>(
      future: _assetImageExists(filename),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          print("📦 Loading flyer from assets: assets/images/$filename");
          return Center(
            child: Container(
              margin: const EdgeInsets.only(top: 20, bottom: 10),
              width: MediaQuery.of(context).size.width * 0.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 5,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.asset(
                  'assets/images/$filename',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print("❌ Asset image error: $error");
                    return _buildPlaceholder();
                  },
                ),
              ),
            ),
          );
        }

        return FutureBuilder<String?>(
          future: _getLocalImagePath(filename, 'flyers'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                margin: const EdgeInsets.all(20),
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              print("💾 Loading flyer from local storage: ${snapshot.data}");
              return Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 20, bottom: 10),
                  width: MediaQuery.of(context).size.width * 0.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 5,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      File(snapshot.data!),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        print("❌ File image error: $error");
                        return _buildPlaceholder();
                      },
                    ),
                  ),
                ),
              );
            }

            print("❌ Flyer image not found: $filename");
            return _buildPlaceholder();
          },
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
              top: BorderSide(color: Colors.grey.shade200))),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isJoined ? Colors.grey : AppColors.primary,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: (_isJoined || _isLoadingStatus)
            ? null
            : () async {
          try {
            setState(() => _isLoadingStatus = true);

            bool success = await EventService.joinEvent(
              widget.event['event_id'].toString(),
              _userId,
            );

            if (mounted) {
              setState(() {
                _isJoined = success;
                _isLoadingStatus = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success
                      ? "Application Successful!"
                      : "Failed to join event."),
                  backgroundColor:
                  success ? Colors.green : Colors.red,
                  duration: const Duration(seconds: 5),
                  action: success
                      ? SnackBarAction(
                    label: "VIEW MY EVENT",
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MyEventsPage(userId: _userId),
                        ),
                      );
                    },
                  )
                      : null,
                ),
              );
            }
          } catch (e) {
            print("❌ Error in button action: $e");
            if (mounted) {
              setState(() => _isLoadingStatus = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("An error occurred"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        child: _isLoadingStatus
            ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
            : Text(_isJoined ? "Already Applied" : "Apply Now",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}