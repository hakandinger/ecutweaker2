import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/logger_service.dart';
import 'ecu_data_provider.dart';
import '../services/ecu_layout_service.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class ConnectionProvider extends ChangeNotifier {
  // ---------- UI state ----------
  ConnectionStatus status = ConnectionStatus.disconnected;
  String? errorMessage;
  String? deviceName;

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isConnecting => status == ConnectionStatus.connecting;

  // ---------- BLE scan (istersen ConnectionScreen’de kullanırsın) ----------
  final List<ScanResult> scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSub;

  // ---------- BLE connection ----------
  BluetoothDevice? _device;
  BluetoothDevice? get device => _device;

  List<BluetoothService> _services = [];
  BluetoothCharacteristic? _tx; // write
  BluetoothCharacteristic? _rx; // notify

  StreamSubscription<List<int>>? _rxSub;

  // ---------- ELM327 response handling ----------
  final StringBuffer _buf = StringBuffer();
  final StreamController<String> _incomingController =
      StreamController<String>.broadcast();
  Stream<String> get incomingResponses => _incomingController.stream;

  // ---------- ECU context ----------
  String? _activeEcuName;
  EcuDataProvider? _dataProvider;

  // paramName -> requestName (layout’tan gelen)
  final Map<String, String> _paramRequests = {};

  Timer? _pollTimer;
  bool _polling = false;

  // ---------------- Public API expected by your screens ----------------

  Future<void> setActiveEcu(
    String ecuName,
    EcuLayoutService layoutService,
  ) async {
    _activeEcuName = ecuName;
    debugPrint('[ConnectionProvider] Active ECU set: $_activeEcuName');

    // ECU protokol ve CAN adreslerini JSON'dan oku
    final protocol = await layoutService.loadEcuProtocol(ecuName);
    if (protocol != null && protocol.obd != null) {
      final sendId = protocol.obd!.sendId;
      final recvId = protocol.obd!.recvId;
      debugPrint('[ConnectionProvider] CAN sendId: $sendId, recvId: $recvId');
      // Burada sendId ve recvId ile CAN başlatma/init işlemleri yapılabilir
      // Örneğin: await tryCmd('ATCF$sendId'); veya benzeri
      // Eğer özel bir komut/protokol gerekiyorsa burada ekle
    } else {
      debugPrint('[ConnectionProvider] CAN protokol veya OBDConfig bulunamadı');
    }
  }

  void setDataProvider(EcuDataProvider provider) {
    _dataProvider = provider;
  }

  void registerParameterRequests(Map<String, String> parameterToRequest) {
    _paramRequests
      ..clear()
      ..addAll(parameterToRequest);

    debugPrint(
      '[ConnectionProvider] Registered ${_paramRequests.length} parameter requests',
    );
  }

  void startPolling({Duration interval = const Duration(milliseconds: 700)}) {
    if (!isConnected) return;
    if (_paramRequests.isEmpty) return;

    stopPolling();
    _polling = true;

    debugPrint(
      '[ConnectionProvider] Polling started (${interval.inMilliseconds}ms)',
    );

    // Round-robin polling
    final entries = _paramRequests.entries.toList();
    int i = 0;

    _pollTimer = Timer.periodic(interval, (_) async {
      if (!isConnected || !_polling || entries.isEmpty) return;

      final e = entries[i % entries.length];
      i++;

      final paramName = e.key;
      final requestName = e.value;

      try {
        final cmd = buildObdCommand(requestName);
        if (cmd == null) return;

        final resp = await request(cmd, timeout: const Duration(seconds: 2));
        // OBD2 yanıtını display/request eşleşmesiyle birlikte ilet
        _dataProvider?.setParameter(paramName, resp, request: requestName);
      } catch (err) {
        // polling sırasında hata olursa UI’yı error’a çekmeyelim, sadece logla
        debugPrint(
          '[ConnectionProvider] Poll error $paramName/$requestName: $err',
        );
      }
    });

    notifyListeners();
  }

  void stopPolling() {
    _polling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    debugPrint('[ConnectionProvider] Polling stopped');
    notifyListeners();
  }

  // ---------------- BLE permissions & adapter ----------------

  Future<bool> _ensurePermissions() async {
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    final loc = await Permission.locationWhenInUse.request();
    return scan.isGranted && connect.isGranted && loc.isGranted;
  }

  Future<void> _ensureBtOn() async {
    final st = await FlutterBluePlus.adapterState.first;
    if (st != BluetoothAdapterState.on) {
      throw Exception('Bluetooth kapalı');
    }
  }

  // ---------------- Scan (optional) ----------------

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    errorMessage = null;

    final ok = await _ensurePermissions();
    if (!ok) {
      status = ConnectionStatus.error;
      errorMessage = 'Bluetooth izinleri verilmedi';
      notifyListeners();
      return;
    }

    await _ensureBtOn();

    scanResults.clear();
    notifyListeners();

    await FlutterBluePlus.stopScan();

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      final map = <String, ScanResult>{};
      for (final r in results) {
        map[r.device.remoteId.str] = r;
      }
      final list =
          map.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
      scanResults
        ..clear()
        ..addAll(list);
      notifyListeners();
    });

    await FlutterBluePlus.startScan(timeout: timeout);
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  // ---------------- Connect / Disconnect ----------------

  Future<void> connect(String deviceId) async {
    errorMessage = null;
    status = ConnectionStatus.connecting;
    notifyListeners();

    final ok = await _ensurePermissions();
    if (!ok) {
      status = ConnectionStatus.error;
      errorMessage = 'Bluetooth izinleri verilmedi';
      notifyListeners();
      return;
    }

    await stopScan();
    await disconnect(); // varsa önce kapat

    _device = BluetoothDevice.fromId(deviceId);

    try {
      await _device!.connect(timeout: const Duration(seconds: 12));
      deviceName =
          _device!.platformName.isNotEmpty
              ? _device!.platformName
              : _device!.remoteId.str;

      status = ConnectionStatus.connected;
      notifyListeners();

      await _discoverAndBindUart();

      // ELM init (isteğe bağlı ama çoğu cihazda şart)
      // echo off, linefeeds off, spaces off, headers off
      await safeInitElm();
    } catch (e) {
      status = ConnectionStatus.error;
      errorMessage = 'Connection failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    stopPolling();

    try {
      _rxSub?.cancel();
      _rxSub = null;

      if (_rx != null) {
        try {
          await _rx!.setNotifyValue(false);
        } catch (_) {}
      }

      _tx = null;
      _rx = null;
      _services.clear();
      _buf.clear();

      if (_device != null) {
        try {
          await _device!.disconnect();
        } catch (_) {}
      }
    } finally {
      _device = null;
      deviceName = null;
      status = ConnectionStatus.disconnected;
      notifyListeners();
    }
  }

  Future<void> _discoverAndBindUart() async {
    if (_device == null) throw Exception('No device');

    _services = await _device!.discoverServices();

    BluetoothCharacteristic? foundTx;
    BluetoothCharacteristic? foundRx;

    // Heuristic: ilk notify + ilk write
    for (final s in _services) {
      for (final c in s.characteristics) {
        final p = c.properties;
        if (foundRx == null && (p.notify || p.indicate)) foundRx = c;
        if (foundTx == null && (p.write || p.writeWithoutResponse)) foundTx = c;
        if (foundTx != null && foundRx != null) break;
      }
      if (foundTx != null && foundRx != null) break;
    }

    if (foundTx == null || foundRx == null) {
      status = ConnectionStatus.error;
      errorMessage = 'UART char bulunamadı (TX write + RX notify gerekli).';
      notifyListeners();
      throw Exception(errorMessage);
    }

    _tx = foundTx;
    _rx = foundRx;

    await _rx!.setNotifyValue(true);

    _rxSub?.cancel();
    _rxSub = _rx!.onValueReceived.listen(_handleIncoming);
  }

  // ---------------- ELM init ----------------

  Future<void> safeInitElm() async {
    // Bazı cihazlar ilk komutta cevap vermeyebilir -> try/catch
    Future<void> tryCmd(String cmd) async {
      try {
        await request(cmd, timeout: const Duration(seconds: 2));
      } catch (_) {}
    }

    await tryCmd('ATZ'); // reset
    await tryCmd('ATE0'); // echo off
    await tryCmd('ATL0'); // linefeeds off
    await tryCmd('ATS0'); // spaces off
    await tryCmd('ATH0'); // headers off

    // ECU/protocol seçimi sende setActiveEcu ile gelecekse burada eklenir.
    // Örn: await tryCmd('ATSP0'); // auto protocol
  }

  // ---------------- Incoming parse ----------------

  void _handleIncoming(List<int> bytes) {
    final s = ascii.decode(Uint8List.fromList(bytes), allowInvalid: true);
    _buf.write(s);

    final full = _buf.toString();
    if (!full.contains('>')) return;

    final parts = full.split('>');
    final msg = parts.first.trim();

    _buf.clear();
    if (parts.length > 1) _buf.write(parts.sublist(1).join('>'));

    if (msg.isNotEmpty) {
      LoggerService().info('CAN RECV: $msg', tag: 'CAN');
      _incomingController.add(msg);
    }
  }

  // ---------------- Send / Request ----------------

  Future<void> sendCommand(String cmd) async {
    if (!isConnected || _tx == null) throw Exception('Not connected');

    final toSend = cmd.endsWith('\r') ? cmd : '$cmd\r';
    final data = ascii.encode(toSend);
    final withoutResp = _tx!.properties.writeWithoutResponse;

    LoggerService().info('CAN SENT: $cmd', tag: 'CAN');
    await _tx!.write(data, withoutResponse: withoutResp);
  }

  Future<String> request(
    String cmd, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final completer = Completer<String>();
    late StreamSubscription sub;

    sub = incomingResponses.listen((line) {
      if (!completer.isCompleted) completer.complete(line);
      sub.cancel();
    });

    await sendCommand(cmd);

    return completer.future.timeout(
      timeout,
      onTimeout: () async {
        await sub.cancel();
        throw TimeoutException('No response for $cmd');
      },
    );
  }

  /// Layout’tan gelen requestName’i gerçek OBD komutuna çevir.
  /// Şimdilik “requestName zaten OBD komutu” varsayıyorum.
  /// Örnek:
  /// - "010C" -> "010C"
  /// - "22F190" -> "22F190"
  /// - "ATZ" -> "ATZ"
  String? buildObdCommand(String requestName) {
    final r = requestName.trim();
    if (r.isEmpty) return null;

    // Eğer layout "request" alanı 'request="010C"' gibi geliyorsa aynen kullan.
    // Eğer farklı format varsa burada map/parse yaparız.
    return r;
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _rxSub?.cancel();
    _incomingController.close();
    super.dispose();
  }
}
