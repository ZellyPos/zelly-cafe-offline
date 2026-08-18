import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/report_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/waiter_provider.dart';
import '../../../data/repositories/settings_repository.dart';
import 'package:intl/intl.dart';

class ReportFilterBar extends StatefulWidget {
  const ReportFilterBar({super.key});

  @override
  State<ReportFilterBar> createState() => _ReportFilterBarState();
}

class _ReportFilterBarState extends State<ReportFilterBar> {
  String? _activeChip;

  @override
  void initState() {
    super.initState();
    _activeChip = 'today';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectChip('today');
    });
  }


  static const _chips = [
    ('today', 'Bugun'),
    ('yesterday', 'Kecha'),
    ('3days', '3 kun'),
    ('week', '1 hafta'),
    ('month', '1 oy'),
  ];

  Future<DateTimeRange> _rangeFor(String chip) async {
    // Kun boshlanish vaqtini (day_reset_time sozlamasi) olamiz
    final dayStart = await SettingsRepository().getDayStartTime();
    final dayEnd = dayStart.add(const Duration(days: 1));

    if (chip == 'today') {
      return DateTimeRange(start: dayStart, end: dayEnd);
    }

    return switch (chip) {
      'yesterday' => DateTimeRange(
          start: dayStart.subtract(const Duration(days: 1)),
          end: dayStart,
        ),
      '3days' => DateTimeRange(
          start: dayStart.subtract(const Duration(days: 2)),
          end: dayEnd,
        ),
      'week' => DateTimeRange(
          start: dayStart.subtract(const Duration(days: 6)),
          end: dayEnd,
        ),
      'month' => DateTimeRange(
          start: DateTime(dayStart.year, dayStart.month, 1, dayStart.hour, dayStart.minute),
          end: dayEnd,
        ),
      _ => DateTimeRange(start: dayStart, end: dayEnd),
    };
  }

  Future<void> _selectChip(String chip) async {
    setState(() => _activeChip = chip);
    final range = await _rangeFor(chip);
    if (!mounted) return;
    context.read<ReportProvider>().updateFilter(
          startDate: range.start,
          endDate: range.end,
          chipKey: chip,
        );
  }

  String _fmtRange(DateTime start, DateTime end) {
    final fmt = DateFormat('dd.MM HH:mm');
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }

  Future<void> _pickCustomRange() async {
    final filter = context.read<ReportProvider>().filter;
    final result = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => _DateTimeRangeDialog(
        initial: DateTimeRange(
          start: filter.startDate,
          end: filter.endDate,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _activeChip = null);
      context.read<ReportProvider>().updateFilter(
            startDate: result.start,
            endDate: result.end,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final waiterProvider = context.watch<WaiterProvider>();
    final filter = reportProvider.filter;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.brightness == Brightness.light
                ? const Color(0xFFE2E8F0)
                : theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
            child: Row(
              children: [
                Icon(Icons.filter_alt_outlined,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ..._chips.map((c) => _DateChip(
                            label: c.$2,
                            active: _activeChip == c.$1,
                            onTap: () => _selectChip(c.$1),
                          )),
                      _DateChip(
                        label: _activeChip == null
                            ? _fmtRange(filter.startDate, filter.endDate)
                            : 'Sana va vaqt',
                        active: _activeChip == null,
                        icon: Icons.access_time_rounded,
                        onTap: _pickCustomRange,
                      ),
                      const SizedBox(width: 4),
                      _buildDropdown<int?>(
                        label: 'Turi',
                        value: filter.orderType,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Barchasi')),
                          DropdownMenuItem(value: 0, child: Text('Stol')),
                          DropdownMenuItem(value: 1, child: Text('Saboy')),
                          DropdownMenuItem(value: 2, child: Text('Yetkazish')),
                        ],
                        onChanged: (val) => reportProvider.updateFilter(
                          orderType: val,
                          clearOrderType: val == null,
                        ),
                        context: context,
                      ),
                      _buildDropdown<int?>(
                        label: 'Joy',
                        value: filter.locationId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Barcha joylar')),
                          ...locationProvider.locations.map(
                            (l) => DropdownMenuItem(value: l.id, child: Text(l.name)),
                          ),
                        ],
                        onChanged: (val) => reportProvider.updateFilter(
                          locationId: val,
                          clearLocation: val == null,
                        ),
                        context: context,
                      ),
                      _buildDropdown<int?>(
                        label: 'Ofitsiant',
                        value: filter.waiterId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Barcha xodimlar')),
                          ...waiterProvider.waiters.map(
                            (w) => DropdownMenuItem(value: w.id, child: Text(w.name)),
                          ),
                        ],
                        onChanged: (val) => reportProvider.updateFilter(
                          waiterId: val,
                          clearWaiter: val == null,
                        ),
                        context: context,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    setState(() => _activeChip = 'today');
                    await _selectChip('today');
                    if (!mounted) return;
                    reportProvider.updateFilter(
                      clearOrderType: true,
                      clearLocation: true,
                      clearWaiter: true,
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded,
                            size: 13,
                            color: Colors.redAccent.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text(
                          'Tozalash',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.redAccent.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? const Color(0xFFF8FAFC)
            : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: theme.brightness == Brightness.light
              ? const Color(0xFFE2E8F0)
              : theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              dropdownColor: theme.colorScheme.surface,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool active;
  final IconData? icon;
  final VoidCallback onTap;

  const _DateChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFF6366F1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? accent
                : theme.brightness == Brightness.light
                    ? const Color(0xFFE2E8F0)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 11,
                  color: active
                      ? Colors.white
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active
                    ? Colors.white
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sana+Vaqt oralig'i dialog ─────────────────────────────────────────────────

class _DateTimeRangeDialog extends StatefulWidget {
  final DateTimeRange initial;
  const _DateTimeRangeDialog({required this.initial});

  @override
  State<_DateTimeRangeDialog> createState() => _DateTimeRangeDialogState();
}

class _DateTimeRangeDialogState extends State<_DateTimeRangeDialog> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initial.start;
    _end = widget.initial.end;
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2022),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = DateTime(picked.year, picked.month, picked.day,
            _start.hour, _start.minute);
      } else {
        _end = DateTime(picked.year, picked.month, picked.day,
            _end.hour, _end.minute);
      }
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = DateTime(_start.year, _start.month, _start.day,
            picked.hour, picked.minute);
      } else {
        _end = DateTime(_end.year, _end.month, _end.day,
            picked.hour, picked.minute);
      }
    });
  }

  String _fmtDate(DateTime dt) => DateFormat('dd.MM.yyyy').format(dt);
  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _row(BuildContext context, String label, DateTime dt, bool isStart) {
    final theme = Theme.of(context);
    const accent = Color(0xFF6366F1);
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Sana tugmasi
        InkWell(
          onTap: () => _pickDate(isStart),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: accent),
                const SizedBox(width: 6),
                Text(
                  _fmtDate(dt),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Soat tugmasi
        InkWell(
          onTap: () => _pickTime(isStart),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 13, color: Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                Text(
                  _fmtTime(dt),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = _end.isAfter(_start);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 420,
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.date_range_rounded,
                    color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sana va vaqt oralig\'ini tanlash',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _row(context, 'Boshlanish:', _start, true),
            const SizedBox(height: 12),
            _row(context, 'Tugash:', _end, false),
            const SizedBox(height: 8),
            if (!isValid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tugash vaqti boshlanishdan keyin bo\'lishi kerak',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Bekor qilish'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isValid
                      ? () => Navigator.pop(
                            context,
                            DateTimeRange(start: _start, end: _end),
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Qo\'llash'),
                ),
              ],
            ),
          ],
        ),   // Column
        ),   // Padding
      ),     // SizedBox
    );       // Dialog
  }
}

