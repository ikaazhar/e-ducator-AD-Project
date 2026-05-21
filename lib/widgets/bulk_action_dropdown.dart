// lib/widgets/bulk_action_dropdown.dart
//
// Dropdown tindakan pukal untuk skrin perekodan kehadiran.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BulkActionDropdown extends StatelessWidget {
  final ValueChanged<String> onSelected;
  final bool enabled;

  const BulkActionDropdown({
    super.key,
    required this.onSelected,
    this.enabled = true,
  });

  static const Map<String, String> _options = {
    'Semua Hadir': 'Hadir',
    'Semua Tak Hadir': 'Tak Hadir',
    'Semua MC': 'MC',
    'Semua CK': 'CK',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.slateBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on, color: AppTheme.teal, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Tindakan Pukal / Bulk Action',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              hint: const Text('Pilih...'),
              onChanged: enabled
                  ? (v) {
                      if (v != null) onSelected(_options[v]!);
                    }
                  : null,
              items: _options.keys
                  .map((label) =>
                      DropdownMenuItem<String>(value: label, child: Text(label)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
