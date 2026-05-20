import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/shift_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../models/shift_models.dart';
import '../../../core/utils/price_formatter.dart';
import 'shift_report_print_service.dart';

class CloseShiftScreen extends StatefulWidget {
  final bool embedded;
  const CloseShiftScreen({super.key, this.embedded = false});

  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  String _input = '0';
  ShiftReport? _previewReport;
  bool _isLoadingPreview = false;
  bool _isClosing = false;
  final TextEditingController _notesController = TextEditingController();

  double get _countedCash => double.tryParse(_input) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    setState(() => _isLoadingPreview = true);
    try {
      final report = await context.read<ShiftProvider>().prepareCloseReport(
        _countedCash,
      );
      if (mounted) setState(() => _previewReport = report);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingPreview = false);
    }
  }

  void _onKey(String key) {
    setState(() {
      if (key == '⌫') {
        _input = _input.length <= 1
            ? '0'
            : _input.substring(0, _input.length - 1);
      } else if (key == '000') {
        if (_input != '0') _input += '000';
      } else {
        if (_input == '0') {
          _input = key;
        } else if (_input.length < 10) {
          _input += key;
        }
      }
    });
  }

  Future<void> _calculateDifference() async {
    setState(() => _isLoadingPreview = true);
    try {
      final report = await context.read<ShiftProvider>().prepareCloseReport(
        _countedCash,
      );
      if (mounted) setState(() => _previewReport = report);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _closeShift() async {
    final connectivity = context.read<ConnectivityProvider>();
    final rawId = connectivity.currentUser?['id'];
    final int userId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final shiftProvider = context.read<ShiftProvider>();

    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;

    setState(() => _isClosing = true);
    try {
      final report = await shiftProvider.closeShift(
        _countedCash,
        userId,
        _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      // Chek chiqarish
      try {
        await ShiftReportPrintService.printCloseReport(report);
      } catch (e) {
        debugPrint('Shift receipt print error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Smena muvaffaqiyatli yopildi'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        if (!widget.embedded) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(
              'Smenani yopishni tasdiqlang',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Smena yopilgandan so\'ng uni qayta ochish uchun admin ruxsati kerak bo\'ladi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('BEKOR'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('HA, YOPISH'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shift = context.watch<ShiftProvider>().activeShift;

    if (shift == null) {
      final empty = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_open_rounded,
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text(
              'Ochiq smena topilmadi',
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
      if (widget.embedded) return empty;
      return Scaffold(
        appBar: AppBar(title: const Text('Smena yopish')),
        body: empty,
      );
    }

    final body = Row(
        children: [
          // ── Chap: Hisob panel ──────────────────────────────────────────
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShiftInfoCard(shift, theme),
                  const SizedBox(height: 16),
                  if (_previewReport != null) ...[
                    _buildSalesCard(_previewReport!, theme),
                    const SizedBox(height: 16),
                    _buildCashCard(_previewReport!, theme),
                    const SizedBox(height: 16),
                    if (_previewReport!.movements.isNotEmpty)
                      _buildMovementsCard(_previewReport!, theme),
                    const SizedBox(height: 16),
                    _buildDifferenceCard(_previewReport!, theme),
                    const SizedBox(height: 16),
                  ],
                  if (_isLoadingPreview)
                    const Center(child: CircularProgressIndicator()),
                  _buildNotesField(theme),
                ],
              ),
            ),
          ),

          // ── O'ng: Numpad + tasdiqlash ──────────────────────────────────
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                left: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sanab tekshirilgan naqd',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          PriceFormatter.format(_countedCash),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildNumpad(theme),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingPreview
                          ? null
                          : _calculateDifference,
                      icon: const Icon(Icons.calculate_rounded, size: 18),
                      label: const Text(
                        'FARQNI HISOBLASH',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isClosing ? null : _closeShift,
                      icon: _isClosing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.lock_rounded, size: 20),
                      label: const Text(
                        'SMENA YOPISH',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.red.withValues(
                          alpha: 0.4,
                        ),
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Smena yopish',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: body,
    );
  }

  Widget _buildShiftInfoCard(Shift shift, ThemeData theme) {
    final duration = DateTime.now().difference(shift.openedAt);
    final hours = duration.inHours;
    final mins = duration.inMinutes % 60;

    return _card(
      theme,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: Color(0xFF10B981),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smena #${shift.id}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Ochilgan: ${_fmt(shift.openedAt)}  •  Davomiyligi: ${hours}s ${mins}d',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCard(ShiftReport report, ThemeData theme) {
    return _card(
      theme,
      title: 'Savdo hisoboti',
      icon: Icons.bar_chart_rounded,
      iconColor: const Color(0xFF3B82F6),
      child: Column(
        children: [
          _row(
            'Naqd savdo',
            report.summary.totalCashSales,
            theme,
            color: const Color(0xFF10B981),
          ),
          _row(
            'Karta savdo',
            report.summary.totalCardSales,
            theme,
            color: const Color(0xFF3B82F6),
          ),
          _row(
            'Nasiya savdo',
            report.summary.totalDebtSales,
            theme,
            color: const Color(0xFFF59E0B),
          ),
          const Divider(height: 20),
          _row('Jami savdo', report.summary.totalSales, theme, bold: true),
          const SizedBox(height: 4),
          _row(
            'Buyurtmalar soni',
            report.orderCount.toDouble(),
            theme,
            isCount: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCashCard(ShiftReport report, ThemeData theme) {
    final s = report.summary;
    return _card(
      theme,
      title: 'Kassa hisobi',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF8B5CF6),
      child: Column(
        children: [
          _row('Boshlang\'ich naqd', report.shift.openingCash, theme),
          _row(
            '+ Naqd savdo',
            s.totalCashSales,
            theme,
            color: const Color(0xFF10B981),
          ),
          if (s.totalInMovements > 0)
            _row(
              '+ Kassa kirimi',
              s.totalInMovements,
              theme,
              color: const Color(0xFF10B981),
            ),
          if (s.totalOutMovements > 0)
            _row(
              '- Kassa chiqimi',
              s.totalOutMovements,
              theme,
              color: Colors.red,
              prefix: '-',
            ),
          const Divider(height: 20),
          _row(
            'Kutilgan naqd',
            s.expectedCashBalance,
            theme,
            bold: true,
            color: const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsCard(ShiftReport report, ThemeData theme) {
    return _card(
      theme,
      title: 'Kassa harakatlari',
      icon: Icons.swap_horiz_rounded,
      iconColor: const Color(0xFFF59E0B),
      child: Column(
        children: report.movements.map((m) {
          final isIn = m.type == 'IN';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(
                  isIn
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 16,
                  color: isIn ? const Color(0xFF10B981) : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m.reason ?? (isIn ? 'Kirim' : 'Chiqim'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  '${isIn ? '+' : '-'} ${PriceFormatter.format(m.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isIn ? const Color(0xFF10B981) : Colors.red,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDifferenceCard(ShiftReport report, ThemeData theme) {
    final diff = report.difference;
    final isZero = diff.abs() < 0.5;
    final isPositive = diff > 0;
    final color = isZero
        ? const Color(0xFF10B981)
        : isPositive
        ? const Color(0xFF3B82F6)
        : Colors.red;
    final label = isZero
        ? 'Kassa to\'g\'ri!'
        : isPositive
        ? 'Ortiqcha (${PriceFormatter.format(diff.abs())})'
        : 'Kamomad (${PriceFormatter.format(diff.abs())})';
    final icon = isZero
        ? Icons.check_circle_rounded
        : isPositive
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Kutilgan: ${PriceFormatter.format(report.summary.expectedCashBalance)}  •  '
                  'Sanalgan: ${PriceFormatter.format(report.countedCash)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Izoh (ixtiyoriy)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Smena haqida izoh kiriting...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildNumpad(ThemeData theme) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['000', '0', '⌫'],
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.8,
      children: keys.expand((r) => r).map((key) {
        final isDel = key == '⌫';
        return InkWell(
          onTap: () => _onKey(key),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: isDel
                  ? Colors.red.withValues(alpha: 0.08)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: isDel
                ? const Icon(
                    Icons.backspace_rounded,
                    size: 18,
                    color: Colors.red,
                  )
                : Text(
                    key,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
          ),
        );
      }).toList(),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _card(
    ThemeData theme, {
    Widget? child,
    String? title,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          ?child,
        ],
      ),
    );
  }

  Widget _row(
    String label,
    double value,
    ThemeData theme, {
    bool bold = false,
    Color? color,
    String prefix = '',
    bool isCount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
          Text(
            isCount
                ? '${value.toInt()} ta'
                : '$prefix${PriceFormatter.format(value)}',
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  $h:$m';
  }
}
