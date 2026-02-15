import 'dart:convert';

enum PrinterType { network, windows, usb_legacy }

class PrinterSettings {
  final int? id;
  final String displayName;
  final PrinterType type;
  final String? printerName; // For Windows RAW or USB Legacy
  final String? ipAddress;
  final int port;
  final List<int> categoryIds;

  PrinterSettings({
    this.id,
    this.displayName = 'Printer',
    this.type = PrinterType.network,
    this.printerName,
    this.ipAddress,
    this.port = 9100,
    this.categoryIds = const [],
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'display_name': displayName,
      'type': type.name,
      'printer_name': printerName ?? '',
      'ip_address': ipAddress ?? '',
      'port': port,
      'category_ids': jsonEncode(categoryIds),
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
      type = PrinterType.usb_legacy;
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
  }) {
    return PrinterSettings(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      type: type ?? this.type,
      printerName: printerName ?? this.printerName,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      categoryIds: categoryIds ?? this.categoryIds,
    );
  }
}
