import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../../models/audit_models.dart';

/// SecurityService - PIN orqali tasdiqlash va xavfsizlik tekshiruvlari uchun servis
class SecurityService {
  static final SecurityService instance = SecurityService._internal();
  SecurityService._internal();

  /// PIN kod menejer yoki adminniki ekanligini tekshirish
  Future<int?> verifyManagerPIN(String pin) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> users = await db.query(
      'users',
      where: 'pin = ? AND (role = ? OR role = ?)',
      whereArgs: [pin, 'admin', 'manager'],
      limit: 1,
    );

    if (users.isEmpty) return null;
    return users.first['id'] as int;
  }

  /// Tasdiqlash oynasini ko'rsatish (PIN va sabab so'rash)
  Future<ApprovalResult> requestApproval({
    required BuildContext context,
    required String title,
    bool requireReason = false,
  }) async {
    final TextEditingController pinController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<ApprovalResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'PIN kodni kiriting',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              if (requireReason) ...[
                SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Sababini ko\'rsating',
                    prefixIcon: Icon(Icons.comment),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, ApprovalResult(isApproved: false)),
              child: Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pin = pinController.text;
                if (pin.isEmpty) return;

                final approvedById = await verifyManagerPIN(pin);
                if (approvedById != null) {
                  if (requireReason && reasonController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sababini ko\'rsatish majburiy')),
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    ApprovalResult(
                      isApproved: true,
                      approvedById: approvedById,
                      reason: reasonController.text,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('PIN kod noto\'g\'ri yoki ruxsat yo\'q'),
                    ),
                  );
                }
              },
              child: Text('Tasdiqlash'),
            ),
          ],
        );
      },
    );

    return result ?? ApprovalResult(isApproved: false);
  }
}
