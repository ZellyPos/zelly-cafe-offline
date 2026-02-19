import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/license_service.dart';
import '../../../core/security/device_fingerprint_service.dart';
import '../../../models/license_model.dart';

class LicenseImportScreen extends StatefulWidget {
  const LicenseImportScreen({super.key});

  @override
  State<LicenseImportScreen> createState() => _LicenseImportScreenState();
}

class _LicenseImportScreenState extends State<LicenseImportScreen> {
  bool _isProcessing = false;
  String? _error;
  LicenseStatus? _previewStatus;
  String? _hwid;

  @override
  void initState() {
    super.initState();
    _loadHwid();
  }

  Future<void> _loadHwid() async {
    final id = await DeviceFingerprintService.getDeviceId();
    if (mounted) setState(() => _hwid = id);
  }

  Future<void> _pickLicenseFile() async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _previewStatus = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        final status = await LicenseService.instance.verifyLicense(content);
        setState(() {
          _previewStatus = status;
          if (!status.isValid && status.type != LicenseType.expired) {
            _error = status.message;
          }
        });

        if (status.isValid || status.type == LicenseType.expired) {
          final success = await LicenseService.instance.saveLicense(content);
          if (success) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Litsenziya muvaffaqiyatli saqlandi!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      setState(() => _error = 'Faylni o\'qishda xatolik: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _previewStatus ?? LicenseService.instance.currentStatus;

    return Scaffold(
      appBar: AppBar(title: const Text('Litsenziya boshqaruvi'), elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_hwid != null) _buildHwidSection(theme),
                const SizedBox(height: 24),
                _buildStatusCard(status, theme),
                const SizedBox(height: 40),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickLicenseFile,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.file_upload),
                  label: Text(
                    _isProcessing
                        ? 'Ishlanmoqda...'
                        : 'Yangi litsenziya faylini tanlash',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Litsenziya fayli (license.json) taʼminotchi tomonidan beriladi.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHwidSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Qurilma ID (HWID):',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  _hwid!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.blue),
                tooltip: 'Nusxalash',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _hwid!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('HWID nusxalandi!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(LicenseStatus status, ThemeData theme) {
    Color statusColor;
    IconData statusIcon;

    switch (status.type) {
      case LicenseType.active:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case LicenseType.gracePeriod:
        statusColor = Colors.orange;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case LicenseType.expired:
      case LicenseType.tampered:
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      color: statusColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(statusIcon, size: 80, color: statusColor),
            const SizedBox(height: 20),
            Text(
              status.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            if (status.payload != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              _buildInfoRow('Kompaniya:', status.payload!.company),
              _buildInfoRow(
                'Muddati:',
                status.payload!.expiry.toString().split(' ').first,
              ),
              _buildInfoRow('Tarif:', status.payload!.plan),
              _buildInfoRow(
                'Qurilma ID:',
                '${status.payload!.deviceId.substring(0, 8)}...',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
