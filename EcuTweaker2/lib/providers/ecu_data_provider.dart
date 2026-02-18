import 'package:flutter/material.dart';
import '../utils/obd2_parser.dart';

/// Manages ECU data and parameters
class EcuDataProvider with ChangeNotifier {
  final Map<String, dynamic> _parameters = {};
  String? _currentEcu;
  String? _currentScreen;

  Map<String, dynamic> get parameters => _parameters;
  String? get currentEcu => _currentEcu;
  String? get currentScreen => _currentScreen;

  /// Set current ECU
  void setCurrentEcu(String ecuName) {
    _currentEcu = ecuName;
    notifyListeners();
  }

  /// Set current screen
  void setCurrentScreen(String screenName) {
    _currentScreen = screenName;
    notifyListeners();
  }

  /// Update parameter value
  void updateParameter(String key, dynamic value) {
    debugPrint('[updateParameter] key=$key value=$value');
    _parameters[key] = value;
    notifyListeners();
  }

  /// Get parameter value
  dynamic getParameter(String key) {
    return _parameters[key];
  }

  /// Clear all parameters
  void clearParameters() {
    _parameters.clear();
    notifyListeners();
  }

  // Ekranda gösterilecek parametreyi (ör: RPM, Speed) insan okunur değere çevirerek sakla
  // value: ham OBD2 yanıtı (ör: 410C0FA0)
  // key: display.text (ör: RPM)
  // Eğer display/request eşleşmesi varsa, parse et
  void setParameter(String key, dynamic value, {String? request}) {
    String displayValue = value?.toString() ?? '';
    if (request != null && value is String) {
      displayValue = Obd2Parser.parse(request, value);
    }
    _parameters[key] = displayValue;
    notifyListeners();
  }

  void onRawObdResponse(String raw) {
    // şimdilik sadece sakla/logla, sonra parse ederiz
    lastRaw = raw;
    notifyListeners();
  }

  String? lastRaw;
}
