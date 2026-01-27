import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// A file browser dialog that scans local directories for supported files
/// Works with D-pad/remote navigation for TV devices
class FileBrowserDialog extends StatefulWidget {
  final Function(String) onFileSelected;
  final VoidCallback onClose;

  const FileBrowserDialog({
    super.key,
    required this.onFileSelected,
    required this.onClose,
  });

  @override
  State<FileBrowserDialog> createState() => _FileBrowserDialogState();
}

class _FileBrowserDialogState extends State<FileBrowserDialog>
    with WidgetsBindingObserver {
  final _scopeFocusNode = FocusScopeNode(debugLabel: 'FileBrowserScope');
  List<String> _files = [];
  bool _isLoading = true;
  String? _error;
  bool _permissionRequested = false;

  // Directories to scan for files
  static const List<String> _scanPaths = [
    '/sdcard/Download',
    '/sdcard/Downloads',
    '/sdcard/MotherMobile',
    '/sdcard/Documents',
    '/sdcard',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/storage/emulated/0/MotherMobile',
    '/storage/emulated/0/Documents',
  ];

  // Supported file extensions
  static const List<String> _supportedExtensions = ['.riv', '.html', '.htm'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionsAndScan();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scopeFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _permissionRequested) {
      _permissionRequested = false;
      _scanDirectories();
    }
  }

  Future<void> _requestPermissionsAndScan() async {
    try {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }

      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isDenied) {
        _permissionRequested = true;
        await Permission.manageExternalStorage.request();
      }

      await _scanDirectories();
    } catch (e) {
      setState(() {
        _error = 'Permission error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _scanDirectories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final foundFiles = <String>{}; // Use Set to deduplicate
    final scannedPaths = <String>[];
    final errorPaths = <String, String>{};

    for (final path in _scanPaths) {
      try {
        final dir = Directory(path);
        if (await dir.exists()) {
          scannedPaths.add(path);

          // Method 1: Try Dart's Directory.list
          try {
            await for (final entity
                in dir.list(recursive: false, followLinks: false)) {
              if (entity is File) {
                final lowerPath = entity.path.toLowerCase();
                if (_supportedExtensions
                    .any((ext) => lowerPath.endsWith(ext))) {
                  foundFiles.add(entity.path);
                }
              }
            }
          } catch (e) {
            debugPrint('Directory.list failed for $path: $e');
          }

          // Method 2: Fallback to shell ls command (works better on Android TV)
          try {
            final result = await Process.run('ls', [path]);
            if (result.exitCode == 0) {
              final output = result.stdout as String;
              for (final line in output.split('\n')) {
                final fileName = line.trim();
                if (fileName.isEmpty) continue;
                final lowerName = fileName.toLowerCase();
                if (_supportedExtensions
                    .any((ext) => lowerName.endsWith(ext))) {
                  final fullPath = '$path/$fileName';
                  foundFiles.add(fullPath);
                  debugPrint('Found via ls: $fullPath');
                }
              }
            }
          } catch (e) {
            debugPrint('ls fallback failed for $path: $e');
          }
        }
      } catch (e) {
        errorPaths[path] = e.toString();
        debugPrint('Error scanning $path: $e');
      }
    }

    // Sort by filename
    final sortedFiles = foundFiles.toList()
      ..sort((a, b) => a.split('/').last.compareTo(b.split('/').last));

    setState(() {
      _files = sortedFiles;
      _isLoading = false;
      if (_files.isEmpty) {
        final scannedInfo = scannedPaths.isNotEmpty
            ? 'Scanned: ${scannedPaths.join(', ')}'
            : 'Could not access any directories';
        final errorInfo = errorPaths.isNotEmpty
            ? '\n\nErrors:\n${errorPaths.entries.map((e) => '${e.key}: ${e.value}').join('\n')}'
            : '';
        _error =
            'No .riv or .html files found.\n\n$scannedInfo$errorInfo\n\nPush files via ADB:\nadb push myfile.riv /sdcard/Download/';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // FocusScope traps all focus within the dialog
    return FocusScope(
      node: _scopeFocusNode,
      autofocus: true,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.goBack ||
              key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.browserBack) {
            widget.onClose();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.keyR) {
            _scanDirectories();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onClose,
          child: Container(
            color: Colors.black87,
            child: SafeArea(
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    constraints:
                        const BoxConstraints(maxWidth: 500, maxHeight: 600),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade800),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Select File',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE94560),
                                ),
                              ),
                              Row(
                                children: [
                                  _DpadIconAction(
                                    icon: Icons.refresh,
                                    tooltip: 'Refresh',
                                    onAction: _scanDirectories,
                                  ),
                                  const SizedBox(width: 4),
                                  _DpadIconAction(
                                    icon: Icons.close,
                                    tooltip: 'Close',
                                    onAction: widget.onClose,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Content
                        Flexible(
                          child: _buildContent(),
                        ),

                        // Footer hint
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade800),
                            ),
                          ),
                          child: Text(
                            'D-pad: Navigate • Select: Open • Back: Close',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
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

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFE94560)),
              SizedBox(height: 16),
              Text(
                'Scanning for files...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open, color: Colors.grey, size: 64),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _DpadIconAction(
                icon: Icons.refresh,
                label: 'Retry',
                onAction: _scanDirectories,
                autofocus: true,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final filePath = _files[index];
        final fileName = filePath.split('/').last;
        final isRive = fileName.toLowerCase().endsWith('.riv');

        return _DpadListItem(
          autofocus: index == 0,
          icon: isRive ? Icons.animation : Icons.web,
          title: fileName,
          subtitle: _getRelativePath(filePath),
          onSelect: () => widget.onFileSelected(filePath),
        );
      },
    );
  }

  String _getRelativePath(String fullPath) {
    for (final basePath in _scanPaths) {
      if (fullPath.startsWith(basePath)) {
        final rel = fullPath.replaceFirst(basePath, '').replaceFirst('/', '');
        return rel.isEmpty ? basePath.split('/').last : rel;
      }
    }
    return fullPath;
  }
}

/// Icon button / text button that responds to D-pad select/enter
class _DpadIconAction extends StatefulWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback onAction;
  final bool autofocus;

  const _DpadIconAction({
    required this.icon,
    this.label,
    this.tooltip,
    required this.onAction,
    this.autofocus = false,
  });

  @override
  State<_DpadIconAction> createState() => _DpadIconActionState();
}

class _DpadIconActionState extends State<_DpadIconAction> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'DpadAction-${widget.tooltip ?? widget.label}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onAction();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onAction,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _focused ? Colors.white24 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: _focused
                ? Border.all(color: const Color(0xFFE94560), width: 2)
                : Border.all(color: Colors.transparent, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: _focused ? const Color(0xFFE94560) : Colors.white70,
                size: 22,
              ),
              if (widget.label != null) ...[
                const SizedBox(width: 8),
                Text(
                  widget.label!,
                  style: TextStyle(
                    color: _focused ? const Color(0xFFE94560) : Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A list item that responds to D-pad focus and select/enter
class _DpadListItem extends StatefulWidget {
  final bool autofocus;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onSelect;

  const _DpadListItem({
    this.autofocus = false,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSelect,
  });

  @override
  State<_DpadListItem> createState() => _DpadListItemState();
}

class _DpadListItemState extends State<_DpadListItem> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'DpadListItem-${widget.title}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onSelect();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _focused
                ? const Color(0xFFE94560).withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: _focused
                ? Border.all(color: const Color(0xFFE94560), width: 2)
                : Border.all(color: Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: _focused ? const Color(0xFFE94560) : Colors.white70,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: _focused ? Colors.white : Colors.white70,
                        fontWeight:
                            _focused ? FontWeight.bold : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
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
