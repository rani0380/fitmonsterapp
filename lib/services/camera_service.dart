import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smart_app/ui/portrait_camera_preview.dart';

class CameraService extends GetxService {
  CameraController? controller;
  CameraDescription? activeCamera;

  final isInitialized = false.obs;
  final isStreaming = false.obs;
  final errorMessage = ''.obs;
  final previewRotationOffset = 0.obs;

  int get previewQuarterTurns =>
      ((cameraPreviewQuarterTurns(activeCamera) + previewRotationOffset.value) %
              4)
          .toInt();

  void rotatePreviewClockwise() {
    previewRotationOffset.value = (previewRotationOffset.value + 1) % 4;
  }

  void _setRx<T>(Rx<T> target, T value) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        target.value = value;
      });
      return;
    }
    target.value = value;
  }

  Future<void> initialize() async {
    if (isInitialized.value && controller != null) return;

    try {
      _setRx(errorMessage, '');
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _setRx(errorMessage, '카메라 권한을 허용해야 모션 인식을 사용할 수 있습니다.');
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setRx(errorMessage, '사용 가능한 카메라를 찾지 못했습니다.');
        return;
      }

      activeCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        activeCamera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller!.initialize();
      await controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      _setRx(isInitialized, true);
    } catch (e) {
      _setRx(errorMessage, '카메라 초기화 오류: $e');
      debugPrint(errorMessage.value);
    }
  }

  Future<void> startImageStream(
      Future<void> Function(CameraImage image) onImage) async {
    final camera = controller;
    if (camera == null || !camera.value.isInitialized) {
      return;
    }

    if (isStreaming.value || camera.value.isStreamingImages) {
      await stopImageStream();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    try {
      await camera.startImageStream((image) {
        unawaited(onImage(image));
      });
      _setRx(isStreaming, true);
    } catch (e) {
      _setRx(isStreaming, false);
      _setRx(errorMessage, '카메라 스트림 시작 오류: $e');
      debugPrint(errorMessage.value);
    }
  }

  Future<void> stopImageStream() async {
    final camera = controller;
    if (camera == null || !camera.value.isInitialized) {
      _setRx(isStreaming, false);
      return;
    }

    if (!isStreaming.value && !camera.value.isStreamingImages) {
      _setRx(isStreaming, false);
      return;
    }

    try {
      if (camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
    } catch (e) {
      debugPrint('카메라 스트림 정지 오류: $e');
    } finally {
      _setRx(isStreaming, false);
    }
  }

  Size poseOverlayImageSize(CameraImage image) {
    final orientation = activeCamera?.sensorOrientation ?? 0;
    if (orientation == 90 || orientation == 270) {
      return Size(image.height.toDouble(), image.width.toDouble());
    }
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  InputImage? inputImageFromCameraImage(CameraImage image) {
    final camera = activeCamera;
    if (camera == null) return null;

    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    if (image.planes.isEmpty) return null;
    final bytes = Platform.isAndroid
        ? _androidNv21Bytes(image)
        : image.planes.first.bytes;
    if (bytes == null) return null;

    final format = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List? _androidNv21Bytes(CameraImage image) {
    if (image.planes.length == 1) {
      return image.planes.first.bytes;
    }
    if (image.planes.length < 3) return null;

    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final bytes = Uint8List(width * height + (width * height ~/ 2));

    var offset = 0;
    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      bytes.setRange(offset, offset + width, yPlane.bytes, rowStart);
      offset += width;
    }

    final chromaHeight = height ~/ 2;
    final chromaWidth = width ~/ 2;
    for (var row = 0; row < chromaHeight; row++) {
      for (var col = 0; col < chromaWidth; col++) {
        final uIndex =
            row * uPlane.bytesPerRow + col * (uPlane.bytesPerPixel ?? 1);
        final vIndex =
            row * vPlane.bytesPerRow + col * (vPlane.bytesPerPixel ?? 1);
        bytes[offset++] = vPlane.bytes[vIndex];
        bytes[offset++] = uPlane.bytes[uIndex];
      }
    }

    return bytes;
  }

  @override
  void onClose() {
    controller?.dispose();
    super.onClose();
  }
}
