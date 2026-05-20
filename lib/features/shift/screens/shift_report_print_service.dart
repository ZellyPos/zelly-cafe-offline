import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database_helper.dart';
import '../../../core/windows_printing_helper.dart';
import '../../../models/shift_models.dart';
import '../../../models/printer_settings.dart';
import '../../../core/utils/price_formatter.dart';

class ShiftReportPrintService {
  static const int _maxChars = 48;

  static Future<void> printCloseReport(ShiftReport report) async {
    try {
      final settings = await _loadPrinterSettings();
      if (settings == null) {
        debugPrint('ShiftReport: printer sozlamalari topilmadi');
        return;
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final List<int> bytes = _buildBytes(generator, report);

      await _sendBytes(bytes, settings);
    } catch (e) {
      debugPrint('ShiftReportPrintService error: $e');
    }
  }

  static List<int> _buildBytes(Generator g, ShiftReport report) {
    var b = <int>[];

    b += g.setGlobalCodeTable('CP1252');

    // ── Header ──────────────────────────────────────────────────────────────
    b += g.text(
      _center('SMENA HISOBOTI'),
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    b += g.text(
      _center('Smena #${report.shift.id}'),
      styles: const PosStyles(align: PosAlign.center),
    );
    b += g.hr();

    // ── Smena ma'lumotlari ───────────────────────────────────────────────────
    final opened = report.shift.openedAt;
    final closed = report.shift.closedAt ?? DateTime.now();
    final duration = closed.difference(opened);

    b += g.text(_kv('Ochildi:', _fmtTime(opened)));
    b += g.text(_kv('Yopildi:', _fmtTime(closed)));
    b += g.text(_kv('Davomiyligi:', '${duration.inHours}s ${duration.inMinutes % 60}d'));
    if (report.openedByName != null) {
      b += g.text(_kv('Kassir:', report.openedByName!));
    }
    b += g.hr();

    // ── Savdo ────────────────────────────────────────────────────────────────
    b += g.text(
      _center('SAVDO'),
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    b += g.text(_kv('Naqd:', PriceFormatter.format(report.summary.totalCashSales)));
    b += g.text(_kv('Karta:', PriceFormatter.format(report.summary.totalCardSales)));
    if (report.summary.totalDebtSales > 0) {
      b += g.text(_kv('Nasiya:', PriceFormatter.format(report.summary.totalDebtSales)));
    }
    b += g.text(
      _kv('Jami savdo:', PriceFormatter.format(report.summary.totalSales)),
      styles: const PosStyles(bold: true),
    );
    b += g.text(_kv('Buyurtmalar:', '${report.orderCount} ta'));
    b += g.hr();

    // ── Kassa hisobi ─────────────────────────────────────────────────────────
    b += g.text(
      _center('KASSA'),
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    b += g.text(_kv('Boshlangich:', PriceFormatter.format(report.shift.openingCash)));
    b += g.text(_kv('+ Naqd savdo:', PriceFormatter.format(report.summary.totalCashSales)));
    if (report.summary.totalInMovements > 0) {
      b += g.text(_kv('+ Kirimlar:', PriceFormatter.format(report.summary.totalInMovements)));
    }
    if (report.summary.totalOutMovements > 0) {
      b += g.text(_kv('- Chiqimlar:', PriceFormatter.format(report.summary.totalOutMovements)));
    }
    b += g.text(_line());
    b += g.text(
      _kv('Kutilgan:', PriceFormatter.format(report.summary.expectedCashBalance)),
      styles: const PosStyles(bold: true),
    );
    b += g.text(
      _kv('Sanalgan:', PriceFormatter.format(report.countedCash)),
      styles: const PosStyles(bold: true),
    );
    b += g.hr();

    // ── Farq ─────────────────────────────────────────────────────────────────
    final diff = report.difference;
    final diffStr = diff >= 0
        ? '+${PriceFormatter.format(diff)}'
        : '-${PriceFormatter.format(diff.abs())}';
    b += g.text(
      _kv('FARQ:', diffStr),
      styles: const PosStyles(bold: true),
    );

    if (report.shift.notes != null && report.shift.notes!.isNotEmpty) {
      b += g.hr();
      b += g.text('Izoh: ${report.shift.notes}');
    }

    b += g.hr();
    b += g.text(
      _center('Kassir imzosi: _______________'),
      styles: const PosStyles(align: PosAlign.center),
    );
    b += g.feed(3);
    b += g.cut();

    return b;
  }

  static Future<void> _sendBytes(List<int> bytes, PrinterSettings settings) async {
    try {
      if (settings.type == PrinterType.windows && settings.printerName != null) {
        if (Platform.isWindows) {
          await WindowsPrintingHelper.rawPrint(settings.printerName!, bytes);
        }
      } else if (settings.type == PrinterType.network) {
        final ip = settings.ipAddress;
        final port = settings.port;
        if (ip != null) {
          final socket = await Socket.connect(ip, port,
              timeout: const Duration(seconds: 5));
          socket.add(bytes);
          await socket.flush();
          await socket.close();
        }
      }
    } catch (e) {
      debugPrint('ShiftReport _sendBytes error: $e');
    }
  }

  static Future<PrinterSettings?> _loadPrinterSettings() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final prefs = await SharedPreferences.getInstance();
      final selectedId = prefs.getInt('selected_receipt_printer_id');

      if (selectedId != null) {
        final res = await db.query('printers', where: 'id = ?', whereArgs: [selectedId]);
        if (res.isNotEmpty) return PrinterSettings.fromMap(res.first);
      }
      final main = await db.query('printers', where: 'is_main = 1');
      if (main.isNotEmpty) return PrinterSettings.fromMap(main.first);

      final all = await db.query('printers');
      if (all.isNotEmpty) return PrinterSettings.fromMap(all.first);
    } catch (_) {}
    return null;
  }

  // ── Formatting helpers ────────────────────────────────────────────────────

  static String _center(String s) {
    if (s.length >= _maxChars) return s;
    final pad = (_maxChars - s.length) ~/ 2;
    return ' ' * pad + s;
  }

  static String _kv(String key, String value) {
    final gap = _maxChars - key.length - value.length;
    return gap <= 0 ? '$key $value' : '$key${' ' * gap}$value';
  }

  static String _line() => '-' * _maxChars;

  static String _fmtTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$d.$mo.${dt.year} $h:$m';
  }
}
