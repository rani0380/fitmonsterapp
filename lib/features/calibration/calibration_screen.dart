import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:smart_app/controllers/game_controller.dart';
import 'package:smart_app/features/game/game_screen.dart';
import 'package:smart_app/services/camera_service.dart';
import 'package:smart_app/services/pose_detector_service.dart';
import 'package:smart_app/ui/fitmon_theme.dart';
import 'package:smart_app/ui/portrait_camera_preview.dart';

Rect _calibrationGuideRect(Size size) {
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height * 0.43),
    width: size.width * 0.74,
    height: size.height * 0.62,
  );
}

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final CameraService _cameraService = Get.find<CameraService>();
  final GameController _gameController = Get.find<GameController>();
  final PoseDetectorService _poseDetector = PoseDetectorService();

  bool _processing = false;
  bool _movingToGame = false;
  bool _closedDetector = false;
  Pose? _latestPose;
  Size? _latestImageSize;
  _PoseQuality _poseQuality = const _PoseQuality.empty();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeCamera();
    });
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize();

      if (!mounted) return;

      await _cameraService.startImageStream(_processCameraImage);
    } catch (e) {
      _cameraService.errorMessage.value = '移대찓??珥덇린???ㅻ쪟: $e';
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_processing || !mounted) return;

    _processing = true;
    _gameController.registerFrame();

    try {
      final inputImage = _cameraService.inputImageFromCameraImage(image);
      final overlaySize = _cameraService.poseOverlayImageSize(image);

      if (inputImage == null) {
        _gameController.updatePoseCount(0);
        _updatePoseDebug(null, overlaySize);
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);

      if (!mounted) return;

      _gameController.updatePoseCount(poses.length);

      final pose = poses.isNotEmpty ? poses.first : null;

      _updatePoseDebug(pose, overlaySize);

      if (pose != null) {
        _gameController.updateMotion(
          squat: _poseDetector.isSquatting(pose),
          lateral: _poseDetector.getLateralOffset(
            pose,
            image.width.toDouble(),
          ),
          hipY: _poseDetector.getHipY(pose),
        );
      }
    } catch (e) {
      _cameraService.errorMessage.value = '?ъ쫰 ?몄떇 ?ㅻ쪟: $e';
    } finally {
      _processing = false;
    }
  }

  void _updatePoseDebug(Pose? pose, Size imageSize) {
    if (!mounted) return;

    final quality = _PoseQuality.fromPose(pose);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _latestPose = pose;
        _latestImageSize = imageSize;
        _poseQuality = quality;
      });
    });
  }

  @override
  void dispose() {
    if (!_movingToGame) {
      _cameraService.stopImageStream();
      _closeDetectorWhenIdle();
    }
    super.dispose();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FitmonColors.bg,
      appBar: AppBar(
        title: const Text('캘리브레이션'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: FitmonColors.green.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: FitmonColors.greenLight.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'POSE CHECK',
                  style: TextStyle(
                    color: FitmonColors.greenLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final guideRect = _calibrationGuideRect(
            Size(constraints.maxWidth, constraints.maxHeight),
          );

          return Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Colors.black),
              ),
              Positioned.fromRect(
                rect: guideRect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ColoredBox(
                    color: Colors.black,
                    child: Obx(() {
                      if (_cameraService.errorMessage.value.isNotEmpty) {
                        return _MessagePanel(
                          message: _cameraService.errorMessage.value,
                        );
                      }

                      if (!_cameraService.isInitialized.value ||
                          _cameraService.controller == null) {
                        return const _LoadingPanel();
                      }

                      return PortraitCameraPreview(
                        controller: _cameraService.controller!,
                        quarterTurns: _cameraService.previewQuarterTurns,
                        fit: BoxFit.cover,
                      );
                    }),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: guideRect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Obx(
                    () => CustomPaint(
                      painter: _PoseOverlayPainter(
                        pose: _latestPose,
                        imageSize: _latestImageSize,
                        quarterTurns: _cameraService.previewQuarterTurns,
                        mirror: _cameraService.activeCamera?.lensDirection ==
                            CameraLensDirection.front,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _CalibrationGuidePainter(),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Obx(
                  () {
                    final degrees =
                        (_cameraService.previewQuarterTurns * 90) % 360;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$degrees°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              _cameraService.rotatePreviewClockwise();
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.screen_rotation_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 28,
                right: 28,
                bottom: 108,
                child: Obx(
                  () => _StatusCard(
                    poseCount: _gameController.detectedPoseCount.value,
                    quality: _poseQuality,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 28,
                child: FilledButton.icon(
                  onPressed: () async {
                    _movingToGame = true;
                    await _cameraService.stopImageStream();
                    await _waitForFrameProcessing();

                    if (!mounted) return;

                    Get.off(() => const GameScreen());
                  },
                  icon: const Icon(Icons.sports_martial_arts),
                  label: const Text('준비 완료 - 배틀 시작'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PoseQuality {
  const _PoseQuality({
    required this.face,
    required this.torso,
    required this.arms,
    required this.legs,
  });

  const _PoseQuality.empty()
      : face = false,
        torso = false,
        arms = false,
        legs = false;

  final bool face;
  final bool torso;
  final bool arms;
  final bool legs;

  bool get allVisible => face && torso && arms && legs;

  static _PoseQuality fromPose(Pose? pose) {
    bool has(PoseLandmarkType type) => pose?.landmarks[type] != null;

    return _PoseQuality(
      face: has(PoseLandmarkType.nose) ||
          (has(PoseLandmarkType.leftEye) && has(PoseLandmarkType.rightEye)),
      torso: has(PoseLandmarkType.leftShoulder) &&
          has(PoseLandmarkType.rightShoulder) &&
          has(PoseLandmarkType.leftHip) &&
          has(PoseLandmarkType.rightHip),
      arms: has(PoseLandmarkType.leftShoulder) &&
          has(PoseLandmarkType.rightShoulder) &&
          has(PoseLandmarkType.leftElbow) &&
          has(PoseLandmarkType.rightElbow) &&
          has(PoseLandmarkType.leftWrist) &&
          has(PoseLandmarkType.rightWrist),
      legs: has(PoseLandmarkType.leftHip) &&
          has(PoseLandmarkType.rightHip) &&
          has(PoseLandmarkType.leftKnee) &&
          has(PoseLandmarkType.rightKnee) &&
          has(PoseLandmarkType.leftAnkle) &&
          has(PoseLandmarkType.rightAnkle),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: FitmonColors.greenLight,
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.poseCount,
    required this.quality,
  });

  final int poseCount;
  final _PoseQuality quality;

  @override
  Widget build(BuildContext context) {
    final detected = poseCount > 0;

    final title = quality.allVisible
        ? '전신 인식 완료'
        : detected
            ? '일부 관절만 인식 중'
            : '전신을 화면 안에 맞춰주세요';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: fitmonCard(
        color: FitmonColors.card.withValues(alpha: 0.92),
        border: quality.allVisible
            ? FitmonColors.greenLight.withValues(alpha: 0.65)
            : FitmonColors.yellow.withValues(alpha: 0.45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                quality.allVisible
                    ? Icons.check_circle
                    : Icons.accessibility_new,
                color: quality.allVisible
                    ? FitmonColors.greenLight
                    : FitmonColors.yellow,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            quality.allVisible
                ? '좋아요. 얼굴, 몸통, 팔, 다리가 모두 잡혔습니다.'
                : '연두색 선 안에 머리부터 발끝까지 들어오게 맞춰주세요.',
            style: const TextStyle(
              color: FitmonColors.soft,
              fontSize: 11,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _PartPill(label: '얼굴', active: quality.face),
              _PartPill(label: '몸통', active: quality.torso),
              _PartPill(label: '팔', active: quality.arms),
              _PartPill(label: '다리', active: quality.legs),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartPill extends StatelessWidget {
  const _PartPill({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? FitmonColors.greenLight : FitmonColors.muted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check : Icons.close,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(18),
        decoration: fitmonCard(),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _PoseOverlayPainter extends CustomPainter {
  const _PoseOverlayPainter({
    required this.pose,
    required this.imageSize,
    required this.quarterTurns,
    required this.mirror,
  });

  final Pose? pose;
  final Size? imageSize;
  final int quarterTurns;
  final bool mirror;

  static const _bones = [
    [PoseLandmarkType.leftEar, PoseLandmarkType.leftEyeOuter],
    [PoseLandmarkType.leftEyeOuter, PoseLandmarkType.leftEye],
    [PoseLandmarkType.leftEye, PoseLandmarkType.leftEyeInner],
    [PoseLandmarkType.leftEyeInner, PoseLandmarkType.nose],
    [PoseLandmarkType.nose, PoseLandmarkType.rightEyeInner],
    [PoseLandmarkType.rightEyeInner, PoseLandmarkType.rightEye],
    [PoseLandmarkType.rightEye, PoseLandmarkType.rightEyeOuter],
    [PoseLandmarkType.rightEyeOuter, PoseLandmarkType.rightEar],
    [PoseLandmarkType.leftMouth, PoseLandmarkType.rightMouth],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb],
    [PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex],
    [PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky],
    [PoseLandmarkType.leftIndex, PoseLandmarkType.leftPinky],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb],
    [PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex],
    [PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky],
    [PoseLandmarkType.rightIndex, PoseLandmarkType.rightPinky],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel],
    [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex],
    [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel],
    [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex],
    [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final currentPose = pose;
    final currentImageSize = imageSize;

    if (currentPose == null || currentImageSize == null) return;

    final bonePaint = Paint()
      ..color = FitmonColors.yellow
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()..color = FitmonColors.greenLight;
    final pointGlow = Paint()
      ..color = FitmonColors.greenLight.withValues(alpha: 0.26)
      ..style = PaintingStyle.fill;

    final pointStroke = Paint()
      ..color = FitmonColors.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    Offset? pointFor(PoseLandmarkType type) {
      final landmark = currentPose.landmarks[type];
      if (landmark == null) return null;
      return _mapPoint(landmark, currentImageSize, size);
    }

    for (final bone in _bones) {
      final a = pointFor(bone[0]);
      final b = pointFor(bone[1]);

      if (a != null && b != null) {
        canvas.drawLine(a, b, bonePaint);
      }
    }

    for (final landmark in currentPose.landmarks.values) {
      final point = _mapPoint(landmark, currentImageSize, size);
      canvas.drawCircle(point, 4.9, pointGlow);
      canvas.drawCircle(point, 3, pointPaint);
      canvas.drawCircle(point, 3, pointStroke);
    }
  }

  Offset _mapPoint(
    PoseLandmark landmark,
    Size source,
    Size target,
  ) {
    double x = landmark.x;
    double y = landmark.y;

    double orientedWidth = source.width;
    double orientedHeight = source.height;

    switch (quarterTurns % 4) {
      case 1:
        x = source.height - landmark.y;
        y = landmark.x;
        orientedWidth = source.height;
        orientedHeight = source.width;
        break;
      case 2:
        x = source.width - landmark.x;
        y = source.height - landmark.y;
        break;
      case 3:
        x = landmark.y;
        y = source.width - landmark.x;
        orientedWidth = source.height;
        orientedHeight = source.width;
        break;
      case 0:
      default:
        break;
    }

    if (mirror) {
      x = orientedWidth - x;
    }

    final scale =
        (target.width / orientedWidth > target.height / orientedHeight)
            ? target.width / orientedWidth
            : target.height / orientedHeight;

    final dx = (target.width - orientedWidth * scale) / 2;
    final dy = (target.height - orientedHeight * scale) / 2;

    return Offset(
      (x * scale + dx).clamp(0.0, target.width),
      (y * scale + dy).clamp(0.0, target.height),
    );
  }

  @override
  bool shouldRepaint(covariant _PoseOverlayPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.quarterTurns != quarterTurns ||
        oldDelegate.mirror != mirror;
  }
}

class _CalibrationGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = FitmonColors.bg.withValues(alpha: 0.22),
    );

    final box = RRect.fromRectAndRadius(
      _calibrationGuideRect(size),
      const Radius.circular(24),
    );

    canvas.drawRRect(
      box,
      Paint()
        ..color = FitmonColors.greenLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final glow = Paint()
      ..color = FitmonColors.greenLight.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    canvas.drawRRect(box, glow);

    final centerLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(size.width / 2, box.top),
      Offset(size.width / 2, box.bottom),
      centerLine,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
