import 'dart:io';
import 'dart:typed_data';
import 'package:print_usb/print_usb.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import '../models/order.dart';
import '../models/printer_settings.dart';
import '../models/receipt_settings.dart';
import '../core/utils/price_formatter.dart';
import 'app_strings.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../core/database_helper.dart';
import 'windows_printing_helper.dart';

class PrintingService {
  // Constant constraints for 80mm Font A
  static const int _maxChars = 48;
  // Dynamic margin will be passed to helper functions

  /// Loads latest settings directly from DB to ensure sync.
  static Future<PrinterSettings> _loadLatestSettings() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('settings');
      if (res.isNotEmpty) {
        Map<String, dynamic> settingsMap = {};
        for (var row in res) {
          settingsMap[row['key'] as String] = row['value'];
        }
        return PrinterSettings.fromMap(settingsMap);
      }
    } catch (e) {
      debugPrint('Error loading settings from DB: $e');
    }
    return PrinterSettings(); // Default
  }

  static Future<ReceiptSettings> _loadReceiptSettings() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('settings');
      if (res.isNotEmpty) {
        Map<String, dynamic> settingsMap = {};
        for (var row in res) {
          settingsMap[row['key'] as String] = row['value'];
        }
        return ReceiptSettings.fromMap(settingsMap);
      }
    } catch (e) {
      debugPrint('Error loading receipt settings from DB: $e');
    }
    return ReceiptSettings();
  }

  static Future<List<String>> getUsbPrinters() async {
    try {
      final List<dynamic> devices = await PrintUsb.getList();
      return devices.map((d) {
        if (d is Map) {
          return (d['name'] ?? d['productName'] ?? d.toString()).toString();
        }
        return d.toString();
      }).toList();
    } catch (e) {
      debugPrint('Error getting USB printers: $e');
      return [];
    }
  }

  static Future<List<String>> getWindowsPrinters() async {
    try {
      if (Platform.isWindows) {
        return WindowsPrintingHelper.getPrinters();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting Windows printers: $e');
      return [];
    }
  }

  /// Helper to get logo bytes safely
  static Future<List<int>> _getLogoBytes(
    ReceiptSettings rSettings,
    Generator generator,
  ) async {
    List<int> bytes = [];
    if (rSettings.showLogo && rSettings.logoPath != null) {
      final File imgFile = File(rSettings.logoPath!);
      if (imgFile.existsSync()) {
        try {
          final img.Image? originalImage = img.decodeImage(
            imgFile.readAsBytesSync(),
          );
          if (originalImage != null) {
            // Resize to 320 (standard safe width divisible by 8)
            const int targetWidth = 320;
            final img.Image resized = img.copyResize(
              originalImage,
              width: targetWidth,
            );
            bytes += generator.imageRaster(resized, align: PosAlign.center);
          }
        } catch (e) {
          debugPrint('Error processing logo image: $e');
        }
      }
    }
    return bytes;
  }

  static String _cleanText(String text) {
    return text
        .replaceAll('№', '#')
        .replaceAll('„', '"')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('🙂', '')
        .replaceAll('😊', '')
        .replaceAll('👍', '');
  }

  // --- MARGIN & FORMATTING HELPERS ---

  /// Adds left margin and limits length.
  /// Used for simple lines or manually constructed strings.
  static String _padLine(String text, int margin) {
    return ' ' * margin + text;
  }

  /// Centers text within the 48-char width, respecting margins implies
  /// we just center it in 48 chars.
  static String _centerLine(String text, {int margin = 0}) {
    text = text.trim();
    if (text.length >= _maxChars) return text.substring(0, _maxChars);

    int totalPadding = _maxChars - text.length;
    int left = totalPadding ~/ 2;
    if (left < margin) left = margin;

    return ' ' * left + text;
  }

  /// Formats a 2-column row (e.g. Total label and Value)
  /// Margin | Col1 (Left) ... Col2 (Right) | (Margin)
  static String _format2Col(
    String label,
    String value, {
    bool bold = false,
    int margin = 2,
  }) {
    int available = _maxChars - margin * 2;

    String cleanLabel = _cleanText(label);
    String cleanValue = _cleanText(value);

    if (cleanLabel.length + cleanValue.length > available) {
      cleanLabel = cleanLabel.substring(0, available - cleanValue.length - 1);
    }

    int spaceNeeded = available - cleanLabel.length - cleanValue.length;
    return ' ' * margin + cleanLabel + ' ' * spaceNeeded + cleanValue;
  }

  /// Formats a 3-column row (Items table)
  /// Margin | Name (22) | Qty (8) | Total (14) |
  static List<String> _format3ColRows(
    String col1,
    String col2,
    String col3, {
    int margin = 2,
  }) {
    // Content width = 48 - 2*margin
    int available = _maxChars - margin * 2;
    // Distribute available width: Name (50%), Qty (18%), Total (32%)
    int wName = (available * 0.5).floor();
    int wQty = (available * 0.18).floor();
    int wTotal = available - wName - wQty;

    List<String> rows = [];
    List<String> nameLines = _wrapText(col1, wName);

    for (int i = 0; i < nameLines.length; i++) {
      String n = nameLines[i];
      String q = (i == 0) ? col2 : '';
      String t = (i == 0) ? col3 : '';

      String fName = n.padRight(wName);
      int qPadLeft = (wQty - q.length) ~/ 2;
      String fQty = (' ' * qPadLeft + q).padRight(wQty);
      String fTotal = t.padLeft(wTotal);

      rows.add(' ' * margin + fName + fQty + fTotal);
    }
    return rows;
  }

  static List<String> _formatClassicItem(
    String name,
    String qty,
    String price,
    String total, {
    int margin = 2,
  }) {
    int available = _maxChars - margin * 2;
    List<String> rows = [];
    rows.add(' ' * margin + _cleanText(name));
    String details = '  $qty x $price';
    int spaceNeeded = available - details.length - total.length;
    if (spaceNeeded < 0) spaceNeeded = 1;
    rows.add(' ' * margin + details + ' ' * spaceNeeded + total);
    return rows;
  }

  static List<String> _wrapText(String text, int width) {
    List<String> lines = [];
    String current = '';
    List<String> words = text.split(' ');

    for (var word in words) {
      if (current.isEmpty) {
        if (word.length > width) {
          // Word too long, force split
          lines.add(word.substring(0, width));
          // Remainder?
          // Simplified: just clip or crude split (rare for names)
          continue;
        }
        current = word;
      } else {
        if ((current.length + 1 + word.length) <= width) {
          current += ' $word';
        } else {
          lines.add(current);
          current = word;
        }
      }
    }
    if (current.isNotEmpty) lines.add(current);
    if (lines.isEmpty)
      lines.add(text.substring(0, text.length > width ? width : text.length));
    return lines;
  }

  // ------------------------------------

  static Future<bool> printEscPosBytes({
    required List<int> bytes,
    PrinterSettings? settings,
  }) async {
    final effectiveSettings = settings ?? await _loadLatestSettings();
    if (effectiveSettings.type == PrinterType.network) {
      return await _printNetwork(
        bytes,
        effectiveSettings.ipAddress,
        effectiveSettings.port,
      );
    } else if (effectiveSettings.type == PrinterType.windows) {
      return await _printWindowsRaw(bytes, effectiveSettings.printerName);
    } else if (effectiveSettings.type == PrinterType.usb_legacy) {
      return await _printUsbLegacy(bytes, effectiveSettings.printerName);
    }
    return false;
  }

  static Future<bool> printReceipt({
    PrinterSettings? settings,
    ReceiptSettings? receiptSettings,
    required Order order,
  }) async {
    try {
      final rSettings = receiptSettings ?? await _loadReceiptSettings();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // 1. HEADER
      // Logo
      bytes += await _getLogoBytes(rSettings, generator);

      // Restaurant Name (Centered with Margin logic)
      if (rSettings.showRestaurantName) {
        if (rSettings.headerBold) {
          // Size 2 implies 24 chars width.
          bytes += generator.text(
            _cleanText(rSettings.restaurantName),
            styles: PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          );
        } else {
          bytes += generator.text(
            _centerLine(
              _cleanText(rSettings.restaurantName),
              margin: rSettings.horizontalMargin,
            ),
            styles: const PosStyles(align: PosAlign.left),
          );
        }
      }

      // Info lines
      void addInfoLine(String text) {
        bytes += generator.text(
          _centerLine(_cleanText(text), margin: rSettings.horizontalMargin),
          styles: const PosStyles(align: PosAlign.left),
        );
      }

      if (rSettings.showBranchName && rSettings.branchName.isNotEmpty) {
        addInfoLine(rSettings.branchName);
      }
      if (rSettings.showAddress && rSettings.address.isNotEmpty) {
        addInfoLine(rSettings.address);
      }
      if (rSettings.showPhoneNumber && rSettings.phoneNumber.isNotEmpty) {
        addInfoLine(rSettings.phoneNumber);
      }

      bytes += generator.feed(1);

      // Date & Time
      if (rSettings.showDate) {
        bytes += generator.text(
          _format2Col(
            'Sana: ${DateFormat('yyyy-MM-dd').format(order.createdAt)}',
            'Vaqt: ${DateFormat('HH:mm').format(order.createdAt)}',
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
      }

      if (rSettings.showOrderNumber) {
        bytes += generator.text(
          _centerLine(
            'Buyurtma: #${order.id.substring(0, 8).toUpperCase()}',
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left, bold: true),
        );
      }
      bytes += generator.hr();

      // 2. ORDER CONTEXT
      if (order.orderType == 0) {
        if (order.locationName != null && rSettings.showTable) {
          bytes += generator.text(
            _padLine(
              'Joy: ${_cleanText(order.locationName!)}',
              rSettings.horizontalMargin,
            ),
          );
        }
        if (order.tableName != null && rSettings.showTable) {
          bytes += generator.text(
            _cleanText(
              'Stol: ${order.tableName!}',
            ), // Large font, kept standard center
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
              bold: true,
            ),
          );
        }
        if (order.waiterName != null && rSettings.showWaiter) {
          bytes += generator.text(
            _padLine(
              'Ofitsiant: ${_cleanText(order.waiterName!)}',
              rSettings.horizontalMargin,
            ),
          );
        }
      } else {
        bytes += generator.text(
          _centerLine('SABOY', margin: rSettings.horizontalMargin),
          styles: const PosStyles(align: PosAlign.left, bold: true),
        );
      }
      bytes += generator.hr();

      // 3. ITEMS
      if (rSettings.showItemsTable) {
        for (var line in _format3ColRows(
          'Nomi',
          'Soni',
          'Summa',
          margin: rSettings.horizontalMargin,
        )) {
          bytes += generator.text(line, styles: const PosStyles(bold: true));
        }
        bytes += generator.hr();

        for (var item in order.items) {
          final qtyStr = item.qty.toString();
          final totalStr = PriceFormatter.format(item.qty * item.price);

          if (rSettings.layoutType == 'table') {
            for (var line in _format3ColRows(
              _cleanText(item.productName),
              qtyStr,
              totalStr,
              margin: rSettings.horizontalMargin,
            )) {
              bytes += generator.text(line);
            }
          } else {
            // Classic layout
            final priceStr = PriceFormatter.format(item.price);
            for (var line in _formatClassicItem(
              item.productName,
              qtyStr,
              priceStr,
              totalStr,
              margin: rSettings.horizontalMargin,
            )) {
              bytes += generator.text(line);
            }
          }
        }
        bytes += generator.hr();
      }

      // 4. CHARGES
      final double foodTotal = order.foodTotal > 0
          ? order.foodTotal
          : (order.total - order.roomCharge - order.serviceTotal);

      bytes += generator.text(
        _format2Col(
          'Taomlar:',
          PriceFormatter.format(foodTotal),
          margin: rSettings.horizontalMargin,
        ),
      );

      if (order.serviceTotal > 0) {
        bytes += generator.text(
          _format2Col(
            'Ofitsiant xizmati:',
            PriceFormatter.format(order.serviceTotal),
            margin: rSettings.horizontalMargin,
          ),
        );
      }

      if (order.roomTotal > 0 && rSettings.showRoomCharges) {
        bytes += generator.text(
          _format2Col(
            'Xona/Stol:',
            PriceFormatter.format(order.roomTotal),
            margin: rSettings.horizontalMargin,
          ),
        );
      }

      if (order.roomTotal > 0 || order.serviceTotal > 0) {
        bytes += generator.hr();
      }

      if (order.roomCharge > 0 && rSettings.showRoomCharges) {
        if (order.openedAt != null && order.closedAt != null) {
          final duration = order.closedAt!.difference(order.openedAt!);
          final hours = duration.inHours;
          final mins = duration.inMinutes % 60;

          bytes += generator.text(
            _format2Col(
              'Boshlandi:',
              DateFormat('HH:mm').format(order.openedAt!),
              margin: rSettings.horizontalMargin,
            ),
          );
          bytes += generator.text(
            _format2Col(
              'Davomiyligi:',
              '${hours}s ${mins}m',
              margin: rSettings.horizontalMargin,
            ),
          );
        }
        bytes += generator.hr();
      }

      // 5. TOTAL
      if (rSettings.totalBold) {
        bytes += generator.text(
          'JAMI:   ${PriceFormatter.format(order.total)}',
          styles: const PosStyles(
            align: PosAlign.right,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
      } else {
        bytes += generator.text(
          _format2Col(
            'JAMI:',
            PriceFormatter.format(order.total),
            bold: true,
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(bold: true),
        );
      }
      bytes += generator.feed(1);

      // 6. PAYMENT
      if (rSettings.showPaymentType) {
        bytes += generator.text(
          _format2Col(
            'To\'lov turi:',
            _cleanText(order.paymentType),
            bold: true,
            margin: rSettings.horizontalMargin,
          ),
        );
        if (rSettings.showChange &&
            (order.paymentType == 'Cash' || order.paymentType == 'Naqd')) {
          bytes += generator.text(
            _format2Col(
              'To\'landi:',
              PriceFormatter.format(order.paidAmount),
              margin: rSettings.horizontalMargin,
            ),
          );
          final change = order.paidAmount - order.total;
          if (change > 0) {
            bytes += generator.text(
              _format2Col(
                'Qaytim:',
                PriceFormatter.format(change),
                bold: true,
                margin: rSettings.horizontalMargin,
              ),
            );
          }
        }
        bytes += generator.hr();
      }

      // 7. FOOTER
      if (rSettings.showFooter && rSettings.footerMessage.isNotEmpty) {
        bytes += generator.text(
          _centerLine(
            _cleanText(rSettings.footerMessage),
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
      }
      bytes += generator.text(
        _centerLine(
          'Rahmat! Yana kutib qolamiz',
          margin: rSettings.horizontalMargin,
        ),
        styles: const PosStyles(align: PosAlign.left),
      );

      bytes += generator.feed(rSettings.feedLines);
      if (rSettings.cutPaper) {
        bytes += generator.cut();
      }

      return await printEscPosBytes(bytes: bytes, settings: settings);
    } catch (e, stack) {
      debugPrint('Print receipt error: $e');
      debugPrint(stack.toString());
      return false;
    }
  }

  static Future<bool> printZReport({
    PrinterSettings? settings,
    ReceiptSettings? receiptSettings,
    required Map<String, dynamic> data,
  }) async {
    try {
      final rSettings = receiptSettings ?? await _loadReceiptSettings();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      final summary = data['summary'];
      final waiters = data['waiters'] as List<Map<String, dynamic>>;

      bytes += await _getLogoBytes(rSettings, generator);

      // Header
      bytes += generator.text(
        'Z-HISOBOT',
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      if (rSettings.showRestaurantName) {
        bytes += generator.text(
          _centerLine(
            _cleanText(rSettings.restaurantName),
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
      }
      bytes += generator.text(
        _centerLine(
          'Sana: ${data['date']}',
          margin: rSettings.horizontalMargin,
        ),
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.feed(1);
      bytes += generator.hr();

      // Stats
      bytes += generator.text(
        _format2Col(
          'Jami savdo:',
          '${PriceFormatter.format((summary['total'] ?? 0).toDouble())}',
          margin: rSettings.horizontalMargin,
        ),
      );
      bytes += generator.text(
        _format2Col(
          'Naqd:',
          '${PriceFormatter.format((summary['cash_total'] ?? 0).toDouble())}',
          margin: rSettings.horizontalMargin,
        ),
      );
      bytes += generator.text(
        _format2Col(
          'Karta:',
          '${PriceFormatter.format((summary['card_total'] ?? 0).toDouble())}',
          margin: rSettings.horizontalMargin,
        ),
      );
      bytes += generator.text(
        _format2Col(
          'Terminal:',
          '${PriceFormatter.format((summary['terminal_total'] ?? 0).toDouble())}',
          margin: rSettings.horizontalMargin,
        ),
      );
      bytes += generator.hr();

      bytes += generator.text(
        _padLine(
          'Buyurtmalar: ${summary['count'] ?? 0}',
          rSettings.horizontalMargin,
        ),
      );
      bytes += generator.text(
        _padLine(
          'Boshlanish: ${summary['first_order']?.toString().substring(11, 16) ?? "-"}',
          rSettings.horizontalMargin,
        ),
      );
      bytes += generator.text(
        _padLine(
          'Yakunlanish: ${summary['last_order']?.toString().substring(11, 16) ?? "-"}',
          rSettings.horizontalMargin,
        ),
      );
      bytes += generator.hr();

      bytes += generator.text(
        _padLine('XODIMLAR BO\'YICHA:', rSettings.horizontalMargin),
        styles: const PosStyles(bold: true),
      );
      for (var w in waiters) {
        bytes += generator.text(
          _format2Col(
            _cleanText(w['name']),
            '${PriceFormatter.format((w['sales'] ?? 0).toDouble())}',
            margin: rSettings.horizontalMargin,
          ),
        );
      }
      bytes += generator.hr();

      final categories = data['categories'] as List<Map<String, dynamic>>?;
      if (categories != null && categories.isNotEmpty) {
        bytes += generator.text(
          _padLine('KATEGORIYALAR BO\'YICHA:', rSettings.horizontalMargin),
          styles: const PosStyles(bold: true),
        );
        for (var c in categories) {
          bytes += generator.text(
            _format2Col(
              _cleanText(c['category']),
              '${PriceFormatter.format((c['total'] ?? 0).toDouble())}',
              margin: rSettings.horizontalMargin,
            ),
          );
        }
        bytes += generator.hr();
      }

      bytes += generator.feed(rSettings.feedLines);
      if (rSettings.cutPaper) bytes += generator.cut();

      return await printEscPosBytes(bytes: bytes, settings: settings);
    } catch (e, stack) {
      debugPrint('Z-Report print error: $e');
      debugPrint(stack.toString());
      return false;
    }
  }

  static Future<bool> printProductPerformanceReport({
    PrinterSettings? settings,
    ReceiptSettings? receiptSettings,
    required List<Map<String, dynamic>> products,
    required String dateRange,
  }) async {
    try {
      final rSettings = receiptSettings ?? await _loadReceiptSettings();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += await _getLogoBytes(rSettings, generator);

      // Header
      bytes += generator.text(
        'TAOMLAR HISOBOTI',
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      if (rSettings.showRestaurantName) {
        bytes += generator.text(
          _centerLine(
            _cleanText(rSettings.restaurantName),
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
      }
      bytes += generator.text(
        _centerLine('Davr: $dateRange', margin: rSettings.horizontalMargin),
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.feed(1);
      bytes += generator.hr();

      // Table Header
      for (var line in _format3ColRows(
        'Nomi',
        'Soni',
        'Summa',
        margin: rSettings.horizontalMargin,
      )) {
        bytes += generator.text(line, styles: const PosStyles(bold: true));
      }
      bytes += generator.hr();

      // Limit to first 30 items if too many
      const int maxRows = 30;
      final itemsToShow = products.length > maxRows
          ? products.sublist(0, maxRows)
          : products;

      // Calculate totals
      int totalQty = 0;
      double totalRevenue = 0;
      for (var product in products) {
        totalQty += (product['total_qty'] as num).toInt();
        totalRevenue += (product['total_revenue'] as num).toDouble();
      }

      // Print items
      for (var product in itemsToShow) {
        final qtyStr = '${product['total_qty']}';
        final revenueStr = PriceFormatter.format(
          (product['total_revenue'] as num).toDouble(),
        );
        for (var line in _format3ColRows(
          _cleanText(product['name']),
          qtyStr,
          revenueStr,
          margin: rSettings.horizontalMargin,
        )) {
          bytes += generator.text(line);
        }
      }

      // Show "..." if truncated
      if (products.length > maxRows) {
        bytes += generator.text(
          _centerLine(
            '... (${products.length - maxRows} ta ko\'proq)',
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
      }

      bytes += generator.hr();

      // Totals
      bytes += generator.text(
        _format2Col(
          'Jami sotilgan:',
          '$totalQty dona',
          margin: rSettings.horizontalMargin,
        ),
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text(
        _format2Col(
          'Jami summa:',
          PriceFormatter.format(totalRevenue),
          margin: rSettings.horizontalMargin,
        ),
        styles: const PosStyles(bold: true),
      );

      bytes += generator.feed(rSettings.feedLines);
      if (rSettings.cutPaper) bytes += generator.cut();

      return await printEscPosBytes(bytes: bytes, settings: settings);
    } catch (e, stack) {
      debugPrint('Product performance report print error: $e');
      debugPrint(stack.toString());
      return false;
    }
  }

  static Future<bool> printWaitersReport({
    PrinterSettings? settings,
    ReceiptSettings? receiptSettings,
    required List<Map<String, dynamic>> waiters,
    required String dateRange,
  }) async {
    try {
      final rSettings = receiptSettings ?? await _loadReceiptSettings();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += await _getLogoBytes(rSettings, generator);

      // Header
      bytes += generator.text(
        'XODIMLAR HISOBOTI',
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      if (rSettings.showRestaurantName) {
        bytes += generator.text(
          _centerLine(
            _cleanText(rSettings.restaurantName),
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
      }
      bytes += generator.text(
        _centerLine('Davr: $dateRange', margin: rSettings.horizontalMargin),
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.feed(1);
      bytes += generator.hr();

      // Calculate totals
      double totalSales = 0;
      double totalCommission = 0;

      for (var waiter in waiters) {
        final double sales = (waiter['total_sales'] as num).toDouble();
        final int type = waiter['waiter_type'] as int;
        final double value = (waiter['waiter_value'] as num).toDouble();
        double commission = 0;
        if (type == 0) {
          commission = value;
        } else {
          commission = sales * (value / 100);
        }
        totalSales += sales;
        totalCommission += commission;
      }

      // Limit to first 20 waiters if too many
      const int maxRows = 20;
      final itemsToShow = waiters.length > maxRows
          ? waiters.sublist(0, maxRows)
          : waiters;

      // Print each waiter
      for (var waiter in itemsToShow) {
        final double sales = (waiter['total_sales'] as num).toDouble();
        final int type = waiter['waiter_type'] as int;
        final double value = (waiter['waiter_value'] as num).toDouble();
        double commission = 0;
        if (type == 0) {
          commission = value;
        } else {
          commission = sales * (value / 100);
        }

        bytes += generator.text(
          _padLine(_cleanText(waiter['name']), rSettings.horizontalMargin),
          styles: const PosStyles(bold: true),
        );
        bytes += generator.text(
          _format2Col(
            '  Buyurtmalar:',
            '${waiter['order_count']} ta',
            margin: rSettings.horizontalMargin,
          ),
        );
        bytes += generator.text(
          _format2Col(
            '  Savdo:',
            PriceFormatter.format(sales),
            margin: rSettings.horizontalMargin,
          ),
        );
        bytes += generator.text(
          _format2Col(
            '  Ish haqi:',
            type == 0 ? 'Fiksirlangan' : 'Foiz ($value%)',
            margin: rSettings.horizontalMargin,
          ),
        );
        bytes += generator.text(
          _format2Col(
            '  Hisoblangan:',
            PriceFormatter.format(commission),
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(bold: true),
        );
        bytes += generator.feed(1);
      }

      // Show "..." if truncated
      if (waiters.length > maxRows) {
        bytes += generator.text(
          _centerLine(
            '... (${waiters.length - maxRows} ta ko\'proq)',
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
        bytes += generator.feed(1);
      }

      bytes += generator.hr();

      // Totals
      bytes += generator.text(
        _format2Col(
          'Jami savdo:',
          PriceFormatter.format(totalSales),
          margin: rSettings.horizontalMargin,
        ),
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text(
        _format2Col(
          'Jami ish haqi:',
          PriceFormatter.format(totalCommission),
          margin: rSettings.horizontalMargin,
        ),
        styles: const PosStyles(bold: true),
      );

      bytes += generator.feed(rSettings.feedLines);
      if (rSettings.cutPaper) bytes += generator.cut();

      return await printEscPosBytes(bytes: bytes, settings: settings);
    } catch (e, stack) {
      debugPrint('Waiters report print error: $e');
      debugPrint(stack.toString());
      return false;
    }
  }

  static Future<bool> printLocationsReport({
    PrinterSettings? settings,
    ReceiptSettings? receiptSettings,
    required List<Map<String, dynamic>> locations,
    required String dateRange,
  }) async {
    try {
      final rSettings = receiptSettings ?? await _loadReceiptSettings();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += await _getLogoBytes(rSettings, generator);

      // Header
      bytes += generator.text(
        'JOYLAR HISOBOTI',
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      if (rSettings.showRestaurantName) {
        bytes += generator.text(
          _centerLine(
            _cleanText(rSettings.restaurantName),
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
      }
      bytes += generator.text(
        _centerLine('Davr: $dateRange', margin: rSettings.horizontalMargin),
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.feed(1);
      bytes += generator.hr();

      // Calculate totals
      int totalOrders = 0;
      double totalRevenue = 0;
      for (var location in locations) {
        totalOrders += (location['order_count'] as num).toInt();
        totalRevenue += (location['total_revenue'] as num).toDouble();
      }

      // Limit to first 25 locations if too many
      const int maxRows = 25;
      final itemsToShow = locations.length > maxRows
          ? locations.sublist(0, maxRows)
          : locations;

      // Print each location
      for (var location in itemsToShow) {
        bytes += generator.text(
          _padLine(_cleanText(location['name']), rSettings.horizontalMargin),
          styles: const PosStyles(bold: true),
        );
        bytes += generator.text(
          _format2Col(
            '  Buyurtmalar:',
            '${location['order_count']} ta',
            margin: rSettings.horizontalMargin,
          ),
        );
        bytes += generator.text(
          _format2Col(
            '  Tushum:',
            PriceFormatter.format(
              (location['total_revenue'] as num).toDouble(),
            ),
            margin: rSettings.horizontalMargin,
          ),
        );
        bytes += generator.feed(1);
      }

      // Show "..." if truncated
      if (locations.length > maxRows) {
        bytes += generator.text(
          _centerLine(
            '... (${locations.length - maxRows} ta ko\'proq)',
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
        bytes += generator.feed(1);
      }

      bytes += generator.hr();

      // Totals
      bytes += generator.text(
        _format2Col('Jami buyurtmalar:', '$totalOrders ta'),
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text(
        _format2Col('Jami tushum:', PriceFormatter.format(totalRevenue)),
        styles: const PosStyles(bold: true),
      );

      bytes += generator.feed(rSettings.feedLines);
      if (rSettings.cutPaper) bytes += generator.cut();

      return await printEscPosBytes(bytes: bytes, settings: settings);
    } catch (e, stack) {
      debugPrint('Locations report print error: $e');
      debugPrint(stack.toString());
      return false;
    }
  }

  static Future<bool> printTablesReport({
    PrinterSettings? settings,
    ReceiptSettings? receiptSettings,
    required List<Map<String, dynamic>> tables,
    required String dateRange,
  }) async {
    try {
      final rSettings = receiptSettings ?? await _loadReceiptSettings();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += await _getLogoBytes(rSettings, generator);

      // Header
      bytes += generator.text(
        'STOLLAR HISOBOTI',
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      if (rSettings.showRestaurantName) {
        bytes += generator.text(
          _centerLine(
            _cleanText(rSettings.restaurantName),
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
      }
      bytes += generator.text(
        _centerLine('Davr: $dateRange', margin: rSettings.horizontalMargin),
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.feed(1);
      bytes += generator.hr();

      // Calculate totals
      int totalOrders = 0;
      double totalRevenue = 0;
      for (var table in tables) {
        totalOrders += (table['order_count'] as num).toInt();
        totalRevenue += (table['total_revenue'] as num).toDouble();
      }

      // Limit to first 25 tables if too many
      const int maxRows = 25;
      final itemsToShow = tables.length > maxRows
          ? tables.sublist(0, maxRows)
          : tables;

      // Print each table
      for (var table in itemsToShow) {
        bytes += generator.text(
          _padLine(
            '${_cleanText(table['table_name'])} (${_cleanText(table['location_name'])})',
            rSettings.horizontalMargin,
          ),
          styles: const PosStyles(bold: true),
        );
        bytes += generator.text(
          _format2Col(
            '  Buyurtmalar:',
            '${table['order_count']} ta',
            margin: rSettings.horizontalMargin,
          ),
        );
        bytes += generator.text(
          _format2Col(
            '  Tushum:',
            PriceFormatter.format((table['total_revenue'] as num).toDouble()),
            margin: rSettings.horizontalMargin,
          ),
        );
        bytes += generator.feed(1);
      }

      // Show "..." if truncated
      if (tables.length > maxRows) {
        bytes += generator.text(
          _centerLine(
            '... (${tables.length - maxRows} ta ko\'proq)',
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
        bytes += generator.feed(1);
      }

      bytes += generator.hr();

      // Totals
      bytes += generator.text(
        _format2Col('Jami buyurtmalar:', '$totalOrders ta'),
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text(
        _format2Col('Jami tushum:', PriceFormatter.format(totalRevenue)),
        styles: const PosStyles(bold: true),
      );

      bytes += generator.feed(rSettings.feedLines);
      if (rSettings.cutPaper) bytes += generator.cut();

      return await printEscPosBytes(bytes: bytes, settings: settings);
    } catch (e, stack) {
      debugPrint('Tables report print error: $e');
      debugPrint(stack.toString());
      return false;
    }
  }

  static Future<bool> printOrdersReport({
    PrinterSettings? settings,
    ReceiptSettings? receiptSettings,
    required List<Map<String, dynamic>> orders,
    required String dateRange,
  }) async {
    try {
      final rSettings = receiptSettings ?? await _loadReceiptSettings();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += await _getLogoBytes(rSettings, generator);

      // Header
      bytes += generator.text(
        'BUYURTMALAR HISOBOTI',
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      if (rSettings.showRestaurantName) {
        bytes += generator.text(
          _centerLine(
            _cleanText(rSettings.restaurantName),
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
      }
      bytes += generator.text(
        _centerLine('Davr: $dateRange', margin: rSettings.horizontalMargin),
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.feed(1);
      bytes += generator.hr();

      // Calculate totals
      int totalOrders = orders.length;
      double totalRevenue = 0;
      double cashTotal = 0;
      double cardTotal = 0;

      for (var order in orders) {
        final total = (order['total'] as num).toDouble();
        totalRevenue += total;
        final paymentType = order['payment_type'] as String?;
        if (paymentType == 'Cash' || paymentType == 'Naqd') {
          cashTotal += total;
        } else if (paymentType == 'Card' || paymentType == 'Karta') {
          cardTotal += total;
        }
      }

      // Limit to first 20 orders if too many
      const int maxRows = 20;
      final itemsToShow = orders.length > maxRows
          ? orders.sublist(0, maxRows)
          : orders;

      // Print each order
      for (var order in itemsToShow) {
        final isDineIn = order['order_type'] == 0;
        final orderNum = order['id'].toString().substring(0, 8).toUpperCase();
        final dateTime = order['created_at']
            .toString()
            .substring(0, 16)
            .replaceFirst('T', ' ');

        bytes += generator.text(
          _padLine('#$orderNum', rSettings.horizontalMargin),
          styles: const PosStyles(bold: true),
        );
        bytes += generator.text(
          _format2Col(
            '  Sana/Vaqt:',
            dateTime,
            margin: rSettings.horizontalMargin,
          ),
        );
        bytes += generator.text(
          _format2Col(
            '  Turi:',
            isDineIn ? 'STOL' : 'SABOY',
            margin: rSettings.horizontalMargin,
          ),
        );
        if (isDineIn) {
          bytes += generator.text(
            _format2Col(
              '  Joy/Stol:',
              '${order['location_name'] ?? '-'}/${order['table_name'] ?? '-'}',
              margin: rSettings.horizontalMargin,
            ),
          );
        }
        bytes += generator.text(
          _format2Col(
            '  To\'lov:',
            order['payment_type'] ?? '-',
            margin: rSettings.horizontalMargin,
          ),
        );
        bytes += generator.text(
          _format2Col(
            '  Summa:',
            PriceFormatter.format((order['total'] as num).toDouble()),
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(bold: true),
        );
        bytes += generator.feed(1);
      }

      // Show "..." if truncated
      if (orders.length > maxRows) {
        bytes += generator.text(
          _centerLine(
            '... (${orders.length - maxRows} ta ko\'proq)',
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
        bytes += generator.feed(1);
      }

      bytes += generator.hr();

      // Totals
      bytes += generator.text(
        _format2Col(
          'Jami buyurtmalar:',
          '$totalOrders ta',
          margin: rSettings.horizontalMargin,
        ),
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text(
        _format2Col(
          'Naqd:',
          PriceFormatter.format(cashTotal),
          margin: rSettings.horizontalMargin,
        ),
      );
      bytes += generator.text(
        _format2Col(
          'Karta:',
          PriceFormatter.format(cardTotal),
          margin: rSettings.horizontalMargin,
        ),
      );
      bytes += generator.text(
        _format2Col(
          'Jami summa:',
          PriceFormatter.format(totalRevenue),
          margin: rSettings.horizontalMargin,
        ),
        styles: const PosStyles(bold: true),
      );

      bytes += generator.feed(rSettings.feedLines);
      if (rSettings.cutPaper) bytes += generator.cut();

      return await printEscPosBytes(bytes: bytes, settings: settings);
    } catch (e, stack) {
      debugPrint('Orders report print error: $e');
      debugPrint(stack.toString());
      return false;
    }
  }

  static Future<bool> testPrint({
    PrinterSettings? settings,
    ReceiptSettings? receiptSettings,
  }) async {
    try {
      final rSettings = receiptSettings ?? await _loadReceiptSettings();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += await _getLogoBytes(rSettings, generator);

      bytes += generator.text(
        _centerLine(
          _cleanText(rSettings.restaurantName),
          margin: rSettings.horizontalMargin,
        ),
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
        ), // Force bold for test
      );
      if (rSettings.showBranchName) {
        bytes += generator.text(
          _centerLine(
            _cleanText(rSettings.branchName),
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
      }
      bytes += generator.text(
        _centerLine('Test chek (80mm)', margin: rSettings.horizontalMargin),
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.feed(1);
      bytes += generator.text(
        _centerLine('Margin Check:', margin: rSettings.horizontalMargin),
        styles: const PosStyles(align: PosAlign.left),
      );

      bytes += generator.hr();
      bytes += generator.text(
        _format2Col(
          'Chap chet',
          'O\'ng chet',
          margin: rSettings.horizontalMargin,
        ),
      );
      bytes += generator.text(
        _centerLine('Markaziy Text', margin: rSettings.horizontalMargin),
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.hr();

      if (rSettings.footerMessage.isNotEmpty) {
        bytes += generator.text(
          _centerLine(
            rSettings.footerMessage,
            margin: rSettings.horizontalMargin,
          ),
          styles: const PosStyles(align: PosAlign.left),
        );
      }

      bytes += generator.feed(rSettings.feedLines);
      if (rSettings.cutPaper) bytes += generator.cut();

      return await printEscPosBytes(bytes: bytes, settings: settings);
    } catch (e, stack) {
      debugPrint('Test print error: $e');
      return false;
    }
  }

  static Future<bool> printWaiterSalaryPayout({
    PrinterSettings? settings,
    ReceiptSettings? receiptSettings,
    required String waiterName,
    required double amount,
    required String dateRange,
    required double earned,
    required double paidBefore,
    required double payableAfter,
    String? note,
  }) async {
    try {
      final rSettings = receiptSettings ?? await _loadReceiptSettings();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += await _getLogoBytes(rSettings, generator);

      bytes += generator.text(
        'OFITSIANT OYLIK CHEKI',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.feed(1);

      bytes += generator.text(
        _centerLine(waiterName, margin: rSettings.horizontalMargin),
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text(
        _centerLine('Davr: $dateRange', margin: rSettings.horizontalMargin),
      );
      bytes += generator.text(
        _centerLine(
          'Sana: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
          margin: rSettings.horizontalMargin,
        ),
      );
      bytes += generator.hr();

      bytes += generator.text(
        _format2Col(
          'Hisoblangan:',
          PriceFormatter.format(earned),
          margin: rSettings.horizontalMargin,
        ),
      );
      bytes += generator.text(
        _format2Col(
          'Oldin to\'langan:',
          PriceFormatter.format(paidBefore),
          margin: rSettings.horizontalMargin,
        ),
      );
      bytes += generator.hr();

      bytes += generator.text(
        _format2Col(
          'TO\'LANDI:',
          PriceFormatter.format(amount),
          margin: rSettings.horizontalMargin,
        ),
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      );
      bytes += generator.hr();

      bytes += generator.text(
        _format2Col(
          'Qoldiiq:',
          PriceFormatter.format(payableAfter),
          margin: rSettings.horizontalMargin,
        ),
      );

      if (note != null && note.isNotEmpty) {
        bytes += generator.feed(1);
        bytes += generator.text(
          _padLine('Izoh: $note', rSettings.horizontalMargin),
        );
      }

      bytes += generator.feed(rSettings.feedLines);
      if (rSettings.cutPaper) bytes += generator.cut();

      return await printEscPosBytes(bytes: bytes, settings: settings);
    } catch (e) {
      debugPrint('Salary payout print error: $e');
      return false;
    }
  }

  static Future<bool> _printWindowsRaw(
    List<int> bytes,
    String? printerName,
  ) async {
    if (printerName == null || printerName.isEmpty) return false;
    if (!Platform.isWindows) return false;
    return await WindowsPrintingHelper.rawPrint(printerName, bytes);
  }

  static Future<bool> _printUsbLegacy(
    List<int> bytes,
    String? printerName,
  ) async {
    if (printerName == null || printerName.isEmpty) return false;
    try {
      final bool connected = await PrintUsb.connect(name: printerName);
      if (connected) {
        final List<dynamic> devices = await PrintUsb.getList();
        dynamic selectedDevice;
        for (var d in devices) {
          if ((d['name'] ?? d['productName'] ?? d.toString()) == printerName) {
            selectedDevice = d;
            break;
          }
        }
        if (selectedDevice != null) {
          return await PrintUsb.printBytes(
            bytes: Uint8List.fromList(bytes),
            device: selectedDevice,
          );
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _printNetwork(
    List<int> bytes,
    String? ip,
    int port,
  ) async {
    final targetIp = ip ?? "192.168.1.100";
    try {
      final socket = await Socket.connect(
        targetIp,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }
}
