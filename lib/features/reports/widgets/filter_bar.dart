import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/report_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/waiter_provider.dart';
import 'package:intl/intl.dart';

class ReportFilterBar extends StatelessWidget {
  const ReportFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final waiterProvider = context.watch<WaiterProvider>();

    final filter = reportProvider.filter;
    final String startDateStr = DateFormat(
      'dd.MM.yyyy',
    ).format(filter.startDate);
    final String endDateStr = DateFormat('dd.MM.yyyy').format(filter.endDate);

    String typeText = filter.orderType == null
        ? "Barchasi"
        : (filter.orderType == 0 ? "Stol" : "Saboy");
    String locationText = filter.locationId == null
        ? "Barcha joylar"
        : locationProvider.locations
              .firstWhere(
                (l) => l.id == filter.locationId,
                orElse: () => locationProvider.locations.first,
              )
              .name;
    String waiterText = filter.waiterId == null
        ? "Barcha xodimlar"
        : waiterProvider.waiters
              .firstWhere(
                (w) => w.id == filter.waiterId,
                orElse: () => waiterProvider.waiters.first,
              )
              .name;

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.brightness == Brightness.light
                ? const Color(0xFFE2E8F0)
                : theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.of(context).size.width > 600) ...[
            Row(
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Filtr: $startDateStr - $endDateStr • $typeText • $locationText • $waiterText",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => reportProvider.updateFilter(
                    clearOrderType: true,
                    clearLocation: true,
                    clearWaiter: true,
                  ),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text("Tozalash", style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Date Range Button
              _buildFilterButton(
                context,
                label: "Sana",
                value: "$startDateStr - $endDateStr",
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    initialDateRange: DateTimeRange(
                      start: filter.startDate,
                      end: filter.endDate,
                    ),
                    firstDate: DateTime(2022),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    reportProvider.updateFilter(
                      startDate: picked.start,
                      endDate: picked.end,
                    );
                  }
                },
              ),

              // Order Type Dropdown
              _buildDropdown<int?>(
                label: "Turi",
                value: filter.orderType,
                items: [
                  const DropdownMenuItem(value: null, child: Text("Barchasi")),
                  const DropdownMenuItem(value: 0, child: Text("Stol")),
                  const DropdownMenuItem(value: 1, child: Text("Saboy")),
                ],
                onChanged: (val) => reportProvider.updateFilter(
                  orderType: val,
                  clearOrderType: val == null,
                ),
                context: context,
              ),

              // Location Dropdown
              _buildDropdown<int?>(
                label: "Joy",
                value: filter.locationId,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text("Barcha joylar"),
                  ),
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

              // Waiter Dropdown
              _buildDropdown<int?>(
                label: "Ofitsiant",
                value: filter.waiterId,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text("Barcha xodimlar"),
                  ),
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
        ],
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? const Color(0xFFF8FAFC)
              : theme.colorScheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.brightness == Brightness.light
                ? const Color(0xFFE2E8F0)
                : theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$label: ",
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.calendar_month,
              size: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
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
    required ValueChanged<T> onChanged,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? const Color(0xFFF8FAFC)
            : theme.colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.brightness == Brightness.light
              ? const Color(0xFFE2E8F0)
              : theme.colorScheme.onSurface.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 12,
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
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
