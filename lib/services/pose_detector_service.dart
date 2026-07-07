import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseDetectorService {
  late final PoseDetector _poseDetector;
  bool _isBusy = false;

  PoseDetectorService() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );
  }

  Future<List<Pose>> processImage(InputImage inputImage) async {
    if (_isBusy) return [];
    _isBusy = true;
    try {
      return await _poseDetector.processImage(inputImage);
    } finally {
      _isBusy = false;
    }
  }

  bool isSquatting(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    final hips = [
      if (_isReliable(leftHip)) leftHip!,
      if (_isReliable(rightHip)) rightHip!,
    ];
    final knees = [
      if (_isReliable(leftKnee)) leftKnee!,
      if (_isReliable(rightKnee)) rightKnee!,
    ];
    final ankles = [
      if (_isReliable(leftAnkle)) leftAnkle!,
      if (_isReliable(rightAnkle)) rightAnkle!,
    ];
    final shoulders = [
      if (_isReliable(leftShoulder)) leftShoulder!,
      if (_isReliable(rightShoulder)) rightShoulder!,
    ];

    if (hips.isEmpty || knees.isEmpty || ankles.isEmpty || shoulders.isEmpty) {
      return false;
    }

    final angles = [
      if (_isReliable(leftHip) &&
          _isReliable(leftKnee) &&
          _isReliable(leftAnkle))
        _angle(leftHip!, leftKnee!, leftAnkle!),
      if (_isReliable(rightHip) &&
          _isReliable(rightKnee) &&
          _isReliable(rightAnkle))
        _angle(rightHip!, rightKnee!, rightAnkle!),
    ];
    if (angles.isEmpty) return false;

    final kneeAngle = angles.reduce(min);
    final clearlyBentKnee = kneeAngle < 150;
    final partlyBentKnee = kneeAngle < 164;

    final hipY = _averageY(hips);
    final kneeY = _averageY(knees);
    final ankleY = _averageY(ankles);
    final shoulderY = _averageY(shoulders);
    final bodyHeight = max(80.0, ankleY - shoulderY);
    final hipToKneeRatio = ((kneeY - hipY) / bodyHeight).clamp(-1.0, 1.0);

    final hipIsLow = hipToKneeRatio < 0.39;
    final kneesAreVisibleAndLow = kneeY > hipY && (ankleY - kneeY) > 20;

    return clearlyBentKnee ||
        (partlyBentKnee && hipIsLow && kneesAreVisibleAndLow);
  }

  double getLateralOffset(Pose pose, double imageWidth) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    final points = [
      if (leftShoulder != null) leftShoulder.x,
      if (rightShoulder != null) rightShoulder.x,
      if (leftHip != null) leftHip.x,
      if (rightHip != null) rightHip.x,
    ];
    if (points.isEmpty || imageWidth <= 0) return 0.5;

    final centerX = points.reduce((a, b) => a + b) / points.length;
    return (centerX / imageWidth).clamp(0.0, 1.0);
  }

  double getHipY(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    if (leftHip == null && rightHip == null) return 0;
    if (leftHip == null) return rightHip!.y;
    if (rightHip == null) return leftHip.y;
    return (leftHip.y + rightHip.y) / 2;
  }

  double getMotionY(Pose pose) {
    const activeTypes = [
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
    ];

    const fallbackTypes = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    final activeValues = [
      for (final type in activeTypes)
        if (pose.landmarks[type] != null) pose.landmarks[type]!.y,
    ];

    if (activeValues.isNotEmpty) {
      return activeValues.reduce((a, b) => a + b) / activeValues.length;
    }

    final values = [
      for (final type in fallbackTypes)
        if (pose.landmarks[type] != null) pose.landmarks[type]!.y,
    ];

    if (values.isEmpty) return getHipY(pose);
    return values.reduce((a, b) => a + b) / values.length;
  }

  double getMotionSignal(Pose pose) {
    const activeTypes = [
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    final points = [
      for (final type in activeTypes)
        if (pose.landmarks[type] != null) pose.landmarks[type]!,
    ];
    if (points.isEmpty) return getMotionY(pose);

    final minX = points.map((point) => point.x).reduce(min);
    final maxX = points.map((point) => point.x).reduce(max);
    final minY = points.map((point) => point.y).reduce(min);
    final maxY = points.map((point) => point.y).reduce(max);
    final centerX =
        points.map((point) => point.x).reduce((a, b) => a + b) / points.length;
    final centerY =
        points.map((point) => point.y).reduce((a, b) => a + b) / points.length;

    final width = maxX - minX;
    final height = maxY - minY;
    return centerX * 0.7 + centerY + width * 0.35 + height * 0.35;
  }

  double getHandMotionSignal(Pose pose) {
    const handTypes = [
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
    ];

    final points = [
      for (final type in handTypes)
        if (_isVisibleEnough(pose.landmarks[type])) pose.landmarks[type]!,
    ];
    if (points.isEmpty) return getMotionSignal(pose);

    final centerX =
        points.map((point) => point.x).reduce((a, b) => a + b) / points.length;
    final centerY =
        points.map((point) => point.y).reduce((a, b) => a + b) / points.length;
    final minX = points.map((point) => point.x).reduce(min);
    final maxX = points.map((point) => point.x).reduce(max);
    final minY = points.map((point) => point.y).reduce(min);
    final maxY = points.map((point) => point.y).reduce(max);

    return centerX * 0.85 +
        centerY * 0.85 +
        (maxX - minX) * 0.55 +
        (maxY - minY) * 0.55;
  }

  double _angle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final ab = Offset2(a.x - b.x, a.y - b.y);
    final cb = Offset2(c.x - b.x, c.y - b.y);
    final dot = ab.x * cb.x + ab.y * cb.y;
    final mag =
        sqrt(ab.x * ab.x + ab.y * ab.y) * sqrt(cb.x * cb.x + cb.y * cb.y);
    if (mag == 0) return 180;
    return acos((dot / mag).clamp(-1.0, 1.0)) * 180 / pi;
  }

  double _averageY(List<PoseLandmark> landmarks) {
    return landmarks.map((landmark) => landmark.y).reduce((a, b) => a + b) /
        landmarks.length;
  }

  bool _isReliable(PoseLandmark? landmark) {
    return landmark != null && landmark.likelihood >= 0.38;
  }

  bool _isVisibleEnough(PoseLandmark? landmark) {
    return landmark != null && landmark.likelihood >= 0.20;
  }

  void close() {
    _poseDetector.close();
  }
}

class Offset2 {
  const Offset2(this.x, this.y);

  final double x;
  final double y;
}
