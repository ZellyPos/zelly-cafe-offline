import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/foundation.dart';

class WindowsPrintingHelper {
  /// Listing printers using EnumPrinters is complex with FFI.
  /// For now, we will assume the user types the exact name or we implement a simpler list if possible.
  /// However, win32 package allows EnumPrinters.
  /// Let's implement a basic list of installed printers.
  static List<String> getPrinters() {
    final printers = <String>[];
    // Level 2 gives printer name, server name, etc.
    // PRINTER_INFO_2 involves generic pointers. Level 4 is simpler (name, server, attributes).
    const level = 4;
    const flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;

    // First call to get size
    final pcbNeeded = calloc<DWORD>();
    final pcReturned = calloc<DWORD>();

    try {
      EnumPrinters(flags, nullptr, level, nullptr, 0, pcbNeeded, pcReturned);

      final cbNeeded = pcbNeeded.value;
      if (cbNeeded == 0) return [];

      final pPrinters = calloc<Uint8>(cbNeeded);
      try {
        final result = EnumPrinters(
          flags,
          nullptr,
          level,
          pPrinters,
          cbNeeded,
          pcbNeeded,
          pcReturned,
        );
        if (result != 0) {
          final count = pcReturned.value;
          // PRINTER_INFO_4 struct size is relatively small.
          // Struct definition in C:
          // typedef struct _PRINTER_INFO_4 {
          //   LPTSTR pPrinterName;
          //   LPTSTR pServerName;
          //   DWORD  Attributes;
          // } PRINTER_INFO_4;
          // On 64-bit: ptr (8) + ptr (8) + dword (4) + padding (4) = 24 bytes?
          // On 32-bit: ptr (4) + ptr (4) + dword (4) = 12 bytes.
          // Win32 package might provide PRINTER_INFO_4 class or we access manually.
          // Accessing manually via Pointer<PRINTER_INFO_4> if available, or just offsets.

          final structSize = sizeOf<PRINTER_INFO_4>();
          for (var i = 0; i < count; i++) {
            // Calculate address: pPrinters + (i * structSize)
            final ptr = pPrinters
                .elementAt(i * structSize)
                .cast<PRINTER_INFO_4>();
            if (ptr.ref.pPrinterName != nullptr) {
              printers.add(ptr.ref.pPrinterName.toDartString());
            }
          }
        }
      } finally {
        calloc.free(pPrinters);
      }
    } finally {
      calloc.free(pcbNeeded);
      calloc.free(pcReturned);
    }

    return printers;
  }

  static Future<bool> rawPrint(String printerName, List<int> bytes) async {
    return _rawPrint(printerName, bytes);
  }

  static bool _rawPrint(String printerName, List<int> bytes) {
    final pPrinterName = printerName.toNativeUtf16();
    // Open the printer
    final phPrinter = calloc<HANDLE>();
    try {
      if (OpenPrinter(pPrinterName, phPrinter, nullptr) == 0) {
        debugPrint('OpenPrinter failed: ${GetLastError()}');
        return false;
      }

      // Start a document
      final pDocInfo = calloc<DOC_INFO_1>();
      pDocInfo.ref.pDocName = 'ZELLY Receipt'.toNativeUtf16();
      pDocInfo.ref.pOutputFile = nullptr; // Print to printer
      pDocInfo.ref.pDatatype = 'RAW'.toNativeUtf16(); // RAW format

      final dwJob = StartDocPrinter(phPrinter.value, 1, pDocInfo);
      if (dwJob == 0) {
        debugPrint('StartDocPrinter failed: ${GetLastError()}');
        ClosePrinter(phPrinter.value);
        _freeDocInfo(pDocInfo);
        return false;
      }

      // Start a page
      if (StartPagePrinter(phPrinter.value) == 0) {
        debugPrint('StartPagePrinter failed: ${GetLastError()}');
        EndDocPrinter(phPrinter.value);
        ClosePrinter(phPrinter.value);
        _freeDocInfo(pDocInfo);
        return false;
      }

      // Write data
      final pBytes = calloc<Uint8>(bytes.length);
      for (var i = 0; i < bytes.length; i++) {
        pBytes[i] = bytes[i];
      }
      final dwBytesWritten = calloc<DWORD>();

      final success = WritePrinter(
        phPrinter.value,
        pBytes,
        bytes.length,
        dwBytesWritten,
      );

      calloc.free(pBytes);
      calloc.free(dwBytesWritten);

      if (success == 0) {
        debugPrint('WritePrinter failed: ${GetLastError()}');
        EndPagePrinter(phPrinter.value);
        EndDocPrinter(phPrinter.value);
        ClosePrinter(phPrinter.value);
        _freeDocInfo(pDocInfo);
        return false;
      }

      // End page and document
      EndPagePrinter(phPrinter.value);
      EndDocPrinter(phPrinter.value);
      ClosePrinter(phPrinter.value);
      _freeDocInfo(pDocInfo);

      return true;
    } finally {
      calloc.free(pPrinterName);
      calloc.free(phPrinter);
    }
  }

  static void _freeDocInfo(Pointer<DOC_INFO_1> pDocInfo) {
    if (pDocInfo.ref.pDocName != nullptr) calloc.free(pDocInfo.ref.pDocName);
    if (pDocInfo.ref.pDatatype != nullptr) calloc.free(pDocInfo.ref.pDatatype);
    calloc.free(pDocInfo);
  }
}
