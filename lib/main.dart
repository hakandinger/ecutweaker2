import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/connection_provider.dart';
import 'providers/ecu_data_provider.dart';
import 'services/logger_service.dart';

void main() {
  runApp(const EcuTweaker2App());
}

class EcuTweaker2App extends StatelessWidget {
  const EcuTweaker2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => LoggerService()),
        ChangeNotifierProvider(create: (_) => EcuDataProvider()),
      ],
      child: MaterialApp(
        title: 'EcuTweaker 2',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
