import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import 'bluetooth_connection_screen.dart';

enum ConnectionType { bluetooth, usb }

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  ConnectionType _selectedType = ConnectionType.bluetooth;

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection Type
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection Type',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<ConnectionType>(
                        segments: const [
                          ButtonSegment(
                            value: ConnectionType.bluetooth,
                            label: Text('Bluetooth (BLE)'),
                            icon: Icon(Icons.bluetooth),
                          ),
                          ButtonSegment(
                            value: ConnectionType.usb,
                            label: Text('USB'),
                            icon: Icon(Icons.usb),
                          ),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _selectedType = newSelection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildStatusIndicator(provider),
                      if (provider.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Error: ${provider.errorMessage}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Available Devices
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Devices',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child:
                              _selectedType == ConnectionType.bluetooth
                                  ? _buildBleDeviceList(provider)
                                  : _buildUsbPlaceholder(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action button
              FilledButton.icon(
                onPressed:
                    provider.isConnected
                        ? () => provider.disconnect()
                        : provider.isConnecting
                        ? null
                        : () => _showDevicePicker(context),
                icon: Icon(
                  provider.isConnected ? Icons.link_off : Icons.search,
                ),
                label: Text(
                  provider.isConnected
                      ? 'Disconnect'
                      : provider.isConnecting
                      ? 'Connecting...'
                      : 'Scan Devices',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(ConnectionProvider provider) {
    IconData icon;
    String text;
    Color color;

    switch (provider.status) {
      case ConnectionStatus.connected:
        icon = Icons.check_circle;
        text = 'Connected to ${provider.deviceName ?? "Unknown"}';
        color = Colors.green;
        break;
      case ConnectionStatus.connecting:
        icon = Icons.sync;
        text = 'Connecting...';
        color = Colors.orange;
        break;
      case ConnectionStatus.error:
        icon = Icons.error;
        text = 'Connection Error';
        color = Colors.red;
        break;
      case ConnectionStatus.disconnected:
        icon = Icons.link_off;
        text = 'Disconnected';
        color = Colors.grey;
        break;
    }

    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color)),
      ],
    );
  }

  Widget _buildBleDeviceList(ConnectionProvider provider) {
    final devices = provider.scanResults;

    if (devices.isEmpty) {
      return Center(
        child: Text(
          'No devices. Tap "Scan Devices".',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final r = devices[index];
        final dev = r.device;
        final name =
            dev.platformName.isNotEmpty ? dev.platformName : 'Unknown Device';
        final id = dev.remoteId.str;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(name),
            subtitle: Text('$id • ${r.rssi} dBm'),
            trailing: ElevatedButton(
              onPressed:
                  provider.isConnecting
                      ? null
                      : () async {
                        try {
                          await provider.connect(id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Connected to $name'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Connection failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
              child: const Text('Connect'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsbPlaceholder() {
    return Center(
      child: Text(
        'USB connection not implemented yet',
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Future<void> _showDevicePicker(BuildContext context) async {
    if (_selectedType == ConnectionType.bluetooth) {
      // BLE device picker screen (scan + select)
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BluetoothConnectionScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('USB connection not implemented yet'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
