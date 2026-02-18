/// OBD2 hex yanıtlarını insan okunur değere çeviren yardımcı fonksiyonlar
/// Örnek: "410C0FA0" (RPM) -> 1000 rpm

class Obd2Parser {
  /// PID'e göre hex yanıtı parse et
  /// [request] örn: "010C" (RPM), "010D" (Speed), "0105" (Temp)
  /// [raw] örn: "410C0FA0"
  static String parse(String request, String raw) {
    // Sadece "41xx" ile başlayan OBD yanıtlarını parse et
    // Özel başlıklar ve Mode 01 dışı yanıtlar için Java'daki mantık
    if (raw.startsWith('6180') && raw.length > 39) {
      // Eski ECU auto identification
      final supplier = raw.substring(16, 22);
      final softVersion = raw.substring(32, 36);
      final version = raw.substring(36, 40);
      final diagVersion = raw.substring(14, 16);
      return 'Supplier: $supplier, Soft: $softVersion, Version: $version, Diag: $diagVersion';
    }
    if (raw.startsWith('62F1A0') && raw.length > 6) {
      return 'Diag Version: ' + raw.substring(6);
    }
    if (raw.startsWith('62F18A') && raw.length > 6) {
      return 'Supplier: ' + raw.substring(6);
    }
    if (raw.startsWith('62F194') && raw.length > 6) {
      return 'Soft Version: ' + raw.substring(6);
    }
    if (raw.startsWith('62F195') && raw.length > 6) {
      return 'Version: ' + raw.substring(6);
    }
    // Mode 01 ve PID'ler için mevcut mantık
    if (raw.length < 4 || !raw.startsWith('41')) return '---';
    try {
      final pid = request.substring(2).toUpperCase();
      final mode = request.substring(0, 2);
      if (mode == '01') {
        switch (pid) {
          case '0C': // RPM
            if (raw.length >= 8) {
              final a = int.parse(raw.substring(4, 6), radix: 16);
              final b = int.parse(raw.substring(6, 8), radix: 16);
              final rpm = ((a * 256) + b) / 4;
              return '${rpm.toStringAsFixed(0)} rpm';
            }
            return '---';
          case '0D': // Speed
            if (raw.length >= 6) {
              final a = int.parse(raw.substring(4, 6), radix: 16);
              return '$a km/h';
            }
            return '---';
          case '05': // Coolant Temp
            if (raw.length >= 6) {
              final a = int.parse(raw.substring(4, 6), radix: 16);
              return '${a - 40} °C';
            }
            return '---';
          case '11': // Throttle Position
            if (raw.length >= 6) {
              final a = int.parse(raw.substring(4, 6), radix: 16);
              final percent = (a * 100) / 255;
              return '${percent.toStringAsFixed(1)} %';
            }
            return '---';
          case '0F': // Intake Air Temp
            if (raw.length >= 6) {
              final a = int.parse(raw.substring(4, 6), radix: 16);
              return '${a - 40} °C';
            }
            return '---';
          case '10': // MAF (Mass Air Flow)
            if (raw.length >= 8) {
              final a = int.parse(raw.substring(4, 6), radix: 16);
              final b = int.parse(raw.substring(6, 8), radix: 16);
              final maf = ((a * 256) + b) / 100.0;
              return '${maf.toStringAsFixed(2)} g/s';
            }
            return '---';
          case '04': // Engine Load
            if (raw.length >= 6) {
              final a = int.parse(raw.substring(4, 6), radix: 16);
              final load = (a * 100) / 255;
              return '${load.toStringAsFixed(1)} %';
            }
            return '---';
          // Diğer PID'ler buraya eklenebilir
        }
      }
    } catch (_) {}
    return '---';
  }
}
