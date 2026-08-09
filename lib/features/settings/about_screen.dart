import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/license_service.dart';
import '../../core/update_service.dart';
import '../../core/app_logger.dart';
import '../../models/license_model.dart';

class AboutScreen extends StatefulWidget {
  final bool embedded;
  const AboutScreen({super.key, this.embedded = false});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appVersion = '—';
  bool _checkingUpdate = false;
  String? _updateMessage;
  List<File> _logFiles = [];

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    final files = await AppLogger.listLogFiles();
    if (mounted) setState(() => _logFiles = files);
  }

  Future<void> _loadVersion() async {
    final v = await UpdateService.getCurrentVersion();
    if (mounted) setState(() => _appVersion = v);
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateMessage = null;
    });
    try {
      final info = await UpdateService.checkForUpdates();
      if (!mounted) return;
      if (info != null) {
        setState(() => _updateMessage = null);
        await UpdateService.showUpdateDialog(context, info);
      } else {
        setState(() => _updateMessage = 'Ilova eng yangi versiyada ✓');
      }
    } catch (_) {
      if (mounted) setState(() => _updateMessage = 'Tekshirib bo\'lmadi');
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final license = context.watch<LicenseService>();
    final status = license.currentStatus;
    final payload = status.payload;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Ilova haqida',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
              elevation: 0,
            ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Ilova ──────────────────────────────────────────────────────
          _section(theme, 'Ilova', [
            _row(theme, Icons.bolt_rounded, 'Ilova nomi', 'ZELLY POS',
                accent: const Color(0xFF6366F1)),
            _row(theme, Icons.tag_rounded, 'Versiya', _appVersion),
            _row(theme, Icons.storage_rounded, 'Ma\'lumotlar bazasi', 'v52'),
          ]),

          // ── Yangilanish ────────────────────────────────────────────────
          _section(theme, 'Yangilanish', [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Yangilanishni tekshirish',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            )),
                        if (_updateMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _updateMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _updateMessage!.contains('✓')
                                    ? const Color(0xFF10B981)
                                    : Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: _checkingUpdate ? null : _checkUpdate,
                      icon: _checkingUpdate
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(_checkingUpdate ? 'Tekshirilmoqda...' : 'Tekshirish'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),

          // ── Litsenziya ─────────────────────────────────────────────────
          _section(theme, 'Litsenziya', [
            _row(
              theme,
              _licenseIcon(status.type),
              'Holat',
              _licenseLabel(status.type),
              accent: _licenseColor(status.type),
            ),
            if (payload != null) ...[
              _row(theme, Icons.business_rounded, 'Kompaniya', payload.company),
              _row(theme, Icons.workspace_premium_rounded, 'Tarif',
                  payload.plan),
              _row(
                theme,
                Icons.calendar_today_rounded,
                'Berilgan sana',
                DateFormat('dd.MM.yyyy').format(payload.issuedAt),
              ),
              _row(
                theme,
                Icons.event_rounded,
                'Muddat',
                DateFormat('dd.MM.yyyy').format(payload.expiry),
                sub: status.remainingDays > 0
                    ? '${status.remainingDays} kun qoldi'
                    : 'Muddati o\'tgan',
                subColor: status.remainingDays > 7
                    ? const Color(0xFF10B981)
                    : Colors.red,
              ),
            ],
          ]),

          // ── Qurilma ────────────────────────────────────────────────────
          if (payload != null)
            _section(theme, 'Qurilma', [
              _copyRow(
                theme,
                Icons.fingerprint_rounded,
                'Qurilma ID',
                payload.deviceId,
                context,
              ),
            ]),

          // ── Log fayllar ────────────────────────────────────────────────
          _section(theme, 'Log fayllar', [
            if (_logFiles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Log fayllar topilmadi',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              )
            else
              ..._logFiles.map(
                (f) => _logFileRow(theme, f, context),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _logFileRow(ThemeData theme, File file, BuildContext context) {
    final name = file.path.split(Platform.pathSeparator).last;
    return InkWell(
      onTap: () => _openLogViewer(context, file),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(Icons.description_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            FutureBuilder<int>(
              future: file.length(),
              builder: (_, snap) => Text(
                snap.hasData ? _fmtSize(snap.data!) : '',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  void _openLogViewer(BuildContext context, File file) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _LogViewerScreen(file: file)),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _section(ThemeData theme, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children
                .asMap()
                .entries
                .map((e) => Column(children: [
                      e.value,
                      if (e.key < children.length - 1)
                        Divider(
                          height: 1,
                          indent: 48,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.06),
                        ),
                    ]))
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _row(
    ThemeData theme,
    IconData icon,
    String label,
    String value, {
    Color? accent,
    String? sub,
    Color? subColor,
  }) {
    final color = accent ?? theme.colorScheme.onSurface.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                )),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accent ?? theme.colorScheme.onSurface,
                  )),
              if (sub != null)
                Text(sub,
                    style: TextStyle(
                      fontSize: 11,
                      color: subColor ??
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _copyRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                )),
          ),
          Text(
            value.length > 16 ? '${value.substring(0, 16)}...' : value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Qurilma ID nusxalandi'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 15,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _licenseIcon(LicenseType type) => switch (type) {
        LicenseType.active      => Icons.verified_rounded,
        LicenseType.gracePeriod => Icons.access_time_rounded,
        LicenseType.expired     => Icons.cancel_rounded,
        LicenseType.tampered    => Icons.warning_rounded,
        LicenseType.invalid     => Icons.error_rounded,
      };

  String _licenseLabel(LicenseType type) => switch (type) {
        LicenseType.active      => 'Faol',
        LicenseType.gracePeriod => 'Muddati yaqinlashmoqda',
        LicenseType.expired     => 'Muddati o\'tgan',
        LicenseType.tampered    => 'Buzilgan',
        LicenseType.invalid     => 'Noto\'g\'ri',
      };

  Color _licenseColor(LicenseType type) => switch (type) {
        LicenseType.active      => const Color(0xFF10B981),
        LicenseType.gracePeriod => const Color(0xFFF59E0B),
        LicenseType.expired     => Colors.red,
        LicenseType.tampered    => Colors.red,
        LicenseType.invalid     => Colors.grey,
      };
}

// ── Log Viewer ──────────────────────────────────────────────────────────────

class _LogViewerScreen extends StatefulWidget {
  final File file;
  const _LogViewerScreen({required this.file});

  @override
  State<_LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<_LogViewerScreen> {
  List<String> _lines = [];
  bool _loading = true;
  String _filter = '';
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final content = await widget.file.readAsLines();
      if (mounted) setState(() { _lines = content.reversed.toList(); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _lines = ['Fayl o\'qishda xato: $e']; _loading = false; });
    }
  }

  Color _lineColor(String line, ThemeData theme) {
    if (line.contains('[ERROR]')) return Colors.red.shade300;
    if (line.contains('[WARN ]')) return Colors.orange.shade300;
    if (line.contains('[INFO ]')) return theme.colorScheme.onSurface;
    return theme.colorScheme.onSurface.withValues(alpha: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filter.isEmpty
        ? _lines
        : _lines.where((l) => l.toLowerCase().contains(_filter.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(
          widget.file.path.split(Platform.pathSeparator).last,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        ),
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Hammasini nusxalash',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _lines.reversed.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log nusxalandi'), duration: Duration(seconds: 2)),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Qidirish... (ERROR, INFO, tag nomi)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                filled: true,
                fillColor: const Color(0xFF21262D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text('${filtered.length} qator',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
                const Spacer(),
                Text('Eng yangi yuqorida',
                    style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final line = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                        child: Text(
                          line,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: _lineColor(line, theme),
                            height: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
