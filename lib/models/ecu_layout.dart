import 'dart:ui';

/// Ana layout yapısı - tüm ECU layout'unu temsil eder
class EcuLayout {
  final Map<String, ScreenConfig> screens;
  final Map<String, List<String>> categories;

  EcuLayout({required this.screens, required this.categories});

  factory EcuLayout.fromJson(Map<String, dynamic> json) {
    final screensMap = <String, ScreenConfig>{};
    final categoriesMap = <String, List<String>>{};

    final screensJson = json['screens'];
    if (screensJson is Map<String, dynamic>) {
      screensJson.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          screensMap[key] = ScreenConfig.fromJson(value, key);
        }
      });

      final categoriesJson = json['categories'];
      if (categoriesJson is Map<String, dynamic>) {
        categoriesJson.forEach((key, value) {
          if (value is List) {
            categoriesMap[key] = value.map((e) => e.toString()).toList();
          }
        });
      }
    } else if (screensJson is List) {
      // Support legacy/list-based schema used by some *.json.layout files.
      // Example:
      // {
      //   "screens": [ {"name": "Engine Data", "category": "Test", "elements": [...] } ]
      // }
      for (final raw in screensJson) {
        if (raw is! Map<String, dynamic>) continue;
        final screenName = (raw['name'] as String?)?.trim();
        if (screenName == null || screenName.isEmpty) continue;

        final category =
            (raw['category'] as String?)?.trim().isNotEmpty == true
                ? (raw['category'] as String)
                : 'Default';

        final elements = raw['elements'];
        final labels = <LabelWidget>[];
        final displays = <DisplayWidget>[];
        final inputs = <InputWidget>[];
        final buttons = <ButtonWidget>[];

        if (elements is List) {
          for (final el in elements) {
            if (el is! Map<String, dynamic>) continue;
            final type = (el['type'] as String?)?.toLowerCase().trim();
            final mapped = _mapLegacyElementToWidgetJson(el);
            if (mapped == null || type == null) continue;

            switch (type) {
              case 'label':
                labels.add(LabelWidget.fromJson(mapped));
              case 'display':
                displays.add(DisplayWidget.fromJson(mapped));
              case 'input':
                inputs.add(InputWidget.fromJson(mapped));
              case 'button':
                buttons.add(ButtonWidget.fromJson(mapped));
              default:
                // unknown element type; ignore
                break;
            }
          }
        }

        final width = (raw['width'] as num?)?.toDouble() ?? 9000;
        final height = (raw['height'] as num?)?.toDouble() ?? 6000;

        screensMap[screenName] = ScreenConfig(
          name: screenName,
          displays: displays,
          labels: labels,
          inputs: inputs,
          buttons: buttons,
          presend: const [],
          backgroundColor: _parseColor(null),
          width: width,
          height: height,
        );

        categoriesMap.putIfAbsent(category, () => <String>[]).add(screenName);
      }
    }

    // If categories are missing but screens exist, build a single default group.
    if (categoriesMap.isEmpty && screensMap.isNotEmpty) {
      categoriesMap['Default'] = screensMap.keys.toList();
    }

    return EcuLayout(screens: screensMap, categories: categoriesMap);
  }
}

Map<String, dynamic>? _mapLegacyElementToWidgetJson(Map<String, dynamic> el) {
  double numField(String key, double fallback) {
    final v = el[key];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? fallback;
  }

  final x = numField('x', 0);
  final y = numField('y', 0);
  final w = numField('width', 100);
  final h = numField('height', 50);
  final fontSize = numField('font_size', 10.0);

  final type = (el['type'] as String?)?.toLowerCase().trim();
  if (type == null) return null;

  final base = <String, dynamic>{
    'text': el['text']?.toString() ?? '',
    'request': el['request']?.toString() ?? '',
    'rect': {'left': x, 'top': y, 'width': w, 'height': h},
    'bbox': {'left': x, 'top': y, 'width': w, 'height': h},
    'font': {'name': 'Arial', 'size': fontSize, 'bold': '0', 'italic': '0'},
    'alignment': '0',
  };

  // For Display/Input widgets, ScreenConfig expects a 'rect'. For Label expects 'bbox'.
  // We provide both and let each widget pick what it needs.
  return base;
}

/// Bir ekranın konfigürasyonu
class ScreenConfig {
  final String name;
  final List<DisplayWidget> displays;
  final List<LabelWidget> labels;
  final List<InputWidget> inputs;
  final List<ButtonWidget> buttons;
  final List<String> presend;
  final Color backgroundColor;
  final double width;
  final double height;

  ScreenConfig({
    required this.name,
    required this.displays,
    required this.labels,
    required this.inputs,
    required this.buttons,
    required this.presend,
    required this.backgroundColor,
    required this.width,
    required this.height,
  });

  factory ScreenConfig.fromJson(Map<String, dynamic> json, String name) {
    return ScreenConfig(
      name: name,
      displays:
          (json['displays'] as List? ?? [])
              .map((e) => DisplayWidget.fromJson(e as Map<String, dynamic>))
              .toList(),
      labels:
          (json['labels'] as List? ?? [])
              .map((e) => LabelWidget.fromJson(e as Map<String, dynamic>))
              .toList(),
      inputs:
          (json['inputs'] as List? ?? [])
              .map((e) => InputWidget.fromJson(e as Map<String, dynamic>))
              .toList(),
      buttons:
          (json['buttons'] as List? ?? [])
              .map((e) => ButtonWidget.fromJson(e as Map<String, dynamic>))
              .toList(),
      presend:
          (json['presend'] as List? ?? []).map((e) => e.toString()).toList(),
      backgroundColor: _parseColor(json['color'] as String?),
      width: (json['width'] as num?)?.toDouble() ?? 9000,
      height: (json['height'] as num?)?.toDouble() ?? 6000,
    );
  }
}

/// Display widget konfigürasyonu (read-only değer gösterimi)
class DisplayWidget {
  final String text;
  final String request;
  final RectConfig rect;
  final Color backgroundColor;
  final Color fontColor;
  final FontConfig font;
  final double width;

  DisplayWidget({
    required this.text,
    required this.request,
    required this.rect,
    required this.backgroundColor,
    required this.fontColor,
    required this.font,
    required this.width,
  });

  factory DisplayWidget.fromJson(Map<String, dynamic> json) {
    return DisplayWidget(
      text: json['text'] as String? ?? '',
      request: json['request'] as String? ?? '',
      rect: RectConfig.fromJson(json['rect'] as Map<String, dynamic>? ?? {}),
      backgroundColor: _parseColor(json['color'] as String?),
      fontColor: _parseColor(json['fontcolor'] as String?),
      font: FontConfig.fromJson(json['font'] as Map<String, dynamic>? ?? {}),
      width: (json['width'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Label widget konfigürasyonu (statik metin)
class LabelWidget {
  final String text;
  final RectConfig bbox;
  final Color backgroundColor;
  final Color fontColor;
  final FontConfig font;
  final int alignment; // 0=left, 1=center, 2=right

  LabelWidget({
    required this.text,
    required this.bbox,
    required this.backgroundColor,
    required this.fontColor,
    required this.font,
    required this.alignment,
  });

  factory LabelWidget.fromJson(Map<String, dynamic> json) {
    return LabelWidget(
      text: json['text'] as String? ?? '',
      bbox: RectConfig.fromJson(json['bbox'] as Map<String, dynamic>? ?? {}),
      backgroundColor: _parseColor(json['color'] as String?),
      fontColor: _parseColor(json['fontcolor'] as String?),
      font: FontConfig.fromJson(json['font'] as Map<String, dynamic>? ?? {}),
      alignment: int.tryParse(json['alignment']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Input widget konfigürasyonu (kullanıcı girişi)
class InputWidget {
  final String text;
  final String request;
  final RectConfig rect;
  final Color backgroundColor;
  final Color fontColor;
  final FontConfig font;
  final double width;

  InputWidget({
    required this.text,
    required this.request,
    required this.rect,
    required this.backgroundColor,
    required this.fontColor,
    required this.font,
    required this.width,
  });

  factory InputWidget.fromJson(Map<String, dynamic> json) {
    return InputWidget(
      text: json['text'] as String? ?? '',
      request: json['request'] as String? ?? '',
      rect: RectConfig.fromJson(json['rect'] as Map<String, dynamic>? ?? {}),
      backgroundColor: _parseColor(json['color'] as String?),
      fontColor: _parseColor(json['fontcolor'] as String?),
      font: FontConfig.fromJson(json['font'] as Map<String, dynamic>? ?? {}),
      width: (json['width'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Button widget konfigürasyonu
class ButtonWidget {
  final String text;
  final String request;
  final RectConfig rect;
  final Color backgroundColor;
  final Color fontColor;
  final FontConfig font;

  ButtonWidget({
    required this.text,
    required this.request,
    required this.rect,
    required this.backgroundColor,
    required this.fontColor,
    required this.font,
  });

  factory ButtonWidget.fromJson(Map<String, dynamic> json) {
    return ButtonWidget(
      text: json['text'] as String? ?? '',
      request: json['request'] as String? ?? '',
      rect: RectConfig.fromJson(json['rect'] as Map<String, dynamic>? ?? {}),
      backgroundColor: _parseColor(json['color'] as String?),
      fontColor: _parseColor(json['fontcolor'] as String?),
      font: FontConfig.fromJson(json['font'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// Dikdörtgen pozisyon ve boyut bilgisi
class RectConfig {
  final double left;
  final double top;
  final double width;
  final double height;

  RectConfig({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory RectConfig.fromJson(Map<String, dynamic> json) {
    return RectConfig(
      left: (json['left'] as num?)?.toDouble() ?? 0,
      top: (json['top'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 100,
      height: (json['height'] as num?)?.toDouble() ?? 50,
    );
  }
}

/// Font konfigürasyonu
class FontConfig {
  final String name;
  final double size;
  final bool bold;
  final bool italic;

  FontConfig({
    required this.name,
    required this.size,
    required this.bold,
    required this.italic,
  });

  factory FontConfig.fromJson(Map<String, dynamic> json) {
    return FontConfig(
      name: json['name'] as String? ?? 'Arial',
      size: (json['size'] as num?)?.toDouble() ?? 10.0,
      bold: json['bold']?.toString() == '1',
      italic: json['italic']?.toString() == '1',
    );
  }
}

/// RGB renk string'ini Color objesine çevir
/// Örnek: "rgb(255,255,255)" -> Color(0xFFFFFFFF)
Color _parseColor(String? colorStr) {
  if (colorStr == null || colorStr.isEmpty) {
    return const Color(0xFFFFFFFF);
  }

  // rgb(r,g,b) formatını parse et
  final rgbMatch = RegExp(r'rgb\((\d+),(\d+),(\d+)\)').firstMatch(colorStr);
  if (rgbMatch != null) {
    final r = int.parse(rgbMatch.group(1)!);
    final g = int.parse(rgbMatch.group(2)!);
    final b = int.parse(rgbMatch.group(3)!);
    return Color.fromARGB(255, r, g, b);
  }

  return const Color(0xFFFFFFFF);
}
