import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pawhub/module/volunteer/service/volunteerService.dart';
import 'package:pawhub/core/constants/colors.dart'; // Ensure these paths are correct
import '../../../core/widgets/appDecorations.dart';
import '../model/OSMPlace.dart';
import '../model/event.dart';
import '../service/OSMService.dart';

class AddEventScreen extends StatefulWidget {
  final String? eventId;

  const AddEventScreen({super.key, this.eventId});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isEditMode = false;
  bool _isLoadingEvent = true;

  // Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  final _capacityController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();

  // State
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _category = 'Rescue Activities';

  File? _flyerFile;
  String? _existingFlyerUrl;
  String? _resolvedFlyerPath;

  final TextEditingController _searchController = TextEditingController();

  List<OSMPlace> _suggestions = [];
  OSMPlace? _selectedPlace;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.eventId != null;
    if (_isEditMode) {
      _loadEventData();
    } else {
      _isLoadingEvent = false;
    }
  }

  Future<void> _loadEventData() async {
    try {
      final event = await EventService.getEventById(widget.eventId!);
      if (event != null && mounted) {
        setState(() {
          _titleController.text = event['title'] ?? '';
          _descController.text = event['description'] ?? '';
          _addressController.text = event['address'] ?? '';
          _selectedPlace = OSMPlace(
            displayName: event['address'] ?? '',
            lat: event['latitude'] ?? 0,
            lon: event['longitude'] ?? 0,
          );
          _capacityController.text = event['volunteer_capacity']?.toString() ?? '';
          _category = event['event_category'] ?? 'Rescue Activities';
          _existingFlyerUrl = event['flyer_url'];

          if (event['event_date'] != null) {
            _selectedDate = DateTime.parse(event['event_date']);
          }

          if (event['start_time'] != null) {
            _startTime = parseSupabaseTime(event['start_time']);
            _startTimeController.text = _formatTime(_startTime);
          }

          if (event['end_time'] != null) {
            _endTime = parseSupabaseTime(event['end_time']);
            _endTimeController.text = _formatTime(_endTime);
          }

        });
        if (_existingFlyerUrl != null) await _loadFlyerPath(_existingFlyerUrl!);
        setState(() => _isLoadingEvent = false);
      }
    } catch (e) {
      setState(() => _isLoadingEvent = false);
    }
  }

  TimeOfDay parseSupabaseTime(String time) {
    try {
      // 1. Remove ALL whitespace including invisible Unicode characters like U+202F
      // \s handles standard space, \u200e-\u200f and \u202f handle common hidden marks
      final clean = time.trim().replaceAll(RegExp(r'[\s\u200e\u200f\u202f]'), '');

      // 2. Split by colon
      final parts = clean.split(':');

      if (parts.length >= 2) {
        // 3. Parse hour and minute, ignoring seconds if they exist
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }

      throw const FormatException("Invalid time format");
    } catch (e) {
      debugPrint("Time parsing failed for '$time': $e");
      // Fallback to a default time so the screen still loads
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  Future<void> _onSearchChanged(String value) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 800), () async {
      if (value.isEmpty) {
        setState(() => _suggestions.clear());
        return;
      }

      try {
        final results = await OSMService.searchPlaces(value);

        if (!mounted) return;

        setState(() {
          _suggestions = results;
        });
      } catch (e) {
        print("Search error: $e");
      }
    });
  }


  Future<void> _loadFlyerPath(String filename) async {
    final assetPath = 'assets/images/$filename';
    try {
      await DefaultAssetBundle.of(context).load(assetPath);
      setState(() => _resolvedFlyerPath = assetPath);
    } catch (_) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/flyers/$filename');
      if (await file.exists()) {
        setState(() => _resolvedFlyerPath = file.path);
      }
    }
  }

  bool _isEndTimeValid(TimeOfDay start, TimeOfDay end) {
    double startDouble = start.hour + start.minute / 60.0;
    double endDouble = end.hour + end.minute / 60.0;
    return endDouble > startDouble;
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return "";
    final dt = DateTime(0, 0, 0, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  String _to24h(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';
  }

  ImageProvider? _getCurrentImageProvider() {
    if (_flyerFile != null) return FileImage(_flyerFile!);
    if (_resolvedFlyerPath != null) {
      return _resolvedFlyerPath!.startsWith('assets/')
          ? AssetImage(_resolvedFlyerPath!)
          : FileImage(File(_resolvedFlyerPath!));
    }
    return null;
  }


  // ================= UI COMPONENTS =================
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }

  Widget _buildUploadBox() {
    final provider = _getCurrentImageProvider();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("Event Flyer (Optional)"),
        InkWell(
          onTap: _handleFlyerTap,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: provider != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image(image: provider, fit: BoxFit.cover),
            )
                : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text("Tap to upload flyer", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingEvent) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditMode ? "Edit Event" : "Create Event", style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel("Basic Details"),
              TextFormField(
                controller: _titleController,
                decoration: AppDecorations.outlineInputDecoration(
                  labelText: "Title",
                  hintText: "Enter event title",
                  prefixIcon: Icons.title,
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: AppDecorations.outlineInputDecoration(
                    hintText: "Select Category",
                    labelText: "Category",
                    prefixIcon: Icons.category),
                items: [
                  'Rescue Activities',
                  'Medical Camps',
                  'Community Awareness'
                ]
                    .map((cat) =>
                    DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) => setState(() => _category = val!),
              ),

              const SizedBox(height: 16),

              TextFormField(
                readOnly: true,
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100));
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                decoration: AppDecorations.outlineInputDecoration(
                    hintText: _selectedDate == null
                        ? "Select Date"
                        : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                    labelText: "Event Date",
                    prefixIcon: Icons.calendar_today),
                validator: (_) =>
                _selectedDate == null ? "Date is required" : null,
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startTimeController,
                      readOnly: true,
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: _startTime ?? TimeOfDay.now());
                        if (picked != null) {
                          setState(() {
                            _startTime = picked;
                            _startTimeController.text = _formatTime(picked);
                          });
                        }
                      },
                      decoration: AppDecorations.outlineInputDecoration(
                          hintText: "00:00 AM",
                          labelText: "Start Time",
                          prefixIcon: Icons.access_time),
                      validator: (_) {
                        if (_startTime == null) return "Required";

                        // Check if selected time is in the past
                        if (_selectedDate != null) {
                          final now = DateTime.now();
                          final selectedDT = DateTime(
                            _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
                            _startTime!.hour, _startTime!.minute,
                          );
                          if (selectedDT.isBefore(now)) {
                            return "Time cannot be in the past";
                          }
                        }
                        return null;
                      },
                    )
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      readOnly: true,
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: _startTime ?? TimeOfDay.now());
                        if (picked != null) {
                          setState(() {
                            _endTime = picked;
                            _endTimeController.text = _formatTime(picked);
                          });
                        }
                      },
                      decoration: AppDecorations.outlineInputDecoration(
                          hintText: "00:00 PM",
                          labelText: "End Time",
                          prefixIcon: Icons.update),
                      validator: (_) {
                        if (_endTime == null) return "Required";
                        if (_startTime != null) {
                          final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
                          final endMinutes = _endTime!.hour * 60 + _endTime!.minute;

                          if (endMinutes <= startMinutes) {
                            return "Must be after start time";
                          }

                          // Ensure at least 30 minutes duration
                          if (endMinutes - startMinutes < 30) {
                            return "Duration must be at least 30 mins";
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: AppDecorations.outlineInputDecoration(
                    hintText: "e.g. 50",
                    labelText: "Volunteer Capacity",
                    prefixIcon: Icons.people),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Capacity is required";
                  final val = int.tryParse(v);
                  if (val == null) return "Enter a valid number";
                  if (val <= 0) return "Capacity must be at least 1"; // Added this check
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: AppDecorations.outlineInputDecoration(
                  hintText: "Enter event address",
                  labelText: "Address",
                  prefixIcon: Icons.location_on,
                ),

                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return "Address is required";
                  }
                  if (_selectedPlace == null) {
                    return "Please select a location from the search results";
                  }
                  return null;
                },
                onFieldSubmitted: _onSearchChanged,
                onChanged: (val) {
                  if (_selectedPlace != null) {
                    setState(() => _selectedPlace = null);
                  }
                  _onSearchChanged(val);
                },
              ),

              if (_suggestions.isNotEmpty)
                Container(
                  height: 200,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.builder(
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final place = _suggestions[index];

                      return ListTile(
                        title: Text(
                          place.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedPlace = place;
                            _searchController.text = place.displayName;
                            _suggestions.clear();
                          });
                        },
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: AppDecorations.outlineInputDecoration(
                    hintText: "Describe the event...",
                    labelText: "Description",
                    prefixIcon: Icons.description),
                validator: (v) =>
                (v == null || v.isEmpty) ? "Description is required" : null,
              ),
              const SizedBox(height: 16),
              _buildUploadBox(),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submitForm,
                  child: Text(_isEditMode ? "UPDATE EVENT" : "CREATE EVENT", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _submitForm() async {
    // 1. Trigger the red error messages below the fields
    // This executes the 'validator' logic in all your TextFormFields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. Safely check the Location selection
    // Since search fields aren't always standard form validators, we check this manually
    if (_selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please search and select a location from the list"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. Safety check for Date and Time
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please ensure Date and Time are selected")),
      );
      return;
    }

    // 4. Time Comparison Logic (Final Check)
    final now = DateTime.now();
    final startDT = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    // Warning for events starting very soon
    if (startDT.isAfter(now) && startDT.difference(now).inMinutes < 60) {
      bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Urgent Event"),
          content: const Text("This event starts in less than an hour. Proceed?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Edit")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm")),
          ],
        ),
      );
      if (proceed != true) return;
    }

    // 5. Start the Loading State
    setState(() => _isLoading = true);

    try {
      // Collect data into variables
      final String cleanTitle = _titleController.text.trim();
      final String cleanDesc = _descController.text.trim();
      final String address = _selectedPlace!.displayName;
      final double lat = _selectedPlace!.lat;
      final double lng = _selectedPlace!.lon;
      final int capacity = int.parse(_capacityController.text);

      // Sanitize time strings using regex to remove hidden Unicode characters
      final String startTimeStr = _to24h(_startTime!).replaceAll(RegExp(r'[^\d:]'), '');
      final String endTimeStr = _to24h(_endTime!).replaceAll(RegExp(r'[^\d:]'), '');

      if (_isEditMode) {
        // Logic for updating an existing event
        Map<String, dynamic> updates = {
          'title': cleanTitle,
          'description': cleanDesc,
          'event_category': _category,
          'address': address,
          'latitude': lat,
          'longitude': lng,
          'volunteer_capacity': capacity,
          'event_date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
          'start_time': startTimeStr,
          'end_time': endTimeStr,
        };

        if (_flyerFile != null) {
          final name = await EventService.copyFlyerLocally(_flyerFile, cleanTitle);
          if (name != null) updates['flyer_url'] = name;
        }

        await EventService.updateEvent(widget.eventId!, updates);
      } else {
        // Logic for creating a new event
        final newEvent = EventModel(
          title: cleanTitle,
          eventDate: _selectedDate!,
          description: cleanDesc,
          startTime: startTimeStr,
          endTime: endTimeStr,
          eventCategory: _category,
          address: address,
          latitude: lat,
          longitude: lng,
          volunteerCapacity: capacity,
          flyerFile: _flyerFile,
        );

        await EventService.addEvent(newEvent);
      }

      // Success - Go back
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleFlyerTap() {
    if (_flyerFile != null || _resolvedFlyerPath != null) {
      showModalBottomSheet(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.visibility), title: const Text("View Flyer"), onTap: () { Navigator.pop(context); _openFlyerPreview(); }),
            ListTile(leading: const Icon(Icons.edit), title: const Text("Change Flyer"), onTap: () { Navigator.pop(context); _pickFlyer(); }),
          ],
        ),
      );
    } else { _pickFlyer(); }
  }

  Future<void> _pickFlyer() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _flyerFile = File(picked.path);
        _resolvedFlyerPath = null;
      });
    }
  }

  void _openFlyerPreview() {
    final provider = _getCurrentImageProvider();
    if (provider == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(child: Image(image: provider, fit: BoxFit.contain)),
            Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }
}