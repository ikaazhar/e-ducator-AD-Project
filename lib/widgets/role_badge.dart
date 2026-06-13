import 'package:flutter/material.dart';

class RoleBadge extends StatelessWidget {
  final String role;
  const RoleBadge({super.key, required this.role});

  Color get _color {
    switch (role) {
      case 'Admin':                        return Colors.purple;
      case 'Timbalan Pengarah Akademik':   return Colors.red.shade700;
      case 'Ketua Jabatan':                return Colors.orange.shade700;
      case 'Ketua Program':                return Colors.blue.shade700;
      case 'Lecturer':                     return Colors.teal.shade700;
      default:                             return Colors.grey;
    }
  }

  IconData get _icon {
    switch (role) {
      case 'Admin':                        return Icons.shield;
      case 'Timbalan Pengarah Akademik':   return Icons.stars;
      case 'Ketua Jabatan':                return Icons.apartment;
      case 'Ketua Program':                return Icons.school;
      case 'Lecturer':                     return Icons.person;
      default:                             return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 13, color: _color),
          const SizedBox(width: 5),
          Text(
            role,
            style: TextStyle(
              fontSize: 12,
              color: _color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}