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
    this.width,
    required this.height,
    required this.coreInfo,
    this.highQuality = false,
    this.scale,
    this.alignment = Alignment.topCenter,
  });

  final int pageIndex;
  final double? width;
  final double? height;
  final EditorCoreInfo coreInfo;

  /// Whether to draw [Stroke.highQualityPath] or [Stroke.lowQualityPath].
  final bool highQuality;

  /// Optional explicit scale factor.
  /// If provided, this overrides the default scale logic.
  final double? scale;

  final Alignment alignment;

  late final pageSize =
      coreInfo.pages.getOrNull(pageIndex)?.size ?? EditorPage.defaultSize;

  @override
  Size get preferredSize =>
      Size(width ?? pageSize.width, height ?? pageSize.height);

  @override
  Widget build(BuildContext context) {
    final computedScale = scale ?? (width ?? pageSize.width) / pageSize.width;

    debugPrint(
      'XXX_DEBUG: CanvasPreview build - pageIndex: $pageIndex, width: $width, height: $height, highQuality: $highQuality, preferredSize: $preferredSize, scale: $computedScale',
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
      currentScale: computedScale,
    );
  }
}
