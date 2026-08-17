import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/history_retention_service.dart';
import '../../providers/app_settings_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class BrandSettingsScreen extends StatelessWidget {
  const BrandSettingsScreen({super.key});

  /// Kunlik qayta ishga tushish vaqtini tanlash (§16).
  static Future<void> _pickRestartTime(
    BuildContext context,
    AppSettingsProvider provider,
  ) async {
    final parts = provider.dailyRestartTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 4,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    await provider.setDailyRestartTime(
      '${picked.hour.toString().padLeft(2, '0')}:'
      '${picked.minute.toString().padLeft(2, '0')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppSettingsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Brend / Login rasmi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: 500,
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Login ekrani rasmi",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Kirish ekranida ko'rinadigan brend rasmini yuklang",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 32),
              Container(
                width: 300,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  image: provider.brandImagePath != null
                      ? DecorationImage(
                          image: FileImage(File(provider.brandImagePath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: provider.brandImagePath == null
                    ? const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: Color(0xFFCBD5E1),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        FilePickerResult? result = await FilePicker.platform
                            .pickFiles(type: FileType.image);
                        if (result != null) {
                          await provider.setBrandImage(
                            result.files.single.path!,
                          );
                        }
                      },
                      icon: const Icon(Icons.upload),
                      label: const Text("Rasm tanlash"),
                      style: OutlinedButton.styleFrom(
                        fixedSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (provider.brandImagePath != null) ...[
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => provider.removeBrandImage(),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: "Rasmni o'chirish",
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Tavsiya etiladi: 800x1200 o'lchamdagi vertikal rasm",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                "Umumiy Sozlamalar",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(
                  "Ombor qismini yoqish",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  "Kirim/chiqim tranzaksiyalari va Ombor bo'limi yoqiladi. O'chirilganida sotuv vaqtida mahsulot tarqalmaydi.",
                  style: TextStyle(fontSize: 12),
                ),
                value: provider.enableInventory,
                onChanged: (val) {
                  provider.setEnableInventory(val);
                },
                activeThumbColor: const Color(0xFF1E293B),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text(
                  "Kunlik avtomatik qayta ishga tushirish",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  "Kuniga bir marta kechasi dastur o'zi yopilib qayta ochiladi. "
                  "Savatda ochiq buyurtma bo'lsa kechiktiriladi.",
                  style: TextStyle(fontSize: 12),
                ),
                value: provider.dailyRestartEnabled,
                onChanged: (val) => provider.setDailyRestartEnabled(val),
                activeThumbColor: const Color(0xFF1E293B),
                contentPadding: EdgeInsets.zero,
              ),
              if (provider.dailyRestartEnabled)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Qayta ishga tushish vaqti"),
                  subtitle: const Text(
                    "Ish vaqtidan tashqari vaqt tanlang",
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(provider.dailyRestartTime),
                    onPressed: () => _pickRestartTime(context, provider),
                  ),
                ),
              if (provider.enableInventory)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "Ombor tarixini saqlash muddati",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Muddati o'tgan harakatlar kuniga bir marta o'chiriladi. "
                    "Tannarx va yetkazuvchi tahlili shu tarixga tayanadi — "
                    "muddatni qisqartirishdan oldin o'ylab ko'ring.",
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: DropdownButton<int>(
                    value: provider.historyRetentionMonths,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final m in HistoryRetentionService.options)
                        DropdownMenuItem(
                          value: m,
                          child: Text(m == 0 ? 'Cheksiz' : '$m oy'),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        provider.setHistoryRetentionMonths(val);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
