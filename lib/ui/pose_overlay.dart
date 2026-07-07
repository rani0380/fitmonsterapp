import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:smart_app/ui/fitmon_theme.dart';

class PoseOverlay extends StatelessWidget {
  const PoseOverlay({
    super.key,
    required this.pose,
    required this.imageSize,
    required this.quarterTurns,
    required this.mirror,
    this.repaintId = 0,
    this.fit = BoxFit.cover,
    this.pointRadius = 2.8,
    this.strokeWidth = 1.8,
  });

  final Pose? pose;
  final Size? imageSize;
  final int quarterTurns;
  final bool mirror;
  final int repaintId;
  final BoxFit fit;
  final double pointRadius;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PoseOverlayPainter(
        pose: pose,
        imageSize: imageSize,
        quarterTurns: quarterTurns,
        mirror: mirror,
        repaintId: repaintId,
        fit: fit,
        pointRadius: pointRadius,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class PoseOverlayPainter extends CustomPainter {
  const PoseOverlayPainter({
    required this.pose,
    required this.imageSize,
    required this.quarterTurns,
    required this.mirror,
    required this.repaintId,
    required this.fit,
    required this.pointRadius,
    required this.strokeWidth,
  });

  final Pose? pose;
  final Size? imageSize;
  final int quarterTurns;
  final bool mirror;
  final int repaintId;
  final BoxFit fit;
  final double pointRadius;
  final double strokeWidth;

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
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = FitmonColors.greenLight;
    final pointGlow = Paint()
      ..color = FitmonColors.greenLight.withValues(alpha: 0.26)
      ..style = PaintingStyle.fill;
    final pointStroke = Paint()
      ..color = FitmonColors.bgDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.45;

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
      canvas.drawCircle(point, pointRadius + 1.9, pointGlow);
      canvas.drawCircle(point, pointRadius, pointPaint);
      canvas.drawCircle(point, pointRadius, pointStroke);
    }
  }

  Offset _mapPoint(PoseLandmark landmark, Size source, Size target) {
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
    }

    if (mirror) {
      x = orientedWidth - x;
    }

    final scaleX = target.width / orientedWidth;
    final scaleY = target.height / orientedHeight;
    final scale = fit == BoxFit.contain
        ? (scaleX < scaleY ? scaleX : scaleY)
        : (scaleX > scaleY ? scaleX : scaleY);
    final dx = (target.width - orientedWidth * scale) / 2;
    final dy = (target.height - orientedHeight * scale) / 2;

    return Offset(
      (x * scale + dx).clamp(0, target.width),
      (y * scale + dy).clamp(0, target.height),
    );
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.repaintId != repaintId ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.quarterTurns != quarterTurns ||
      oldDelegate.mirror != mirror ||
      oldDelegate.fit != fit;
}
