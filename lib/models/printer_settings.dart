import 'dart:convert';

/// Bazada `toDbValue` orqali saqlanadi — enum nomini o'zgartirish
/// saqlangan ma'lumotni buzmasligi uchun.
enum PrinterType {
  network,
  windows,
  usbLegacy,
  receipt;

  /// SQLite ustunidagi qiymat (eski yozuvlar bilan mos).
  String get dbValue => this == PrinterType.usbLegacy ? 'usb_legacy' : name;
}

class PrinterSettings {
  final int? id;
  final String displayName;
  final PrinterType type;
  final String? printerName; // For Windows RAW or USB Legacy
  final String? ipAddress;
  final int port;
  final List<int> categoryIds;
  final bool isMain;
  final int? locationId;

  PrinterSettings({
    this.id,
    this.displayName = 'Printer',
    this.type = PrinterType.network,
    this.printerName,
    this.ipAddress,
    this.port = 9100,
    this.categoryIds = const [],
    this.isMain = false,
    this.locationId,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'display_name': displayName,
      'type': type.dbValue,
      'printer_name': printerName ?? '',
      'ip_address': ipAddress ?? '',
      'port': port,
      'category_ids': jsonEncode(categoryIds),
      'is_main': isMain ? 1 : 0,
      'location_id': locationId,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory PrinterSettings.fromMap(Map<String, dynamic> map) {
    PrinterType type = PrinterType.network;
    final typeStr = map['type'] ?? map['printer_type'];
    if (typeStr == 'windows') {
      type = PrinterType.windows;
    } else if (typeStr == 'usb' || typeStr == 'usb_legacy') {
      type = PrinterType.usbLegacy;
    } else if (typeStr == 'receipt') {
      type = PrinterType.receipt;
    }

    List<int> catIds = [];
    if (map['category_ids'] != null &&
        map['category_ids'].toString().isNotEmpty) {
      try {
        catIds = List<int>.from(jsonDecode(map['category_ids']));
      } catch (e) {
        catIds = [];
      }
    }

    return PrinterSettings(
      id: map['id'],
      displayName: map['display_name'] ?? 'Printer',
      type: type,
      printerName:
          map['printer_name'] ?? map['usb_name'], // Fallback for migration
      ipAddress: map['ip_address'],
      port: int.tryParse(map['port']?.toString() ?? '9100') ?? 9100,
      categoryIds: catIds,
      isMain: (map['is_main'] as int? ?? 0) == 1,
      locationId: map['location_id'] as int?,
    );
  }

  PrinterSettings copyWith({
    int? id,
    String? displayName,
    PrinterType? type,
    String? printerName,
    String? ipAddress,
    int? port,
    List<int>? categoryIds,
    bool? isMain,
    Object? locationId = _sentinel,
  }) {
    return PrinterSettings(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      type: type ?? this.type,
      printerName: printerName ?? this.printerName,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      categoryIds: categoryIds ?? this.categoryIds,
      isMain: isMain ?? this.isMain,
      locationId: locationId == _sentinel
          ? this.locationId
          : locationId as int?,
    );
  }
}

const _sentinel = Object();
