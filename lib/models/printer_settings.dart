enum PrinterType { network, windows, usb_legacy }

class PrinterSettings {
  final PrinterType type;
  final String? printerName; // For Windows RAW or USB Legacy
  final String? ipAddress;
  final int port;

  PrinterSettings({
    this.type = PrinterType.network,
    this.printerName,
    this.ipAddress,
    this.port = 9100,
  });

  Map<String, String> toMap() {
    return {
      'printer_type': type.name,
      'printer_name': printerName ?? '',
      'ip_address': ipAddress ?? '',
      'port': port.toString(),
    };
  }

  factory PrinterSettings.fromMap(Map<String, dynamic> map) {
    PrinterType type = PrinterType.network;
    if (map['printer_type'] == 'windows') {
      type = PrinterType.windows;
    } else if (map['printer_type'] == 'usb' ||
        map['printer_type'] == 'usb_legacy') {
      type = PrinterType.usb_legacy;
    }

    return PrinterSettings(
      type: type,
      printerName:
          map['printer_name'] ?? map['usb_name'], // Fallback for migration
      ipAddress: map['ip_address'],
      port: int.tryParse(map['port']?.toString() ?? '9100') ?? 9100,
    );
  }

  PrinterSettings copyWith({
    PrinterType? type,
    String? printerName,
    String? ipAddress,
    int? port,
  }) {
    return PrinterSettings(
      type: type ?? this.type,
      printerName: printerName ?? this.printerName,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
    );
  }
}
