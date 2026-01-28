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
  final _urlFocusNode = FocusNode(debugLabel: 'UrlInput');
  bool _urlFieldFocused = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.currentUrl == 'about:blank' ? '' : widget.currentUrl,
    );
    _urlFocusNode.addListener(() {
      setState(() => _urlFieldFocused = _urlFocusNode.hasFocus);
      // Always hide OSK when the field gains focus.
      // The OSK will only be shown explicitly via D-pad select button.
      // Hardware keyboards work directly without the OSK.
      if (_urlFocusNode.hasFocus) {
        // Delay slightly to let TextField's own show request go through first
        Future.delayed(const Duration(milliseconds: 50), () {
          if (!_oskRequested) {
            SystemChannels.textInput.invokeMethod('TextInput.hide');
          }
          _oskRequested = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final lowerPath = path.toLowerCase();

        if (lowerPath.endsWith('.html') ||
            lowerPath.endsWith('.htm') ||
            lowerPath.endsWith('.riv')) {
          widget.onFileSelect(path);
        } else {
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

  void _unfocusUrlField() {
    if (_urlFocusNode.hasFocus) {
      _urlFocusNode.unfocus();
    }
  }

  // Flag to track when we explicitly request the OSK via D-pad select
  bool _oskRequested = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black54,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () {},
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
                child: Focus(
                  // Top-level focus handler for back/escape to close
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    final key = event.logicalKey;

                    // If URL field is focused, back button unfocuses it first
                    if (_urlFieldFocused) {
                      if (key == LogicalKeyboardKey.goBack ||
                          key == LogicalKeyboardKey.escape ||
                          key == LogicalKeyboardKey.browserBack) {
                        _unfocusUrlField();
                        return KeyEventResult.handled;
                      }
                      // D-pad down exits the URL field
                      if (key == LogicalKeyboardKey.arrowDown) {
                        _unfocusUrlField();
                        // Let focus system move to next widget
                        return KeyEventResult.ignored;
                      }
                      // Center/Select: show OSK (for D-pad remote)
                      // Enter on hardware keyboard: submit URL
                      if (key == LogicalKeyboardKey.select ||
                          key == LogicalKeyboardKey.enter) {
                        if (key == LogicalKeyboardKey.enter) {
                          // Let TextField onSubmitted handle Enter key
                          return KeyEventResult.ignored;
                        }
                        // D-pad select: explicitly show OSK with cursor preserved
                        _oskRequested = true;
                        final selection = _urlController.selection;
                        SystemChannels.textInput.invokeMethod('TextInput.show');
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_urlController.text.isNotEmpty && selection.isValid) {
                            _urlController.selection = selection;
                          }
                        });
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    }

                    // Otherwise back/escape closes the overlay
                    if (key == LogicalKeyboardKey.escape ||
                        key == LogicalKeyboardKey.goBack ||
                        key == LogicalKeyboardKey.browserBack) {
                      widget.onClose();
                      return KeyEventResult.handled;
                    }

                    return KeyEventResult.ignored;
                  },
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
                              'Mother',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE94560),
                              ),
                            ),
                            _SettingsDpadButton(
                              icon: Icons.close,
                              onPressed: widget.onClose,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // URL Input - wrapped with key handler to allow D-pad exit
                        TextField(
                          controller: _urlController,
                          focusNode: _urlFocusNode,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter URL',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[600]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFE94560), width: 2),
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

                        // Reload button
                        _SettingsDpadTextButton(
                          label: 'Reload',
                          icon: Icons.refresh,
                          isPrimary: false,
                          onPressed: widget.onReload,
                        ),

                        const SizedBox(height: 24),

                        // Screen settings section
                        _sectionHeader('Screen Settings'),
                        const SizedBox(height: 8),

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
                        _sectionHeader('Sensor Settings'),
                        const SizedBox(height: 8),

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
                        _sectionHeader('Rive Sensor Input'),
                        const SizedBox(height: 4),
                        Text(
                          'Feed sensor data to Rive state machine inputs',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),

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
                        _sectionHeader('Local Files'),
                        const SizedBox(height: 8),

                        _SettingsDpadTextButton(
                          label: 'System file picker',
                          icon: Icons.file_open,
                          isPrimary: false,
                          onPressed: _pickFile,
                        ),

                        const SizedBox(height: 8),

                        _SettingsDpadTextButton(
                          label: 'Browse /sdcard (TV/Chromecast)',
                          icon: Icons.folder,
                          isPrimary: true,
                          onPressed: widget.onBrowseLocalFiles,
                        ),

                        const SizedBox(height: 20),

                        // Version info
                        Center(
                          child: Text(
                            'Mother v1.0.0',
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

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.grey[400],
      ),
    );
  }
}

/// A button with D-pad focus feedback for the settings overlay
class _SettingsDpadButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SettingsDpadButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_SettingsDpadButton> createState() => _SettingsDpadButtonState();
}

class _SettingsDpadButtonState extends State<_SettingsDpadButton> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _focused ? Colors.white24 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: _focused
                ? Border.all(color: const Color(0xFFE94560), width: 2)
                : Border.all(color: Colors.transparent, width: 2),
          ),
          child: Icon(
            widget.icon,
            color: _focused ? const Color(0xFFE94560) : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// A text button with D-pad focus feedback
class _SettingsDpadTextButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _SettingsDpadTextButton({
    required this.label,
    this.icon,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  State<_SettingsDpadTextButton> createState() => _SettingsDpadTextButtonState();
}

class _SettingsDpadTextButtonState extends State<_SettingsDpadTextButton> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _focused
                ? const Color(0xFFE94560)
                : (widget.isPrimary ? const Color(0xFFE94560).withValues(alpha: 0.2) : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused
                  ? Colors.white
                  : (widget.isPrimary ? const Color(0xFFE94560) : Colors.grey[600]!),
              width: _focused ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: _focused ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
