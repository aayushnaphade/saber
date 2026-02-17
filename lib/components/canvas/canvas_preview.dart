import 'package:flutter/material.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/inner_canvas.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/extensions/list_extensions.dart';

class CanvasPreview extends StatelessWidget implements PreferredSizeWidget {
  CanvasPreview({
    super.key,
    this.pageIndex = 0,
    required this.height,
    required this.coreInfo,
    this.highQuality = false,
    this.scale,
  });

  final int pageIndex;
  final double? height;
  final EditorCoreInfo coreInfo;

  /// Whether to draw [Stroke.highQualityPath] or [Stroke.lowQualityPath].
  final bool highQuality;

  /// Optional explicit scale factor.
  /// If provided, this overrides the default scale logic.
  final double? scale;

  late final pageSize =
      coreInfo.pages.getOrNull(pageIndex)?.size ?? EditorPage.defaultSize;
  @override
  late final preferredSize = Size(pageSize.width, height ?? pageSize.height);

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'XXX_DEBUG: CanvasPreview build - pageIndex: $pageIndex, height: $height, highQuality: $highQuality, preferredSize: $preferredSize, scale: ${highQuality ? 5.0 : double.minPositive}',
    );
    return InnerCanvas(
      pageIndex: pageIndex,
      width: preferredSize.width,
      height: preferredSize.height,
      isPreview: true,
      coreInfo: coreInfo,
      currentStroke: null,
      currentStrokeDetectedShape: null,
      currentSelection: null,
      currentToolIsSelect: false,
      currentScale: scale ?? (highQuality ? 5.0 : double.minPositive),
    );
  }
}
