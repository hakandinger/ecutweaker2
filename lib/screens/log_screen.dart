import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/logger_service.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  LogLevel? _filterLevel;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Logs'),
        actions: [
          // Filter
          PopupMenuButton<LogLevel?>(
            icon: Icon(
              _filterLevel != null
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            tooltip: 'Filter by level',
            onSelected: (level) {
              setState(() {
                _filterLevel = level;
              });
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.filter_alt_off),
                        SizedBox(width: 8),
                        Text('All'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: LogLevel.debug,
                    child: Row(
                      children: [
                        Icon(Icons.bug_report, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('Debug'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: LogLevel.info,
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text('Info'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: LogLevel.warning,
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text('Warning'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: LogLevel.error,
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Error'),
                      ],
                    ),
                  ),
                ],
          ),
          // Auto-scroll toggle
          IconButton(
            icon: Icon(_autoScroll ? Icons.arrow_downward : Icons.pause),
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
          ),
          // Export
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export logs',
            onPressed: () async {
              final logger = LoggerService();
              final logs = await logger.exportLogs();
              if (logs.isNotEmpty) {
                Share.share(logs, subject: 'EcuTweaker Logs');
              }
            },
          ),
          // Clear
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear logs',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Clear Logs'),
                      content: const Text(
                        'Are you sure you want to clear all logs?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
              );

              if (confirmed == true) {
                LoggerService().clear();
                LoggerService().clearFile();
              }
            },
          ),
        ],
      ),
      body: Consumer<LoggerService>(
        builder: (context, logger, child) {
          // Filter logs
          final filteredLogs =
              _filterLevel == null
                  ? logger.logs
                  : logger.logs
                      .where((log) => log.level == _filterLevel)
                      .toList();

          // Auto-scroll to bottom when new logs arrive
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });

          if (filteredLogs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No logs available',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: filteredLogs.length,
            itemBuilder: (context, index) {
              final log = filteredLogs[index];
              return _buildLogEntry(log);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _scrollToBottom,
        tooltip: 'Scroll to bottom',
        child: const Icon(Icons.arrow_downward),
      ),
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: log.toString()));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Log copied to clipboard'),
              duration: Duration(seconds: 1),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time
              Text(
                log.formattedTime,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              // Icon
              Icon(log.icon, size: 16, color: log.color),
              const SizedBox(width: 8),
              // Message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (log.tag != null) ...[
                      Text(
                        log.tag!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      log.message,
                      style: TextStyle(fontSize: 13, color: log.color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
