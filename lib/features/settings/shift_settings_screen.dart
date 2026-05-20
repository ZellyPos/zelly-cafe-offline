import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/shift_provider.dart';

class ShiftSettingsScreen extends StatefulWidget {
  final bool embedded;
  const ShiftSettingsScreen({super.key, this.embedded = false});

  @override
  State<ShiftSettingsScreen> createState() => _ShiftSettingsScreenState();
}

class _ShiftSettingsScreenState extends State<ShiftSettingsScreen> {
  late bool _enabled;
  late String _start;
  late String _end;
  late String _dayResetTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final prov = context.read<ShiftProvider>();
    _enabled = prov.autoShiftEnabled;
    _start = prov.autoShiftStart;
    _end = prov.autoShiftEnd;
    _dayResetTime = prov.dayResetTime;
  }

  Future<void> _pickShiftTime(bool isStart) async {
    final current = isStart ? _start : _end;
    final parts = current.split(':');
    final init = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? (isStart ? 9 : 21),
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: init,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      setState(() {
        if (isStart) {
          _start = '$hh:$mm';
        } else {
          _end = '$hh:$mm';
        }
      });
    }
  }

  Future<void> _pickDayResetTime() async {
    final parts = _dayResetTime.split(':');
    final init = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: init,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      setState(() => _dayResetTime = '$hh:$mm');
    }
  }

  void _clearDayResetTime() => setState(() => _dayResetTime = '');

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await context.read<ShiftProvider>().saveAutoShiftSettings(
            enabled: _enabled,
            start: _start,
            end: _end,
            dayResetTime: _dayResetTime,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sozlamalar saqlandi'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smena sozlamalari',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Avtomatik smena va kun boshlanish vaqtini belgilang',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),

            // ── Avtomatik smena ─────────────────────────────────────────────
            _sectionLabel('Avtomatik smena', theme),
            const SizedBox(height: 10),
            Container(
              decoration: _cardDecor(theme),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        _iconBox(Icons.schedule_rounded, const Color(0xFF6366F1)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Avtomatik smena',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              Text(
                                'Belgilangan vaqtda smena avtomatik ochiladi va yopiladi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                          activeThumbColor: const Color(0xFF6366F1),
                        ),
                      ],
                    ),
                  ),
                  if (_enabled) ...[
                    _divider(theme),
                    _timeTile(
                      icon: Icons.lock_open_rounded,
                      iconColor: const Color(0xFF10B981),
                      label: 'Ochilish vaqti',
                      subtitle: 'Smena avtomatik ochiladi',
                      time: _start,
                      onTap: () => _pickShiftTime(true),
                      theme: theme,
                    ),
                    _divider(theme, indent: 56),
                    _timeTile(
                      icon: Icons.lock_rounded,
                      iconColor: Colors.redAccent,
                      label: 'Yopilish vaqti',
                      subtitle: 'Smena avtomatik yopiladi',
                      time: _end,
                      onTap: () => _pickShiftTime(false),
                      theme: theme,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: _infoBox(
                        'Dastur yopiq bo\'lgan paytda smena vaqti kelsa, keyingi '
                        'ochilishda smena avtomatik boshlanadi.',
                        theme,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Kun boshlanish vaqti ────────────────────────────────────────
            _sectionLabel('Buyurtma raqami', theme),
            const SizedBox(height: 10),
            Container(
              decoration: _cardDecor(theme),
              child: Column(
                children: [
                  _timeTile(
                    icon: Icons.restart_alt_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'Kun boshlanish vaqti',
                    subtitle: _dayResetTime.isEmpty
                        ? 'Belgilanmagan — yarim tungdan boshlanadi'
                        : 'Har kuni $_dayResetTime da raqam 1 dan boshlanadi',
                    time: _dayResetTime.isEmpty ? '--:--' : _dayResetTime,
                    onTap: _pickDayResetTime,
                    theme: theme,
                    dimTime: _dayResetTime.isEmpty,
                    trailing: _dayResetTime.isNotEmpty
                        ? GestureDetector(
                            onTap: _clearDayResetTime,
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                          )
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _infoBox(
                      'Masalan, 08:00 belgilansa — har kuni soat 08:00 dan boshlab '
                      'buyurtma raqami 1 dan boshlanadi. Belgilanmasa yarim tungdan hisoblanadi.',
                      theme,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: 200,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Saqlash',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
    );

    if (widget.embedded) return content;
    return Scaffold(body: content);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, ThemeData theme) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );

  BoxDecoration _cardDecor(ThemeData theme) => BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      );

  Widget _iconBox(IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      );

  Divider _divider(ThemeData theme, {double indent = 0}) => Divider(
        height: 1,
        indent: indent,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
      );

  Widget _infoBox(String text, ThemeData theme,
      {Color color = const Color(0xFF6366F1)}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 15, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:
                  TextStyle(fontSize: 12, color: color.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required String time,
    required VoidCallback onTap,
    required ThemeData theme,
    bool dimTime = false,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: dimTime
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
                    : iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: dimTime
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
                      : iconColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
          ],
        ),
      ),
    );
  }
}
