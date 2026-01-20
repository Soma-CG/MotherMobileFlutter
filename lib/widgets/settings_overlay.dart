import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Settings overlay that slides in from top
class SettingsOverlay extends StatefulWidget {
  final String currentUrl;
  final bool keepScreenOn;
  final Function(String) onUrlSubmit;
  final Function(String) onFileSelect;
  final VoidCallback onReload;
  final Function(bool) onKeepScreenOnChanged;
  final VoidCallback onClose;

  const SettingsOverlay({
    super.key,
    required this.currentUrl,
    required this.keepScreenOn,
    required this.onUrlSubmit,
    required this.onFileSelect,
    required this.onReload,
    required this.onKeepScreenOnChanged,
    required this.onClose,
  });

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  late TextEditingController _urlController;

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
    super.dispose();
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
    return GestureDetector(
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

                      // File picker button
                      OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Open local html or Rive file'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[600]!),
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
    );
  }
}
