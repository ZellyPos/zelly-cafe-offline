import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/shift_provider.dart';
import '../../../models/shift_models.dart';
import '../../../core/utils/price_formatter.dart';

class ShiftHistoryScreen extends StatefulWidget {
  final bool embedded;
  const ShiftHistoryScreen({super.key, this.embedded = false});

  @override
  State<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends State<ShiftHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShiftProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Consumer<ShiftProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 72,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Smena tarixi topilmadi',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: provider.history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final shift = provider.history[index];
              return _ShiftHistoryCard(
                shift: shift,
                onTap: () => _showDetail(context, provider, shift),
              );
            },
          );
        },
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smena tarixi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
      ),
      body: body,
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    ShiftProvider provider,
    Shift shift,
  ) async {
    showDialog(
      context: context,
      builder: (_) => _ShiftDetailDialog(shift: shift, provider: provider),
    );
  }
}

class _ShiftHistoryCard extends StatelessWidget {
  final Shift shift;
  final VoidCallback onTap;

  const _ShiftHistoryCard({required this.shift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = shift.status == 0;
    final statusColor = isOpen ? const Color(0xFF10B981) : const Color(0xFF64748B);
    final statusLabel = isOpen ? 'OCHIQ' : 'YOPILGAN';

    Duration? duration;
    if (shift.closedAt != null) {
      duration = shift.closedAt!.difference(shift.openedAt);
    } else {
      duration = DateTime.now().difference(shift.openedAt);
    }
    final durationStr =
        '${duration.inHours}s ${duration.inMinutes % 60}d';

    final diff = shift.difference;
    Color diffColor = const Color(0xFF10B981);
    String diffStr = '—';
    if (diff != null) {
      if (diff.abs() < 0.5) {
        diffStr = '✓ To\'g\'ri';
        diffColor = const Color(0xFF10B981);
      } else if (diff > 0) {
        diffStr = '+${PriceFormatter.format(diff)}';
        diffColor = const Color(0xFF3B82F6);
      } else {
        diffStr = '-${PriceFormatter.format(diff.abs())}';
        diffColor = Colors.red;
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOpen
                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                : theme.dividerColor.withValues(alpha: 0.1),
            width: isOpen ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // ID badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${shift.id}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _fmtDate(shift.openedAt),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_fmtTime(shift.openedAt)}  →  '
                    '${shift.closedAt != null ? _fmtTime(shift.closedAt!) : "hozir"}  '
                    '($durationStr)',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // Farq
            if (diff != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Farq',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  Text(
                    diffStr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: diffColor,
                    ),
                  ),
                ],
              ),

            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final months = [
      'Yan', 'Fev', 'Mar', 'Apr', 'May', 'Iyn',
      'Iyl', 'Avg', 'Sen', 'Okt', 'Noy', 'Dek',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ShiftDetailDialog extends StatefulWidget {
  final Shift shift;
  final ShiftProvider provider;

  const _ShiftDetailDialog({required this.shift, required this.provider});

  @override
  State<_ShiftDetailDialog> createState() => _ShiftDetailDialogState();
}

class _ShiftDetailDialogState extends State<_ShiftDetailDialog> {
  ShiftReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.provider.getHistoryReport(widget.shift);
      if (mounted) setState(() => _report = r);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shift = widget.shift;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Smena #${shift.id} — batafsil',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )
            else if (_report == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text('Ma\'lumot yuklanmadi'),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildContent(theme, _report!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ShiftReport r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Savdo
        _section(theme, 'Savdo', [
          _kv('Naqd', PriceFormatter.format(r.summary.totalCashSales), theme),
          _kv('Karta', PriceFormatter.format(r.summary.totalCardSales), theme),
          if (r.summary.totalTerminalSales > 0)
            _kv('Terminal', PriceFormatter.format(r.summary.totalTerminalSales), theme),
          if (r.summary.totalDebtSales > 0)
            _kv('Nasiya', PriceFormatter.format(r.summary.totalDebtSales), theme),
          _kv('Jami', PriceFormatter.format(r.summary.totalSales), theme, bold: true),
          _kv('Buyurtmalar', '${r.orderCount} ta', theme),
        ]),
        const SizedBox(height: 14),

        // Kassa
        _section(theme, 'Kassa', [
          _kv("Boshlang'ich", PriceFormatter.format(r.shift.openingCash), theme),
          _kv('+ Naqd savdo', PriceFormatter.format(r.summary.totalCashSales), theme),
          if (r.summary.totalInMovements > 0)
            _kv('+ Kirimlar', PriceFormatter.format(r.summary.totalInMovements), theme),
          if (r.summary.totalOutMovements > 0)
            _kv('- Chiqimlar', PriceFormatter.format(r.summary.totalOutMovements), theme),
          _kv('Kutilgan', PriceFormatter.format(r.summary.expectedCashBalance), theme, bold: true),
          _kv('Sanalgan', PriceFormatter.format(r.countedCash), theme, bold: true),
        ]),
        const SizedBox(height: 14),

        // Farq
        _diffTile(theme, r.difference),

        // Harakatlar
        if (r.movements.isNotEmpty) ...[
          const SizedBox(height: 14),
          _section(theme, 'Kassa harakatlari',
            r.movements.map((m) {
              final isIn = m.type == 'IN';
              return _kv(
                '${isIn ? "+" : "-"} ${m.reason ?? m.type}',
                PriceFormatter.format(m.amount),
                theme,
                color: isIn ? const Color(0xFF10B981) : Colors.red,
              );
            }).toList(),
          ),
        ],

        // Izoh
        if (r.shift.notes != null && r.shift.notes!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Izoh: ${r.shift.notes}',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _section(ThemeData theme, String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  Widget _kv(String k, String v, ThemeData theme, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: bold ? 0.85 : 0.55),
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            v,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _diffTile(ThemeData theme, double diff) {
    final isZero = diff.abs() < 0.5;
    final isPos = diff > 0;
    final color = isZero
        ? const Color(0xFF10B981)
        : isPos
            ? const Color(0xFF3B82F6)
            : Colors.red;
    final label = isZero
        ? "Kassa to'g'ri"
        : isPos
            ? 'Ortiqcha: +${PriceFormatter.format(diff)}'
            : 'Kamomad: -${PriceFormatter.format(diff.abs())}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isZero
                ? Icons.check_circle_rounded
                : isPos
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
