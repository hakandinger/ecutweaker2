import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class ClassicBluetoothScreen extends StatefulWidget {
  const ClassicBluetoothScreen({super.key});

  @override
  State<ClassicBluetoothScreen> createState() => _ClassicBluetoothScreenState();
}

class _ClassicBluetoothScreenState extends State<ClassicBluetoothScreen> {
  List<BluetoothDevice> _devices = [];
  bool _isLoading = false;

  BluetoothConnection? _connection;
  String? _connectedDeviceName;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = await _ensureBtPermissions();
    if (!ok) {
      _toast('Bluetooth izinleri verilmedi', isError: true);
      return;
    }

    // Bluetooth kapalıysa açtır (kullanıcıya dialog gösterir)
    await FlutterBluetoothSerial.instance.requestEnable();

    await _loadBondedDevices();
  }

  Future<bool> _ensureBtPermissions() async {
    // Android 12+ için gerekli
    final connect = await Permission.bluetoothConnect.request();
    final scan = await Permission.bluetoothScan.request();

    // Bazı cihazlarda bonded/scan için location da isteyebiliyor
    final loc = await Permission.locationWhenInUse.request();

    return connect.isGranted && scan.isGranted && loc.isGranted;
  }

  Future<void> _loadBondedDevices() async {
    setState(() => _isLoading = true);
    try {
      final ok = await _ensureBtPermissions();
      if (!ok) {
        _toast('Bluetooth izinleri verilmedi', isError: true);
        return;
      }

      final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      if (!mounted) return;

      setState(() {
        _devices = bonded.toList();
      });
    } catch (e) {
      _toast('Cihaz listesi alınamadı: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _isLoading = true);
    try {
      final ok = await _ensureBtPermissions();
      if (!ok) {
        _toast('Bluetooth izinleri verilmedi', isError: true);
        return;
      }

      // Eğer önceki bağlantı varsa kapat
      await _disconnectSilently();

      await FlutterBluetoothSerial.instance.cancelDiscovery();

      final connection = await BluetoothConnection.toAddress(device.address);
      if (!mounted) return;

      setState(() {
        _connection = connection;
        _connectedDeviceName = device.name ?? device.address;
      });

      _toast('Bağlandı: ${device.name ?? device.address}');

      // Bağlantı koparsa UI’yı güncelle
      connection.input
          ?.listen((data) {
            // İstersen burada gelen datayı işleyebilirsin
          })
          .onDone(() {
            if (!mounted) return;
            setState(() {
              _connection = null;
              _connectedDeviceName = null;
            });
            _toast('Bağlantı koptu', isError: true);
          });
    } catch (e) {
      _toast('Bağlantı başarısız: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnectSilently() async {
    try {
      _connection?.finish(); // politely close
      _connection?.dispose();
    } catch (_) {}
    _connection = null;
    _connectedDeviceName = null;
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    try {
      await _disconnectSilently();
      if (mounted) setState(() {});
      _toast('Bağlantı kesildi');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _disconnectSilently();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connection != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Klasik Bluetooth Cihazları'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadBondedDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
            child: Row(
              children: [
                Icon(
                  isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isConnected
                        ? 'Bağlı: $_connectedDeviceName'
                        : 'Bağlı cihaz yok',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                if (isConnected)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _disconnect,
                    child: const Text('Bağlantıyı Kes'),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _devices.isEmpty
                    ? const Center(
                      child: Text(
                        'Eşleşmiş cihaz bulunamadı.\nAyarlar > Bluetooth’dan önce eşleştir.',
                        textAlign: TextAlign.center,
                      ),
                    )
                    : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final name = device.name ?? 'Unknown';
                        final addr = device.address;

                        final isThisConnected =
                            isConnected &&
                            _connectedDeviceName == (device.name ?? addr);

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.bluetooth),
                            title: Text(name),
                            subtitle: Text(addr),
                            trailing: ElevatedButton(
                              onPressed:
                                  _isLoading
                                      ? null
                                      : () => _connectToDevice(device),
                              child: Text(isThisConnected ? 'Bağlı' : 'Bağlan'),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
