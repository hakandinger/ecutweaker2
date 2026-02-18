import 'dart:io';
import 'package:path_provider/path_provider.dart';

// LogWriter kaldırıldı, tüm loglar LoggerService ile kaydediliyor.
/// Uygulama loglarını dosyaya yazmak için yardımcı sınıf
class LogWriter {
  static File? _logFile;

  /// Log dosyasını hazırla (uygulama başında çağır)
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/ecutweaker2_log.txt');
    _logFile = file;
    if (!(await file.exists())) {
      await file.create();
    }
  }

  /// Log satırı ekle
  static Future<void> write(String line) async {
    if (_logFile == null) return;
    await _logFile!.writeAsString(line + '\n', mode: FileMode.append);
  }
}
