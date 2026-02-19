import 'package:flutter/material.dart';
import '../../../core/services/license_service.dart';
import '../../../models/license_model.dart';
import '../screens/license_import_screen.dart';

/// Litsenziya holatiga qarab kontentni bloklovchi yoki ruxsat beruvchi vidjet.
class LicenseGate extends StatelessWidget {
  final Widget child;

  /// Bloklangan holatda ko'rsatiladigan alternativ vidjet (ixtiyoriy)
  final Widget? blockedPlaceholder;

  /// Faqat "active" holatda ruxsat berish (grace period-ni bloklash uchun)
  final bool strict;

  const LicenseGate({
    super.key,
    required this.child,
    this.blockedPlaceholder,
    this.strict = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = LicenseService.instance.currentStatus;

    // 1. Agar litsenziya faol bo'lsa yoki (strict bo'lmasa va grace period bo'lsa)
    if (status.type == LicenseType.active ||
        (!strict && status.type == LicenseType.gracePeriod)) {
      return child;
    }

    // 2. Bloklangan holat
    if (blockedPlaceholder != null) return blockedPlaceholder!;

    return _buildDefaultBlockedUI(context, status);
  }

  Widget _buildDefaultBlockedUI(BuildContext context, LicenseStatus status) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_person_outlined, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Litsenziya Cheklovi',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status.message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LicenseImportScreen()),
              );
            },
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Litsenziya yuklash'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
