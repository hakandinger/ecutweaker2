import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Log dosyasını paylaşmak için yardımcı fonksiyon
Future<void> shareLogFile() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/ecutweaker2_log.txt');
  if (await file.exists()) {
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'EcuTweaker2 Log Dosyası');
  } else {
    throw Exception('Log dosyası bulunamadı!');
  }
}
