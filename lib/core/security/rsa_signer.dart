import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';

/// RSA-SHA256 raqamli imzolarini yaratish uchun xizmat.
class RsaSigner {
  /// Ma'lumotni RSA xususiy kaliti (private key) bilan imzolaydi.
  static String sign(String plainText, String privateKeyPem) {
    try {
      final parser = RSAPrivateKeyParser();
      final RSAPrivateKey privateKey = parser.parsePrivateKey(privateKeyPem);

      // 1. Ma'lumotni xeshlash (SHA-256)
      final dataBytes = utf8.encode(plainText);
      final hash = SHA256Digest().process(dataBytes);

      // 2. DigestInfo prefix (PKCS#1 v1.5 padding uchun SHA-256 identifikatori)
      final digestInfoPrefix = Uint8List.fromList([
        0x30,
        0x31,
        0x30,
        0x0d,
        0x06,
        0x09,
        0x60,
        0x86,
        0x48,
        0x01,
        0x65,
        0x03,
        0x04,
        0x02,
        0x01,
        0x05,
        0x00,
        0x04,
        0x20,
      ]);

      // 3. DigestInfo yaratish
      final digestInfo = Uint8List(digestInfoPrefix.length + hash.length);
      digestInfo.setAll(0, digestInfoPrefix);
      digestInfo.setAll(digestInfoPrefix.length, hash);

      // 4. PKCS#1 v1.5 padding qo'shish
      final paddedDigest = _pkcs1pad(
        digestInfo,
        (privateKey.modulus!.bitLength + 7) ~/ 8,
      );

      // 5. RSA bilan imzolash
      final signer = RSAEngine();
      signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
      final signature = signer.process(paddedDigest);

      return base64.encode(signature);
    } catch (e) {
      print('RSA Signing Error: $e');
      rethrow;
    }
  }

  static Uint8List _pkcs1pad(Uint8List data, int tLen) {
    final res = Uint8List(tLen);
    res[0] = 0x00;
    res[1] = 0x01; // Block type 1 (Private Key)
    for (int i = 2; i < tLen - data.length - 1; i++) {
      res[i] = 0xFF;
    }
    res[tLen - data.length - 1] = 0x00;
    res.setAll(tLen - data.length, data);
    return res;
  }
}

class RSAPrivateKeyParser {
  RSAPrivateKey parsePrivateKey(String pem) {
    final rows = pem.split('\n');
    final base64Content = rows
        .skipWhile((row) => row.startsWith('-----'))
        .takeWhile((row) => !row.startsWith('-----'))
        .join('');

    final bytes = base64.decode(base64Content);
    final asn1Parser = ASN1Parser(bytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    // Version
    // (topLevelSeq.elements![0] as ASN1Integer)

    // PrivateKeyInfo (PKCS#8) structure:
    // Version, PrivateKeyAlgorithm, PrivateKey

    // Some keys are PKCS#1 (-----BEGIN RSA PRIVATE KEY-----)
    // But this one is PKCS#8 (-----BEGIN PRIVATE KEY-----)

    final octetString = topLevelSeq.elements![2] as ASN1OctetString;
    final privateKeyBytes = octetString.valueBytes!;

    final privateKeyParser = ASN1Parser(privateKeyBytes);
    final privateKeySeq = privateKeyParser.nextObject() as ASN1Sequence;

    // PKCS#1 Private Key components:
    // version, n, e, d, p, q, dP, dQ, qInv
    final n = (privateKeySeq.elements![1] as ASN1Integer).integer!;
    // (privateKeySeq.elements![2] as ASN1Integer)
    final d = (privateKeySeq.elements![3] as ASN1Integer).integer!;
    final p = (privateKeySeq.elements![4] as ASN1Integer).integer!;
    final q = (privateKeySeq.elements![5] as ASN1Integer).integer!;

    return RSAPrivateKey(n, d, p, q);
  }
}
