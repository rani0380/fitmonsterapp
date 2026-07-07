import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:smart_app/controllers/game_controller.dart';
import 'package:smart_app/services/camera_service.dart';
import 'package:smart_app/services/pose_detector_service.dart';
import 'package:smart_app/ui/fitmon_theme.dart';
import 'package:smart_app/ui/portrait_camera_preview.dart';
import 'package:smart_app/ui/pose_overlay.dart';

class JumpRunScreen extends StatefulWidget {
  const JumpRunScreen({super.key});

  @override
  State<JumpRunScreen> createState() => _JumpRunScreenState();
}

class _JumpRunScreenState extends State<JumpRunScreen> {
  static const int targetScore = 10;
  static const double _playerX = 78;
  static const double _groundY = 0;
  static const List<String> _cactusAssets = [
    'assets/images/cactus01.png',
    'assets/images/cactus02.png',
    'assets/images/cactus03.png',
  ];

  final CameraService _cameraService = Get.find<CameraService>();
  final PoseDetectorService _poseDetector = PoseDetectorService();
  final math.Random _random = math.Random();

  Timer? _gameLoop;
  DateTime? _lastGameTick;
  bool _processing = false;
  bool _finished = false;
  bool _closedDetector = false;
  bool _gameOver = false;
  bool _resultSaved = false;
  bool _armedForJump = true;
  bool _hasSeenPose = false;
  int _processedFrames = 0;
  int _poseCount = 0;
  int _score = 0;
  int _jumpCount = 0;
  int _airFrames = 0;
  int _groundFrames = 0;
  int _poseFrameId = 0;
  double? _baselineHipY;
  double _jumpPower = 0;
  double _runnerY = _groundY;
  double _runnerVelocity = 0;
  double _speed = 82;
  double _nextObstacleIn = 1.45;
  Pose? _latestPose;
  Size? _latestImageSize;
  String _cameraDebug = 'camera waiting';
  String _feedback =
      '\uC804\uC2E0\uC774 \uBCF4\uC774\uB3C4\uB85D \uCE74\uBA54\uB77C\uC5D0 \uB9DE\uCDB0 \uC8FC\uC138\uC694.';
  final List<_Obstacle> _obstacles = [];

  double get _progress => (_score / targetScore).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCamera();
      _startGameLoop();
    });
  }

  Future<void> _startCamera() async {
    await _cameraService.stopImageStream();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted || _finished) return;
    await _cameraService.initialize();
    if (!mounted || _finished) return;
    await _cameraService.startImageStream(_processFrame);
  }

  void _startGameLoop() {
    _lastGameTick = DateTime.now();
    _obstacles
      ..clear()
      ..add(_createObstacle(x: 285));
    _gameLoop?.cancel();
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || _finished || _gameOver) return;
      final now = DateTime.now();
      final dt = math.min(
        0.05,
        now.difference(_lastGameTick ?? now).inMilliseconds / 1000.0,
      );
      _lastGameTick = now;
      _tickGame(dt);
    });
  }

  void _tickGame(double dt) {
    if (!_hasSeenPose) {
      _feedback =
          '\uC900\uBE44 \uC911\uC785\uB2C8\uB2E4. \uC804\uC2E0\uC774 \uBCF4\uC774\uB3C4\uB85D \uC11C \uC8FC\uC138\uC694.';
      setState(() {});
      return;
    }

    _runnerVelocity -= 420 * dt;
    _runnerY += _runnerVelocity * dt;
    if (_runnerY <= _groundY) {
      _runnerY = _groundY;
      _runnerVelocity = 0;
    }

    for (final obstacle in _obstacles) {
      obstacle.x -= _speed * dt;
      if (!obstacle.scored && obstacle.x + obstacle.width < _playerX - 16) {
        obstacle.scored = true;
        _score++;
        _feedback =
            '\uC88B\uC544\uC694! \uC120\uC778\uC7A5\uC744 \uB118\uC5C8\uC5B4\uC694.';
      }
    }
    _obstacles.removeWhere((obstacle) => obstacle.x < -35);

    if (_obstacles.isEmpty) {
      _nextObstacleIn -= dt;
      if (_nextObstacleIn <= 0) {
        _obstacles.add(
          _createObstacle(x: 285 + _random.nextDouble() * 45),
        );
        _nextObstacleIn = 1.7 + _random.nextDouble() * 0.9;
        _speed = math.min(124, _speed + 1.2);
      }
    }

    if (_hitsObstacle()) {
      _gameOver = true;
      _saveRunResult(completed: false);
      _feedback =
          '\uC120\uC778\uC7A5\uC5D0 \uBD80\uB52A\uD614\uC5B4\uC694. \uB2E4\uC2DC \uB3C4\uC804\uD574\uC694!';
    }

    if (_score >= targetScore) {
      _finished = true;
      _saveRunResult(completed: true);
      _feedback =
          '\uC131\uACF5! \uC120\uC778\uC7A5\uC744 \uBAA8\uB450 \uB118\uC5C8\uC5B4\uC694.';
      _showFinishDialog();
    }

    setState(() {});
  }

  bool _hitsObstacle() {
    final playerLeft = _playerX - 14;
    final playerRight = _playerX + 16;
    final playerBottom = _runnerY;
    final playerTop = _runnerY + 50;

    for (final obstacle in _obstacles) {
      final obstacleLeft = obstacle.x;
      final obstacleRight = obstacle.x + obstacle.width * 0.78;
      final obstacleTop = obstacle.height * 0.72;
      final overlapsX =
          playerRight > obstacleLeft && playerLeft < obstacleRight;
      final overlapsY = playerBottom < obstacleTop && playerTop > 4;
      if (overlapsX && overlapsY) return true;
    }
    return false;
  }

  void _triggerJump() {
    if (_gameOver || _finished) return;
    if (_runnerY > _groundY + 2) return;
    _runnerVelocity = 245 + _jumpPower * 0.55;
    _jumpCount++;
    _feedback = '\uC810\uD504!';
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_processing || _finished) return;
    _processing = true;
    _processedFrames++;
    _cameraDebug =
        '${image.width}x${image.height} f${image.format.raw} p${image.planes.length}';

    try {
      final inputImage = _cameraService.inputImageFromCameraImage(image);
      final overlaySize = _cameraService.poseOverlayImageSize(image);
      if (inputImage == null) {
        _poseCount = 0;
        _feedback = '?怨멸텭?嶺????ш끽維????怨뚮뼚???????됰꽡: $_cameraDebug';
        _setPose(null, overlaySize);
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);
      if (!mounted || _finished) return;

      final pose = poses.isNotEmpty ? poses.first : null;
      _poseCount = poses.length;
      if (pose != null) {
        _hasSeenPose = true;
      }
      _setPose(pose, overlaySize);

      if (pose == null) {
        setState(() {
          _jumpPower = 0;
          _feedback =
              '\uC804\uC2E0\uC774 \uBCF4\uC774\uB3C4\uB85D 2m \uC815\uB3C4 \uB5A8\uC5B4\uC838 \uC11C \uC8FC\uC138\uC694.';
        });
        return;
      }

      _updatePoseJump(pose);
    } finally {
      _processing = false;
    }
  }

  void _updatePoseJump(Pose pose) {
    final hipY = _poseDetector.getHipY(pose);
    if (hipY <= 0) return;

    _baselineHipY ??= hipY;
    if (_armedForJump) {
      _baselineHipY = _baselineHipY! * 0.94 + hipY * 0.06;
    }

    final baseline = _baselineHipY!;
    final lift = baseline - hipY;
    final jumpThreshold = math.max(20.0, baseline * 0.032);
    final landThreshold = math.max(9.0, jumpThreshold * 0.42);
    final airborne = lift > jumpThreshold;

    if (airborne) {
      _airFrames++;
      _groundFrames = 0;
    } else if (lift < landThreshold) {
      _groundFrames++;
      _airFrames = 0;
    }

    if (_groundFrames >= 4) {
      _armedForJump = true;
    }

    final poseJumped = _armedForJump && _airFrames >= 2;
    setState(() {
      _jumpPower = (lift / jumpThreshold * 100).clamp(0.0, 100.0).toDouble();
    });

    if (poseJumped) {
      _armedForJump = false;
      _triggerJump();
    }
  }

  void _setPose(Pose? pose, Size imageSize) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finished) return;
      setState(() {
        _latestPose = pose;
        _latestImageSize = imageSize;
        _poseFrameId++;
      });
    });
  }

  void _restartGame() {
    setState(() {
      _gameOver = false;
      _resultSaved = false;
      _score = 0;
      _jumpCount = 0;
      _hasSeenPose = false;
      _runnerY = _groundY;
      _runnerVelocity = 0;
      _speed = 82;
      _nextObstacleIn = 1.45;
      _feedback = '전신이 보이도록 서 주세요.';
      _obstacles
        ..clear()
        ..add(_createObstacle(x: 285));
    });
    _startGameLoop();
  }

  void _saveRunResult({required bool completed}) {
    if (_resultSaved) return;
    _resultSaved = true;
    Get.find<GameController>().saveJumpRunResult(
      cactusCount: _score,
      jumpCount: _jumpCount,
      targetCount: targetScore,
      completed: completed,
    );
  }

  _Obstacle _createObstacle({required double x}) {
    return _Obstacle(
      x: x,
      width: 20 + _random.nextDouble() * 8,
      height: 34 + _random.nextDouble() * 12,
      asset: _cactusAssets[_random.nextInt(_cactusAssets.length)],
    );
  }

  Future<void> _showFinishDialog() async {
    _gameLoop?.cancel();
    await _cameraService.stopImageStream();
    await _waitForFrameProcessing();
    await _closeDetectorWhenIdle();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('??ш끽維???濚밸Þ?볠쾮?'),
        content: Text('???믩눀?룐뫖??$targetScore??좊즵獒? 癲ル슢?꾤땟?嶺???筌????⑤챶萸?'),
        actions: [
          FilledButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) Get.back();
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
    _gameLoop?.cancel();
    _cameraService.stopImageStream();
    _closeDetectorWhenIdle();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF07111D),
      body: Stack(
        children: [
          Positioned.fill(
            child: _SideRunnerScene(
              obstacles: List<_Obstacle>.from(_obstacles),
              runnerY: _runnerY,
              score: _score,
              onTapJump: _triggerJump,
            ),
          ),
          _buildHud(),
          _buildCameraPanel(safeBottom),
          if (_gameOver) _buildGameOverOverlay(),
        ],
      ),
    );
  }

  Widget _buildHud() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Column(
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () async {
                    _finished = true;
                    _gameLoop?.cancel();
                    await _cameraService.stopImageStream();
                    await _waitForFrameProcessing();
                    await _closeDetectorWhenIdle();
                    if (mounted) Get.back();
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: FitmonColors.greenLight,
                    foregroundColor: FitmonColors.bg,
                  ),
                  icon: const Icon(Icons.close),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '\uC0AC\uB9C9 \uB2EC\uB9AC\uAE30',
                            style: TextStyle(
                              color: FitmonColors.yellow,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(_progress * 100).toStringAsFixed(0)}%',
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
                          value: _progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            FitmonColors.greenLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: fitmonCard(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '\uC120\uC778\uC7A5\uC774 \uC624\uBA74 \uC810\uD504\uD574\uC11C \uB6F0\uC5B4\uB118\uC5B4\uC694.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _feedback,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: FitmonColors.soft, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Metric(
                          label: '\uC120\uC778\uC7A5',
                          value: '$_score/$targetScore'),
                      const SizedBox(width: 8),
                      _Metric(label: '\uC810\uD504', value: '$_jumpCount'),
                      const SizedBox(width: 8),
                      _Metric(label: '\uC778\uC2DD', value: '$_poseCount'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPanel(double safeBottom) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = (screenWidth * 0.36).clamp(116.0, 146.0).toDouble();
    return Positioned(
      right: 14,
      bottom: safeBottom + 20,
      child: Container(
        width: panelWidth,
        height: panelWidth * 1.18,
        decoration: BoxDecoration(
          color: FitmonColors.bgDeep.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FitmonColors.greenLight, width: 1.5),
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
                  fit: BoxFit.contain,
                ),
                PoseOverlay(
                  pose: _latestPose,
                  imageSize: _latestImageSize,
                  quarterTurns: _cameraService.previewQuarterTurns,
                  mirror: _cameraService.activeCamera?.lensDirection ==
                      CameraLensDirection.front,
                  repaintId: _poseFrameId,
                  fit: BoxFit.contain,
                  pointRadius: 3,
                  strokeWidth: 2,
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'F$_processedFrames $_cameraDebug',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
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

  Widget _buildGameOverOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.50),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(18),
            decoration: fitmonCard(color: FitmonColors.cardAlt),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '게임 종료',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text('선인장 $_score개를 넘었어요.'),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _restartGame,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시하기'),
                ),
              ],
            ),
          ),
        ),
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
          color: FitmonColors.bgDeep.withValues(alpha: 0.36),
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

class _SideRunnerScene extends StatelessWidget {
  const _SideRunnerScene({
    required this.obstacles,
    required this.runnerY,
    required this.score,
    required this.onTapJump,
  });

  final List<_Obstacle> obstacles;
  final double runnerY;
  final int score;
  final VoidCallback onTapJump;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapJump,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final groundY = size.height * 0.78;
          final playerX = 78 / 240 * size.width;
          final playerBottom = groundY - runnerY / 140 * size.height;
          final isJumping = runnerY > 2;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/desert.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.22),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: groundY - 10,
                bottom: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00D99D4A), Color(0x88C2722C)],
                    ),
                  ),
                ),
              ),
              for (final obstacle in obstacles)
                _CactusObstacle(
                  obstacle: obstacle,
                  screenSize: size,
                  groundY: groundY,
                ),
              Positioned(
                left: playerX - 36,
                top: playerBottom - (isJumping ? 112 : 104),
                child: _RunnerImage(isJumping: isJumping),
              ),
              Positioned(
                left: playerX - 26,
                top: groundY + 5,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: isJumping ? 34 : 54,
                  height: isJumping ? 7 : 10,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: isJumping ? 0.14 : 0.26,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                top: 34,
                child: Text(
                  'SCORE $score',
                  style: const TextStyle(
                    color: FitmonColors.yellow,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CactusObstacle extends StatelessWidget {
  const _CactusObstacle({
    required this.obstacle,
    required this.screenSize,
    required this.groundY,
  });

  final _Obstacle obstacle;
  final Size screenSize;
  final double groundY;

  @override
  Widget build(BuildContext context) {
    final left = obstacle.x / 240 * screenSize.width;
    final width = obstacle.width / 240 * screenSize.width * 1.45;
    final height = obstacle.height / 140 * screenSize.height * 0.92;

    return Positioned(
      left: left,
      top: groundY - height + 28,
      width: width,
      height: height,
      child: Image.asset(
        obstacle.asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _RunnerImage extends StatelessWidget {
  const _RunnerImage({required this.isJumping});

  final bool isJumping;

  @override
  Widget build(BuildContext context) {
    final asset = isJumping
        ? 'assets/images/jump_smaeong3.png'
        : 'assets/images/smaeong_ver03.png';

    return SizedBox(
      width: isJumping ? 84 : 76,
      height: isJumping ? 112 : 104,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _Obstacle {
  _Obstacle({
    required this.x,
    required this.width,
    required this.height,
    required this.asset,
  });

  double x;
  final double width;
  final double height;
  final String asset;
  bool scored = false;
}
