import 'dart:io';

class EventModel {
  final String? id;
  final String title;
  final DateTime eventDate;
  final String description;
  final String startTime;
  final String endTime;
  final String eventCategory;
  final String address;
  final int volunteerCapacity;

  // optional
  final double? latitude;
  final double? longitude;
  final File? flyerFile;
  final File? qrFile;

  EventModel({
    this.id,
    required this.title,
    required this.eventDate,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.eventCategory,
    required this.address,
    required this.volunteerCapacity,
    this.latitude,
    this.longitude,
    this.flyerFile,
    this.qrFile,
  });
}
