import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class PortraitCameraPreview extends StatelessWidget {
  const PortraitCameraPreview({
    super.key,
    required this.controller,
    required this.quarterTurns,
    this.fit = BoxFit.contain,
  });

  final CameraController controller;
  final int quarterTurns;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    final isSideways = quarterTurns.isOdd;
    final width = isSideways ? previewSize.height : previewSize.width;
    final height = isSideways ? previewSize.width : previewSize.height;

    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: FittedBox(
          fit: fit,
          child: SizedBox(
            width: width,
            height: height,
            child: RotatedBox(
              quarterTurns: quarterTurns,
              child: SizedBox(
                width: previewSize.width,
                height: previewSize.height,
                child: CameraPreview(controller),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

int cameraPreviewQuarterTurns(CameraDescription? camera) {
  return 0;
}
