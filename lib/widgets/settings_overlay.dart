import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

/// Settings overlay that slides in from top
class SettingsOverlay extends StatefulWidget {
  final String currentUrl;
  final bool keepScreenOn;
  final bool proximityDimEnabled;
  final bool proximityUprightOnly;
  final bool riveAccelerometerEnabled;
  final bool riveGyroscopeEnabled;
  final bool riveProximityEnabled;
  final Function(String) onUrlSubmit;
  final Function(String) onFileSelect;
  final VoidCallback onReload;
  final Function(bool) onKeepScreenOnChanged;
  final Function(bool) onProximityDimChanged;
  final Function(bool) onProximityUprightOnlyChanged;
  final Function(bool) onRiveAccelerometerChanged;
  final Function(bool) onRiveGyroscopeChanged;
  final Function(bool) onRiveProximityChanged;
  final VoidCallback onClose;
  final VoidCallback onBrowseLocalFiles;

  const SettingsOverlay({
    super.key,
    required this.currentUrl,
    required this.keepScreenOn,
    required this.proximityDimEnabled,
    required this.proximityUprightOnly,
    required this.riveAccelerometerEnabled,
    required this.riveGyroscopeEnabled,
    required this.riveProximityEnabled,
    required this.onUrlSubmit,
    required this.onFileSelect,
    required this.onReload,
    required this.onKeepScreenOnChanged,
    required this.onProximityDimChanged,
    required this.onProximityUprightOnlyChanged,
    required this.onRiveAccelerometerChanged,
    required this.onRiveGyroscopeChanged,
    required this.onRiveProximityChanged,
    required this.onClose,
    required this.onBrowseLocalFiles,
  });

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  late TextEditingController _urlController;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.currentUrl == 'about:blank' ? '' : widget.currentUrl,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Handle keyboard input for closing overlay
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Escape or Back button closes the overlay
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      widget.onClose();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _pickFile() async {
    try {
      // Use FileType.any because custom extensions can be unreliable on Android
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final lowerPath = path.toLowerCase();

        // Check if it's a supported file type
        if (lowerPath.endsWith('.html') ||
            lowerPath.endsWith('.htm') ||
            lowerPath.endsWith('.riv')) {
          widget.onFileSelect(path);
        } else {
          // Show error for unsupported files
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select an HTML or Rive (.riv) file'),
                backgroundColor: Color(0xFFE94560),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black54,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () {}, // Prevent close when tapping settings panel
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xE6121212),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade800,
                    width: 1,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Mother Mobile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE94560),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: widget.onClose,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // URL Input
                      TextField(
                        controller: _urlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter URL',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[600]!),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFE94560)),
                          ),
                        ),
                        keyboardType: TextInputType.url,
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            widget.onUrlSubmit(value);
                          }
                        },
                      ),

                      const SizedBox(height: 12),

                      // Go / Reload buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final url = _urlController.text;
                                if (url.isNotEmpty) {
                                  widget.onUrlSubmit(url);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE94560),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Go'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onReload,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.grey[600]!),
                              ),
                              child: const Text('Reload'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Screen settings section
                      Text(
                        'Screen Settings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Keep screen on toggle
                      SwitchListTile(
                        title: const Text(
                          'Keep screen on',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Prevent display from sleeping',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        value: widget.keepScreenOn,
                        onChanged: widget.onKeepScreenOnChanged,
                        activeTrackColor: const Color(0xFFE94560),
                        contentPadding: EdgeInsets.zero,
                      ),

                      const SizedBox(height: 24),

                      // Sensor settings section
                      Text(
                        'Sensor Settings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Proximity dim toggle
                      SwitchListTile(
                        title: const Text(
                          'Proximity fade to black',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Dim screen when sensor is covered',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        value: widget.proximityDimEnabled,
                        onChanged: widget.onProximityDimChanged,
                        activeTrackColor: const Color(0xFFE94560),
                        contentPadding: EdgeInsets.zero,
                      ),

                      // Upright-only option (only shown when proximity is enabled)
                      if (widget.proximityDimEnabled)
                        SwitchListTile(
                          title: const Text(
                            'Upright only (phone mode)',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Only dim when held to ear, not flat on desk',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          value: widget.proximityUprightOnly,
                          onChanged: widget.onProximityUprightOnlyChanged,
                          activeTrackColor: const Color(0xFFE94560),
                          contentPadding: EdgeInsets.zero,
                        ),

                      const SizedBox(height: 24),

                      // Rive sensor input section
                      Text(
                        'Rive Sensor Input',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Feed sensor data to Rive state machine inputs',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Rive accelerometer toggle
                      SwitchListTile(
                        title: const Text(
                          'Accelerometer',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'accelX, accelY, accelZ, isFlat, isUpright',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        value: widget.riveAccelerometerEnabled,
                        onChanged: widget.onRiveAccelerometerChanged,
                        activeTrackColor: const Color(0xFFE94560),
                        contentPadding: EdgeInsets.zero,
                      ),

                      // Rive gyroscope toggle
                      SwitchListTile(
                        title: const Text(
                          'Gyroscope',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'gyroX, gyroY, gyroZ',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        value: widget.riveGyroscopeEnabled,
                        onChanged: widget.onRiveGyroscopeChanged,
                        activeTrackColor: const Color(0xFFE94560),
                        contentPadding: EdgeInsets.zero,
                      ),

                      // Rive proximity toggle
                      SwitchListTile(
                        title: const Text(
                          'Proximity',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'isNear (boolean)',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        value: widget.riveProximityEnabled,
                        onChanged: widget.onRiveProximityChanged,
                        activeTrackColor: const Color(0xFFE94560),
                        contentPadding: EdgeInsets.zero,
                      ),

                      const SizedBox(height: 16),

                      // Local files section
                      Text(
                        'Local Files',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // File picker button (uses system picker - works on phones)
                      OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.file_open),
                        label: const Text('System file picker'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[600]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Built-in file browser (works on TV/Chromecast)
                      ElevatedButton.icon(
                        onPressed: widget.onBrowseLocalFiles,
                        icon: const Icon(Icons.folder),
                        label: const Text('Browse /sdcard (TV/Chromecast)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE94560),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Version info
                      Center(
                        child: Text(
                          'Mother Mobile v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
