import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_settings_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class BrandSettingsScreen extends StatelessWidget {
  const BrandSettingsScreen({super.key});

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
            ],
          ),
        ),
      ),
    );
  }
}
