import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

import '../config/app_config.dart';

/// CryptoJS-compatible AES encryption/decryption.
///
/// CryptoJS.AES.encrypt(passphrase) uses OpenSSL EVP_BytesToKey to derive a
/// 32-byte key and 16-byte IV from the passphrase + a random 8-byte salt.
/// The output is Base64( "Salted__" | salt | ciphertext ).
///
/// We mirror that exact algorithm so messages encrypted by the web app can be
/// decrypted here, and vice-versa.
class EncryptionService {
  EncryptionService._();

  static String get _passphrase => AppConfig.aesKey;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Encrypts [plaintext] the same way as
  /// `CryptoJS.AES.encrypt(JSON.stringify(plaintext), key).toString()`.
  ///
  /// Returns a base64 string; returns the original value unchanged on error.
  static String encrypt(String plaintext) {
    try {
      final salt = _randomBytes(8);
      final (key, iv) = _evpBytesToKey(_passphrase, salt);

      // CryptoJS wraps the value with JSON.stringify before encrypting
      final encrypter =
          enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc));
      final encrypted =
          encrypter.encrypt(jsonEncode(plaintext), iv: enc.IV(iv));

      // Output: Base64("Salted__" + salt + ciphertext)
      final out = Uint8List(8 + 8 + encrypted.bytes.length);
      out.setRange(0, 8, 'Salted__'.codeUnits);
      out.setRange(8, 16, salt);
      out.setRange(16, out.length, encrypted.bytes);
      return base64.encode(out);
    } catch (_) {
      return plaintext;
    }
  }

  /// Decrypts a CryptoJS AES ciphertext.
  ///
  /// Mirrors: `CryptoJS.AES.decrypt(ciphertext, key).toString(CryptoJS.enc.Utf8)`.
  /// If the result is valid JSON (as CryptoJS wraps strings), it is parsed.
  /// Returns [ciphertext] unchanged on any error (graceful degradation).
  static String decrypt(String ciphertext) {
    if (ciphertext.isEmpty) return ciphertext;
    try {
      // Base64-decode the ciphertext
      final raw = base64.decode(ciphertext);
      if (raw.length < 16) return ciphertext;

      // Verify "Salted__" header (first 8 bytes)
      final header = String.fromCharCodes(raw.sublist(0, 8));
      if (header != 'Salted__') return ciphertext;

      final salt = raw.sublist(8, 16);
      final data = raw.sublist(16);

      final (key, iv) = _evpBytesToKey(_passphrase, salt);

      final encrypter =
          enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc));
      final decrypted =
          encrypter.decrypt(enc.Encrypted(Uint8List.fromList(data)), iv: enc.IV(iv));

      // CryptoJS wraps values with JSON.stringify — try JSON.parse first
      try {
        final parsed = jsonDecode(decrypted);
        if (parsed is String) return parsed;
        return parsed.toString();
      } catch (_) {
        return decrypted.trim();
      }
    } catch (_) {
      // Not encrypted, or wrong key — return as-is so old plain messages show
      return ciphertext;
    }
  }

  // ── EVP_BytesToKey ─────────────────────────────────────────────────────────
  // OpenSSL-compatible key+IV derivation used by CryptoJS when a passphrase
  // string (not a WordArray) is passed to AES.encrypt.
  //   D_i = MD5( D_{i-1} + passphrase + salt )
  // Concatenate until we have 32 (key) + 16 (IV) = 48 bytes.

  static (Uint8List key, Uint8List iv) _evpBytesToKey(
      String passphrase, List<int> salt) {
    const keyLen = 32;
    const ivLen = 16;
    final pass = utf8.encode(passphrase);
    final derived = <int>[];
    var block = <int>[];

    while (derived.length < keyLen + ivLen) {
      final hash = md5.convert([...block, ...pass, ...salt]);
      block = hash.bytes;
      derived.addAll(block);
    }

    return (
      Uint8List.fromList(derived.sublist(0, keyLen)),
      Uint8List.fromList(derived.sublist(keyLen, keyLen + ivLen)),
    );
  }

  static Uint8List _randomBytes(int n) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => rng.nextInt(256)));
  }
}
