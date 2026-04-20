import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/supabase_config.dart';
import '../providers/device_provider.dart';
import '../widgets/mjpeg_view.dart';

// ---------------------------------------------------------------------------
// Live stream widget — isolated so data refreshes never rebuild/destroy it.
// The [visible] flag lets the parent hide the platform view before showing
// overlays; on Flutter Web the HtmlElementView always renders above Flutter
// overlays, so it must be removed from the tree before a modal is shown.
// ---------------------------------------------------------------------------
class _LiveStreamSection extends StatefulWidget {
  final bool visible;
  final double streamHeight;
  const _LiveStreamSection({
    this.visible = true,
    this.streamHeight = 260,
  });

  @override
  State<_LiveStreamSection> createState() => _LiveStreamSectionState();
}

class _LiveStreamSectionState extends State<_LiveStreamSection> {
  bool _loading = true;
  bool _disconnected = false;
  String _streamUrl = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    setState(() {
      _loading = true;
      _disconnected = false;
      _streamUrl = _bustCache(AppConfig.streamUrl);
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  String _bustCache(String base) {
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}_t=${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Live View', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reconnect', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: !widget.visible
                ? const Center(
                    child: Icon(Icons.videocam, size: 48, color: Colors.white24),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_loading)
                        const Center(child: CircularProgressIndicator(color: Colors.white))
                      else
                        MjpegView(url: _streamUrl, fit: BoxFit.contain),
                      if (_disconnected)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off, size: 48, color: Colors.white70),
                                const SizedBox(height: 8),
                                const Text('Stream disconnected', style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _start,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------
class AiHealthScreen extends StatefulWidget {
  const AiHealthScreen({super.key});

  @override
  State<AiHealthScreen> createState() => _AiHealthScreenState();
}

class _AiHealthScreenState extends State<AiHealthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic>? _latestCompletedJob;
  Map<String, dynamic>? _inProgressJob;
  Map<String, dynamic>? _latestInference;
  List<Map<String, dynamic>> _historyJobs = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  String? _currentDeviceId;
  final Map<String, Future<String>> _signedUrlFutureCache = {};
  bool _loadInFlight = false;
  bool _historySheetVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _load(silent: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final deviceId =
        context.read<DeviceProvider>().selectedDevice?.id;
    if (deviceId != _currentDeviceId) {
      _currentDeviceId = deviceId;
      _signedUrlFutureCache.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_loadInFlight) return;
    _loadInFlight = true;

    final device = context.read<DeviceProvider>().selectedDevice;
    if (device == null || !SupabaseConfig.isInitialized) {
      if (mounted) {
        setState(() {
          _loading = false;
          _latestCompletedJob = null;
          _inProgressJob = null;
          _latestInference = null;
          _historyJobs = [];
        });
      }
      _loadInFlight = false;
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final completedJobs = await SupabaseConfig.client!
          .from('ai_capture_jobs')
          .select()
          .eq('device_id', device.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(1);

      final pendingJobs = await SupabaseConfig.client!
          .from('ai_capture_jobs')
          .select()
          .eq('device_id', device.id)
          .inFilter('status', ['pending', 'processing'])
          .order('created_at', ascending: false)
          .limit(1);

      final inferences = await SupabaseConfig.client!
          .from(SupabaseConfig.mlInferencesTable)
          .select()
          .eq('device_id', device.id)
          .order('timestamp', ascending: false)
          .limit(1);

      final historyJobs = await SupabaseConfig.client!
          .from('ai_capture_jobs')
          .select(
              'id, image_url, status, llm_result, vision_result, processed_at, created_at')
          .eq('device_id', device.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(20);

      if (!mounted) return;

      final latestCompleted = (completedJobs as List).isNotEmpty
          ? Map<String, dynamic>.from(completedJobs.first as Map)
          : null;
      final latestInference = (inferences as List).isNotEmpty
          ? Map<String, dynamic>.from(inferences.first as Map)
          : _inferenceFromJob(latestCompleted);
      final nextInProgress = (pendingJobs as List).isNotEmpty
          ? Map<String, dynamic>.from(pendingJobs.first as Map)
          : null;
      final nextHistory = List<Map<String, dynamic>>.from(
        (historyJobs as List)
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      // Skip setState if nothing changed (avoid tearing down widgets)
      if (silent &&
          _latestCompletedJob?['id'] == latestCompleted?['id'] &&
          _inProgressJob?['id'] == nextInProgress?['id'] &&
          _inProgressJob?['status'] == nextInProgress?['status'] &&
          _latestInference?['id'] == latestInference?['id'] &&
          _historyJobs.length == nextHistory.length &&
          (_historyJobs.isEmpty ||
              _historyJobs.first['id'] == nextHistory.first['id']) &&
          _error == null) {
        return;
      }

      setState(() {
        _latestCompletedJob = latestCompleted;
        _inProgressJob = nextInProgress;
        _latestInference = latestInference;
        _historyJobs = nextHistory;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } finally {
      _loadInFlight = false;
    }
  }

  Map<String, dynamic>? _inferenceFromJob(Map<String, dynamic>? job) {
    if (job == null) return null;
    final llm = _asMap(job['llm_result']);
    final vision = _asMap(job['vision_result']);
    if (llm == null && vision == null) return null;
    return {
      'diagnostic': llm?['diagnostic'],
      'tips': llm?['tips'] ?? const [],
      'result': {
        'vision': vision ?? const {},
        'llm': llm ?? const {},
        'sensor_snapshot': '',
      },
      'created_at': job['processed_at'] ?? job['created_at'],
    };
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _safeString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  String _formatDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return 'Unknown time';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showHistorySheet() async {
    // Hide the live-stream platform view BEFORE the overlay appears.
    // On Flutter Web, HtmlElementView always renders above Flutter overlays,
    // so the bottom sheet would be invisible behind the video stream unless
    // we remove the platform view from the tree first.
    setState(() => _historySheetVisible = true);

    // Yield one frame so the rebuild removes the HtmlElementView before the
    // sheet route is pushed.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final jobs = List<Map<String, dynamic>>.from(_historyJobs);

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.86,
            child: jobs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history,
                            size: 48, color: theme.disabledColor),
                        const SizedBox(height: 12),
                        Text('No AI history yet',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Row(
                          children: [
                            Text('AI Capture History',
                                style: theme.textTheme.titleLarge),
                            const Spacer(),
                            IconButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(),
                              icon: const Icon(Icons.close),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              16, 4, 16, 16),
                          itemCount: jobs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final job = jobs[index];
                            final llm = _asMap(job['llm_result']);
                            final vision =
                                _asMap(job['vision_result']);
                            final imagePath = _safeString(
                                job['image_url']);
                            final diagnostic =
                                _safeString(llm?['diagnostic']) ??
                                    'No diagnostic';
                            final plantState =
                                _safeString(
                                    vision?['plant_state']) ??
                                    'unknown';
                            final processedAt = _formatDate(
                                job['processed_at'] ??
                                    job['created_at']);
                            final isAttention =
                                plantState == 'needs_attention';
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isAttention
                                              ? Icons
                                                  .warning_amber_rounded
                                              : Icons
                                                  .check_circle_outline,
                                          color: isAttention
                                              ? Colors.orange.shade700
                                              : Colors.green.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '$processedAt • '
                                            '${plantState.replaceAll('_', ' ')}',
                                            style: theme
                                                .textTheme.labelLarge,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (imagePath != null &&
                                        imagePath.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      FutureBuilder<String>(
                                        future:
                                            _getImageUrlCached(
                                                imagePath),
                                        builder: (context, snap) {
                                          if (!snap.hasData ||
                                              snap.data!.isEmpty) {
                                            return _placeholderImage(
                                                theme,
                                                height: 180);
                                          }
                                          return ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    8),
                                            child: Image.network(
                                              snap.data!,
                                              height: 180,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_,
                                                      __,
                                                      ___) =>
                                                  _placeholderImage(
                                                      theme,
                                                      height: 180),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Text(
                                      diagnostic,
                                      style:
                                          theme.textTheme.bodyMedium,
                                      maxLines: 4,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );

    if (mounted) setState(() => _historySheetVisible = false);
  }

  Future<void> _triggerCapture() async {
    final device =
        context.read<DeviceProvider>().selectedDevice;
    if (device == null || !SupabaseConfig.isInitialized) return;

    try {
      await SupabaseConfig.client!
          .from(SupabaseConfig.deviceCommandsTable)
          .insert({
        'device_id': device.id,
        'command_type': 'capture_image',
        'payload': {},
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Capture command sent')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device =
        context.watch<DeviceProvider>().selectedDevice;

    if (device == null) {
      return Material(
        color: theme.scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.devices_other,
                  size: 64, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text('Select a device',
                  style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return Material(
        color: theme.scaffoldBackgroundColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Material(
        color: theme.scaffoldBackgroundColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _load(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final inference = _latestInference;
    final diagnostic = _safeString(inference?['diagnostic']);
    final tips = inference?['tips'] as List?;
    final imageUrl =
        _safeString(_latestCompletedJob?['image_url']);
    final inProgressStatus =
        _safeString(_inProgressJob?['status']);
    final resultMap = _asMap(inference?['result']);
    final analysis =
        _asMap(_asMap(resultMap?['llm'])?['analysis']) ??
            _asMap(
                _asMap(_latestCompletedJob?['llm_result'])?[
                    'analysis']);
    final sensorSnapshot =
        _safeString(resultMap?['sensor_snapshot']);
    final envAssessment =
        _safeString(analysis?['environment_assessment']);
    final healthStatus =
        _safeString(analysis?['health_status']) ??
            _safeString(
                _asMap(resultMap?['vision'])?['plant_state']);
    final isHealthy = healthStatus != 'needs_attention';

    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;

    // Shared action bar (capture + history)
    final actionButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: () => _showHistorySheet(),
          icon: const Icon(Icons.history, size: 18),
          label: const Text('History'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _triggerCapture,
          icon: const Icon(Icons.camera_alt, size: 18),
          label: const Text('Capture Now'),
        ),
      ],
    );

    // Live stream section (always uses AspectRatio internally now)
    final live = _LiveStreamSection(
      visible: !_historySheetVisible,
      streamHeight: 260, // unused — stream uses AspectRatio internally
    );

    // Analysis content list (shared between wide right column and narrow tab)
    List<Widget> analysisContent() => [
          if (analysis != null) ...[
            _HealthStatusBanner(isHealthy: isHealthy, theme: theme),
            const SizedBox(height: 16),
          ],

          if (inProgressStatus != null)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 14),
                    Text('Capture in progress ($inProgressStatus)…'),
                  ],
                ),
              ),
            ),

          if (imageUrl != null) ...[
            FutureBuilder<String>(
              future: _getImageUrlCached(imageUrl),
              builder: (context, snap) {
                if (snap.hasData && snap.data!.isNotEmpty) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      snap.data!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _placeholderImage(theme),
                    ),
                  );
                }
                return _placeholderImage(theme);
              },
            ),
            const SizedBox(height: 16),
          ] else if (inProgressStatus == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.photo_camera, size: 48, color: theme.disabledColor),
                    const SizedBox(height: 12),
                    Text('No captures yet', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('Tap "Capture Now" to take a photo for AI analysis.'),
                  ],
                ),
              ),
            ),

          if (analysis != null) ...[
            const SizedBox(height: 8),
            Text('Plant Analysis', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _AnalysisGrid(analysis: analysis, theme: theme),
            const SizedBox(height: 16),
          ],

          if (envAssessment != null && envAssessment.isNotEmpty) ...[
            Text('Environment', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.sensors, color: theme.colorScheme.primary),
                title: Text(envAssessment, style: theme.textTheme.bodyMedium),
                subtitle: (sensorSnapshot != null && sensorSnapshot.isNotEmpty)
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          sensorSnapshot,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (diagnostic != null && diagnostic.isNotEmpty &&
              !(diagnostic.startsWith('<') && diagnostic.endsWith('>'))) ...[
            Text('Diagnostic', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(diagnostic, style: theme.textTheme.bodyMedium),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (tips != null)
            Builder(builder: (context) {
              final visibleTips = tips.where((t) {
                final s = t?.toString() ?? '';
                return s.isNotEmpty && !(s.startsWith('<') && s.endsWith('>'));
              }).toList();
              if (visibleTips.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Care Tips', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...visibleTips.asMap().entries.map((e) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text('${e.key + 1}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onPrimaryContainer)),
                          ),
                          title: Text(e.value is String ? e.value as String : e.value.toString()),
                        ),
                      )),
                ],
              );
            }),
        ];

    if (wide) {
      // Wide: stream on left (natural 4:3 aspect), scrollable analysis on right
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: stream column, constrained to 45% of width
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: size.width * 0.45),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('AI Plant Health',
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  live,
                  const SizedBox(height: 12),
                  actionButtons,
                ],
              ),
            ),
          ),
          // Divider
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          // Right: scrollable analysis
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: analysisContent(),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Narrow: tab bar with Live | Analysis
    return Column(
      children: [
        Material(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.videocam_outlined), text: 'Live'),
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Analysis'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 0: Live view + capture actions
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    live,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: actionButtons),
                  ],
                ),
              ),
              // Tab 1: Analysis results
              RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: analysisContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholderImage(ThemeData theme, {double height = 280}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(Icons.image_not_supported,
            size: 64, color: theme.disabledColor),
      ),
    );
  }

  Future<String> _getImageUrlCached(String path) {
    return _signedUrlFutureCache.putIfAbsent(
        path, () => _createSignedImageUrl(path));
  }

  Future<String> _createSignedImageUrl(String path) async {
    try {
      return await SupabaseConfig.client!.storage
          .from('device-images')
          .createSignedUrl(path, 3600);
    } catch (_) {
      return '';
    }
  }
}

// ---------------------------------------------------------------------------
// Health status banner
// ---------------------------------------------------------------------------
class _HealthStatusBanner extends StatelessWidget {
  const _HealthStatusBanner(
      {required this.isHealthy, required this.theme});
  final bool isHealthy;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color =
        isHealthy ? Colors.green.shade700 : Colors.orange.shade700;
    final bg =
        isHealthy ? Colors.green.shade50 : Colors.orange.shade50;
    final icon = isHealthy
        ? Icons.check_circle_outline
        : Icons.warning_amber_outlined;
    final label =
        isHealthy ? 'Plant is Healthy' : 'Needs Attention';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Text(label,
              style: theme.textTheme.titleMedium?.copyWith(
                  color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Analysis grid
// ---------------------------------------------------------------------------
class _AnalysisGrid extends StatelessWidget {
  const _AnalysisGrid(
      {required this.analysis, required this.theme});
  final Map<String, dynamic> analysis;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    bool isPlaceholder(String str) =>
        str.startsWith('<') && str.endsWith('>');

    String s(dynamic v) {
      if (v == null) return '—';
      if (v is List) {
        final parts = v
            .where((e) =>
                e != null &&
                e.toString().isNotEmpty &&
                !isPlaceholder(e.toString()))
            .map((e) => e.toString())
            .toList();
        return parts.isEmpty ? '—' : parts.join(', ');
      }
      final str = v.toString().trim();
      if (str.isEmpty || isPlaceholder(str)) return '—';
      return str;
    }

    final items = <_AnalysisItem>[
      _AnalysisItem(Icons.eco_outlined, 'Species',
          s(analysis['species'])),
      _AnalysisItem(Icons.palette_outlined, 'Leaf Colour',
          s(analysis['leaf_color'])),
      _AnalysisItem(Icons.crop_free_outlined, 'Leaf Area',
          s(analysis['leaf_area'])),
      _AnalysisItem(Icons.texture_outlined, 'Leaf Condition',
          s(analysis['leaf_condition'])),
      _AnalysisItem(Icons.timeline_outlined, 'Growth Stage',
          s(analysis['growth_stage'])),
      _AnalysisItem(Icons.bug_report_outlined, 'Disease / Pests',
          s(analysis['disease_signs'])),
      _AnalysisItem(Icons.water_drop_outlined, 'Soil',
          s(analysis['soil_observation'])),
    ].where((i) => i.value.isNotEmpty && i.value != '—').toList();

    return Column(
      children: items
          .map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(item.icon,
                      color: theme.colorScheme.primary),
                  title: Text(item.label,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(
                              color: theme
                                  .colorScheme.onSurfaceVariant)),
                  subtitle: Text(item.value,
                      style: theme.textTheme.bodyMedium),
                ),
              ))
          .toList(),
    );
  }
}

class _AnalysisItem {
  const _AnalysisItem(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}
