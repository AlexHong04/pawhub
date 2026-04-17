import 'dart:io';

import 'package:flutter/material.dart';
import '../../module/pet/model/pet_model.dart';
import '../constants/colors.dart';

class PetCard extends StatelessWidget {
  final Pet pet;
  final File? file;
  final bool showCheckbox;
  final bool isSelected;
  final Function()? onSelect;
  final Widget? trailingStatus;
  final List<TableRow> tableRows;
  final VoidCallback? onTap;
  final Widget? bottomWidget;

  const PetCard({
    super.key,
    required this.pet,
    required this.file,
    this.onTap,
    this.showCheckbox = false,
    this.isSelected = false,
    this.onSelect,
    this.trailingStatus,
    required this.tableRows,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (showCheckbox)
                  Checkbox(value: isSelected, onChanged: (_) => onSelect?.call()),

                const SizedBox(width: 8),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 85,
                    height: 85,
                    child: Image.network(
                      pet.image.split(',').first.trim(),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        if (file != null && file!.existsSync()) {
                          return Image.file(file!, fit: BoxFit.cover);
                        }
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.pets, size: 40),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              pet.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (trailingStatus != null) trailingStatus!,
                        ],
                      ),

                      const SizedBox(height: 10),

                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(1),
                        },
                        children: tableRows,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (bottomWidget != null) bottomWidget!,
          ],
        ),
      ),
    );
  }
}
