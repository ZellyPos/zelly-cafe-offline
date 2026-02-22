import 'dart:io';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/price_formatter.dart';

/// ExportService - Hisobotlarni Excel va PDF formatida eksport qilish servisi
class ExportService {
  static final ExportService instance = ExportService._internal();
  ExportService._internal();

  /// Ma'lumotlarni Excel formatida saqlash
  Future<String?> exportToExcel({
    required String fileName,
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel[sheetName];

      // Sarlavhalar
      for (var i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(
          headers[i],
        );
      }

      // Ma'lumotlar
      for (var rowIdx = 0; rowIdx < rows.length; rowIdx++) {
        for (var colIdx = 0; colIdx < rows[rowIdx].length; colIdx++) {
          final value = rows[rowIdx][colIdx];
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: colIdx,
                  rowIndex: rowIdx + 1,
                ),
              )
              .value = _getCellValue(
            value,
          );
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final fullPath = p.join(directory.path, '$fileName.xlsx');
      final fileBytes = excel.save();

      if (fileBytes != null) {
        final file = File(fullPath);
        await file.writeAsBytes(fileBytes);
        return fullPath;
      }
      return null;
    } catch (e) {
      print('Excel export error: $e');
      return null;
    }
  }

  /// Moliyaviy hisobotni PDF formatida saqlash
  Future<String?> exportSummaryToPDF({
    required String title,
    required String dateRange,
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> items,
    required List<String> itemHeaders,
    required List<String> itemKeys,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(dateRange),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Financial Summary Section
            pw.Text(
              'Moliyaviy Xulosa',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Jami Savdo:'),
                pw.Text(
                  '${PriceFormatter.format((summary['total'] as num?)?.toDouble() ?? 0.0)} so\'m',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Cheklar soni:'),
                pw.Text('${summary['count'] ?? 0} ta'),
              ],
            ),
            pw.SizedBox(height: 30),

            // Detailed Table
            pw.TableHelper.fromTextArray(
              headers: itemHeaders,
              data: items
                  .map(
                    (item) => itemKeys.map((key) {
                      final val = item[key];
                      if (val is num &&
                          (key.contains('price') ||
                              key.contains('total') ||
                              key.contains('revenue') ||
                              key.contains('sales'))) {
                        return PriceFormatter.format(val.toDouble());
                      }
                      return val?.toString() ?? '';
                    }).toList(),
                  )
                  .toList(),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final fullPath = p.join(
        directory.path,
        'Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      final file = File(fullPath);
      await file.writeAsBytes(await pdf.save());
      return fullPath;
    } catch (e) {
      print('PDF export error: $e');
      return null;
    }
  }

  CellValue _getCellValue(dynamic value) {
    if (value is num) return DoubleCellValue(value.toDouble());
    if (value is bool) return BoolCellValue(value);
    return TextCellValue(value?.toString() ?? '');
  }
}
