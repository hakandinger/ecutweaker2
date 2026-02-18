import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';

class BluetoothConnectionScreen extends StatefulWidget {
  const BluetoothConnectionScreen({super.key});

  @override
  State<BluetoothConnectionScreen> createState() =>
      _BluetoothConnectionScreenState();
}

class _BluetoothConnectionScreenState extends State<BluetoothConnectionScreen> {
  bool _scanningUi = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  Future<void> _startScan() async {
    final provider = context.read<ConnectionProvider>();
    setState(() => _scanningUi = true);

    try {
      await provider.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _scanningUi = false);
    }
  }

  Future<void> _connect(ScanResult r) async {
    final provider = context.read<ConnectionProvider>();
    final name =
        r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.device.remoteId.str;

    try {
      await provider.connect(r.device.remoteId.str);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to $name'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connect failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();
    final devices = provider.scanResults;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE OBD Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanningUi ? null : _startScan,
          ),
          if (provider.isConnected)
            IconButton(
              icon: const Icon(Icons.link_off),
              onPressed: provider.disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_scanningUi)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.withOpacity(0.1),
              child: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 16),
                  Text('Scanning for BLE devices...'),
                ],
              ),
            ),
          Expanded(
            child:
                devices.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _scanningUi ? 'Searching...' : 'No devices found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _scanningUi ? null : _startScan,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Scan Again'),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final r = devices[index];
                        final dev = r.device;
                        final name =
                            dev.platformName.isNotEmpty
                                ? dev.platformName
                                : 'Unknown';
                        final id = dev.remoteId.str;
                        final rssi = r.rssi;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.bluetooth,
                              color: rssi > -70 ? Colors.blue : Colors.grey,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '$id • $rssi dBm',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            trailing: ElevatedButton(
                              onPressed:
                                  provider.isConnecting
                                      ? null
                                      : () => _connect(r),
                              child: const Text('Connect'),
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
