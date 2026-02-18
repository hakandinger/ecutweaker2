import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ecu_data_provider.dart';
import '../services/ecu_layout_service.dart';
import 'ecu_detail_screen.dart';

class EcuListScreen extends StatefulWidget {
  const EcuListScreen({super.key});

  @override
  State<EcuListScreen> createState() => _EcuListScreenState();
}

class _EcuListScreenState extends State<EcuListScreen> {
  final _layoutService = EcuLayoutService();
  late Future<List<_EcuListItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
  }

  Future<List<_EcuListItem>> _loadItems() async {
    final index = await _layoutService.loadDbIndex();
    if (index.isNotEmpty) {
      final items = index.entries
          .map(
            (e) => _EcuListItem(
              name: e.key,
              title:
                  e.value.ecuname?.trim().isNotEmpty == true
                      ? e.value.ecuname!
                      : e.key,
              subtitle: _buildSubtitle(e.value),
            ),
          )
          .toList(growable: false);
      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    }

    final names = await _layoutService.getAvailableEcus();
    return names
        .map((n) => _EcuListItem(name: n, title: n, subtitle: null))
        .toList(growable: false);
  }

  static String? _buildSubtitle(EcuDbEntry entry) {
    final parts = <String>[];
    final protocol = entry.protocol?.trim();
    if (protocol != null && protocol.isNotEmpty) {
      parts.add(protocol);
    }
    final group = entry.group?.trim();
    if (group != null && group.isNotEmpty) {
      parts.add(group);
    }
    if (entry.projects.isNotEmpty) {
      parts.add(entry.projects.join(', '));
    }
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EcuDataProvider>(
      builder: (context, provider, _) {
        return FutureBuilder<List<_EcuListItem>>(
          future: _itemsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = snapshot.data ?? const <_EcuListItem>[];
            if (items.isEmpty) {
              return Center(
                child: Text(
                  'No ECU definitions found (db.json empty or missing).',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _itemsFuture = _loadItems();
                });
                await _itemsFuture;
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final ecu = items[index];
                  final isSelected = provider.currentEcu == ecu.name;

                  return Card(
                    elevation: isSelected ? 4 : 1,
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          ecu.name.isNotEmpty ? ecu.name[0] : '?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      title: Text(
                        ecu.title,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle:
                          ecu.subtitle == null ? null : Text(ecu.subtitle!),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        provider.setCurrentEcu(ecu.name);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => EcuDetailScreen(ecuName: ecu.name),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _EcuListItem {
  final String name;
  final String title;
  final String? subtitle;

  const _EcuListItem({required this.name, required this.title, this.subtitle});
}
