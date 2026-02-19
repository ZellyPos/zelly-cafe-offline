import 'dart:convert';

/// Litsenziya ma'lumotlari (Payload) modeli.
class LicensePayload {
  final String product;
  final String company;
  final String deviceId;
  final DateTime issuedAt;
  final DateTime expiry;
  final String plan;
  final Map<String, dynamic> features;

  LicensePayload({
    required this.product,
    required this.company,
    required this.deviceId,
    required this.issuedAt,
    required this.expiry,
    required this.plan,
    required this.features,
  });

  factory LicensePayload.fromMap(Map<String, dynamic> map) {
    return LicensePayload(
      product: map['product'] ?? 'Zelly POS',
      company: map['company'] ?? '',
      deviceId: map['device_id'] ?? map['deviceId'] ?? '',
      issuedAt:
          DateTime.tryParse(map['issued_at'] ?? map['issuedAt'] ?? '') ??
          DateTime.now(),
      expiry:
          DateTime.tryParse(map['expiry'] ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      plan: map['plan'] ?? 'STANDARD',
      features: Map<String, dynamic>.from(map['features'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company': company,
      'device_id': deviceId,
      'expiry': expiry.toIso8601String().split('.').first,
      'features': features,
      'issued_at': issuedAt.toIso8601String().split('.').first,
      'plan': plan,
      'product': product,
    };
  }

  /// Imzo tekshirish uchun JSON ma'lumotni kanonik ko'rinishga keltiradi.
  String toCanonicalJson() {
    final sortedMap = _sortMap(toMap());
    // separators: (',', ':') ga moslashish uchun (bo'sh joysiz)
    return const JsonEncoder().convert(sortedMap);
  }

  Map<String, dynamic> _sortMap(Map<String, dynamic> map) {
    var sortedKeys = map.keys.toList()..sort();
    var result = <String, dynamic>{};
    for (var key in sortedKeys) {
      var value = map[key];
      if (value is Map<String, dynamic>) {
        result[key] = _sortMap(value);
      } else {
        result[key] = value;
      }
    }
    return result;
  }
}

/// Litsenziya holati (Status) modeli.
enum LicenseType { active, expired, gracePeriod, invalid, tampered }

class LicenseStatus {
  final LicenseType type;
  final String message;
  final LicensePayload? payload;
  final int remainingDays;

  LicenseStatus({
    required this.type,
    required this.message,
    this.payload,
    this.remainingDays = 0,
  });

  bool get isValid =>
      type == LicenseType.active || type == LicenseType.gracePeriod;
  bool get canSell => isValid;
}
