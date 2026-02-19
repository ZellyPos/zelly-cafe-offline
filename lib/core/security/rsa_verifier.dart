import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';

/// RSA-SHA256 raqamli imzolarini tekshirish uchun xizmat.
class RsaVerifier {
  /// Ma'lumotni va uning imzosini RSA ommaviy kaliti bilan tekshiradi.
  static bool verify(
    String plainText,
    String base64Signature,
    String publicKeyPem,
  ) {
    try {
      final parser = RSAKeyParser();
      final RSAPublicKey publicKey = parser.parsePublicKey(publicKeyPem);

      // 1. Ma'lumotni xeshlash
      final dataBytes = utf8.encode(plainText);
      final hash = SHA256Digest().process(dataBytes);

      // 2. Imzoni dekodlash
      final signatureBytes = base64.decode(base64Signature);

      // 3. RSA bilan dekodlash (Manual mode)
      final cipher = RSAEngine();
      cipher.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

      final decrypted = cipher.process(signatureBytes);

      // 4. PKCS#1 v1.5 formatini tekshirish
      // SHA-256 DigestInfo prefix: 3031300d060960864801650304020105000420
      final decryptedHex = _toHex(decrypted).toLowerCase();
      final hashHex = _toHex(hash).toLowerCase();

      // DigestInfo ko'rinishi
      final expectedDigestInfo =
          '3031300d060960864801650304020105000420$hashHex';

      final isValid = decryptedHex.endsWith(expectedDigestInfo);

      if (!isValid) {
        print('RSA Mismatch Diagnostics:');
        print('Expected end: $expectedDigestInfo');
        if (decryptedHex.length >= expectedDigestInfo.length) {
          print(
            'Actual end:   ${decryptedHex.substring(decryptedHex.length - expectedDigestInfo.length)}',
          );
        } else {
          print('Decrypted block too short: $decryptedHex');
        }
      }

      return isValid;
    } catch (e) {
      print('RSA Verification Error: $e');
      return false;
    }
  }

  static String _toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// PEM formatidagi kalitni PointyCastle formatiga o'tkazish uchun yordamchi klass.
class RSAKeyParser {
  RSAPublicKey parsePublicKey(String pem) {
    final rows = pem.split('\n');

    final base64Content = rows
        .skipWhile((row) => row.startsWith('-----'))
        .takeWhile((row) => !row.startsWith('-----'))
        .join('');

    final bytes = base64.decode(base64Content);
    final asn1Parser = ASN1Parser(bytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    // SubjectPublicKeyInfo structure
    final bitString = topLevelSeq.elements![1] as ASN1BitString;
    final publicKeyBytes = Uint8List.fromList(bitString.stringValues!);

    final publicKeyParser = ASN1Parser(publicKeyBytes);
    final publicKeySeq = publicKeyParser.nextObject() as ASN1Sequence;

    final modulus = publicKeySeq.elements![0] as ASN1Integer;
    final exponent = publicKeySeq.elements![1] as ASN1Integer;

    return RSAPublicKey(modulus.integer!, exponent.integer!);
  }
}
