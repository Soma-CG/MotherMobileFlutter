import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

/// Screen for playing Rive animations using the native Rive package
/// Supports data binding and view models for full feature compatibility
class RivePlayerScreen extends StatefulWidget {
  final String filePath;

  const RivePlayerScreen({super.key, required this.filePath});

  @override
  State<RivePlayerScreen> createState() => _RivePlayerScreenState();
}

class _RivePlayerScreenState extends State<RivePlayerScreen> {
  File? _riveFile;
  RiveWidgetController? _controller;
  ViewModelInstance? _viewModelInstance;
  bool _isLoading = true;
  String? _error;

  // For two-finger gesture detection
  int _pointerCount = 0;
  double _startY = 0;

  @override
  void initState() {
    super.initState();
    _loadRiveFile();
  }

  Future<void> _loadRiveFile() async {
    try {
      // Load file using the new rive_native API
      final file = await File.path(
        widget.filePath,
        riveFactory: Factory.rive,
      );

      if (file == null) {
        throw Exception('Failed to decode Rive file');
      }

      debugPrint('Rive file loaded from: ${widget.filePath}');

      // Create the widget controller with default artboard and state machine
      final controller = RiveWidgetController(
        file,
        artboardSelector: const ArtboardDefault(),
        stateMachineSelector: const StateMachineDefault(),
      );

      debugPrint('Created controller with artboard: ${controller.artboard.name}');

      // Try to enable data binding
      ViewModelInstance? vmi;
      try {
        vmi = controller.dataBind(DataBind.auto());
        debugPrint('Data binding enabled (auto mode)');
      } catch (e) {
        debugPrint('Data binding not available: $e');
      }

      setState(() {
        _riveFile = file;
        _controller = controller;
        _viewModelInstance = vmi;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('Error loading Rive: $e');
      debugPrint('Stack: $stack');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _goBack() {
    Navigator.pop(context);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _viewModelInstance?.dispose();
    _controller?.dispose();
    _riveFile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown: (event) {
          _pointerCount++;
          if (_pointerCount == 2) {
            _startY = event.position.dy;
          }
        },
        onPointerUp: (event) {
          _pointerCount--;
          if (_pointerCount < 0) _pointerCount = 0;
        },
        onPointerCancel: (event) {
          _pointerCount--;
          if (_pointerCount < 0) _pointerCount = 0;
        },
        onPointerMove: (event) {
          if (_pointerCount == 2) {
            final deltaY = event.position.dy - _startY;
            if (deltaY > 100) {
              _goBack();
            }
          }
        },
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE94560)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFE94560), size: 64),
              const SizedBox(height: 16),
              Text(
                'Error loading Rive file',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _goBack, child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }

    if (_controller != null) {
      return RiveWidget(
        controller: _controller!,
        fit: Fit.contain,
        alignment: Alignment.center,
      );
    }

    return const SizedBox.shrink();
  }
}
