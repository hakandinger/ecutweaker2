import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ecu_layout.dart';
import '../models/ecu_protocol_config.dart';

/// ECU JSON layout dosyalarını yükleyen ve parse eden servis
class EcuLayoutService {
  // Cache için layout'ları bellekte tut
  final Map<String, EcuLayout> _layoutCache = {};
  final Map<String, EcuProtocolConfig> _protocolCache = {};

  Future<Map<String, EcuDbEntry>> loadDbIndex() async {
    final dbJson = await _loadTextFile('assets/ecu/db.json', 'db.json') ?? '{}';
    final index = <String, EcuDbEntry>{};

    try {
      final map = json.decode(dbJson) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final key = entry.key;
        if (!key.endsWith('.json')) continue;
        final ecuName = key.replaceAll('.json', '');

        final value = entry.value;
        if (value is Map<String, dynamic>) {
          index[ecuName] = EcuDbEntry.fromJson(value);
        } else {
          index[ecuName] = const EcuDbEntry();
        }
      }
    } catch (e) {
      print('[EcuLayoutService] Could not parse db.json: $e');
    }

    return index;
  }

  Future<Directory> _getEcuDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/ecu');
  }

  Future<String?> _loadTextFile(String assetPath, String fileName) async {
    // 1) Documents directory (user-imported database)
    try {
      // In widget tests, platform channels used by path_provider can hang;
      // keep this probe bounded and fall back to assets quickly.
      final ecuDir = await _getEcuDir().timeout(
        const Duration(milliseconds: 250),
      );
      final file = File('${ecuDir.path}/$fileName');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {
      // ignore and fallback to assets
    }

    // 2) Bundled assets
    try {
      return await rootBundle.loadString(assetPath);
    } catch (_) {
      return null;
    }
  }

  /// Belirtilen ECU için protocol config yükle (.json dosyası)
  Future<EcuProtocolConfig?> loadEcuProtocol(String ecuName) async {
    // Cache'de varsa direkt döndür
    if (_protocolCache.containsKey(ecuName)) {
      return _protocolCache[ecuName];
    }

    try {
      final jsonString = await _loadTextFile(
        'assets/ecu/$ecuName.json',
        '$ecuName.json',
      );
      if (jsonString == null) {
        print('[EcuLayoutService] Protocol file not found for $ecuName');
        return null;
      }

      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final protocol = EcuProtocolConfig.fromJson(jsonData);
      _protocolCache[ecuName] = protocol;

      print(
        '[EcuLayoutService] Loaded ${protocol.requests.length} requests for $ecuName',
      );
      return protocol;
    } catch (e, stackTrace) {
      print('[EcuLayoutService] Error loading protocol for $ecuName: $e');
      print('[EcuLayoutService] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Request tanımını bul
  RequestDefinition? getRequestDefinition(String ecuName, String requestName) {
    final protocol = _protocolCache[ecuName];
    if (protocol == null) return null;

    return protocol.requests.firstWhere(
      (r) => r.name == requestName,
      orElse:
          () => RequestDefinition(
            name: requestName,
            sentbytes: '',
            replybytes: '',
            minbytes: 0,
          ),
    );
  }

  /// Belirtilen ECU için layout dosyasını yükle
  ///
  /// [ecuName]: ECU adı (örn: "ABS-ESP", "BCM", "MR20")
  /// Returns: Parse edilmiş EcuLayout objesi
  Future<EcuLayout?> loadEcuLayout(String ecuName) async {
    // Cache'de varsa direkt döndür
    if (_layoutCache.containsKey(ecuName)) {
      return _layoutCache[ecuName];
    }

    try {
      // Önce workspace'deki ../ecu/ klasöründen yüklemeyi dene
      final layout = await _loadFromWorkspace(ecuName);
      if (layout != null) {
        _layoutCache[ecuName] = layout;
        return layout;
      }

      // Workspace'de bulunamazsa assets'ten yüklemeyi dene
      final assetLayout = await _loadFromAssets(ecuName);
      if (assetLayout != null) {
        _layoutCache[ecuName] = assetLayout;
        return assetLayout;
      }

      return null;
    } catch (e) {
      print('Error loading ECU layout for $ecuName: $e');
      return null;
    }
  }

  /// Workspace'deki ../ecu/ klasöründen layout yükle
  /// Layout dosyası .json.layout uzantılı olmalı (UI düzeni için)
  Future<EcuLayout?> _loadFromWorkspace(String ecuName) async {
    try {
      final jsonString = await _loadTextFile(
        'assets/ecu/$ecuName.json.layout',
        '$ecuName.json.layout',
      );

      if (jsonString == null) {
        return null;
      }

      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return EcuLayout.fromJson(jsonData);
    } catch (e, stackTrace) {
      // Workspace'den okunamazsa (release build gibi) devam et
      print('[EcuLayoutService] Could not load from workspace: $e');
      print('[EcuLayoutService] Stack trace: $stackTrace');
    }
    return null;
  }

  /// Assets klasöründen layout yükle
  /// Layout dosyası .json.layout uzantılı olmalı (UI düzeni için)
  Future<EcuLayout?> _loadFromAssets(String ecuName) async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/ecu/$ecuName.json.layout',
      );
      print(
        '[EcuLayoutService] Assets layout loaded: ${jsonString.length} bytes',
      );
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      print('[EcuLayoutService] Assets JSON parsed successfully');
      final layout = EcuLayout.fromJson(jsonData);
      print(
        '[EcuLayoutService] Assets layout created with ${layout.screens.length} screens',
      );
      return layout;
    } catch (e, stackTrace) {
      print('[EcuLayoutService] Could not load layout from assets: $e');
      print('[EcuLayoutService] Assets stack trace: $stackTrace');
      return null;
    }
  }

  /// Tüm mevcut ECU'ları listele
  ///
  /// Returns: ECU adları listesi
  Future<List<String>> getAvailableEcus() async {
    final ecuList = <String>[];

    // Prefer db.json (same approach as legacy app's database index)
    final index = await loadDbIndex();
    if (index.isNotEmpty) {
      ecuList.addAll(index.keys);
      ecuList.sort();
      return ecuList;
    }

    // Fallback: list cached layouts if any
    ecuList.addAll(_layoutCache.keys);

    return ecuList;
  }

  /// Belirtilen ECU'nun kategori listesini al
  ///
  /// [ecuName]: ECU adı
  /// Returns: Kategori map'i (kategori adı -> ekran listesi)
  Future<Map<String, List<String>>> getEcuCategories(String ecuName) async {
    final layout = await loadEcuLayout(ecuName);
    return layout?.categories ?? {};
  }

  /// Belirtilen ECU ve ekran adı için screen config al
  ///
  /// [ecuName]: ECU adı
  /// [screenName]: Ekran adı
  /// Returns: ScreenConfig objesi
  Future<ScreenConfig?> getScreen(String ecuName, String screenName) async {
    final layout = await loadEcuLayout(ecuName);
    return layout?.screens[screenName];
  }

  /// Cache'i temizle
  void clearCache() {
    _layoutCache.clear();
    _protocolCache.clear();
  }
}

class EcuDbEntry {
  final String? protocol;
  final String? ecuname;
  final String? address;
  final String? group;
  final List<String> projects;

  const EcuDbEntry({
    this.protocol,
    this.ecuname,
    this.address,
    this.group,
    this.projects = const [],
  });

  factory EcuDbEntry.fromJson(Map<String, dynamic> json) {
    final projectsRaw = json['projects'];
    final projects =
        projectsRaw is List
            ? projectsRaw.whereType<String>().toList(growable: false)
            : const <String>[];

    return EcuDbEntry(
      protocol: json['protocol'] as String?,
      ecuname: json['ecuname'] as String?,
      address: json['address'] as String?,
      group: json['group'] as String?,
      projects: projects,
    );
  }
}
