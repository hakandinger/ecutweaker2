import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ecu_layout.dart';
import '../services/ecu_layout_service.dart';
import '../providers/ecu_data_provider.dart';
import '../providers/connection_provider.dart';

/// ECU detay ekranı - seçili ECU'nun kategorilerini ve ekranlarını gösterir
class EcuDetailScreen extends StatefulWidget {
  final String ecuName;

  const EcuDetailScreen({super.key, required this.ecuName});

  @override
  State<EcuDetailScreen> createState() => _EcuDetailScreenState();
}

class _EcuDetailScreenState extends State<EcuDetailScreen> {
  final _layoutService = EcuLayoutService();
  Map<String, List<String>> _categories = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    // Load ECU protocol configuration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectionProvider = Provider.of<ConnectionProvider>(
        context,
        listen: false,
      );
      connectionProvider.setActiveEcu(widget.ecuName, _layoutService);
    });
  }

  Future<void> _loadCategories() async {
    print('[EcuDetailScreen] Loading categories for: ${widget.ecuName}');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories = await _layoutService.getEcuCategories(widget.ecuName);
      print('[EcuDetailScreen] Got ${categories.length} categories');
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('[EcuDetailScreen] Error loading categories: $e');
      print('[EcuDetailScreen] Stack trace: $stackTrace');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.ecuName)),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: $_error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadCategories,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : _categories.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No screens found for ${widget.ecuName}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('Layout file might be missing or empty'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadCategories,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories.keys.elementAt(index);
                  final screens = _categories[category]!;

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ExpansionTile(
                      title: Text(
                        category,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      leading: const Icon(Icons.folder),
                      children:
                          screens.map((screenName) {
                            return ListTile(
                              leading: const Icon(Icons.wysiwyg),
                              title: Text(screenName),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => EcuScreenView(
                                          ecuName: widget.ecuName,
                                          screenName: screenName,
                                        ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                    ),
                  );
                },
              ),
    );
  }
}

/// Tekil ECU ekranını render eden widget
class EcuScreenView extends StatefulWidget {
  final String ecuName;
  final String screenName;

  const EcuScreenView({
    super.key,
    required this.ecuName,
    required this.screenName,
  });

  @override
  State<EcuScreenView> createState() => _EcuScreenViewState();
}

class _EcuScreenViewState extends State<EcuScreenView> {
  final _layoutService = EcuLayoutService();
  ScreenConfig? _screenConfig;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadScreen();
  }

  @override
  void dispose() {
    // Stop polling when screen is disposed
    final connectionProvider = Provider.of<ConnectionProvider>(
      context,
      listen: false,
    );
    connectionProvider.stopPolling();
    super.dispose();
  }

  Future<void> _loadScreen() async {
    print(
      '[EcuScreenView] Loading screen: ${widget.screenName} for ${widget.ecuName}',
    );
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final screen = await _layoutService.getScreen(
        widget.ecuName,
        widget.screenName,
      );
      print(
        '[EcuScreenView] Screen loaded: ${screen != null ? "Success" : "Null"}',
      );
      if (screen != null) {
        print(
          '[EcuScreenView] Labels: ${screen.labels.length}, Displays: ${screen.displays.length}, Inputs: ${screen.inputs.length}, Buttons: ${screen.buttons.length}',
        );
        print('[EcuScreenView] Screen size: ${screen.width}x${screen.height}');

        // Register display requests for polling
        _registerDisplayRequests(screen);
      }
      setState(() {
        _screenConfig = screen;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('[EcuScreenView] Error loading screen: $e');
      print('[EcuScreenView] Stack trace: $stackTrace');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.screenName)),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: $_error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadScreen,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : _screenConfig == null
              ? const Center(child: Text('Screen not found'))
              : _buildScreenContent(),
    );
  }

  Widget _buildScreenContent() {
    final config = _screenConfig!;

    print('[EcuScreenView] Building modern layout');
    print(
      '[EcuScreenView] Rendering ${config.labels.length} labels, ${config.displays.length} displays, ${config.inputs.length} inputs, ${config.buttons.length} buttons',
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withOpacity(0.8),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Labels Section (başlıklar ve açıklamalar)
            if (config.labels.isNotEmpty) ...[
              _buildSectionHeader('Bilgiler', Icons.info_outline),
              const SizedBox(height: 8),
              ...config.labels.map(_buildModernLabel),
              const SizedBox(height: 24),
            ],

            // Displays Section (okunan değerler)
            if (config.displays.isNotEmpty) ...[
              _buildSectionHeader('Canlı Veriler', Icons.sensors),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: config.displays.map(_buildModernDisplay).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Inputs Section (kullanıcı girişleri)
            if (config.inputs.isNotEmpty) ...[
              _buildSectionHeader('Parametreler', Icons.tune),
              const SizedBox(height: 8),
              ...config.inputs.map(_buildModernInput),
              const SizedBox(height: 24),
            ],

            // Buttons Section
            if (config.buttons.isNotEmpty) ...[
              _buildSectionHeader('İşlemler', Icons.touch_app),
              const SizedBox(height: 8),
              ...config.buttons.map(_buildModernButton),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  // Modern layout metodları (JSON'dan sadece text/request alır)
  Widget _buildModernLabel(LabelWidget label) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.label_outline,
              size: 20,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      label.font.bold ? FontWeight.bold : FontWeight.normal,
                  fontStyle:
                      label.font.italic ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDisplay(DisplayWidget display) {
    return Card(
      elevation: 4,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        child: Consumer<EcuDataProvider>(
          builder: (context, dataProvider, child) {
            final paramName = display.text;
            final value = dataProvider.getParameter(paramName) ?? '---';

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display.text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  value.toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildModernInput(InputWidget input) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: InputDecoration(
            labelText: input.text,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: Icon(
              Icons.edit,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          onSubmitted: (value) {
            print('Input submitted: $value for ${input.request}');
            // TODO: Send value to ECU
          },
        ),
      ),
    );
  }

  Widget _buildModernButton(ButtonWidget button) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          print('Button pressed: ${button.request}');
          // TODO: Execute button request
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_arrow,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Text(
                button.text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Register display requests for automatic polling
  void _registerDisplayRequests(ScreenConfig screen) {
    final parameterToRequest = <String, String>{};
    for (final display in screen.displays) {
      final parameterKey = display.text;
      final requestName = display.request;
      if (parameterKey.isEmpty || requestName.isEmpty) continue;
      parameterToRequest[parameterKey] = requestName;
    }

    if (parameterToRequest.isEmpty) {
      print('[EcuScreenView] No display requests to register');
      return;
    }

    print(
      '[EcuScreenView] Registering ${parameterToRequest.length} display requests',
    );

    final connectionProvider = Provider.of<ConnectionProvider>(
      context,
      listen: false,
    );

    final dataProvider = Provider.of<EcuDataProvider>(context, listen: false);

    // Set data provider for updates
    connectionProvider.setDataProvider(dataProvider);

    // Register requests
    connectionProvider.registerParameterRequests(parameterToRequest);

    // Start polling if connected
    if (connectionProvider.isConnected) {
      connectionProvider.startPolling();
    }
  }
}
