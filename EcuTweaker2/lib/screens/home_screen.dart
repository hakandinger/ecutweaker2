import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/ecu_data_provider.dart';
import '../services/logger_service.dart';
import 'connection_screen.dart';
import 'ecu_list_screen.dart';
import 'bluetooth_connection_screen.dart';
import 'log_screen.dart';
import '../utils/share_log_file.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const EcuListScreen(),
    const BluetoothConnectionScreen(),
    const SettingsPlaceholder(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EcuTweaker 2'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Log Dosyasını Paylaş',
            onPressed: () async {
              try {
                await shareLogFile();
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Paylaşım hatası: $e')));
              }
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'ECU'),
          NavigationDestination(
            icon: Icon(Icons.settings_input_antenna),
            label: 'Connection',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = LoggerService();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.description),
            title: const Text('System Logs'),
            subtitle: Consumer<LoggerService>(
              builder: (context, logger, _) {
                return Text('${logger.logs.length} entries');
              },
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('EcuTweaker 2'),
                const Text('Version: 2.0.0'),
                const SizedBox(height: 16),
                FutureBuilder<String>(
                  future: logger.getLogFilePath(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Log File:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            snapshot.data!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
