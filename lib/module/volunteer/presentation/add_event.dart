import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pawhub/module/volunteer/service/volunteerService.dart';
import 'package:pawhub/core/constants/colors.dart';
import '../../../core/utils/event_draft_store.dart';
import '../../../core/utils/local_file_service.dart';
import '../../../core/widgets/appDecorations.dart';
import '../model/OSMPlace.dart';
import '../model/event.dart';
import '../service/OSMService.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _showFlyerError = false;

  // Flyer state (Supabase URL + optional new local file)
  File? _flyerFile;
  String? _existingFlyerUrl;

  List<OSMPlace> _suggestions = [];
  OSMPlace? _selectedPlace;
  Timer? _debounce;
  static const String _draftImageKey = 'event_draft_flyer';
  bool _isRestoringDraft = false;
  bool _draftListenersAttached = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.eventId != null;

    if (_isEditMode) {
      _loadEventData();
    } else {
      _isLoadingEvent = false;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _tryRestoreDraft();
        _attachDraftListeners();
      });
    }
  }

  void _attachDraftListeners() {
    if (_draftListenersAttached) return;
    _draftListenersAttached = true;

    _titleController.addListener(_saveDraftSafely);
    _descController.addListener(_saveDraftSafely);
    _addressController.addListener(_saveDraftSafely);
    _capacityController.addListener(_saveDraftSafely);
  }

  Future<void> _tryRestoreDraft() async {
    if (_isEditMode) return;

    final draft = await EventDraftStore.read();
    if (draft == null || draft.isEmpty) return;

    // Check if the draft actually has any text typed into it
    bool hasActualData = draft.values.any((value) =>
    value != null && value.toString().trim().isNotEmpty);

    if (!hasActualData) {
      // If it's just empty strings, silently clear it
      await _clearDraftAll();
      return;
    }

    if (!mounted) return;
    final restore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore draft?'),
        content: const Text('We found an unsaved event draft. Do you want to continue editing it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (restore == true) {
      _isRestoringDraft = true;
      try {
        _titleController.text = draft['title'] ?? '';
        _descController.text = draft['description'] ?? '';
        _addressController.text = draft['address'] ?? '';
        _capacityController.text = draft['capacity']?.toString() ?? '';
        _category = draft['category'] ?? 'Rescue Activities';

        final dateStr = draft['event_date'] as String?;
        if (dateStr != null && dateStr.isNotEmpty) {
          _selectedDate = DateTime.tryParse(dateStr);
        }

        final start = draft['start_time'] as String?;
        if (start != null && start.isNotEmpty) {
          _startTime = parseSupabaseTime(start);
          _startTimeController.text = _formatTime(_startTime);
        }

        final end = draft['end_time'] as String?;
        if (end != null && end.isNotEmpty) {
          _endTime = parseSupabaseTime(end);
          _endTimeController.text = _formatTime(_endTime);
        }

        final lat = (draft['lat'] as num?)?.toDouble();
        final lon = (draft['lon'] as num?)?.toDouble();
        final displayName = draft['selected_place_name'] as String?;
        if (lat != null && lon != null && displayName != null && displayName.isNotEmpty) {
          _selectedPlace = OSMPlace(displayName: displayName, lat: lat, lon: lon);
        }

        // Restore flyer file from local metadata safely
        final localFlyer = await LocalFileService.loadSavedImage(_draftImageKey);
        if (localFlyer != null && await localFlyer.exists()) {
          if (await localFlyer.length() > 0) {
            _flyerFile = localFlyer;
          } else {
            // Delete corrupted 0-byte file
            await localFlyer.delete();
          }
        }

        if (mounted) setState(() {});
      } finally {
        _isRestoringDraft = false;
      }
    } else {
      // user chose discard
      await _clearDraftAll();
    }
  }

  Future<void> _clearDraftAll() async {
    await EventDraftStore.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftImageKey);

    // Optional: remove local draft image file too
    final localFile = await LocalFileService.loadSavedImage(_draftImageKey);
    if (localFile != null && await localFile.exists()) {
      await localFile.delete();
    }
  }

  Future<void> _saveDraftSafely() async {
    if (_isEditMode || _isRestoringDraft) return;

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'address': _addressController.text.trim(),
      'capacity': _capacityController.text.trim(),
      'category': _category,
      'event_date': _selectedDate?.toIso8601String(),
      'start_time': _startTime != null ? _to24h(_startTime!) : null,
      'end_time': _endTime != null ? _to24h(_endTime!) : null,
      'selected_place_name': _selectedPlace?.displayName,
      'lat': _selectedPlace?.lat,
      'lon': _selectedPlace?.lon,
    };

    await EventDraftStore.save(data);
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
            lat: (event['latitude'] ?? 0).toDouble(),
            lon: (event['longitude'] ?? 0).toDouble(),
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
      }
    } catch (e) {
      debugPrint("Load event error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingEvent = false);
    }
  }

  TimeOfDay parseSupabaseTime(String time) {
    try {
      final clean = time.trim().replaceAll(RegExp(r'[\s\u200e\u200f\u202f]'), '');
      final parts = clean.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
      throw const FormatException("Invalid time format");
    } catch (e) {
      debugPrint("Time parsing failed for '$time': $e");
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  Future<void> _onSearchChanged(String value) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 800), () async {
      if (value.isEmpty) {
        if (mounted) setState(() => _suggestions.clear());
        return;
      }

      try {
        final results = await OSMService.searchPlaces(value);
        if (!mounted) return;
        setState(() => _suggestions = results);
      } catch (e) {
        debugPrint("Search error: $e");
      }
    });
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return "";
    final dt = DateTime(0, 1, 1, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  String _to24h(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';
  }

  // ================= UI COMPONENTS =================

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildUploadBox() {
    final hasLocal = _flyerFile != null;
    final hasRemote = _existingFlyerUrl != null && _existingFlyerUrl!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("Event Flyer *"),
        InkWell(
          onTap: _handleFlyerTap,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showFlyerError ? Colors.red.shade700 : Colors.grey[300]!,
                width: _showFlyerError ? 1.5 : 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasLocal
                  ? Image.file(
                _flyerFile!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text("Corrupted image", style: TextStyle(color: Colors.grey)),
                    ],
                  );
                },
              )
                  : hasRemote
                  ? Image.network(
                _existingFlyerUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text("Unable to load flyer", style: TextStyle(color: Colors.grey)),
                  ],
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
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
        ),
        if (_showFlyerError)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0),
            child: Text(
              "Flyer image is required",
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingEvent) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEditMode ? "Edit Event" : "Create Event",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _category,
                decoration: AppDecorations.outlineInputDecoration(
                  hintText: "Select Category",
                  labelText: "Category",
                  prefixIcon: Icons.category,
                ),
                items: ['Rescue Activities', 'Medical Camps', 'Community Awareness']
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
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
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                decoration: AppDecorations.outlineInputDecoration(
                  hintText: _selectedDate == null
                      ? "Select Date"
                      : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                  labelText: "Event Date",
                  prefixIcon: Icons.calendar_today,
                ),
                validator: (_) => _selectedDate == null ? "Date is required" : null,
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
                          initialTime: _startTime ?? TimeOfDay.now(),
                        );
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
                        prefixIcon: Icons.access_time,
                      ),
                      validator: (_) {
                        if (_startTime == null) return "Required";

                        if (_selectedDate != null) {
                          final now = DateTime.now();
                          final selectedDT = DateTime(
                            _selectedDate!.year,
                            _selectedDate!.month,
                            _selectedDate!.day,
                            _startTime!.hour,
                            _startTime!.minute,
                          );
                          if (selectedDT.isBefore(now)) return "Cannot be in past";
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      readOnly: true,
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
                        );
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
                        prefixIcon: Icons.update,
                      ),
                      validator: (_) {
                        if (_endTime == null) return "Required";
                        if (_startTime != null) {
                          final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
                          final endMinutes = _endTime!.hour * 60 + _endTime!.minute;

                          if (endMinutes <= startMinutes) return "Must be after start";
                          if (endMinutes - startMinutes < 30) return "Min 30 mins";
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
                  prefixIcon: Icons.people,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Capacity is required";
                  final val = int.tryParse(v);
                  if (val == null) return "Enter a valid number";
                  if (val <= 0) return "Capacity must be at least 1";
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
                  if (v == null || v.isEmpty) return "Address is required";
                  if (_selectedPlace == null) {
                    return "Please select a location from the search results";
                  }
                  return null;
                },
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
                            _addressController.text = place.displayName;
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
                  prefixIcon: Icons.description,
                ),
                validator: (v) => (v == null || v.isEmpty) ? "Description is required" : null,
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
                  onPressed: _isLoading ? null : _submitForm,
                  child: Text(
                    _isEditMode ? "UPDATE EVENT" : "CREATE EVENT",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
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
    if (_isLoading) return;

    final hasFlyer = _flyerFile != null || (_existingFlyerUrl != null && _existingFlyerUrl!.trim().isNotEmpty);

    if (!hasFlyer) {
      setState(() => _showFlyerError = true);
    } else {
      setState(() => _showFlyerError = false);
    }

    if (!_formKey.currentState!.validate() || !hasFlyer) {
      if (!hasFlyer) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Event Flyer is required"), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (_selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please search and select a location from the list"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please ensure Date and Time are selected")),
      );
      return;
    }

    final now = DateTime.now();
    final startDT = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );

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

    setState(() => _isLoading = true);

    try {
      final String cleanTitle = _titleController.text.trim();
      final String cleanDesc = _descController.text.trim();
      final String address = _selectedPlace!.displayName;
      final double lat = _selectedPlace!.lat;
      final double lng = _selectedPlace!.lon;
      final int capacity = int.parse(_capacityController.text);

      final String startTimeStr = _to24h(_startTime!).replaceAll(RegExp(r'[^\d:]'), '');
      final String endTimeStr = _to24h(_endTime!).replaceAll(RegExp(r'[^\d:]'), '');

      bool ok;
      if (_isEditMode) {
        final updates = <String, dynamic>{
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
          'flyerFile': _flyerFile, // handled by EventService.updateEvent
        };

        ok = await EventService.updateEvent(widget.eventId!, updates);
      } else {
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

        ok = await EventService.addEvent(newEvent);
        if (!_isEditMode) {
          await _clearDraftAll();
        }
      }

      if (!ok) {
        throw Exception('Failed to save event');
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleFlyerTap() {
    final hasAnyImage =
        _flyerFile != null || (_existingFlyerUrl != null && _existingFlyerUrl!.trim().isNotEmpty);

    if (hasAnyImage) {
      showModalBottomSheet(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text("View Flyer"),
              onTap: () {
                Navigator.pop(context);
                _openFlyerPreview();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Change Flyer"),
              onTap: () {
                Navigator.pop(context);
                _pickFlyer();
              },
            ),
          ],
        ),
      );
    } else {
      _pickFlyer();
    }
  }

  Future<void> _pickFlyer() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);

      // Persist image into app documents folder for draft
      await LocalFileService.storeImageLocally(
        'event_draft',
        file.path,
        _draftImageKey,
        'event_drafts',
        index: 0,
      );

      setState(() {
        _flyerFile = file;
        _showFlyerError = false;
      });

      await _saveDraftSafely();
    }
  }

  void _openFlyerPreview() {
    final hasLocal = _flyerFile != null;
    final hasRemote = _existingFlyerUrl != null && _existingFlyerUrl!.trim().isNotEmpty;
    if (!hasLocal && !hasRemote) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: hasLocal
                  ? Image.file(
                _flyerFile!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white, size: 64),
                ),
              )
                  : Image.network(_existingFlyerUrl!, fit: BoxFit.contain),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();

    _titleController.removeListener(_saveDraftSafely);
    _descController.removeListener(_saveDraftSafely);
    _addressController.removeListener(_saveDraftSafely);
    _capacityController.removeListener(_saveDraftSafely);

    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }
}