import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
import '../service/pet_adoption_service.dart';

class SchedulePickupPage extends StatefulWidget {
  final String adoptionId;

  const SchedulePickupPage({super.key, required this.adoptionId});

  @override
  State<SchedulePickupPage> createState() => _PickupState();
}

class _PickupState extends State<SchedulePickupPage> {
  final AdoptionService _adoptionService = AdoptionService();

  DateTime? _selectedDate;
  final DateTime now = DateTime.now();
  late final DateTime minDate = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 3));

  @override
  void dispose() {
    _selectedDate = null;
    super.dispose();
  }

  void _showDialog({required bool isConfirming}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        if (!isConfirming) {
          return AlertDialog(
            title: const Text("Discard Selection?"),
            content: const Text(
              "Are you sure you want to cancel? Your selected date will be lost.",
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "No, Keep it",
                  style: TextStyle(color: AppColors.textDark),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text(
                  "Yes, Discard",
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          );
        } else {
          return AlertDialog(
            title: const Text("Confirm Pickup Schedule?"),
            content: const Text(
              "Are you confirming to schedule this pickup booking?",
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, _selectedDate),
                child: const Text(
                  "No, Discard",
                  style: TextStyle(color: AppColors.textDark),
                ),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await _adoptionService.schedulePickup(
                      adoptionId: widget.adoptionId,
                      pickupDate: _selectedDate!,
                    );

                    Navigator.pop(context);

                    // 4. Success Message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Schedule successfully applied!'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );

                    Navigator.pop(context);

                  } catch (e) {
                    log("Schedule pickup time error: $e");
                  }
                },
                child: const Text(
                  "Yes, Schedule",
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Schedule Pickup",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select a Pickup Date",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: CalendarDatePicker(
                initialDate:
                    _selectedDate != null && !_selectedDate!.isBefore(minDate)
                    ? _selectedDate!
                    : minDate,
                firstDate: minDate,
                lastDate: DateTime(2100),
                onDateChanged: (DateTime date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "* Pickups must be scheduled at least 3 days in advance",
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Shelter Location",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            const Text(
              "Ground Floor, Bangunan Tan Sri Khaw Kai Boh (Block A), Jalan Genting Kelang, Setapak, 53300 Kuala Lumpur, Federal Territory of Kuala Lumpur",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 10),

            const Text(
              "Operating hours: 10am to 6pm",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _showDialog(isConfirming: false);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.black45),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Click the date to select...'),
                          ),
                        );
                      } else {
                        _showDialog(isConfirming: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Apply",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
