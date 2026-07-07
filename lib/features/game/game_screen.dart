import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:smart_app/controllers/game_controller.dart';
import 'package:smart_app/features/result/result_screen.dart';
import 'package:smart_app/services/camera_service.dart';
import 'package:smart_app/services/pose_detector_service.dart';
import 'package:smart_app/ui/fitmon_theme.dart';
import 'package:smart_app/ui/portrait_camera_preview.dart';
import 'package:smart_app/ui/pose_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameController _controller = Get.find<GameController>();
  final CameraService _cameraService = Get.find<CameraService>();
  final PoseDetectorService _poseDetector = PoseDetectorService();

  Timer? _ticker;
  bool _processing = false;
  bool _finished = false;
  bool _closedDetector = false;
  Pose? _latestPose;
  Size? _latestImageSize;
  int _poseFrameId = 0;
  DateTime? _lastPoseAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.resetGame();
      _start();
    });
  }

  Future<void> _start() async {
    _processing = false;
    await _cameraService.stopImageStream();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted || _finished) return;
    await _cameraService.initialize();
    if (!mounted || _finished) return;
    await _cameraService.startImageStream(_processFrame);
    if (!mounted || _finished) {
      await _cameraService.stopImageStream();
      return;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (!mounted || _finished) return;
      final poseIsFresh = _lastPoseAt != null &&
          DateTime.now().difference(_lastPoseAt!).inMilliseconds < 700;
      if (!poseIsFresh) {
        _controller.tickWithoutPose();
      }
      if (!_finished &&
          _controller.squatCount.value >= _controller.targetSquatCount.value) {
        _finish();
      }
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_processing || _finished) return;
    _processing = true;
    _controller.registerFrame();
    try {
      final inputImage = _cameraService.inputImageFromCameraImage(image);
      final overlaySize = _cameraService.poseOverlayImageSize(image);
      if (inputImage == null) {
        _controller.updatePoseCount(0);
        _updatePoseOverlay(null, overlaySize);
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);
      if (!mounted || _finished) return;
      _controller.updatePoseCount(poses.length);
      final pose = poses.isNotEmpty ? poses.first : null;
      if (pose != null) {
        _lastPoseAt = DateTime.now();
      }
      _updatePoseOverlay(pose, overlaySize);
      if (pose != null) {
        _controller.updateMotion(
          squat: _poseDetector.isSquatting(pose),
          lateral: _poseDetector.getLateralOffset(pose, image.width.toDouble()),
          hipY: _poseDetector.getMotionSignal(pose),
        );
      }
    } finally {
      _processing = false;
    }
  }

  void _updatePoseOverlay(Pose? pose, Size imageSize) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _latestPose = pose;
        _latestImageSize = imageSize;
        _poseFrameId++;
      });
    });
  }

  Future<void> _finish() async {
    _finished = true;
    _ticker?.cancel();
    await _cameraService.stopImageStream();
    await _waitForFrameProcessing();
    await _closeDetectorWhenIdle();
    if (mounted) Get.off(() => const ResultScreen());
  }

  Future<void> _waitForFrameProcessing() async {
    for (var i = 0; i < 10 && _processing; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _closeDetectorWhenIdle() async {
    if (_closedDetector) return;
    await _waitForFrameProcessing();
    if (_closedDetector) return;
    _closedDetector = true;
    _poseDetector.close();
  }

  @override
  void dispose() {
    _finished = true;
    _ticker?.cancel();
    _cameraService.stopImageStream();
    _closeDetectorWhenIdle();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FitmonColors.bg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BattleBgPainter())),
          Positioned.fill(
            child: Obx(
              () => _BattleScene(
                attackTick: _controller.attackTick.value,
                monsterAttackTick: _controller.monsterAttackTick.value,
                isSquatting: _controller.isSquatting.value,
                lateral: _controller.lateralOffset.value,
                monsterHp: _controller.monsterHp.value,
                character: _controller.selectedCharacter.value,
              ),
            ),
          ),
          _buildHud(),
          _buildCameraPreview(),
          _buildBoosterButton(),
        ],
      ),
    );
  }

  Widget _buildHud() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: FitmonColors.greenLight,
                    foregroundColor: FitmonColors.bg,
                  ),
                  onPressed: () async {
                    _finished = true;
                    await _cameraService.stopImageStream();
                    await _waitForFrameProcessing();
                    await _closeDetectorWhenIdle();
                    Get.back();
                  },
                  icon: const Icon(Icons.close),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Obx(
                    () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'BATTLE RUN',
                              style: TextStyle(
                                fontSize: 11,
                                color: FitmonColors.yellow,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(_controller.raceProgress.value * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: FitmonColors.greenLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _controller.raceProgress.value,
                            minHeight: 8,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              FitmonColors.greenLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Obx(
              () => _HudPanel(
                quest: _controller.questText,
                feedback: _controller.feedbackText.value,
                squat: _controller.squatPower.value.toStringAsFixed(0),
                shots: '${_controller.squatCount.value}',
                pose: '${_controller.detectedPoseCount.value}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final screenSize = MediaQuery.sizeOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final panelWidth = (screenSize.width * 0.42).clamp(142.0, 164.0).toDouble();
    final panelHeight = (panelWidth * 1.68).clamp(238.0, 276.0).toDouble();

    return Positioned(
      right: 10,
      bottom: safeBottom + 74,
      child: Container(
        width: panelWidth,
        height: panelHeight,
        decoration: BoxDecoration(
          color: FitmonColors.bgDeep.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FitmonColors.greenLight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Obx(() {
            final camera = _cameraService.controller;
            if (!_cameraService.isInitialized.value || camera == null) {
              return const Center(
                child: Icon(Icons.videocam_off, color: FitmonColors.muted),
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                PortraitCameraPreview(
                  controller: camera,
                  quarterTurns: _cameraService.previewQuarterTurns,
                  fit: BoxFit.cover,
                ),
                PoseOverlay(
                  pose: _latestPose,
                  imageSize: _latestImageSize,
                  quarterTurns: _cameraService.previewQuarterTurns,
                  mirror: _cameraService.activeCamera?.lensDirection ==
                      CameraLensDirection.front,
                  repaintId: _poseFrameId,
                  fit: BoxFit.cover,
                  pointRadius: 3.2,
                  strokeWidth: 2.2,
                ),
                if (_latestPose == null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PoseGuidePainter(),
                    ),
                  ),
                if (_latestPose == null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 18, 6, 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                      child: const Text(
                        '전신을 맞춰주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 6,
                  right: 6,
                  top: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.56),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _latestPose == null
                          ? '동작 확인 F${_controller.processedFrames.value}'
                          : '자세 추적 ${_controller.detectedPoseCount.value} F${_controller.processedFrames.value}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBoosterButton() {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 16,
      right: 16,
      bottom: safeBottom + 16,
      child: Obx(
        () => FilledButton.icon(
          onPressed: _controller.boosterGauge.value >= 1
              ? _controller.useBooster
              : null,
          icon: const Icon(Icons.flash_on),
          label: Text(
            '부스터 ${(100 * _controller.boosterGauge.value).toStringAsFixed(0)}%',
          ),
          style: FilledButton.styleFrom(
            disabledBackgroundColor: FitmonColors.cardAlt,
            disabledForegroundColor: FitmonColors.muted,
            minimumSize: const Size.fromHeight(46),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}

class _HudPanel extends StatelessWidget {
  const _HudPanel({
    required this.quest,
    required this.feedback,
    required this.squat,
    required this.shots,
    required this.pose,
  });

  final String quest;
  final String feedback;
  final String squat;
  final String shots;
  final String pose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FitmonColors.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quest,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            feedback,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: FitmonColors.soft, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(label: '스쿼트', value: squat),
              const SizedBox(width: 8),
              _Metric(label: '명중', value: shots),
              const SizedBox(width: 8),
              _Metric(label: '자세', value: pose),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: FitmonColors.bgDeep.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: FitmonColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoseGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = FitmonColors.yellow.withValues(alpha: 0.62)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final point = Paint()..color = FitmonColors.greenLight;

    Offset p(double x, double y) => Offset(size.width * x, size.height * y);

    final head = p(0.50, 0.22);
    final neck = p(0.50, 0.34);
    final leftShoulder = p(0.35, 0.36);
    final rightShoulder = p(0.65, 0.36);
    final leftElbow = p(0.27, 0.52);
    final rightElbow = p(0.73, 0.52);
    final leftWrist = p(0.22, 0.66);
    final rightWrist = p(0.78, 0.66);
    final hip = p(0.50, 0.62);
    final leftKnee = p(0.40, 0.78);
    final rightKnee = p(0.60, 0.78);
    final leftAnkle = p(0.36, 0.92);
    final rightAnkle = p(0.64, 0.92);

    void bone(Offset a, Offset b) => canvas.drawLine(a, b, line);
    bone(head, neck);
    bone(leftShoulder, rightShoulder);
    bone(neck, hip);
    bone(leftShoulder, leftElbow);
    bone(leftElbow, leftWrist);
    bone(rightShoulder, rightElbow);
    bone(rightElbow, rightWrist);
    bone(hip, leftKnee);
    bone(leftKnee, leftAnkle);
    bone(hip, rightKnee);
    bone(rightKnee, rightAnkle);

    for (final joint in [
      head,
      leftShoulder,
      rightShoulder,
      leftElbow,
      rightElbow,
      leftWrist,
      rightWrist,
      hip,
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
    ]) {
      canvas.drawCircle(joint, 4, point);
      canvas.drawCircle(
        joint,
        4,
        Paint()
          ..color = FitmonColors.bgDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BattleScene extends StatelessWidget {
  const _BattleScene({
    required this.attackTick,
    required this.monsterAttackTick,
    required this.isSquatting,
    required this.lateral,
    required this.monsterHp,
    required this.character,
  });

  final int attackTick;
  final int monsterAttackTick;
  final bool isSquatting;
  final double lateral;
  final double monsterHp;
  final GameCharacter character;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final safeTop = padding.top;
    final safeBottom = padding.bottom;
    final contentTop = safeTop + 128;
    final boosterTop = size.height - safeBottom - 78;
    final contentHeight = (boosterTop - contentTop).clamp(260.0, 520.0);
    final monsterTop = contentTop + contentHeight * 0.04;
    final playerY = (contentTop + contentHeight * 0.70)
        .clamp(contentTop + 190, boosterTop - 82)
        .toDouble();
    final monsterCenter = Offset(size.width * 0.5, monsterTop + 78);
    final playerCenter = Offset(
      (size.width * (0.28 + lateral * 0.22)).clamp(94.0, size.width * 0.56),
      playerY,
    );
    final muzzle = playerCenter + const Offset(66, -64);
    final monsterDamage = (1 - monsterHp).clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned(
          top: monsterTop,
          left: 0,
          right: 0,
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey('monster-$attackTick'),
                tween: Tween(begin: 1, end: 0),
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOut,
                builder: (context, hit, child) {
                  final shake = math.sin(hit * math.pi * 8) * 7 * hit;
                  return Transform.translate(
                    offset: Offset(shake, 0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 176,
                          height: 176,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                FitmonColors.greenLight.withValues(alpha: 0.23),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.red.withValues(alpha: 0.42 * hit),
                            BlendMode.srcATop,
                          ),
                          child: child,
                        ),
                        if (hit > 0.05)
                          Positioned(
                            right: 34,
                            top: 38,
                            child: Opacity(
                              opacity: hit.clamp(0.0, 1.0),
                              child: const _HitBurst(
                                  color: FitmonColors.greenLight),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                child: SizedBox(
                  width: 180,
                  height: 156,
                  child: _OrcMonsterSprite(
                    attackTick: attackTick,
                    monsterAttackTick: monsterAttackTick,
                    monsterHp: monsterHp,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 184,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: monsterHp,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(FitmonColors.red),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '피해량 ${(monsterDamage * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: FitmonColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        CustomPaint(
          size: Size.infinite,
          painter: _AimLinePainter(from: muzzle, to: monsterCenter),
        ),
        if (attackTick > 0)
          TweenAnimationBuilder<double>(
            key: ValueKey('shot-$attackTick'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 430),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _GelShotPainter(
                  progress: value,
                  from: muzzle,
                  to: monsterCenter,
                ),
              );
            },
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          left: playerCenter.dx - 64,
          top: playerCenter.dy - 74,
          child: _SmameongShooter(
            attackTick: attackTick,
            firing: attackTick > 0,
            isSquatting: isSquatting,
            character: character,
          ),
        ),
      ],
    );
  }
}

enum _OrcSpriteMode { idle, hurt, attack, dead }

class _OrcMonsterSprite extends StatefulWidget {
  const _OrcMonsterSprite({
    required this.attackTick,
    required this.monsterAttackTick,
    required this.monsterHp,
  });

  final int attackTick;
  final int monsterAttackTick;
  final double monsterHp;

  @override
  State<_OrcMonsterSprite> createState() => _OrcMonsterSpriteState();
}

class _OrcMonsterSpriteState extends State<_OrcMonsterSprite> {
  _OrcSpriteMode _mode = _OrcSpriteMode.idle;
  Timer? _returnToIdleTimer;

  @override
  void didUpdateWidget(covariant _OrcMonsterSprite oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.monsterHp <= 0.04) {
      _setMode(_OrcSpriteMode.dead);
      return;
    }

    if (widget.attackTick != oldWidget.attackTick) {
      _setModeTemporarily(
          _OrcSpriteMode.hurt, const Duration(milliseconds: 520));
      return;
    }

    if (widget.monsterAttackTick != oldWidget.monsterAttackTick) {
      _setModeTemporarily(
        _OrcSpriteMode.attack,
        const Duration(milliseconds: 720),
      );
    }
  }

  @override
  void dispose() {
    _returnToIdleTimer?.cancel();
    super.dispose();
  }

  void _setMode(_OrcSpriteMode mode) {
    _returnToIdleTimer?.cancel();
    if (_mode == mode) return;
    setState(() => _mode = mode);
  }

  void _setModeTemporarily(_OrcSpriteMode mode, Duration duration) {
    _returnToIdleTimer?.cancel();
    setState(() => _mode = mode);
    _returnToIdleTimer = Timer(duration, () {
      if (!mounted || widget.monsterHp <= 0.04) return;
      setState(() => _mode = _OrcSpriteMode.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_mode) {
      _OrcSpriteMode.hurt => const _SpriteSheetAnimation(
          assetPath: 'assets/images/orc_warrior_hurt.png',
          frameCount: 2,
          frameDuration: Duration(milliseconds: 150),
          loop: false,
        ),
      _OrcSpriteMode.attack => const _SpriteSheetAnimation(
          assetPath: 'assets/images/orc_warrior_attack_1.png',
          frameCount: 4,
          frameDuration: Duration(milliseconds: 130),
          loop: false,
        ),
      _OrcSpriteMode.dead => const _SpriteSheetAnimation(
          assetPath: 'assets/images/orc_warrior_dead.png',
          frameCount: 4,
          frameDuration: Duration(milliseconds: 180),
          loop: false,
        ),
      _ => const _SpriteSheetAnimation(
          assetPath: 'assets/images/orc_warrior_idle.png',
          frameCount: 5,
          frameDuration: Duration(milliseconds: 170),
        ),
    };
  }
}

class _SpriteSheetAnimation extends StatefulWidget {
  const _SpriteSheetAnimation({
    required this.assetPath,
    required this.frameCount,
    required this.frameDuration,
    this.loop = true,
  });

  final String assetPath;
  final int frameCount;
  final Duration frameDuration;
  final bool loop;

  @override
  State<_SpriteSheetAnimation> createState() => _SpriteSheetAnimationState();
}

class _SpriteSheetAnimationState extends State<_SpriteSheetAnimation> {
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _SpriteSheetAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath ||
        oldWidget.frameCount != widget.frameCount ||
        oldWidget.frameDuration != widget.frameDuration ||
        oldWidget.loop != widget.loop) {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _frame = 0;
    _timer = Timer.periodic(widget.frameDuration, (_) {
      if (!mounted) return;
      setState(() {
        if (_frame >= widget.frameCount - 1) {
          _frame = widget.loop ? 0 : widget.frameCount - 1;
        } else {
          _frame++;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameWidth = constraints.maxWidth;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: frameWidth * widget.frameCount,
            maxWidth: frameWidth * widget.frameCount,
            minHeight: constraints.maxHeight,
            maxHeight: constraints.maxHeight,
            child: Transform.translate(
              offset: Offset(-frameWidth * _frame, 0),
              child: Image.asset(
                widget.assetPath,
                width: frameWidth * widget.frameCount,
                height: constraints.maxHeight,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SmameongShooter extends StatelessWidget {
  const _SmameongShooter({
    required this.attackTick,
    required this.firing,
    required this.isSquatting,
    required this.character,
  });

  final int attackTick;
  final bool firing;
  final bool isSquatting;
  final GameCharacter character;

  @override
  Widget build(BuildContext context) {
    final assetPath = switch (character) {
      GameCharacter.monster01 => 'assets/images/monster01.png',
      GameCharacter.monster02 => 'assets/images/monster02.png',
      GameCharacter.smameong => isSquatting
          ? 'assets/images/smaeong_squat_down.png'
          : 'assets/images/smaeong_squat_up.png',
    };

    return TweenAnimationBuilder<double>(
      key: ValueKey('smameong-attack-$attackTick'),
      tween: Tween(begin: firing ? 1 : 0, end: 0),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (context, recoil, _) {
        final kick = recoil * 13;
        final scale = 1 + recoil * 0.08;
        final rotation = -recoil * 0.08;
        return Transform.translate(
          offset: Offset(-kick, kick * 0.22),
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 132,
                height: 150,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 14,
                      bottom: 0,
                      child: Container(
                        width: 106,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        child: Image.asset(
                          assetPath,
                          key: ValueKey(assetPath),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: 58,
                      child: CustomPaint(
                        size: const Size(52, 30),
                        painter: _GunPainter(),
                      ),
                    ),
                    if (recoil > 0.04)
                      Positioned(
                        right: -12,
                        top: 46,
                        child: Opacity(
                          opacity: recoil.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.75 + recoil * 0.65,
                            child: const _MuzzleFlash(),
                          ),
                        ),
                      ),
                    if (recoil > 0.20)
                      Positioned(
                        left: 7,
                        top: 18,
                        child: Transform.rotate(
                          angle: -0.18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: FitmonColors.yellow,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: FitmonColors.yellow
                                      .withValues(alpha: 0.5),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Text(
                              '젤 발사!',
                              style: TextStyle(
                                color: FitmonColors.bg,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MuzzleFlash extends StatelessWidget {
  const _MuzzleFlash();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(42, 42),
      painter: _StarPainter(color: FitmonColors.yellow),
    );
  }
}

class _HitBurst extends StatelessWidget {
  const _HitBurst({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(50, 50),
      painter: _StarPainter(color: color),
    );
  }
}

class _GunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = const Color(0xFF17253A);
    final metal = Paint()..color = const Color(0xFFB7C4D8);
    final accent = Paint()..color = FitmonColors.cyan;

    final barrel = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.12, 4, size.width * 0.80, 10),
      const Radius.circular(5),
    );
    canvas.drawRRect(barrel, metal);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.05, 11, size.width * 0.55, 16),
        const Radius.circular(5),
      ),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.26, 24, 13, 18),
        const Radius.circular(4),
      ),
      body,
    );
    canvas.drawCircle(Offset(size.width * 0.23, 19), 3, accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AimLinePainter extends CustomPainter {
  const _AimLinePainter({required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FitmonColors.cyan.withValues(alpha: 0.14)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, paint);
  }

  @override
  bool shouldRepaint(covariant _AimLinePainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to;
}

class _GelShotPainter extends CustomPainter {
  const _GelShotPainter({
    required this.progress,
    required this.from,
    required this.to,
  });

  final double progress;
  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final current = Offset.lerp(from, to, progress)!;
    final tail = Offset.lerp(from, to, (progress - 0.18).clamp(0.0, 1.0))!;
    final wobble = math.sin(progress * math.pi * 8) * 7;
    final direction = to - from;
    final length = direction.distance == 0 ? 1.0 : direction.distance;
    final normal = Offset(-direction.dy / length, direction.dx / length);
    final gelCenter = current + normal * wobble;

    final trail = Paint()
      ..shader = LinearGradient(
        colors: [
          FitmonColors.greenLight.withValues(alpha: 0.0),
          FitmonColors.greenLight.withValues(alpha: 0.55),
          FitmonColors.cyan.withValues(alpha: 0.45),
        ],
      ).createShader(Rect.fromPoints(tail, gelCenter))
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = FitmonColors.greenLight.withValues(alpha: 0.20)
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(tail, gelCenter, glow);
    canvas.drawLine(tail, gelCenter, trail);
    canvas.drawCircle(
      gelCenter,
      18,
      Paint()..color = FitmonColors.greenLight.withValues(alpha: 0.16),
    );
    canvas.drawOval(
      Rect.fromCenter(center: gelCenter, width: 24, height: 18),
      Paint()..color = const Color(0xFF7DFF57),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: gelCenter + const Offset(-5, -5),
        width: 9,
        height: 6,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.78),
    );
    canvas.drawCircle(
      gelCenter + normal * 14,
      5,
      Paint()..color = FitmonColors.cyan.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      gelCenter - normal * 12,
      4,
      Paint()..color = FitmonColors.green.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _GelShotPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.from != from ||
      oldDelegate.to != to;
}

class _StarPainter extends CustomPainter {
  const _StarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final radius = i.isEven ? size.width * 0.48 : size.width * 0.16;
      final angle = -math.pi / 2 + i * math.pi / 8;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: 0.34),
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(center, size.width * 0.12, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _BattleBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B1526), Color(0xFF06080F)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final arena = Path()
      ..moveTo(size.width * 0.12, size.height)
      ..lineTo(size.width * 0.36, size.height * 0.30)
      ..lineTo(size.width * 0.64, size.height * 0.30)
      ..lineTo(size.width * 0.88, size.height)
      ..close();
    canvas.drawPath(arena, Paint()..color = const Color(0xFF101B2B));

    final edge = Paint()
      ..color = FitmonColors.cyan.withValues(alpha: 0.14)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(arena, edge);

    final linePaint = Paint()
      ..color = FitmonColors.yellow.withValues(alpha: 0.24)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (double y = size.height * 0.38; y < size.height; y += 58) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + 26),
        linePaint,
      );
    }

    final spark = Paint()
      ..color = FitmonColors.greenLight.withValues(alpha: 0.18)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(22, size.height * 0.31),
        Offset(size.width * 0.22, size.height * 0.20), spark);
    canvas.drawLine(Offset(size.width - 24, size.height * 0.34),
        Offset(size.width * 0.78, size.height * 0.21), spark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
