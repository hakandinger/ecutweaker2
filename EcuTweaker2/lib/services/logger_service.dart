import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? tag;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
  });

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  Color get color {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (level) {
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.error:
        return Icons.error;
    }
  }

  @override
  String toString() {
    final tagStr = tag != null ? '[$tag] ' : '';
    return '[$formattedTime] [${level.name.toUpperCase()}] $tagStr$message';
  }
}

class LoggerService extends ChangeNotifier {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;

  LoggerService._internal() {
    _initLogFile();
  }

  final List<LogEntry> _logs = [];
  final int _maxLogs = 1000; // Keep last 1000 logs in memory
  File? _logFile;

  List<LogEntry> get logs => List.unmodifiable(_logs);

  Future<void> _initLogFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/ecutweaker_log.txt');

      // Create file if doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }

      // Add startup log
      info('Logger initialized', tag: 'Logger');
    } catch (e) {
      print('Failed to initialize log file: $e');
    }
  }

  void _addLog(LogEntry entry) {
    _logs.add(entry);

    // Keep only recent logs
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    // Write to file
    _writeToFile(entry);

    // Also print to console
    print(entry.toString());

    notifyListeners();
  }

  Future<void> _writeToFile(LogEntry entry) async {
    try {
      if (_logFile != null) {
        await _logFile!.writeAsString(
          '${entry.toString()}\n',
          mode: FileMode.append,
        );
      }
    } catch (e) {
      print('Failed to write log to file: $e');
    }
  }

  void debug(String message, {String? tag}) {
    _addLog(
      LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.debug,
        message: message,
        tag: tag,
      ),
    );
  }

  void info(String message, {String? tag}) {
    _addLog(
      LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        message: message,
        tag: tag,
      ),
    );
  }

  void warning(String message, {String? tag}) {
    _addLog(
      LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.warning,
        message: message,
        tag: tag,
      ),
    );
  }

  void error(String message, {String? tag}) {
    _addLog(
      LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.error,
        message: message,
        tag: tag,
      ),
    );
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  Future<void> clearFile() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
        info('Log file cleared', tag: 'Logger');
      }
    } catch (e) {
      error('Failed to clear log file: $e', tag: 'Logger');
    }
  }

  Future<String> getLogFilePath() async {
    if (_logFile != null) {
      return _logFile!.path;
    }
    return '';
  }

  Future<String> exportLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
      return '';
    } catch (e) {
      error('Failed to export logs: $e', tag: 'Logger');
      return '';
    }
  }
}
