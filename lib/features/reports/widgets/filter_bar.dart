import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/report_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/waiter_provider.dart';
import '../../../core/database_helper.dart';
import 'package:intl/intl.dart';

class ReportFilterBar extends StatefulWidget {
  const ReportFilterBar({super.key});

  @override
  State<ReportFilterBar> createState() => _ReportFilterBarState();
}

class _ReportFilterBarState extends State<ReportFilterBar> {
  String? _activeChip = 'today';

  static const _chips = [
    ('today', 'Bugun'),
    ('yesterday', 'Kecha'),
    ('3days', '3 kun'),
    ('week', '1 hafta'),
    ('month', '1 oy'),
  ];

  Future<DateTimeRange> _rangeFor(String chip) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (chip == 'today') {
      // Kun boshlanish vaqtini hisobga oladi (day_reset_time sozlamasi)
      final dayStart = await DatabaseHelper.instance.getDayStartTime();
      return DateTimeRange(start: dayStart, end: todayEnd);
    }

    return switch (chip) {
      'yesterday' => DateTimeRange(
          start: today.subtract(const Duration(days: 1)),
          end: today.subtract(const Duration(seconds: 1)),
        ),
      '3days' => DateTimeRange(
          start: today.subtract(const Duration(days: 2)),
          end: todayEnd,
        ),
      'week' => DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: todayEnd,
        ),
      'month' => DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: todayEnd,
        ),
      _ => DateTimeRange(start: today, end: todayEnd),
    };
  }

  Future<void> _selectChip(String chip) async {
    setState(() => _activeChip = chip);
    final range = await _rangeFor(chip);
    if (!mounted) return;
    context.read<ReportProvider>().updateFilter(
          startDate: range.start,
          endDate: range.end,
        );
  }

  Future<void> _pickCustomRange() async {
    final filter = context.read<ReportProvider>().filter;
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: filter.startDate,
        end: filter.endDate,
      ),
      firstDate: DateTime(2022),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _activeChip = null);
      context.read<ReportProvider>().updateFilter(
            startDate: picked.start,
            endDate: picked.end,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_outlined,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Quick date chips
                ..._chips.map((c) => _DateChip(
                      label: c.$2,
                      active: _activeChip == c.$1,
                      onTap: () => _selectChip(c.$1),
                    )),

                // Custom range chip
                _DateChip(
                  label: _activeChip == null
                      ? '${DateFormat('dd.MM').format(filter.startDate)} – ${DateFormat('dd.MM.yyyy').format(filter.endDate)}'
                      : 'Sana tanlash',
                  active: _activeChip == null,
                  icon: Icons.calendar_month,
                  onTap: _pickCustomRange,
                ),

                const SizedBox(width: 4),

                // Dropdowns
                _buildDropdown<int?>(
                  label: "Turi",
                  value: filter.orderType,
                  items: const [
                    DropdownMenuItem(value: null, child: Text("Barchasi")),
                    DropdownMenuItem(value: 0, child: Text("Stol")),
                    DropdownMenuItem(value: 1, child: Text("Saboy")),
                    DropdownMenuItem(value: 2, child: Text("Yetkazish")),
                  ],
                  onChanged: (val) => reportProvider.updateFilter(
                    orderType: val,
                    clearOrderType: val == null,
                  ),
                  context: context,
                ),
                _buildDropdown<int?>(
                  label: "Joy",
                  value: filter.locationId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text("Barcha joylar")),
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
                  label: "Ofitsiant",
                  value: filter.waiterId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text("Barcha xodimlar")),
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
                      size: 13, color: Colors.redAccent.withValues(alpha: 0.8)),
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
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
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
            "$label: ",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: (val) => val != null ? onChanged(val) : null,
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
