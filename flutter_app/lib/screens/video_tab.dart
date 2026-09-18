import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import '../theme.dart';
import '../app_model.dart';
import '../services/subtitle_parser.dart';
import '../services/web_blob.dart';
import '../widgets/highlighted_text.dart';

class VideoTab extends StatefulWidget {
  const VideoTab({super.key});

  @override
  State<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends State<VideoTab> {
  VideoPlayerController? _controller;
  bool _isVideoReady = false;
  String? _videoName;
  String? _blobUrl;

  List<SubtitleCue> _subtitles = [];
  int _currentCueIndex = -1;
  String? _subtitleName;

  final _scrollController = ScrollController();
  static const _estimatedItemHeight = 72.0;

  static const _sampleSrt = '''1
00:00:01,000 --> 00:00:04,000
El hombre camina por la calle mientras come una manzana.

2
00:00:05,000 --> 00:00:08,000
Tiene mucho trabajo que hacer hoy.

3
00:00:09,000 --> 00:00:13,000
Después de comer, va a estudiar español en la biblioteca.

4
00:00:14,000 --> 00:00:17,000
Aprende nuevas palabras cada día.

5
00:00:18,000 --> 00:00:22,000
Cuando terminó de estudiar, decidió nadar en la piscina.

6
00:00:23,000 --> 00:00:27,000
Su amigo le dijo que era importante practicar todos los días.

7
00:00:28,000 --> 00:00:32,000
Hablar con personas nativas ayuda mucho.

8
00:00:33,000 --> 00:00:37,000
Escribir y leer también son actividades importantes.

9
00:00:38,000 --> 00:00:42,000
Ellos quieren viajar a España el próximo año.

10
00:00:43,000 --> 00:00:47,000
Para ellos, es importante aprender el idioma antes del viaje.
''';

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    if (_blobUrl != null) revokeBlobUrl(_blobUrl!);
    _scrollController.dispose();
    super.dispose();
  }

  // ── File picking ──────────────────────────────────────────────────────────

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mkv', 'webm', 'mov', 'ogg', 'ogv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      await _initVideoController(file.bytes!, file.name);
    } catch (e) {
      _showError('Failed to open video: $e');
    }
  }

  Future<void> _initVideoController(List<int> bytes, String name) async {
    // Clean up previous controller.
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    if (_blobUrl != null) revokeBlobUrl(_blobUrl!);

    final mimeType = _getMimeType(name);
    final url = createBlobUrl(bytes, mimeType);
    _blobUrl = url;
    _videoName = name;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;

    setState(() => _isVideoReady = false);

    try {
      await controller.initialize();
      controller.addListener(_onVideoUpdate);
      setState(() => _isVideoReady = true);
      controller.play();
    } catch (e) {
      _showError('Failed to initialize video: $e');
    }
  }

  Future<void> _pickSubtitles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      final content = String.fromCharCodes(file.bytes!);
      final cues = SubtitleParser.parse(content);

      setState(() {
        _subtitles = cues;
        _subtitleName = file.name;
        _currentCueIndex = -1;
      });
    } catch (e) {
      _showError('Failed to open subtitles: $e');
    }
  }

  void _loadSampleSubtitles() {
    final cues = SubtitleParser.parse(_sampleSrt);
    setState(() {
      _subtitles = cues;
      _subtitleName = 'Sample Subtitles';
      _currentCueIndex = -1;
    });
  }

  // ── Video update listener ─────────────────────────────────────────────────

  void _onVideoUpdate() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_subtitles.isEmpty) return;

    final position = _controller!.value.position;
    int newIndex = -1;
    for (int i = 0; i < _subtitles.length; i++) {
      if (_subtitles[i].isActiveAt(position)) {
        newIndex = i;
        break;
      }
    }

    if (newIndex != _currentCueIndex) {
      setState(() => _currentCueIndex = newIndex);
      if (newIndex >= 0) _scrollToCurrent();
    }
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    final offset = (_currentCueIndex * _estimatedItemHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _seekTo(Duration position) {
    _controller?.seekTo(position);
  }

  void _togglePlay() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
    setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasContent = _isVideoReady || _subtitles.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video'),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_file),
            tooltip: 'Pick Video',
            onPressed: _pickVideo,
          ),
          IconButton(
            icon: const Icon(Icons.subtitles),
            tooltip: 'Pick Subtitles',
            onPressed: _pickSubtitles,
          ),
        ],
      ),
      body: hasContent ? _buildContent(context) : _buildEmptyState(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_library,
              size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text('No video or subtitles loaded',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _loadSampleSubtitles,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              minimumSize: const Size(220, 46),
            ),
            child: const Text('Load Sample Subtitles'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _pickVideo,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              minimumSize: const Size(220, 46),
            ),
            child: const Text('Pick Video File'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _pickSubtitles,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              minimumSize: const Size(220, 46),
            ),
            child: const Text('Pick Subtitle File (SRT/VTT)'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final model = context.watch<AppModel>();
    return Column(
      children: [
        _buildVideoArea(),
        if (_isVideoReady) _buildControls(),
        if (_currentCueIndex >= 0 && _currentCueIndex < _subtitles.length)
          _buildCurrentSubtitle(model),
        if (_subtitles.isNotEmpty)
          Expanded(child: _buildSubtitleList(model)),
      ],
    );
  }

  Widget _buildVideoArea() {
    if (_isVideoReady && _controller != null) {
      return AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      );
    }
    return Container(
      height: 200,
      width: double.infinity,
      color: AppTheme.card,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_settings,
              size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 8),
          Text(
            _videoName ?? 'No video loaded',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickVideo,
            icon: const Icon(Icons.video_file),
            label: const Text('Pick Video'),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final controller = _controller!;
    final position = controller.value.position;
    final duration = controller.value.duration;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(
          bottom: BorderSide(color: AppTheme.cardBorder),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(controller.value.isPlaying
                ? Icons.pause
                : Icons.play_arrow),
            onPressed: _togglePlay,
            color: AppTheme.accent,
          ),
          Expanded(
            child: Slider(
              value: position.inMilliseconds.toDouble().clamp(
                    0.0,
                    duration.inMilliseconds.toDouble(),
                  ),
              max: duration.inMilliseconds.toDouble(),
              onChanged: (v) => _seekTo(
                Duration(milliseconds: v.round()),
              ),
            ),
          ),
          Text(
            '${_fmtDuration(position)} / ${_fmtDuration(duration)}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSubtitle(AppModel model) {
    final cue = _subtitles[_currentCueIndex];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.08),
        border: Border(
          bottom: BorderSide(color: AppTheme.cardBorder),
        ),
      ),
      child: Center(
        child: HighlightedText(
          text: cue.text,
          model: model,
          fontSize: 17,
        ),
      ),
    );
  }

  Widget _buildSubtitleList(AppModel model) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _subtitles.length,
      itemBuilder: (context, index) {
        final cue = _subtitles[index];
        final isCurrent = index == _currentCueIndex;
        return GestureDetector(
          onTap: () => _seekTo(cue.start),
          child: Container(
            color: isCurrent
                ? AppTheme.accent.withOpacity(0.12)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    _fmtDuration(cue.start),
                    style: TextStyle(
                      color: isCurrent
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: HighlightedText(
                    text: cue.text,
                    model: model,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'mp4' => 'video/mp4',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      'ogg' || 'ogv' => 'video/ogg',
      'mov' => 'video/quicktime',
      _ => 'video/mp4',
    };
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.error),
      );
    }
  }
}
