import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:logging/logging.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:saber/components/canvas/_canvas_background_painter.dart';
import 'package:saber/components/canvas/_canvas_painter.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/canvas_image.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/quill_styles.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/i18n/strings.g.dart';

class InnerCanvas extends StatefulWidget {
  static final log = Logger('InnerCanvas');

  const InnerCanvas({
    super.key,
    required this.pageIndex,
    this.redrawPageListenable,
    required this.width,
    required this.height,
    this.isPreview = false,
    this.isPrint = false,
    this.textEditing = false,
    required this.coreInfo,
    required this.currentStroke,
    required this.currentStrokeDetectedShape,
    required this.currentSelection,
    this.setAsBackground,
    this.onRenderObjectChange,
    required this.currentToolIsSelect,
    required this.currentScale,
  });

  final int pageIndex;
  final Listenable? redrawPageListenable;
  final double width;
  final double height;

  final bool isPreview;
  final bool isPrint;

  final bool textEditing;
  final EditorCoreInfo coreInfo;
  final Stroke? currentStroke;
  final RecognizedUnistroke? currentStrokeDetectedShape;
  final SelectResult? currentSelection;
  final void Function(EditorImage image)? setAsBackground;
  final ValueChanged<RenderObject>? onRenderObjectChange;

  final bool currentToolIsSelect;

  final double currentScale;

  static const defaultBackgroundColor = Color(0xFFFCFCFC);

  @override
  State<InnerCanvas> createState() => _InnerCanvasState();
}

class _InnerCanvasState extends State<InnerCanvas> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final Brightness brightness = Theme.brightnessOf(context);
    final invert =
        stows.editorAutoInvert.value && brightness == Brightness.dark;
    final Color backgroundColor =
        widget.coreInfo.backgroundColor ?? InnerCanvas.defaultBackgroundColor;

    if (widget.coreInfo.pages.isEmpty) {
      return SizedBox(width: widget.width, height: widget.height);
    }

    final page = widget.coreInfo.pages[widget.pageIndex];

    InnerCanvas.log.info(
      'DEBUG: InnerCanvas build - pageIndex: ${widget.pageIndex}, width: ${widget.width}, height: ${widget.height}, pageSize: ${page.size}',
    );

    final quillEditor = widget.coreInfo.pages.isNotEmpty
        ? QuillEditor(
            controller:
                widget.coreInfo.pages[widget.pageIndex].quill.controller,
            config: QuillEditorConfig(
              customStyles: SaberQuillStyles.get(
                invert: invert,
                secondary: colorScheme.secondary,
                lineHeight: widget.coreInfo.lineHeight,
              ),
              scrollable: false,
              autoFocus: false,
              expands: true,
              placeholder: widget.textEditing
                  ? t.editor.quill.typeSomething
                  : null,
              showCursor: true,
              keyboardAppearance: invert ? Brightness.dark : Brightness.light,
              padding: EdgeInsets.only(
                top: widget.coreInfo.lineHeight * 1.2,
                left: widget.coreInfo.lineHeight * 0.5,
                right: widget.coreInfo.lineHeight * 0.5,
                bottom: widget.coreInfo.lineHeight * 0.5,
              ),
            ),
            scrollController: ScrollController(),
            focusNode: widget.coreInfo.pages[widget.pageIndex].quill.focusNode,
          )
        : null;

    final logicalWidth = widget.width / widget.currentScale;
    final logicalHeight = widget.height / widget.currentScale;

    InnerCanvas.log.info(
      'DEBUG: InnerCanvas build details - width: ${widget.width}, height: ${widget.height}, scale: ${widget.currentScale}, logicalWidth: $logicalWidth, logicalHeight: $logicalHeight, pageSize: ${page.size}',
    );

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: logicalWidth,
          height: logicalHeight,
          child: CustomPaint(
            painter: CanvasBackgroundPainter(
              invert: invert,
              backgroundColor: page.backgroundImage != null
                  ? Colors.white
                  : backgroundColor,
              backgroundPattern: page.backgroundImage != null
                  ? CanvasBackgroundPattern.none
                  : widget.coreInfo.backgroundPattern,
              lineHeight: widget.coreInfo.lineHeight,
              lineThickness: widget.coreInfo.lineThickness,
              primaryColor: colorScheme.primary,
              secondaryColor: colorScheme.secondary,
            ),
            foregroundPainter: CanvasPainter(
              repaint: widget.redrawPageListenable,
              invert: invert,
              strokes: page.strokes,
              laserStrokes: page.laserStrokes,
              currentStroke: widget.currentStroke,
              currentSelection: widget.currentSelection,
              primaryColor: colorScheme.primary,
              page: page,
              showPageIndicator:
                  !widget.isPreview &&
                  (!widget.isPrint || stows.printPageIndicators.value),
              pageIndex: widget.pageIndex,
              totalPages: widget.coreInfo.pages.length,
              currentScale: widget.currentScale,
            ),
            isComplex: true,
            willChange: true,
            child: DeferredPointerHandler(
              child: Stack(
                children: [
                  if (page.backgroundImage != null)
                    CanvasImage(
                      filePath: widget.coreInfo.filePath,
                      image: page.backgroundImage!,
                      pageSize: page.size,
                      setAsBackground: null,
                      isBackground: true,
                      readOnly: true,
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: widget.coreInfo.readOnly || !widget.textEditing,
                      child: quillEditor,
                    ),
                  ),
                  for (int i = 0; i < page.images.length; i++)
                    CanvasImage(
                      filePath: widget.coreInfo.filePath,
                      image: page.images[i],
                      pageSize: page.size,
                      setAsBackground: widget.setAsBackground,
                      readOnly:
                          widget.coreInfo.readOnly ||
                          !widget.currentToolIsSelect,
                      selected:
                          widget.currentSelection?.images.contains(
                            page.images[i],
                          ) ??
                          false,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
