import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collapsible/collapsible.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as flutter_quill;
import 'package:intl/intl.dart';
import 'package:keybinder/keybinder.dart';
import 'package:logging/logging.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart' as lottie_pkg;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/canvas.dart';
import 'package:saber/components/canvas/canvas_gesture_detector.dart';
import 'package:saber/components/canvas/canvas_image.dart';
import 'package:saber/components/canvas/canvas_preview.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/canvas/save_indicator.dart';
import 'package:saber/data/models/vitals.dart';
import 'package:saber/components/intake_form/intake_overlay_card.dart';
import 'package:saber/components/intake_form/psychiatric_intake_form.dart';
import 'package:saber/components/intake_form/vitals_overlay_card.dart';
import 'package:saber/components/editor/previous_notes_overlay_card.dart';
import 'package:saber/data/models/previous_session_note.dart';
import 'package:saber/components/overlays/medication_history_overlay.dart';
import 'package:saber/data/supabase/supabase_consultation_service.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/components/toolbar/color_bar.dart';
import 'package:saber/components/toolbar/editor_bottom_sheet.dart';
import 'package:saber/components/toolbar/editor_page_manager.dart';
import 'package:saber/components/toolbar/toolbar.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/api/report_generator.dart';
import 'package:saber/data/editor/_color_change.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/editor_exporter.dart';
import 'package:saber/data/editor/editor_history.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/extensions/change_notifier_extensions.dart';
import 'package:saber/data/extensions/matrix4_extensions.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/models/psychiatric_intake.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/supabase/supabase_dashboard_service.dart';
import 'package:saber/data/supabase/supabase_intake_service.dart';
import 'package:saber/data/supabase/supabase_patient_service.dart';
import 'package:saber/data/supabase/supabase_prescription_service.dart';
import 'package:saber/data/supabase/supabase_vitals_service.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/session_manager.dart';
import 'package:saber/data/supabase/supabase_report_service.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/main.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/laser_pointer.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/report_view.dart';
import 'package:saber/pages/home/whiteboard.dart';
import 'package:screenshot/screenshot.dart';
import 'package:super_clipboard/super_clipboard.dart';

typedef _PhotoInfo = ({Uint8List bytes, String extension});

class Editor extends StatefulWidget {
  Editor({
    super.key,
    String? path,
    this.customTitle,
    this.pdfPath,
    this.consultationId,
    this.patientName,
    this.patientId,
    this.onVerify,
    this.readOnly = false,
    this.isWhiteboard = false,
  }) : initialPath = path != null
           ? Future.value(path)
           : FileManager.newFilePath('/'),
       needsNaming = path == null;

  final Future<String> initialPath;
  final bool needsNaming;

  final String? customTitle;
  final String? pdfPath;

  final String? consultationId;
  final String? patientName;
  final String? patientId;
  final bool isWhiteboard;
  final VoidCallback? onVerify;
  final bool readOnly;

  /// The file extension used by the app.
  /// Files with this extension are
  /// encoded in BSON format.
  static const extension = '.sbn2';

  /// The old file extension used by the app.
  /// Files with this extension are
  /// encoded in JSON format.
  static const extensionOldJson = '.sbn';

  static const double gapBetweenPages = 16;

  /// Returns true if [path] belongs to a hidden file
  /// used by other functions of the app
  static bool isReservedPath(String path) {
    return _reservedFilePaths.any((regex) => regex.hasMatch(path));
  }

  static final _reservedFilePaths = <RegExp>[
    RegExp(RegExp.escape(Whiteboard.filePath)),
  ];

  /// Whether the platform can rasterize a pdf
  static var canRasterPdf = true;

  @override
  State<Editor> createState() => EditorState();
}

class EditorState extends State<Editor> {
  final log = Logger('EditorState');

  bool _isClearing = false;

  late var coreInfo = EditorCoreInfo(filePath: '');

  final _canvasGestureDetectorKey = GlobalKey<CanvasGestureDetectorState>();
  final _transformationController = TransformationController();
  double get scrollY {
    final transformation = _transformationController.value;
    final scale = transformation.approxScale;
    final translation = transformation.getTranslation();
    final gestureDetector = _canvasGestureDetectorKey.currentState;

    if (gestureDetector == null) {
      log.warning('scrollY: Could not find CanvasGestureDetectorState');
      return translation.y / scale;
    } else {
      final middle = gestureDetector.containerBounds.maxHeight / 2;
      return (translation.y - middle) / scale + middle;
    }
  }

  var history = EditorHistory();

  late bool needsNaming = widget.needsNaming && stows.editorPromptRename.value;

  late Tool _currentTool = () {
    switch (stows.lastTool.value) {
      case .fountainPen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = Pen.fountainPen();
        }
        return Pen.currentPen;
      case .ballpointPen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = Pen.ballpointPen();
        }
        return Pen.currentPen;
      case .shapePen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = ShapePen();
        }
        return Pen.currentPen;
      case .highlighter:
        return Highlighter.currentHighlighter;
      case .pencil:
        return Pencil.currentPencil;
      case .eraser:
        return Eraser();
      case .select:
        return Select.currentSelect;
      case .textEditing:
        return Tool.textEditing;
      case .laserPointer:
        return LaserPointer.currentLaserPointer;
    }
  }();
  Tool get currentTool => _currentTool;
  set currentTool(Tool tool) {
    _currentTool = tool;
    stows.lastTool.value = tool.toolId;
  }

  ValueNotifier<SavingState> savingState = ValueNotifier(SavingState.saved);
  Timer? _delayedSaveTimer;
  Timer? _watchServerTimer;

  // Psychiatric intake overlay state
  PsychiatricIntake? _patientIntake;
  bool _showIntakeOverlay = false;
  bool _hasLoadedIntake = false;
  bool _isIntakeExpanded = false;
  Offset? _intakeOverlayPosition; // null means use default right-side position

  // Vitals overlay state
  List<Vitals> _vitalsHistory = [];
  bool _showVitalsOverlay =
      false; // Only show in minimized form if there are vitals entries
  bool _isVitalsExpanded = false;
  Offset? _vitalsOverlayPosition;

  String? _doctorName;
  String? _patientId;
  String? _patientName;

  // Previous Session Notes overlay state
  bool _showPreviousNotesOverlay = false;
  List<PreviousSessionNote> _previousNotes = [];
  bool _isLoadingPreviousNotes = false;
  Offset? _previousNotesOverlayPosition;

  // Medication History overlay state
  bool _showMedicationHistoryOverlay = false;
  Offset? _medicationHistoryOverlayPosition;

  // used to prevent accidentally drawing when pinch zooming
  var lastSeenPointerCount = 0;
  Timer? _lastSeenPointerCountTimer;

  ValueNotifier<QuillStruct?> quillFocus = ValueNotifier(null);

  /// The tool that was used before switching to the eraser.
  Tool? tmpTool;

  /// If the stylus button is pressed, or was pressed during the current draw gesture.
  var stylusButtonPressed = false;

  @override
  void initState() {
    DynamicMaterialApp.addFullscreenListener(_setState);

    _initAsync();
    _assignKeybindings();

    _patientName = widget.patientName;
    _patientId = widget.patientId;

    super.initState();
  }

  void _initAsync() async {
    debugPrint('Editor: _initAsync started');
    try {
      coreInfo.filePath = await widget.initialPath;
      debugPrint('Editor: filePath resolved: ${coreInfo.filePath}');
      filenameTextEditingController.text = coreInfo.fileName;

      if (needsNaming) {
        filenameTextEditingController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: filenameTextEditingController.text.length,
        );
      }

      debugPrint('Editor: Starting parallel initialization');

      // Load core strokes with timeout
      final strokesFuture = _initStrokes().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          log.warning('Editor: _initStrokes timed out!');
          // Create empty core info on timeout to avoid crash
          coreInfo = EditorCoreInfo(filePath: coreInfo.filePath);
          if (mounted) setState(() {});
        },
      );

      // Load patient intake largely in parallel, but don't block main core info loading
      // We start it here but await independent of strokes if possible, or just await together
      final intakeFuture = _loadPatientIntake().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          log.warning('Editor: _loadPatientIntake timed out!');
        },
      );

      await Future.wait([strokesFuture, intakeFuture]);

      // Ensure we have at least one page to avoid layout errors
      if (coreInfo.pages.isEmpty) {
        log.warning('Editor: Loaded file has no pages. Adding default page.');
        coreInfo.pages.add(EditorPage(size: EditorPage.defaultSize));
      }

      debugPrint(
        'Editor: Parallel initialization complete. Pages: ${coreInfo.pages.length}',
      );

      if (widget.pdfPath != null) {
        debugPrint('Editor: Importing PDF: ${widget.pdfPath}');
        await importPdfFromFilePath(widget.pdfPath!);
      }

      debugPrint('Editor: Calling _fetchDoctorProfile');
      _fetchDoctorProfile();

      if (!widget.readOnly &&
          (widget.consultationId != null || _patientId != null)) {
        SessionManager().startSession(
          coreInfo: coreInfo,
          patientName: _patientName,
          patientId: _patientId,
          consultationId: widget.consultationId,
        );
      }
    } catch (e, stack) {
      log.severe('Editor: Critical error in _initAsync', e, stack);
    }
    debugPrint('Editor: _initAsync finished');
  }

  Future<void> _fetchDoctorProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _doctorName = data['full_name'] as String?;
        });
      }
    } catch (e) {
      log.warning('Error fetching doctor profile: $e');
    }
  }

  /// Extracts patient ID from file path and loads their intake data
  Future<void> _loadPatientIntake() async {
    if (_hasLoadedIntake) return;
    _hasLoadedIntake = true;

    try {
      // Extract patient ID from file path
      // Path format: .../patients/{patient_id}/session_notes/session_X/...
      String filePath = coreInfo.filePath;
      log.info('Attempting to load intake. Raw FilePath: $filePath');

      String? patientId;

      // Normalize path separators
      final normalizedPath = filePath.replaceAll('\\', '/');
      final parts = normalizedPath.split('/');

      // Find 'patients' segment and get the next segment
      final patientsIndex = parts.indexOf('patients');
      if (patientsIndex != -1 && patientsIndex + 1 < parts.length) {
        patientId = parts[patientsIndex + 1];
      }

      if (patientId != null) {
        _patientId =
            patientId; // Store patient ID for potential intake creation

        log.info('Found patient ID: $patientId. Loading intake and vitals...');

        final intake = await SupabaseIntakeService.getIntake(patientId);
        final vitals = await SupabaseVitalsService.getVitalsHistory(patientId);
        final patient = await SupabasePatientService.getPatient(patientId);

        if (mounted) {
          setState(() {
            if (intake != null) _patientIntake = intake;
            _vitalsHistory = vitals;
            if (patient != null) _patientName = patient.fullName;

            // Check if this is a restored session
            final isRestore =
                SessionManager().hasActiveSession &&
                SessionManager().activeSession?.filePath == coreInfo.filePath;

            // Show vitals overlay in minimized form ONLY if there are vitals entries
            // AND it is NOT a restored session (only show on fresh start)
            _showVitalsOverlay = vitals.isNotEmpty && !isRestore;

            // Always collapse vitals by default
            _isVitalsExpanded = false;

            // Vitals overlay logic handled by initialization
          });
          log.info(
            'Loaded intake and vitals for patient: $patientId. Vitals count: ${vitals.length}',
          );
        }
      } else {
        log.warning('Could not extract patient ID from path: $filePath');
      }
    } catch (e, stack) {
      log.warning('Failed to load patient intake: $e', e, stack);
      // Don't fail the editor if intake can't be loaded
    }
  }

  Future _initStrokes() async {
    debugPrint('Editor: _initStrokes loading from file: ${coreInfo.filePath}');
    coreInfo = await EditorCoreInfo.loadFromFilePath(coreInfo.filePath);
    if (widget.readOnly) {
      coreInfo.readOnly = true;
    }
    debugPrint(
      'Editor: EditorCoreInfo load complete. ReadOnly: ${coreInfo.readOnly}',
    );
    if (coreInfo.readOnly) {
      log.info('Loaded file as read-only');
    }

    for (int pageIndex = 0; pageIndex < coreInfo.pages.length; pageIndex++) {
      listenToQuillChanges(coreInfo.pages[pageIndex].quill, pageIndex);
    }

    if (coreInfo.isEmpty) {
      createPage(-1);
    } else {
      for (final page in coreInfo.pages) {
        page.backgroundImage?.onMoveImage = onMoveImage;
        page.backgroundImage?.onDeleteImage = onDeleteImage;
        page.backgroundImage?.onMiscChange = autosaveAfterDelay;
        for (final image in page.images) {
          image.onMoveImage = onMoveImage;
          image.onDeleteImage = onDeleteImage;
          image.onMiscChange = autosaveAfterDelay;
        }
      }
    }

    if (currentTool == Tool.textEditing) {
      int pageIndex;
      if (coreInfo.initialPageIndex != null) {
        pageIndex = coreInfo.initialPageIndex!;
      } else {
        pageIndex = 0;
      }
      assert(pageIndex < coreInfo.pages.length);

      quillFocus.value = coreInfo.pages[pageIndex].quill
        ..focusNode.requestFocus();
    }

    if (coreInfo.filePath == Whiteboard.filePath &&
        stows.autoClearWhiteboardOnExit.value &&
        Whiteboard.needsToAutoClearWhiteboard) {
      // clear whiteboard (and add to history)
      clearAllPages();

      // save cleared whiteboard
      await saveToFile();
      Whiteboard.needsToAutoClearWhiteboard = false;
    } else {
      setState(() {});
    }
  }

  void _setState() => setState(() {});

  Keybinding? _ctrlZ, _ctrlY, _ctrlShiftZ;
  void _assignKeybindings() {
    _ctrlZ = Keybinding([
      KeyCode.ctrl,
      KeyCode.from(LogicalKeyboardKey.keyZ),
    ], inclusive: true);
    _ctrlY = Keybinding([
      KeyCode.ctrl,
      KeyCode.from(LogicalKeyboardKey.keyY),
    ], inclusive: true);
    _ctrlShiftZ = Keybinding([
      KeyCode.ctrl,
      KeyCode.shift,
      KeyCode.from(LogicalKeyboardKey.keyZ),
    ], inclusive: true);
    Keybinder.bind(_ctrlZ!, undo);
    Keybinder.bind(_ctrlY!, redo);
    Keybinder.bind(_ctrlShiftZ!, redo);
  }

  void _removeKeybindings() {
    if (_ctrlZ != null) Keybinder.remove(_ctrlZ!);
    if (_ctrlY != null) Keybinder.remove(_ctrlY!);
    if (_ctrlShiftZ != null) Keybinder.remove(_ctrlShiftZ!);
  }

  /// Creates pages until the given page index exists,
  /// plus an extra blank page
  void createPage(int pageIndex) {
    while (pageIndex >= coreInfo.pages.length - 1) {
      final page = EditorPage();
      coreInfo.pages.add(page);
      listenToQuillChanges(page.quill, coreInfo.pages.length - 1);
    }
  }

  void removeExcessPages() {
    bool removedAPage = false;

    // remove excess pages if all pages >= this one are empty
    for (int i = coreInfo.pages.length - 1; i >= 1; --i) {
      final thisPage = coreInfo.pages[i];
      final prevPage = coreInfo.pages[i - 1];
      if (thisPage.isEmpty && prevPage.isEmpty) {
        final page = coreInfo.pages.removeAt(i);
        page.dispose();
        removedAPage = true;
      } else {
        break;
      }
    }

    if (removedAPage) {
      // scroll to the last page (only if we're below the last page)

      final scrollY = this.scrollY;
      late final topOfLastPage = -CanvasGestureDetector.getTopOfPage(
        pageIndex: coreInfo.pages.length - 1,
        pages: coreInfo.pages,
        screenWidth: MediaQuery.sizeOf(context).width,
      );
      final bottomOfLastPage = -CanvasGestureDetector.getTopOfPage(
        pageIndex: coreInfo.pages.length,
        pages: coreInfo.pages,
        screenWidth: MediaQuery.sizeOf(context).width,
      );

      if (scrollY < bottomOfLastPage) {
        _transformationController.value = Matrix4.translationValues(
          0,
          // Slight upwards offset so that the page is not flush with the top of the screen
          topOfLastPage + 50,
          0,
        );
      }
    }
  }

  void undo([EditorHistoryItem? item]) {
    if (item == null) {
      if (!history.canUndo) return;

      // if we disabled redo, re-enable it
      if (!history.canRedo) {
        // no redo is possible, so clear the redo stack
        history.clearRedo();
        // don't disable redoing anymore
        history.canRedo = true;
      }

      item = history.undo();
    }

    setState(() {
      switch (item!.type) {
        case .draw:
          for (final stroke in item.strokes) {
            coreInfo.pages[stroke.pageIndex].strokes.remove(stroke);
          }
          for (final image in item.images) {
            coreInfo.pages[image.pageIndex].images.remove(image);
          }
          removeExcessPages();

        case .erase:
          for (final stroke in item.strokes) {
            createPage(stroke.pageIndex);
            coreInfo.pages[stroke.pageIndex].insertStroke(stroke);
          }
          for (final image in item.images) {
            createPage(image.pageIndex);
            coreInfo.pages[image.pageIndex].images.add(image);
            image.newImage = true;
          }

        case .deletePage:
          // make sure we already have a (blank/otherwise) page at this index
          createPage(item.pageIndex - 1);

          // insert the page at the correct index
          coreInfo.pages.insert(item.pageIndex, item.page!);

          // fix the page indices of all pages after this one
          for (int i = item.pageIndex + 1; i < coreInfo.pages.length; ++i) {
            final page = coreInfo.pages[i];
            for (final stroke in page.strokes) {
              stroke.pageIndex = i;
            }
            for (final image in page.images) {
              image.pageIndex = i;
            }
            page.backgroundImage?.pageIndex = i;
          }

        case .insertPage:
          // remove the page at the given index
          coreInfo.pages.removeAt(item.pageIndex);

          // fix the page indices of all pages after this one
          for (int i = item.pageIndex; i < coreInfo.pages.length; ++i) {
            final page = coreInfo.pages[i];
            for (final stroke in page.strokes) {
              stroke.pageIndex = i;
            }
            for (final image in page.images) {
              image.pageIndex = i;
            }
            page.backgroundImage?.pageIndex = i;
          }

        case .move:
          for (final stroke in item.strokes) {
            stroke.shift(Offset(-item.offset!.left, -item.offset!.top));
          }
          final select = Select.currentSelect;
          if (select.doneSelecting) {
            select.selectResult.path = select.selectResult.path.shift(
              Offset(-item.offset!.left, -item.offset!.top),
            );
          }
          for (final image in item.images) {
            image.dstRect = .fromLTRB(
              image.dstRect.left - item.offset!.left,
              image.dstRect.top - item.offset!.top,
              image.dstRect.right - item.offset!.right,
              image.dstRect.bottom - item.offset!.bottom,
            );
          }

        case .quillChange:
          final quill = coreInfo.pages[item.pageIndex].quill;
          quill.controller.undo();

        case .quillUndoneChange:
          final quill = coreInfo.pages[item.pageIndex].quill;
          quill.controller.redo();
        case .changeColor:
          for (final stroke in item.strokes) {
            stroke.color = item.colorChange![stroke]!.previous;
          }
      }

      if (item.type != .move) {
        Select.currentSelect.unselect();
      }
    });

    autosaveAfterDelay();
  }

  void redo() {
    if (!history.canRedo) return;
    final item = history.redo();

    switch (item.type) {
      case .draw:
        undo(item.copyWith(type: .erase));
      case .erase:
        undo(item.copyWith(type: .draw));
      case .deletePage:
        undo(item.copyWith(type: .insertPage));
      case .insertPage:
        undo(item.copyWith(type: .deletePage));
      case .move:
        undo(
          item.copyWith(
            offset: .fromLTRB(
              -item.offset!.left,
              -item.offset!.top,
              -item.offset!.right,
              -item.offset!.bottom,
            ),
          ),
        );
      case .quillChange:
        undo(item.copyWith(type: .quillUndoneChange));
      case .quillUndoneChange: // this will never happen
        throw Exception('history should not contain quillUndoneChange items');
      case .changeColor:
        undo(
          item.copyWith(
            colorChange: item.colorChange!.map(
              (key, value) => MapEntry(key, value.swap()),
            ),
          ),
        );
    }
  }

  int? onWhichPageIsFocalPoint(Offset focalPoint) {
    for (int i = 0; i < coreInfo.pages.length; ++i) {
      if (coreInfo.pages[i].renderBox == null) continue;
      final pageBounds = Offset.zero & coreInfo.pages[i].size;
      if (pageBounds.contains(
        coreInfo.pages[i].renderBox!.globalToLocal(focalPoint),
      ))
        return i;
    }
    return null;
  }

  /// The position of the previous draw gesture event.
  /// Used to move a selection.
  Offset previousPosition = .zero;

  /// The total offset of the current move gesture.
  /// Used to record a move in the history.
  Offset moveOffset = .zero;

  var isHovering = true;
  int? dragPageIndex;
  PointerDeviceKind? currentPointerKind;
  double? currentPressure;
  bool isDrawGesture(ScaleStartDetails details) {
    if (coreInfo.readOnly) return false;

    CanvasImage.activeListener
        .notifyListenersPlease(); // un-select active image

    _lastSeenPointerCountTimer?.cancel();
    if (lastSeenPointerCount >= 2) {
      // was a zoom gesture, ignore
      lastSeenPointerCount = lastSeenPointerCount;
      return false;
    } else if (details.pointerCount >= 2) {
      // is a zoom gesture, remove accidental stroke
      if (lastSeenPointerCount == 1 &&
          stows.editorFingerDrawing.value &&
          (currentTool is Pen || currentTool is Eraser)) {
        final item = history.removeAccidentalStroke();
        if (item != null) undo(item);
      }
      lastSeenPointerCount = details.pointerCount;
      return false;
    } else {
      // is a stroke
      lastSeenPointerCount = details.pointerCount;
    }

    dragPageIndex = onWhichPageIsFocalPoint(details.focalPoint);
    if (dragPageIndex == null) return false;

    if (currentTool == Tool.textEditing) {
      return false;
    } else if (stows.editorFingerDrawing.value ||
        currentPointerKind == PointerDeviceKind.stylus ||
        currentPointerKind == PointerDeviceKind.invertedStylus ||
        currentPressure != null) {
      return true;
    } else {
      log.fine('Non-stylus found, rejected stroke');
      return false;
    }
  }

  void onDrawStart(ScaleStartDetails details) {
    final page = coreInfo.pages[dragPageIndex!];
    final position = page.renderBox!.globalToLocal(details.focalPoint);
    history.canRedo = false;

    if (currentTool is Pen) {
      (currentTool as Pen).onDragStart(
        position,
        page,
        dragPageIndex!,
        currentPressure,
      );
    } else if (currentTool is Eraser) {
      for (final stroke in (currentTool as Eraser).checkForOverlappingStrokes(
        position,
        page.strokes,
      )) {
        page.strokes.remove(stroke);
      }
      removeExcessPages();
    } else if (currentTool is Select) {
      final select = currentTool as Select;
      if (select.doneSelecting &&
          select.selectResult.pageIndex == dragPageIndex! &&
          select.selectResult.path.contains(position)) {
        // drag selection in onDrawUpdate
      } else {
        select.onDragStart(position, dragPageIndex!);
        history.canRedo = true; // selection doesn't affect history
      }
    } else if (currentTool is LaserPointer) {
      (currentTool as LaserPointer).onDragStart(position, page, dragPageIndex!);
    }

    previousPosition = position;
    moveOffset = .zero;

    if (currentTool is! Select) {
      Select.currentSelect.unselect();
    }

    // setState to let canvas know about currentStroke
    setState(() {});
  }

  void onDrawUpdate(ScaleUpdateDetails details) {
    final page = coreInfo.pages[dragPageIndex!];
    final position = page.renderBox!.globalToLocal(details.focalPoint);
    final offset = position - previousPosition;

    if (currentTool is Pen) {
      (currentTool as Pen).onDragUpdate(position, currentPressure);
      page.redrawStrokes();
    } else if (currentTool is Eraser) {
      for (final stroke in (currentTool as Eraser).checkForOverlappingStrokes(
        position,
        page.strokes,
      )) {
        page.strokes.remove(stroke);
      }
      page.redrawStrokes();
      removeExcessPages();
    } else if (currentTool is Select) {
      final select = currentTool as Select;
      if (select.doneSelecting) {
        for (final stroke in select.selectResult.strokes) {
          stroke.shift(offset);
        }
        for (final image in select.selectResult.images) {
          image.dstRect = image.dstRect.shift(offset);
        }
        select.selectResult.path = select.selectResult.path.shift(offset);
      } else {
        select.onDragUpdate(position);
      }
      page.redrawStrokes();
    } else if (currentTool is LaserPointer) {
      (currentTool as LaserPointer).onDragUpdate(position);
      page.redrawStrokes();
    }
    previousPosition = position;
    moveOffset += offset;
  }

  void onDrawEnd(ScaleEndDetails details) {
    final page = coreInfo.pages[dragPageIndex!];
    bool shouldSave = true;
    setState(() {
      if (currentTool is Pen) {
        final newStroke = (currentTool as Pen).onDragEnd();
        if (newStroke == null) return;
        if (newStroke.isEmpty) return;

        if (stows.autoStraightenLines.value &&
            currentTool is! ShapePen &&
            newStroke.isStraightLine()) {
          newStroke.convertToLine();
        }

        createPage(newStroke.pageIndex);
        page.insertStroke(newStroke);
        history.recordChange(
          EditorHistoryItem(
            type: .draw,
            pageIndex: dragPageIndex!,
            strokes: [newStroke],
            images: [],
          ),
        );
      } else if (currentTool is Eraser) {
        final erased = (currentTool as Eraser).onDragEnd();
        if (tmpTool != null &&
            (stylusButtonPressed || stows.disableEraserAfterUse.value)) {
          // restore previous tool
          stylusButtonPressed = false;
          currentTool = tmpTool!;
          tmpTool = null;
        }
        if (erased.isEmpty) return;
        history.recordChange(
          EditorHistoryItem(
            type: .erase,
            pageIndex: dragPageIndex!,
            strokes: erased,
            images: [],
          ),
        );
      } else if (currentTool is Select) {
        if (moveOffset == .zero) return;
        final select = currentTool as Select;
        if (select.doneSelecting) {
          history.recordChange(
            EditorHistoryItem(
              type: .move,
              pageIndex: dragPageIndex!,
              strokes: select.selectResult.strokes,
              images: select.selectResult.images,
              offset: .fromLTRB(
                moveOffset.dx,
                moveOffset.dy,
                moveOffset.dx,
                moveOffset.dy,
              ),
            ),
          );
        } else {
          shouldSave = false;
          select.onDragEnd(page.strokes, page.images);

          if (select.selectResult.isEmpty) {
            Select.currentSelect.unselect();
          }
        }
      } else if (currentTool is LaserPointer) {
        shouldSave = false;
        final newStroke = (currentTool as LaserPointer).onDragEnd(
          page.redrawStrokes,
          (Stroke stroke) {
            page.laserStrokes.remove(stroke);
          },
        );
        if (newStroke != null) page.laserStrokes.add(newStroke);
      }
    });

    if (shouldSave) autosaveAfterDelay();
  }

  void onInteractionEnd(ScaleEndDetails details) {
    // reset after 1ms to keep track of the same gesture only
    _lastSeenPointerCountTimer?.cancel();
    _lastSeenPointerCountTimer = Timer(const Duration(milliseconds: 10), () {
      lastSeenPointerCount = 0;
    });
  }

  void updatePointerData(PointerDeviceKind kind, double? pressure) {
    currentPointerKind = kind;
    currentPressure = pressure;
  }

  void onHovering() {
    isHovering = true;
  }

  void onHoveringEnd() {
    isHovering = false;
  }

  void onStylusButtonChanged(bool buttonPressed) {
    // whether the stylus button is or was pressed
    stylusButtonPressed = stylusButtonPressed || buttonPressed;

    if (isHovering) {
      if (buttonPressed) {
        if (currentTool is Eraser) return;
        tmpTool = currentTool;
        currentTool = Eraser();
        setState(() {});
      } else {
        if (tmpTool != null && currentTool is Eraser) {
          currentTool = tmpTool!;
          tmpTool = null;
          setState(() {});
        }
      }
    }
  }

  void onMoveImage(EditorImage image, Rect offset) {
    history.recordChange(
      EditorHistoryItem(
        type: .move,
        pageIndex: image.pageIndex,
        strokes: [],
        images: [image],
        offset: offset,
      ),
    );
    // setState to update undo button
    setState(() {});
    autosaveAfterDelay();
  }

  void onDeleteImage(EditorImage image) {
    history.recordChange(
      EditorHistoryItem(
        type: .erase,
        pageIndex: image.pageIndex,
        strokes: [],
        images: [image],
      ),
    );
    setState(() {
      coreInfo.pages[image.pageIndex].images.remove(image);
    });
    autosaveAfterDelay();
  }

  void listenToQuillChanges(QuillStruct quill, int pageIndex) {
    quill.changeSubscription?.cancel();
    quill.changeSubscription = quill.controller.changes.listen((event) {
      final undoRedoButtonsNeedUpdating = !history.canUndo || history.canRedo;
      _addQuillChangeToHistory(
        quill: quill,
        pageIndex: pageIndex,
        event: event,
      );
      createPage(pageIndex); // create empty last page
      if (undoRedoButtonsNeedUpdating) {
        setState(() {});
      }
      autosaveAfterDelay();
    });
    quill.focusNode.addListener(_onQuillFocusChange);
  }

  void _onQuillFocusChange() {
    for (final page in coreInfo.pages) {
      if (!page.quill.focusNode.hasFocus) continue;
      quillFocus.value = page.quill;
    }
  }

  void _addQuillChangeToHistory({
    required QuillStruct quill,
    required int pageIndex,
    required flutter_quill.DocChange event,
  }) {
    final eventWasUndo = quill.controller.hasRedo;
    if (eventWasUndo) return;

    // the change subscription sometimes fires multiple times for the same change
    // so compare the "before" of each change to merge them
    if (history.canUndo && !history.canRedo) {
      final lastChange = history.peekUndo();
      if (lastChange.type == .quillChange &&
          lastChange.pageIndex == pageIndex &&
          lastChange.quillChange!.before == event.before) {
        history.undo(); // remove the last change, to be replaced
      }
    }

    history.recordChange(
      EditorHistoryItem(
        type: .quillChange,
        pageIndex: pageIndex,
        strokes: const [],
        images: const [],
        quillChange: event,
      ),
    );
  }

  // Note refresh removed - will be reimplemented with Supabase sync
  // See SYNAPSEAI_ROADMAP.md Phase 4
  void _refreshCurrentNote() async {
    // TODO: Implement Supabase-based sync check
    return;
  }

  void autosaveAfterDelay() {
    if (history.isCurrentStateSaved) return cancelAutosaveAndMarkSaved();

    late final void Function() callback;

    void startTimer() {
      _delayedSaveTimer?.cancel();
      if (stows.autosaveDelay.value < 0) return;
      _delayedSaveTimer = Timer(
        Duration(milliseconds: stows.autosaveDelay.value),
        callback,
      );
    }

    callback = () {
      if (Pen.currentStroke != null) {
        // don't save yet if the pen is currently drawing
        startTimer();
        return;
      }
      saveToFile();
    };

    savingState.value = .waitingToSave;
    startTimer();
  }

  void cancelAutosaveAndMarkSaved() {
    _delayedSaveTimer?.cancel();
    savingState.value = .saved;
  }

  Future<void> saveToFile() async {
    if (coreInfo.readOnly) return;

    switch (savingState.value) {
      case .saved:
        // avoid saving if nothing has changed
        return;
      case .saving:
        // avoid saving if already saving
        log.warning('saveToFile() called while already saving');
        return;
      case .waitingToSave:
        // continue
        _delayedSaveTimer?.cancel();
        savingState.value = .saving;
    }
    if (history.isCurrentStateSaved) return cancelAutosaveAndMarkSaved();

    await _renameFileNow();

    final filePath = coreInfo.filePath + Editor.extension;
    final Uint8List bson;
    final OrderedAssetCache assets;
    coreInfo.assetCache.allowRemovingAssets = false;
    try {
      (bson, assets) = coreInfo.saveToBinary(
        currentPageIndex: currentPageIndex,
      );
    } finally {
      coreInfo.assetCache.allowRemovingAssets = true;
    }
    try {
      await Future.wait([
        FileManager.writeFile(filePath, bson, awaitWrite: true),
        for (int i = 0; i < assets.length; ++i)
          assets
              .getBytes(i)
              .then(
                (bytes) => FileManager.writeFile(
                  '$filePath.$i',
                  bytes,
                  awaitWrite: true,
                ),
              ),
        FileManager.removeUnusedAssets(filePath, numAssets: assets.length),
      ]);
      savingState.value = .saved;
      history.markLastChangeAsSaved();

      // Mark consultation as completed if this is a session note
      // REMOVED: Logic moved to Report Generation verification step
      // to prevent premature status updates.
    } catch (e) {
      log.severe('Failed to save file: $e', e);
      savingState.value = .waitingToSave;
      if (kDebugMode) rethrow;
      return;
    }

    if (!mounted) return;
    final screenshotter = ScreenshotController();
    final page = coreInfo.pages.first;
    final previewHeight = page.previewHeight(lineHeight: coreInfo.lineHeight);
    final thumbnailSize = Size(720, 720 * previewHeight / page.size.width);
    final thumbnail = await screenshotter.captureFromWidget(
      Theme(
        data: ThemeData(
          brightness: .light,
          colorScheme: const ColorScheme.light(
            primary: EditorExporter.primaryColor,
            secondary: EditorExporter.secondaryColor,
          ),
        ),
        child: Localizations.override(
          context: context,
          child: SizedBox(
            width: thumbnailSize.width,
            height: thumbnailSize.height,
            child: FittedBox(
              child: pageBuilderForScreenshot(
                context,
                pageIndex: 0,
                previewHeight: previewHeight,
              ),
            ),
          ),
        ),
      ),
      pixelRatio: 1,
      context: context,
      targetSize: thumbnailSize,
    );
    await FileManager.writeFile(
      // Note that this ends with .sbn2.p
      '$filePath.p',
      thumbnail,
      awaitWrite: true,
    );
  }

  late final _filenameFormKey = GlobalKey<FormState>();
  late final filenameTextEditingController = TextEditingController();
  Timer? _renameTimer;
  void renameFile([String? _]) {
    _renameTimer?.cancel();
    _renameTimer = Timer(const Duration(seconds: 5), _renameFileNow);
  }

  Future<void> _renameFileNow() async {
    final newName = filenameTextEditingController.text;
    if (newName == coreInfo.fileName) return;

    if (_filenameFormKey.currentState?.validate() ??
        _validateFilenameTextField(newName) == null) {
      coreInfo.filePath = await FileManager.moveFile(
        coreInfo.filePath + Editor.extension,
        newName.trim() + Editor.extension,
      );
      coreInfo.filePath = coreInfo.filePath.substring(
        0,
        coreInfo.filePath.lastIndexOf(Editor.extension),
      );
      needsNaming = false;
    }

    final actualName = coreInfo.fileName;
    if (actualName != newName) {
      // update text field if renamed differently
      filenameTextEditingController.value = filenameTextEditingController.value
          .copyWith(
            text: actualName,
            selection: TextSelection.fromPosition(
              TextPosition(offset: actualName.length),
            ),
            composing: TextRange.empty,
          );
    }
  }

  String? _validateFilenameTextField(String? newName) {
    if (newName == null) return null;
    if (newName.isEmpty) return t.home.renameNote.noteNameEmpty;
    if (newName.contains('/')) return t.home.renameNote.noteNameContainsSlash;
    return null;
  }

  void updateColorBar(Color color) {
    if (stows.recentColorsDontSavePresets.value) {
      if (ColorBar.colorPresets.any(
        (colorPreset) => colorPreset.color == color,
      )) {
        return;
      }
    }

    final newColorString = color.toARGB32().toString();

    // migrate from old pref format
    if (stows.recentColorsChronological.value.length !=
        stows.recentColorsPositioned.value.length) {
      log.info(
        'MIGRATING recentColors: ${stows.recentColorsChronological.value.length} vs ${stows.recentColorsPositioned.value.length}',
      );
      stows.recentColorsChronological.value = List.of(
        stows.recentColorsPositioned.value,
      );
    }

    if (stows.pinnedColors.value.contains(newColorString)) {
      // do nothing, color is already pinned
    } else if (stows.recentColorsPositioned.value.contains(newColorString)) {
      // if it's already a recent color, move it to the top
      stows.recentColorsChronological.value.remove(newColorString);
      stows.recentColorsChronological.value.add(newColorString);
      stows.recentColorsChronological.notifyListeners();
    } else {
      if (stows.recentColorsPositioned.value.length >=
          stows.recentColorsLength.value) {
        // if full, replace the oldest color with the new one
        final removedColorString = stows.recentColorsChronological.value
            .removeAt(0);
        stows.recentColorsChronological.value.add(newColorString);
        final int removedColorPosition = stows.recentColorsPositioned.value
            .indexOf(removedColorString);
        stows.recentColorsPositioned.value[removedColorPosition] =
            newColorString;
      } else {
        // if not full, add the new color to the end
        stows.recentColorsChronological.value.add(newColorString);
        stows.recentColorsPositioned.value.insert(0, newColorString);
      }
      stows.recentColorsChronological.notifyListeners();
      stows.recentColorsPositioned.notifyListeners();
    }
  }

  /// Prompts the user to pick photos from their device.
  /// Returns the number of photos picked.
  ///
  /// If [photoInfos] is provided, it will be used instead of the file picker.
  Future<int> _pickPhotos([List<_PhotoInfo>? photoInfos]) async {
    if (coreInfo.readOnly) return 0;

    final currentPageIndex = this.currentPageIndex;

    photoInfos ??= await _pickPhotosWithFilePicker();
    if (photoInfos.isEmpty) return 0;

    // use the Select tool so that the user can move the new image
    currentTool = Select.currentSelect;

    final images = [
      for (final _PhotoInfo photoInfo in photoInfos)
        if (photoInfo.extension == '.svg')
          SvgEditorImage(
            id: coreInfo.nextImageId++,
            svgString: utf8.decode(photoInfo.bytes),
            svgFile: null,
            pageIndex: currentPageIndex,
            pageSize: coreInfo.pages[currentPageIndex].size,
            onMoveImage: onMoveImage,
            onDeleteImage: onDeleteImage,
            onMiscChange: autosaveAfterDelay,
            onLoad: () => setState(() {}),
            assetCache: coreInfo.assetCache,
          )
        else
          PngEditorImage(
            id: coreInfo.nextImageId++,
            extension: photoInfo.extension,
            imageProvider: MemoryImage(photoInfo.bytes),
            pageIndex: currentPageIndex,
            pageSize: coreInfo.pages[currentPageIndex].size,
            onMoveImage: onMoveImage,
            onDeleteImage: onDeleteImage,
            onMiscChange: autosaveAfterDelay,
            onLoad: () => setState(() {}),
            assetCache: coreInfo.assetCache,
          ),
    ];

    history.recordChange(
      EditorHistoryItem(
        type: .draw,
        pageIndex: currentPageIndex,
        strokes: [],
        images: images,
      ),
    );
    createPage(currentPageIndex);
    coreInfo.pages[currentPageIndex].images.addAll(images);
    autosaveAfterDelay();

    return images.length;
  }

  Future<List<_PhotoInfo>> _pickPhotosWithFilePicker() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // Taken from
      // https://github.com/brendan-duncan/image/blob/main/doc/formats.md
      // (plus .svg)
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'tiff',
        'bmp',
        'tga',
        'ico',
        'pvrtc',
        'svg',
        'webp',
        'psd',
        'exr',
      ],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return const [];

    return [
      for (final PlatformFile file in result.files)
        if (file.bytes != null && file.extension != null)
          (bytes: file.bytes!, extension: '.${file.extension}'),
    ];
  }

  /// Prompts the user to pick a PDF to import.
  /// Returns whether a PDF was picked.
  Future<bool> importPdf() async {
    if (coreInfo.readOnly) return false;
    if (!Editor.canRasterPdf) return false;

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null) return false;

    final PlatformFile file = result.files.single;
    return importPdfFromFilePath(file.path!);
  }

  Future<bool> importPdfFromFilePath(String path) async {
    final pdfDocument = await coreInfo.assetCache.pdfDocumentCache.load(path);

    final emptyPage = coreInfo.pages.removeLast();
    assert(emptyPage.isEmpty);

    for (final pdfPage in pdfDocument.pages) {
      assert(pdfPage.pageNumber >= 1, 'pdfrx page numbers start at 1');

      // resize to [defaultWidth] to keep pen sizes consistent
      final pageSize = Size(
        EditorPage.defaultWidth,
        EditorPage.defaultWidth * pdfPage.height / pdfPage.width,
      );

      final page = EditorPage(
        size: pageSize,
        backgroundImage: PdfEditorImage(
          id: coreInfo.nextImageId++,
          pdfBytes: null,
          pdfFile: File(path),
          pdfPage: pdfPage.pageNumber - 1,
          pageIndex: coreInfo.pages.length,
          pageSize: pageSize,
          naturalSize: pdfPage.size,
          onMoveImage: onMoveImage,
          onDeleteImage: onDeleteImage,
          onMiscChange: autosaveAfterDelay,
          onLoad: () => setState(() {}),
          assetCache: coreInfo.assetCache,
        ),
      );
      coreInfo.pages.add(page);
      // TODO(adil192): Group multiple pages into one atomic change
      history.recordChange(
        EditorHistoryItem(
          type: .insertPage,
          pageIndex: coreInfo.pages.length - 1,
          strokes: const [],
          images: const [],
          page: page,
        ),
      );
    }

    coreInfo.pages.add(emptyPage);
    if (mounted) setState(() {});

    autosaveAfterDelay();

    return true;
  }

  Future paste() async {
    /// Maps image formats to their file extension.
    const Map<SimpleFileFormat, String> formats = {
      Formats.jpeg: '.jpeg',
      Formats.png: '.png',
      Formats.gif: '.gif',
      Formats.tiff: '.tiff',
      Formats.bmp: '.bmp',
      Formats.ico: '.ico',
      Formats.svg: '.svg',
      Formats.webp: '.webp',
    };

    final reader = await SystemClipboard.instance?.read();
    if (reader == null) return;

    final List<_PhotoInfo> photoInfos = [];
    final List<ReadProgress> progresses = [];

    for (final format in formats.keys) {
      if (!reader.canProvide(format)) continue;
      final progress = reader.getFile(format, (file) async {
        final stream = file.getStream();
        final List<int> bytes = [];
        await for (final chunk in stream) {
          bytes.addAll(chunk);
        }
        if (bytes.isEmpty) {
          log.warning('Pasted empty file: $file (${formats[format]})');
          return;
        }

        String extension;
        if (file.fileName != null) {
          extension = file.fileName!.substring(file.fileName!.lastIndexOf('.'));
        } else {
          extension = formats[format]!;
        }

        photoInfos.add((
          bytes: Uint8List.fromList(bytes),
          extension: extension,
        ));
      });
      if (progress != null) progresses.add(progress);
    }

    while (progresses.isNotEmpty) {
      progresses.removeWhere((progress) => progress.fraction.value == 1);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    await _pickPhotos(photoInfos);
  }

  Future exportAsPdf(BuildContext context) async {
    final pdf = await EditorExporter.generatePdf(coreInfo, context);
    final bytes = await pdf.save();
    if (!context.mounted) return;
    await FileManager.exportFile(
      '${coreInfo.fileName}.pdf',
      bytes,
      context: context,
    );
  }

  /// Exports the current note as an SBA (Saber Archive) file.
  Future exportAsSba(BuildContext context) async {
    final sba = await coreInfo.saveToSba(currentPageIndex: currentPageIndex);
    if (!context.mounted) return;
    await FileManager.exportFile(
      '${coreInfo.fileName}.sba',
      sba,
      context: context,
    );
  }

  /// Opens the intake form for editing
  Future<void> _openIntakeFormEditor() async {
    // If we have a patient intake, we can open it.
    // If we don't have one, we need at least the patient ID to create one.
    if (_patientIntake == null && _patientId == null) return;

    final patientId = _patientIntake?.patientId ?? _patientId!;

    try {
      final patient = await SupabasePatientService.getPatient(patientId);
      if (patient == null || !mounted) return;

      final result = await Navigator.of(context).push<PsychiatricIntake>(
        MaterialPageRoute(
          builder: (context) => PsychiatricIntakeForm(
            patient: patient,
            existingIntake: _patientIntake,
            doctorName: _doctorName,
            readOnly:
                true, // Start in read-only mode to prevent accidental edits
            onSave: (intake) async {
              try {
                final savedIntake = await SupabaseIntakeService.upsertIntake(
                  intake,
                );
                if (mounted) {
                  Navigator.of(context).pop(savedIntake);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _patientIntake = result;
        });
      }
    } catch (e) {
      log.warning('Failed to open intake form: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  @override
  Future<void> _generateReport(BuildContext context) async {
    // 1. Capture Screenshots of ALL pages
    final screenshotController = ScreenshotController();
    final imageBytesList = <Uint8List>[];

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              lottie_pkg.Lottie.asset(
                'assets/saber.json',
                width: 250,
                height: 250,
                errorBuilder: (context, error, stackTrace) =>
                    const CircularProgressIndicator(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Digitizing clinical notes...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Loop through all pages
      for (var i = 0; i < coreInfo.pages.length; i++) {
        final page = coreInfo.pages[i];
        final previewHeight = page.previewHeight(
          lineHeight: coreInfo.lineHeight,
        );
        final targetSize = Size(page.size.width, page.size.height);

        log.info(
          'Capturing page ${i + 1}/${coreInfo.pages.length} with size: $targetSize',
        );

        final imageBytes = await screenshotController.captureFromWidget(
          MediaQuery(
            // Provide consistent MediaQuery data regardless of device orientation
            data: MediaQueryData(
              size: targetSize,
              devicePixelRatio: 2.0,
              padding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
            ),
            child: Theme(
              data: ThemeData(
                brightness: Brightness.light,
                colorScheme: const ColorScheme.light(
                  primary: EditorExporter.primaryColor,
                  secondary: EditorExporter.secondaryColor,
                ),
              ),
              child: Localizations.override(
                context: context,
                child: SizedBox(
                  width: targetSize.width,
                  height: targetSize.height,
                  child: FittedBox(
                    child: pageBuilderForScreenshot(
                      context,
                      pageIndex: i,
                      previewHeight: previewHeight,
                    ),
                  ),
                ),
              ),
            ),
          ),
          delay: const Duration(milliseconds: 100), // Allow time for rendering
          pixelRatio: 2.0, // Higher quality for OCR
          context: context,
          targetSize: targetSize,
        );

        log.info(
          'Captured page ${i + 1}, image size: ${imageBytes.length} bytes',
        );

        if (imageBytes.isEmpty) {
          throw Exception('Failed to capture page ${i + 1}: empty image bytes');
        }

        imageBytesList.add(imageBytes);
      }

      // 2. Send to API
      // ignore: use_build_context_synchronously
      if (!context.mounted) return;

      final reportData = await ReportGenerator.generateReport(imageBytesList);

      // 3. Show Split Screen / Report View
      // ignore: use_build_context_synchronously
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Calculate total height for the scrollable preview
      // We'll just stack them vertically in a ListView
      // No need to stitch bytes manually, the UI can just list them.

      _showReportDialog(context, reportData, imageBytesList);
    } catch (e) {
      // ignore: use_build_context_synchronously
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final platform = theme.platform;
    final isToolbarVertical =
        stows.editorToolbarAlignment.value == AxisDirection.left ||
        stows.editorToolbarAlignment.value == AxisDirection.right;

    final Widget actualCanvas = CanvasGestureDetector(
      key: _canvasGestureDetectorKey,
      filePath: coreInfo.filePath,
      isDrawGesture: isDrawGesture,
      onInteractionEnd: onInteractionEnd,
      onDrawStart: onDrawStart,
      onDrawUpdate: onDrawUpdate,
      onDrawEnd: onDrawEnd,
      onHovering: onHovering,
      onHoveringEnd: onHoveringEnd,
      onStylusButtonChanged: onStylusButtonChanged,
      updatePointerData: updatePointerData,
      undo: undo,
      redo: redo,
      pages: coreInfo.pages,
      initialPageIndex: coreInfo.initialPageIndex,
      pageBuilder: pageBuilder,
      isTextEditing: () => currentTool == Tool.textEditing,
      placeholderPageBuilder: (BuildContext context, int pageIndex) {
        return Canvas(
          path: coreInfo.filePath,
          page: coreInfo.pages[pageIndex],
          pageIndex: 0,
          textEditing: false,
          coreInfo: EditorCoreInfo.empty,
          currentStroke: null,
          currentStrokeDetectedShape: null,
          currentSelection: null,
          placeholder: true,
          setAsBackground: null,
          currentTool: currentTool,
          currentScale: double.minPositive,
        );
      },
      transformationController: _transformationController,
    );

    final Widget canvas = Stack(
      children: [
        if (_isClearing)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            builder: (context, value, child) {
              return Stack(
                children: [
                  // The content sliding out
                  Transform.translate(
                    offset: Offset(
                      value * MediaQuery.of(context).size.width,
                      -value * 100,
                    ),
                    child: Transform.rotate(
                      angle: value * 0.1,
                      child: Opacity(
                        opacity: (1.0 - value * 1.5).clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                  ),
                  // Wind streaks
                  Positioned.fill(
                    child: CustomPaint(
                      painter: WindPainter(
                        progress: value,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              );
            },
            child: actualCanvas,
          )
        else
          actualCanvas,
      ],
    );

    final Widget? readonlyBanner = coreInfo.readOnlyBecauseOfVersion
        ? Collapsible(
            collapsed:
                !(coreInfo.readOnly && coreInfo.readOnlyBecauseOfVersion),
            axis: CollapsibleAxis.vertical,
            child: SafeArea(
              child: ListTile(
                onTap: askUserToDisableReadOnly,
                title: Text(t.editor.newerFileFormat.readOnlyMode),
                subtitle: Text(t.editor.newerFileFormat.title),
                trailing: const Icon(Icons.edit_off),
              ),
            ),
          )
        : null;

    final Widget toolbar = Collapsible(
      axis: isToolbarVertical
          ? CollapsibleAxis.horizontal
          : CollapsibleAxis.vertical,
      collapsed:
          DynamicMaterialApp.isFullscreen &&
          !stows.editorToolbarShowInFullscreen.value,
      maintainState: true,
      child: SafeArea(
        bottom: stows.editorToolbarAlignment.value != AxisDirection.up,
        child: Toolbar(
          readOnly: coreInfo.readOnly,
          setTool: (tool) {
            setState(() {
              if (tool is Eraser) {
                // setTool(Eraser) is called to toggle eraser
                if (currentTool is Eraser && tmpTool != null) {
                  // switch to previous tool
                  tool = tmpTool!;
                  tmpTool = null;
                } else {
                  // store previous tool to restore it later
                  tmpTool = currentTool;
                }
              }

              currentTool = tool;

              if (currentTool is Highlighter) {
                Highlighter.currentHighlighter = currentTool as Highlighter;
              } else if (currentTool is Pencil) {
                Pencil.currentPencil = currentTool as Pencil;
              } else if (currentTool is Pen) {
                Pen.currentPen = currentTool as Pen;
              }
            });
          },
          currentTool: currentTool,
          duplicateSelection: () {
            final select = currentTool as Select;
            if (!select.doneSelecting) return;

            setState(() {
              final page = coreInfo.pages[select.selectResult.pageIndex];
              final strokes = select.selectResult.strokes;
              final images = select.selectResult.images;

              const duplicationFeedbackOffset = Offset(25, -25);

              final duplicatedStrokes = strokes.map((stroke) {
                return stroke.copy()..shift(duplicationFeedbackOffset);
              }).toList();

              final duplicatedImages = images.map((image) {
                return image.copy()
                  ..id = coreInfo.nextImageId++
                  ..dstRect.shift(duplicationFeedbackOffset);
              }).toList();

              page.strokes.addAll(duplicatedStrokes);
              page.images.addAll(duplicatedImages);

              select.selectResult = select.selectResult.copyWith(
                strokes: duplicatedStrokes,
                images: duplicatedImages,
                path: select.selectResult.path.shift(duplicationFeedbackOffset),
              );

              history.recordChange(
                EditorHistoryItem(
                  type: .draw,
                  pageIndex: select.selectResult.pageIndex,
                  strokes: duplicatedStrokes,
                  images: duplicatedImages,
                ),
              );
              autosaveAfterDelay();
            });
          },
          deleteSelection: () {
            final select = currentTool as Select;
            if (!select.doneSelecting) {
              return;
            }

            setState(() {
              final page = coreInfo.pages[select.selectResult.pageIndex];
              final strokes = select.selectResult.strokes;
              final images = select.selectResult.images;

              for (final stroke in strokes) {
                page.strokes.remove(stroke);
              }
              for (final image in images) {
                page.images.remove(image);
              }

              select.unselect();

              history.recordChange(
                EditorHistoryItem(
                  type: .erase,
                  pageIndex: strokes.first.pageIndex,
                  strokes: strokes,
                  images: images,
                ),
              );
              autosaveAfterDelay();
            });
          },
          setColor: (color) {
            setState(() {
              updateColorBar(color);

              if (currentTool is Highlighter) {
                (currentTool as Highlighter).color = color.withAlpha(
                  Highlighter.alpha,
                );
              } else if (currentTool is Pen) {
                (currentTool as Pen).color = color;
              } else if (currentTool is Select) {
                // Changes color of selected strokes
                final select = currentTool as Select;
                if (select.doneSelecting) {
                  final strokes = select.selectResult.strokes;

                  final colorChange = <Stroke, ColorChange>{};
                  for (final stroke in strokes) {
                    colorChange[stroke] = ColorChange(
                      previous: stroke.color,
                      current: color,
                    );
                    stroke.color = color;
                  }

                  history.recordChange(
                    EditorHistoryItem(
                      type: .changeColor,
                      pageIndex: strokes.first.pageIndex,
                      strokes: strokes,
                      colorChange: colorChange,
                      images: [],
                    ),
                  );
                  autosaveAfterDelay();
                }
              }
            });
          },
          quillFocus: quillFocus,
          textEditing: currentTool == Tool.textEditing,
          toggleTextEditing: () => setState(() {
            if (currentTool == Tool.textEditing) {
              currentTool = Pen.currentPen;
              for (final page in coreInfo.pages) {
                // unselect text, but maintain cursor position
                page.quill.controller.moveCursorToPosition(
                  page.quill.controller.selection.extentOffset,
                );
                page.quill.focusNode.unfocus();
              }
            } else {
              currentTool = Tool.textEditing;
              quillFocus.value = coreInfo.pages[currentPageIndex].quill
                ..focusNode.requestFocus();
            }
          }),
          undo: undo,
          isUndoPossible: history.canUndo,
          redo: redo,
          isRedoPossible: history.canRedo,
          toggleFingerDrawing: () {
            stows.editorFingerDrawing.value = !stows.editorFingerDrawing.value;
            lastSeenPointerCount = 0;
          },
          pickPhoto: _pickPhotos,
          paste: paste,
          exportAsSba: exportAsSba,
          exportAsPdf: exportAsPdf,
          exportAsPng: null,
          toggleMedicationHistory: _patientId != null
              ? _toggleMedicationHistoryOverlay
              : null,
        ),
      ),
    );

    // Canvas with intake overlay if available
    // ----------------------------------------------------------------------
    // Final Layout: Canvas + ALL Overlays (Intake, Vitals, History)
    // ----------------------------------------------------------------------
    // We use a SINGLE LayoutBuilder and Stack here to prevent layout cycles/ANRs
    // caused by nested LayoutBuilders in previous implementations.

    Widget finalCanvasWithOverlay = LayoutBuilder(
      builder: (context, constraints) {
        final List<Widget> stackChildren = [canvas];

        // --------------------------------------------------------------------
        // Right-Side Controls (Buttons and Draggable Overlays)
        // --------------------------------------------------------------------
        // Using a Column for default positions to provide an 'adaptive gap',
        // ensuring expanded overlays don't obstruct other buttons.
        // --------------------------------------------------------------------

        // Items that have been dragged or have custom positions
        if (_showIntakeOverlay && _intakeOverlayPosition != null) {
          stackChildren.add(
            Positioned(
              left: _intakeOverlayPosition!.dx,
              top: _intakeOverlayPosition!.dy,
              child: _buildDraggableIntakeOverlay(constraints),
            ),
          );
        }
        if (_showVitalsOverlay && _vitalsOverlayPosition != null) {
          stackChildren.add(
            Positioned(
              left: _vitalsOverlayPosition!.dx,
              top: _vitalsOverlayPosition!.dy,
              child: _buildDraggableVitalsOverlay(constraints),
            ),
          );
        }
        if (_showPreviousNotesOverlay &&
            _previousNotesOverlayPosition != null) {
          stackChildren.add(
            Positioned(
              left: _previousNotesOverlayPosition!.dx,
              top: _previousNotesOverlayPosition!.dy,
              child: _buildDraggablePreviousNotesOverlay(constraints),
            ),
          );
        }
        if (_showMedicationHistoryOverlay &&
            _medicationHistoryOverlayPosition != null) {
          stackChildren.add(
            Positioned(
              left: _medicationHistoryOverlayPosition!.dx,
              top: _medicationHistoryOverlayPosition!.dy,
              child: _buildDraggableMedicationHistoryOverlay(constraints),
            ),
          );
        }

        // Column for items at their default (non-dragged) position
        stackChildren.add(
          Positioned(
            right: 16,
            top: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Intake
                if (_patientId != null || _patientIntake != null) ...[
                  _showIntakeOverlay && _intakeOverlayPosition == null
                      ? _buildDraggableIntakeOverlay(constraints)
                      : _buildIntakeButton(colorScheme, theme),
                  const SizedBox(height: 16),
                ],
                // 2. Vitals
                if (_patientId != null) ...[
                  _showVitalsOverlay && _vitalsOverlayPosition == null
                      ? _buildDraggableVitalsOverlay(constraints)
                      : _buildVitalsButton(colorScheme, theme),
                  const SizedBox(height: 16),
                ],
                // 3. Previous Notes
                if (_patientId != null) ...[
                  _showPreviousNotesOverlay &&
                          _previousNotesOverlayPosition == null
                      ? _buildDraggablePreviousNotesOverlay(constraints)
                      : _buildPreviousNotesButton(colorScheme, theme),
                  const SizedBox(height: 16),
                ],
                // 4. Medication History
                if (_patientId != null) ...[
                  _showMedicationHistoryOverlay &&
                          _medicationHistoryOverlayPosition == null
                      ? _buildDraggableMedicationHistoryOverlay(constraints)
                      : _buildMedicationHistoryButton(colorScheme, theme),
                ],
              ],
            ),
          ),
        );

        return Stack(children: stackChildren);
      },
    );

    final Widget body;
    if (isToolbarVertical) {
      body = Row(
        textDirection: stows.editorToolbarAlignment.value == AxisDirection.left
            ? .ltr
            : .rtl,
        children: [
          toolbar,
          Expanded(
            child: Column(
              children: [
                Expanded(child: finalCanvasWithOverlay),
                if (readonlyBanner != null) readonlyBanner,
              ],
            ),
          ),
        ],
      );
    } else {
      body = Column(
        verticalDirection:
            stows.editorToolbarAlignment.value == AxisDirection.up
            ? VerticalDirection.up
            : VerticalDirection.down,
        children: [
          Expanded(child: finalCanvasWithOverlay),
          toolbar,
          if (readonlyBanner != null) readonlyBanner,
        ],
      );
    }

    return ValueListenableBuilder(
      valueListenable: savingState,
      builder: (context, savingState, child) {
        // handle session minimization on back navigation
        return PopScope(
          canPop: savingState != SavingState.saving,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              snackBarNeedsToSaveBeforeExiting();
              return;
            }

            // The pop happened. Use a post-frame callback to trigger minimization
            // to avoid state changes during the transition/pop processing.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!widget.readOnly &&
                  SessionManager().hasActiveSession &&
                  SessionManager().isMinimized == false) {
                SessionManager().minimize();
              }
            });
          },
          child: child!,
        );
      },
      child: Scaffold(
        appBar: DynamicMaterialApp.isFullscreen
            ? null
            : AppBar(
                centerTitle: false,
                toolbarHeight: kToolbarHeight,
                title: widget.customTitle != null
                    ? Text(
                        widget.customTitle!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : _patientName != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _patientName!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            coreInfo.fileName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      )
                    : Form(
                        key: _filenameFormKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: TextFormField(
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          controller: filenameTextEditingController,
                          onChanged: renameFile,
                          autofocus: needsNaming,
                          validator: _validateFilenameTextField,
                        ),
                      ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () {
                    debugPrint('Editor: Back button pressed');
                    if (savingState.value == SavingState.saving) {
                      snackBarNeedsToSaveBeforeExiting();
                    } else {
                      // Safety fallback: if there is no stack to pop (can happen with go_router),
                      // navigate to the dashboard explicitly instead of popping to black.
                      if (Navigator.of(context).canPop()) {
                        context.pop();
                      } else {
                        // If no session terminated, minimize first before moving
                        if (!widget.readOnly &&
                            SessionManager().hasActiveSession) {
                          SessionManager().minimize();
                        }
                        context.go(HomeRoutes.getRoute(0));
                      }
                    }
                  },
                ),
                actions: [
                  if (!widget.isWhiteboard)
                    SaveIndicator(
                      savingState: savingState,
                      triggerSave: saveToFile,
                    ),
                  if (widget.isWhiteboard) _buildClearWhiteboardButton(context),
                  if (!widget.isWhiteboard) const SizedBox(width: 16),
                  if (!widget.readOnly && !widget.isWhiteboard)
                    _buildTerminateButton(context),
                  if (!widget.isWhiteboard) const SizedBox(width: 20),
                  if (!widget.isWhiteboard)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade500, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Finish Session',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: coreInfo.readOnly
                            ? null
                            : () async {
                                // First, check if a report already exists for this session
                                log.info(
                                  'Checking for existing report with path: ${coreInfo.filePath}',
                                );
                                ClinicalReport? existingReport;
                                try {
                                  existingReport =
                                      await SupabaseReportService.getReportBySourcePath(
                                        coreInfo.filePath,
                                      );
                                  if (existingReport != null) {
                                    log.info(
                                      'Found existing report: ${existingReport.id}',
                                    );
                                  } else {
                                    log.info(
                                      'No existing report found for this session',
                                    );
                                  }
                                } catch (e) {
                                  log.warning(
                                    'Failed to check for existing report: $e',
                                  );
                                }

                                if (existingReport != null) {
                                  // Show existing report without confirmation
                                  if (!context.mounted) return;
                                  log.info(
                                    'Showing existing report instead of generating new one',
                                  );
                                  _showReportDialog(
                                    context,
                                    existingReport.structuredData,
                                    <Uint8List>[],
                                    onRegenerate: () async {
                                      // Close the current dialog
                                      Navigator.pop(context);

                                      // Show confirmation dialog for regeneration
                                      final confirmRegen = await showDialog<bool>(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (dialogContext) => Dialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 400,
                                            ),
                                            padding: const EdgeInsets.all(24),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Warning icon with gradient background
                                                Container(
                                                  width: 80,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.orange.shade400,
                                                        Colors.orange.shade700,
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.orange
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                        blurRadius: 12,
                                                        spreadRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.refresh,
                                                    color: Colors.white,
                                                    size: 40,
                                                  ),
                                                ),
                                                const SizedBox(height: 24),
                                                // Title
                                                Text(
                                                  'Regenerate Report?',
                                                  style: Theme.of(dialogContext)
                                                      .textTheme
                                                      .headlineSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 12),
                                                // Description
                                                Text(
                                                  'This will generate a new AI report for this session. The current report will be replaced. This action cannot be undone.',
                                                  style: Theme.of(dialogContext)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            Theme.of(
                                                                  dialogContext,
                                                                )
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                      ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 24),
                                                // Action buttons
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: OutlinedButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              dialogContext,
                                                              false,
                                                            ),
                                                        style: OutlinedButton.styleFrom(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 14,
                                                              ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          t.common.cancel,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: FilledButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              dialogContext,
                                                              true,
                                                            ),
                                                        style: FilledButton.styleFrom(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 14,
                                                              ),
                                                          backgroundColor:
                                                              Colors
                                                                  .orange
                                                                  .shade700,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                        ),
                                                        child: const Text(
                                                          'Regenerate',
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );

                                      // If confirmed, delete the old report and generate a new one
                                      if (confirmRegen == true &&
                                          context.mounted) {
                                        try {
                                          // Delete the existing report from database
                                          await SupabaseReportService.deleteReport(
                                            existingReport!.id,
                                          );
                                          log.info(
                                            'Deleted existing report ${existingReport!.id}',
                                          );

                                          // Generate new report
                                          _generateReport(context);
                                        } catch (e) {
                                          log.severe(
                                            'Failed to delete existing report',
                                            e,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to regenerate report: $e',
                                                ),
                                                backgroundColor: Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  );
                                  return;
                                }

                                // No existing report, show confirmation dialog
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (dialogContext) => Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 400,
                                      ),
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Icon with gradient background
                                          Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.blue.shade400,
                                                  Colors.blue.shade700,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.blue.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  blurRadius: 12,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.auto_awesome,
                                              color: Colors.white,
                                              size: 40,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          // Title
                                          Text(
                                            'Generate AI Report?',
                                            style: Theme.of(dialogContext)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 12),
                                          // Description
                                          Text(
                                            'This will finalize the session and generate a comprehensive clinical report using AI. The editor will be locked after generation.',
                                            style: Theme.of(dialogContext)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(dialogContext)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 24),
                                          // Action buttons
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        false,
                                                      ),
                                                  style: OutlinedButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(t.common.cancel),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        true,
                                                      ),
                                                  style: FilledButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    backgroundColor:
                                                        Colors.blue.shade700,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Generate Report',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );

                                if (confirm == true && context.mounted) {
                                  _generateReport(context);
                                }
                              },
                      ),
                    ),
                  if (coreInfo.readOnly)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            coreInfo.readOnly = false;
                          });
                        },
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        label: const Text(
                          'Unlock to Edit',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  IconButton(
                    icon: const AdaptiveIcon(
                      icon: Icons.insert_page_break,
                      cupertinoIcon: CupertinoIcons.add,
                    ),
                    tooltip: t.editor.menu.insertPage,
                    onPressed: () => setState(() {
                      final currentPageIndex = this.currentPageIndex;
                      insertPageAfter(currentPageIndex);
                      CanvasGestureDetector.scrollToPage(
                        pageIndex: currentPageIndex + 1,
                        pages: coreInfo.pages,
                        screenWidth: MediaQuery.sizeOf(context).width,
                        transformationController: _transformationController,
                      );
                    }),
                  ),
                  IconButton(
                    icon: const AdaptiveIcon(
                      icon: Icons.grid_view,
                      cupertinoIcon: CupertinoIcons.rectangle_grid_2x2,
                    ),
                    tooltip: t.editor.pages,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AdaptiveAlertDialog(
                          title: Text(t.editor.pages),
                          content: pageManager(context),
                          actions: const [],
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const AdaptiveIcon(
                      icon: Icons.more_vert,
                      cupertinoIcon: CupertinoIcons.ellipsis_vertical,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => bottomSheet(context),
                        isScrollControlled: true,
                        showDragHandle: true,
                        backgroundColor: colorScheme.surface,
                        constraints: const BoxConstraints(maxWidth: 500),
                      );
                    },
                  ),
                ],
              ),
        body: body,
        floatingActionButton:
            (DynamicMaterialApp.isFullscreen &&
                !stows.editorToolbarShowInFullscreen.value)
            ? FloatingActionButton(
                shape: platform.isCupertino ? const CircleBorder() : null,
                onPressed: () {
                  DynamicMaterialApp.setFullscreen(false, updateSystem: true);
                },
                child: const Icon(Icons.fullscreen_exit),
              )
            : null,
      ),
    );
  }

  void snackBarNeedsToSaveBeforeExiting() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.editor.needsToSaveBeforeExiting)));
  }

  Widget bottomSheet(BuildContext context) {
    final Brightness brightness = Theme.brightnessOf(context);
    final invert = stows.editorAutoInvert.value && brightness == .dark;
    final int currentPageIndex = this.currentPageIndex;

    return EditorBottomSheet(
      invert: invert,
      coreInfo: coreInfo,
      currentPageIndex: currentPageIndex,
      setBackgroundPattern: (pattern) => setState(() {
        if (coreInfo.readOnly) return;
        coreInfo.backgroundPattern = pattern;
        stows.lastBackgroundPattern.value = pattern;
        autosaveAfterDelay();
      }),
      setLineHeight: (lineHeight) => setState(() {
        if (coreInfo.readOnly) return;
        coreInfo.lineHeight = lineHeight;
        stows.lastLineHeight.value = lineHeight;
        autosaveAfterDelay();
      }),
      setLineThickness: (lineThickness) => setState(() {
        if (coreInfo.readOnly) return;
        coreInfo.lineThickness = lineThickness;
        stows.lastLineThickness.value = lineThickness;
        autosaveAfterDelay();
      }),
      removeBackgroundImage: () => setState(() {
        if (coreInfo.readOnly) return;

        final page = coreInfo.pages[currentPageIndex];
        if (page.backgroundImage == null) return;
        page.images.add(page.backgroundImage!);
        page.backgroundImage = null;

        autosaveAfterDelay();
      }),
      redrawImage: () => setState(() {}),
      clearPage: () {
        clearPage(currentPageIndex);
      },
      clearAllPages: clearAllPages,
      redrawAndSave: () => setState(() {
        if (coreInfo.readOnly) return;
        autosaveAfterDelay();
      }),
      pickPhotos: _pickPhotos,
      importPdf: importPdf,
      canRasterPdf: Editor.canRasterPdf,
      getIsWatchingServer: () => _watchServerTimer?.isActive ?? false,
      setIsWatchingServer: (bool watch) {
        if (watch) {
          _watchServerTimer ??= Timer.periodic(
            const Duration(seconds: 5),
            (_) => _refreshCurrentNote(),
          );
          coreInfo.readOnlyBecauseWatchingServer |= !coreInfo.readOnly;
          if (!coreInfo.readOnly) setState(() => coreInfo.readOnly = true);
        } else {
          _watchServerTimer?.cancel();
          _watchServerTimer = null;
          if (coreInfo.readOnlyBecauseWatchingServer)
            setState(() {
              coreInfo.readOnly = false;
              coreInfo.readOnlyBecauseWatchingServer = false;
            });
        }
      },
    );
  }

  Widget pageBuilder(BuildContext context, int pageIndex) {
    final page = coreInfo.pages[pageIndex];
    final currentStroke = Pen.currentStroke?.pageIndex == pageIndex
        ? Pen.currentStroke
        : null;
    return Canvas(
      path: coreInfo.filePath,
      page: page,
      pageIndex: pageIndex,
      textEditing: currentTool == Tool.textEditing,
      coreInfo: coreInfo,
      currentStroke: currentStroke,
      currentStrokeDetectedShape:
          currentTool is ShapePen && currentStroke != null
          ? ShapePen.detectedShape
          : null,
      currentSelection: () {
        if (currentTool is! Select) return null;
        final selectResult = (currentTool as Select).selectResult;
        if (selectResult.pageIndex != pageIndex) return null;
        return selectResult;
      }(),
      setAsBackground: (EditorImage image) {
        if (page.backgroundImage != null) {
          // restore previous background image as normal image
          page.images.add(page.backgroundImage!);
        }
        page.images.remove(image);
        page.backgroundImage = image;

        CanvasImage.activeListener
            .notifyListenersPlease(); // un-select active image

        autosaveAfterDelay();
        setState(() {});
      },
      currentTool: currentTool,
      currentScale: _transformationController.value.approxScale,
    );
  }

  Widget pageBuilderForScreenshot(
    BuildContext context, {
    required int pageIndex,
    double? previewHeight,
  }) {
    final page = coreInfo.pages[pageIndex];
    previewHeight ??= page.previewHeight(lineHeight: coreInfo.lineHeight);
    return CanvasPreview(
      pageIndex: pageIndex,
      height: previewHeight,
      coreInfo: coreInfo,
      highQuality: true,
    );
  }

  Widget pageManager(BuildContext context) {
    return EditorPageManager(
      coreInfo: coreInfo,
      currentPageIndex: currentPageIndex,
      redrawAndSave: () => setState(() {
        if (coreInfo.readOnly) return;
        autosaveAfterDelay();
      }),
      insertPageAfter: insertPageAfter,
      duplicatePage: (int pageIndex) => setState(() {
        if (coreInfo.readOnly) return;
        final page = coreInfo.pages[pageIndex];
        final newPage = page.copyWith(
          strokes: page.strokes
              .map((stroke) => stroke.copy()..pageIndex += 1)
              .toList(),
          images: page.images
              .map((image) => image.copy()..pageIndex += 1)
              .toList(),
          quill: QuillStruct(
            controller: flutter_quill.QuillController(
              document: flutter_quill.Document.fromDelta(
                page.quill.controller.document.toDelta(),
              ),
              selection: const TextSelection.collapsed(offset: 0),
            ),
            focusNode: FocusNode(debugLabel: 'Quill Focus Node'),
          ),
          backgroundImage: page.backgroundImage?.copy()?..pageIndex += 1,
        );
        coreInfo.pages.insert(pageIndex + 1, newPage);
        listenToQuillChanges(newPage.quill, pageIndex + 1);
        history.recordChange(
          EditorHistoryItem(
            type: .insertPage,
            pageIndex: pageIndex,
            strokes: const [],
            images: const [],
            page: newPage,
          ),
        );
        autosaveAfterDelay();
      }),
      clearPage: clearPage,
      deletePage: (int pageIndex) => setState(() {
        if (coreInfo.readOnly) return;
        final page = coreInfo.pages.removeAt(pageIndex);
        createPage(pageIndex - 1);
        history.recordChange(
          EditorHistoryItem(
            type: .deletePage,
            pageIndex: pageIndex,
            strokes: const [],
            images: const [],
            page: page,
          ),
        );
        autosaveAfterDelay();
      }),
      transformationController: _transformationController,
    );
  }

  void insertPageAfter(int pageIndex) => setState(() {
    if (coreInfo.readOnly) return;
    final page = EditorPage();
    coreInfo.pages.insert(pageIndex + 1, page);
    listenToQuillChanges(page.quill, pageIndex + 1);
    history.recordChange(
      EditorHistoryItem(
        type: .insertPage,
        pageIndex: pageIndex + 1,
        strokes: const [],
        images: const [],
        page: page,
      ),
    );
    autosaveAfterDelay();
  });

  void clearPage(int pageIndex) {
    if (coreInfo.readOnly) return;
    final page = coreInfo.pages[pageIndex];
    setState(() {
      final removedStrokes = page.strokes.toList();
      final removedImages = page.images.toList();
      page.strokes.clear();
      page.images.clear();
      removeExcessPages();
      history.recordChange(
        EditorHistoryItem(
          type: .erase,
          pageIndex: pageIndex,
          strokes: removedStrokes,
          images: removedImages,
        ),
      );
      autosaveAfterDelay();
    });
  }

  void clearAllPages() {
    if (coreInfo.readOnly) return;
    setState(() {
      final removedStrokes = <Stroke>[];
      final removedImages = <EditorImage>[];
      for (final page in coreInfo.pages) {
        removedStrokes.addAll(page.strokes);
        removedImages.addAll(page.images);
        page.strokes.clear();
        page.images.clear();
      }
      removeExcessPages();
      history.recordChange(
        EditorHistoryItem(
          type: .erase,
          pageIndex: 0,
          strokes: removedStrokes,
          images: removedImages,
        ),
      );
    });
    autosaveAfterDelay();
  }

  Future askUserToDisableReadOnly() async {
    final disableReadOnly =
        await showDialog(
          context: context,
          builder: (context) => AdaptiveAlertDialog(
            title: Text(t.editor.newerFileFormat.title),
            content: Text(t.editor.newerFileFormat.subtitle),
            actions: [
              CupertinoDialogAction(
                child: Text(t.common.cancel),
                onPressed: () => Navigator.pop(context, false),
              ),
              CupertinoDialogAction(
                child: Text(t.editor.newerFileFormat.allowEditing),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;
    if (!disableReadOnly) return;

    setState(() {
      coreInfo.readOnly = false;
    });
  }

  late int _lastCurrentPageIndex = coreInfo.initialPageIndex ?? 0;

  /// The index of the page that is currently centered on screen.
  int get currentPageIndex {
    if (!mounted) return _lastCurrentPageIndex;

    final screenWidth = MediaQuery.sizeOf(context).width;

    return _lastCurrentPageIndex = getPageIndexFromScrollPosition(
      scrollY: -scrollY,
      screenWidth: screenWidth,
      pages: coreInfo.pages,
    );
  }

  @visibleForTesting
  static int getPageIndexFromScrollPosition({
    required double scrollY,
    required double screenWidth,
    required List<EditorPage> pages,
  }) {
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final bottomOfPage = CanvasGestureDetector.getTopOfPage(
        pageIndex: pageIndex + 1, // top of next page
        pages: pages,
        screenWidth: screenWidth,
      );

      if (scrollY < bottomOfPage) {
        return pageIndex;
      }
    }
    // below the last page
    return pages.length - 1;
  }

  Widget _buildTerminateButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: FilledButton.icon(
        onPressed: () => _confirmTerminateSession(context),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red.withValues(alpha: 0.1),
          foregroundColor: Colors.red,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const StadiumBorder(),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.2)),
        ),
        icon: const Icon(Icons.cancel_outlined, size: 20),
        label: const Text(
          'Terminate',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  void _confirmTerminateSession(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Terminate Session?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to end this session? Any unsaved changes will be permanently lost.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Keep Writing',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        // 1. Cancel in DB if we have a consultation ID
                        final consultationId =
                            widget.consultationId ??
                            SessionManager().consultationId;
                        if (consultationId != null) {
                          try {
                            await SupabaseDashboardService.cancelAppointment(
                              consultationId,
                            );
                          } catch (e) {
                            log.warning(
                              'Failed to cancel appointment in DB: $e',
                            );
                          }
                        }

                        // 2. Delete the session file/folder
                        try {
                          final relativePath = coreInfo.filePath;
                          log.info(
                            'Terminating session. File path: $relativePath',
                          );

                          final parentDir = p.dirname(relativePath);
                          final parentDirName = p.basename(parentDir);

                          // Check if parent dir is like "session_123"
                          if (parentDirName.startsWith('session_')) {
                            // Delete the entire session directory
                            log.info('Deleting session directory: $parentDir');
                            await FileManager.deleteDirectory(parentDir);
                          } else {
                            // Just delete the file
                            log.info('Deleting session file: $relativePath');
                            await FileManager.deleteFile(relativePath);
                          }
                        } catch (e) {
                          log.warning(
                            'Failed to delete terminated session file: $e',
                          );
                        }

                        // 3. Terminate local state
                        SessionManager().terminate();

                        // 4. Close dialog
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }

                        // 5. Navigate away
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) {
                            if (Navigator.of(context).canPop()) {
                              context.pop();
                            } else {
                              context.go(HomeRoutes.getRoute(0));
                            }
                          }
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Terminate',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearWhiteboardButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: FilledButton.icon(
        onPressed: () => _confirmClearWhiteboard(context),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          foregroundColor: Colors.orange.shade800,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const StadiumBorder(),
          side: BorderSide(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        icon: const Icon(Icons.delete_sweep_outlined, size: 20),
        label: const Text(
          'Clear',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  void _confirmClearWhiteboard(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.orange,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Clear Whiteboard?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This will erase all drawings and images on the whiteboard. This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        t.common.cancel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _handleClearWithAnimation();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleClearWithAnimation() {
    setState(() {
      _isClearing = true;
    });

    // Clear actual data halfway through the "wind blow"
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        clearAllPages();
        setState(() {});
      }
    });

    // Reset after animation finishes
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    unawaited(_cleanUpAsync());

    DynamicMaterialApp.removeFullscreenListener(_setState);

    _delayedSaveTimer?.cancel();
    _watchServerTimer?.cancel();
    _lastSeenPointerCountTimer?.cancel();

    _removeKeybindings();

    // manually save pen properties since the listeners don't fire if a property is changed
    stows.lastFountainPenOptions.notifyListeners();
    stows.lastBallpointPenOptions.notifyListeners();
    stows.lastHighlighterOptions.notifyListeners();
    stows.lastPencilOptions.notifyListeners();
    stows.lastShapePenOptions.notifyListeners();

    super.dispose();
  }

  Future<void> _cleanUpAsync() async {
    try {
      if (_renameTimer?.isActive ?? false) {
        _renameTimer!.cancel();
        await _renameFileNow();
        filenameTextEditingController.dispose();
      }
      await saveToFile();
    } finally {
      coreInfo.dispose();
    }
  }

  void _showReportDialog(
    BuildContext context,
    Map<String, dynamic> reportData,
    List<Uint8List> imageBytesList, {
    VoidCallback? onRegenerate,
  }) {
    final reportViewKey = GlobalKey();

    showDialog(
      context: context,

      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [
                      const Color(0xFF1E1E1E), // Dark Dialog
                      const Color(0xFF2C2C2C), // Slightly lighter
                    ]
                  : [
                      const Color(0xFFF5F7FA), // Very light grey
                      const Color(0xFFE4EBF5), // Subtle blue-grey
                    ],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Use orientation from MediaQuery to avoid flipping layout when keyboard appears
              final isPortrait =
                  MediaQuery.of(context).orientation == Orientation.portrait;

              // Common Image Preview Widget
              Widget buildImagePreview() => ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: imageBytesList.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        imageBytesList[index],
                        gaplessPlayback: true,
                        cacheWidth: 1024,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              );

              // Common Report View Widget
              Widget buildReportView() => ReportView(
                key: reportViewKey,
                reportData: reportData,
                onRegenerate: onRegenerate,
                onVerify: () async {
                  try {
                    // Convert to Markdown
                    final sb = StringBuffer();
                    sb.writeln('# 📋 Clinical Assessment Report');
                    sb.writeln();
                    sb.writeln('---');
                    sb.writeln();
                    if (_patientName != null) {
                      sb.writeln('**👤 Patient:** $_patientName');
                    }
                    sb.writeln(
                      '**📅 Date:** ${DateFormat.yMMMd().format(DateTime.now())}',
                    );
                    if (_doctorName != null) {
                      sb.writeln('**👨‍⚕️ Doctor:** $_doctorName');
                    }
                    sb.writeln();
                    sb.writeln('---');
                    sb.writeln();

                    sb.writeln('### 🕒 Current Symptoms (HPI)');
                    sb.writeln(
                      reportData['current_symptoms'] ?? 'Not mentioned',
                    );
                    sb.writeln();

                    sb.writeln('### 👤 Premorbid Personality');
                    sb.writeln(
                      reportData['premorbid_personality'] ?? 'Not mentioned',
                    );
                    sb.writeln();

                    sb.writeln('### 📜 Past History');
                    sb.writeln(reportData['past_history'] ?? 'Not mentioned');
                    sb.writeln();

                    sb.writeln('### 👨‍👩‍👧‍👦 Family History');
                    sb.writeln(reportData['family_history'] ?? 'Not mentioned');
                    sb.writeln();

                    sb.writeln('### 🏥 Mental Status Examination');
                    final mse = reportData['mental_status_examination'];
                    if (mse is Map) {
                      mse.forEach((key, value) {
                        final formattedKey = key
                            .toString()
                            .replaceAll('_', ' ')
                            .toUpperCase();
                        sb.writeln('- **$formattedKey:** $value');
                      });
                    } else if (mse is String) {
                      sb.writeln(mse);
                    } else {
                      sb.writeln('*Not mentioned*');
                    }
                    sb.writeln();

                    sb.writeln('### 🏁 Diagnosis');
                    sb.writeln(
                      '**${reportData['provided_diagnosis'] ?? 'Not mentioned'}**',
                    );
                    sb.writeln();

                    sb.writeln('---');
                    sb.writeln();
                    sb.writeln('### 💊 Prescribed Medications');
                    final meds = reportData['medications'] as List?;
                    if (meds != null && meds.isNotEmpty) {
                      sb.writeln(
                        '| Medication | Frequency | Duration | Remarks |',
                      );
                      sb.writeln('| :--- | :--- | :--- | :--- |');
                      for (final m in meds) {
                        if (m is Map) {
                          final name = m['name'] ?? 'N/A';
                          final freq = m['frequency'] ?? 'N/A';
                          final duration = m['duration'] ?? 'N/A';
                          final remarks = m['remarks'] ?? '';
                          sb.writeln(
                            '| **$name** | $freq | $duration | $remarks |',
                          );
                        }
                      }
                    } else {
                      sb.writeln('*None prescribed or not mentioned.*');
                    }
                    sb.writeln();
                    sb.writeln('---');
                    sb.writeln();
                    sb.write(
                      '> *This report was automatically generated by Synapse AI based on clinical notes.*',
                    );

                    // Determine path
                    String filePath = coreInfo.filePath;
                    String? patientId;

                    // Ensure we have a valid absolute path
                    // If the path is just '/patients/...' on mobile, it's likely relative to the app sandbox
                    if (!File(filePath).isAbsolute ||
                        (Platform.isAndroid || Platform.isIOS) &&
                            filePath.startsWith('/patients')) {
                      if (filePath.startsWith('/')) {
                        filePath = filePath.substring(1);
                      }

                      // Attempt to extract patient ID from path "patients/{id}/..."
                      final parts = filePath.split('/');
                      if (parts.length >= 2 && parts[0] == 'patients') {
                        patientId = parts[1];
                      }

                      // Use FileManager.documentsDirectory to ensure we are in the 'Saber' subfolder
                      filePath = p.join(
                        FileManager.documentsDirectory,
                        filePath,
                      );
                    }

                    // Submit to Supabase if we found a patient ID
                    if (patientId != null) {
                      try {
                        log.info(
                          'Saving report with sourceDocumentPath: ${coreInfo.filePath}',
                        );
                        await SupabaseReportService.createReport(
                          patientId: patientId,
                          structuredData: reportData,
                          markdownContent: sb.toString(),
                          sourceDocumentPath: coreInfo.filePath,
                        );
                        log.info(
                          'Report saved to Supabase for patient $patientId',
                        );
                      } catch (dbError) {
                        log.severe('Failed to save report to DB', dbError);
                        // Don't block local file save if DB fails
                      }

                      // Send medications to Pharmacy (prescriptions table)
                      try {
                        final medications = reportData['medications'];
                        if (medications is List && medications.isNotEmpty) {
                          // Fetch patient name if possible for the pharmacy
                          String? patientName;
                          try {
                            final pData =
                                await SupabasePatientService.getPatient(
                                  patientId,
                                );
                            patientName = pData?.fullName;
                          } catch (e) {
                            // ignore
                          }

                          // Convert medications to List<Map<String, dynamic>>
                          final medsList = medications
                              .whereType<Map<String, dynamic>>()
                              .map((m) {
                                final newMap = Map<String, dynamic>.from(m);
                                // Map remarks to instructions for pharmacy compatibility
                                if (newMap.containsKey('remarks')) {
                                  newMap['instructions'] = newMap['remarks'];
                                }
                                return newMap;
                              })
                              .toList();

                          if (medsList.isNotEmpty) {
                            await SupabasePrescriptionService.createPrescription(
                              patientId: patientId,
                              consultationId: widget.consultationId,
                              medications: medsList,
                              patientName: patientName,
                            );
                            log.info('Prescriptions sent to pharmacy');
                          }
                        }
                      } catch (rxError) {
                        log.severe('Failed to send prescriptions', rxError);
                      }

                      // Mark consultation as completed
                      if (widget.consultationId != null) {
                        try {
                          await SupabaseDashboardService.completeConsultation(
                            widget.consultationId!,
                          );
                          log.info(
                            'Consultation ${widget.consultationId} marked as completed',
                          );
                        } catch (e) {
                          log.warning(
                            'Failed to mark consultation as completed: $e',
                          );
                        }
                      }
                    }

                    // Save report to file
                    final reportFileName =
                        'clinical_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.md';
                    final reportPath = p.join(
                      p.dirname(filePath),
                      reportFileName,
                    );

                    // Only try to write file if directory exists
                    if (await Directory(p.dirname(filePath)).exists()) {
                      await File(reportPath).writeAsString(sb.toString());

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report verified and saved!'),
                          ),
                        );
                        Navigator.pop(context); // Close dialog
                        if (widget.onVerify != null) {
                          widget.onVerify?.call();
                        } else {
                          // Production fallback: Terminate session and go to dashboard
                          SessionManager().terminate();
                          final targetContext =
                              App.rootNavigatorKey.currentContext ?? context;
                          if (targetContext.mounted) {
                            GoRouter.of(
                              targetContext,
                            ).go(HomeRoutes.getRoute(0));
                          }
                        }
                      }
                    } else {
                      log.warning(
                        'Cannot save report locally: Directory not found ${p.dirname(filePath)}',
                      );
                      // Still show success if DB save worked
                      if (context.mounted && patientId != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report saved to database!'),
                          ),
                        );
                        Navigator.pop(context);
                        if (widget.onVerify != null) {
                          widget.onVerify?.call();
                        } else {
                          // Production fallback: Terminate session and go to dashboard
                          SessionManager().terminate();
                          final targetContext =
                              App.rootNavigatorKey.currentContext ?? context;
                          if (targetContext.mounted) {
                            GoRouter.of(
                              targetContext,
                            ).go(HomeRoutes.getRoute(0));
                          }
                        }
                      }
                    }
                  } catch (e) {
                    log.severe('Error saving report', e);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save report: $e')),
                      );
                    }
                  }
                },
              );

              if (isPortrait) {
                return Column(
                  children: [
                    // Portrait: Top Image Preview (Flexible Height)
                    Expanded(
                      flex: 4, // 40% height for the note
                      child: buildImagePreview(),
                    ),

                    Expanded(
                      flex: 6, // 60% height for the report
                      child: buildReportView(),
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    // Landscape: Left Image Preview
                    if (imageBytesList.isNotEmpty)
                      Expanded(
                        flex: 4, // 40% width
                        child: buildImagePreview(),
                      ),

                    Expanded(
                      flex: 6, // 60% width for report
                      child: buildReportView(),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableIntakeOverlay(BoxConstraints constraints) {
    // Show placeholder card if no intake data
    if (_patientIntake == null) {
      return Draggable(
        feedback: Opacity(
          opacity: 0.5,
          child: Material(child: _buildEmptyIntakeCard()),
        ),
        childWhenDragging: Container(),
        onDragEnd: (details) {
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          if (box != null) {
            final localPos = box.globalToLocal(details.offset);
            setState(() {
              _intakeOverlayPosition = localPos;
            });
          }
        },
        child: _buildEmptyIntakeCard(),
      );
    }

    return Draggable(
      feedback: Opacity(
        opacity: 0.5,
        child: Material(
          child: IntakeOverlayCard(intake: _patientIntake!, isExpanded: false),
        ),
      ),
      childWhenDragging: Container(),
      onDragEnd: (details) {
        // Convert global position to local position relative to the stack
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final localPos = box.globalToLocal(details.offset);
          setState(() {
            _intakeOverlayPosition = localPos;
          });
        }
      },
      child: IntakeOverlayCard(
        intake: _patientIntake!,
        isExpanded: _isIntakeExpanded,
        onExpandChanged: (expanded) =>
            setState(() => _isIntakeExpanded = expanded),
        onClose: () => setState(() => _showIntakeOverlay = false),
        onEdit: _openIntakeFormEditor,
      ),
    );
  }

  Widget _buildIntakeButton(ColorScheme colorScheme, ThemeData theme) {
    return Tooltip(
      message: _patientIntake != null ? 'View Intake Form' : 'Fill Intake Form',
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.surface,
        child: InkWell(
          onTap: _patientIntake != null
              ? () => setState(() {
                  final newState = !_showIntakeOverlay;
                  if (newState) {
                    _showVitalsOverlay = false;
                    _showPreviousNotesOverlay = false;
                    _showMedicationHistoryOverlay = false;
                  }
                  _showIntakeOverlay = newState;
                  _intakeOverlayPosition = null;
                })
              : _openIntakeFormEditor,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              _patientIntake != null
                  ? Icons.assignment_ind_outlined
                  : Icons.assignment_outlined,
              size: 28,
              color: _patientIntake != null ? null : colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyIntakeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Intake Form',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _showIntakeOverlay = false),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'No intake form filled',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _openIntakeFormEditor,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Fill Form'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableVitalsOverlay(BoxConstraints constraints) {
    return Draggable(
      feedback: Opacity(
        opacity: 0.5,
        child: Material(
          child: VitalsOverlayCard(
            vitalsHistory: _vitalsHistory,
            isExpanded: false,
          ),
        ),
      ),
      childWhenDragging: Container(),
      onDragEnd: (details) {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final localPos = box.globalToLocal(details.offset);
          setState(() {
            _vitalsOverlayPosition = localPos;
          });
        }
      },
      child: VitalsOverlayCard(
        vitalsHistory: _vitalsHistory,
        isExpanded: _isVitalsExpanded,
        onExpandChanged: (expanded) =>
            setState(() => _isVitalsExpanded = expanded),
        onClose: () => setState(() => _showVitalsOverlay = false),
      ),
    );
  }

  Widget _buildVitalsButton(ColorScheme colorScheme, ThemeData theme) {
    return Tooltip(
      message: 'Show Vitals',
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.surface,
        child: InkWell(
          onTap: () {
            setState(() {
              final newState = !_showVitalsOverlay;
              if (newState) {
                _showIntakeOverlay = false;
                _showPreviousNotesOverlay = false;
                _showMedicationHistoryOverlay = false;
              }
              _showVitalsOverlay = newState;
              _vitalsOverlayPosition = null;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(
              Icons.monitor_heart_outlined,
              size: 28,
              color: Colors.pink,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _togglePreviousNotesOverlay() async {
    if (_showPreviousNotesOverlay) {
      setState(() => _showPreviousNotesOverlay = false);
      return;
    }

    // Close others
    setState(() {
      _showIntakeOverlay = false;
      _showVitalsOverlay = false;
      _showMedicationHistoryOverlay = false;
    });

    if (_previousNotes.isEmpty && _patientId != null) {
      setState(() {
        _isLoadingPreviousNotes = true;
      });

      try {
        // Extract session number from current file path if possible
        // Expected format: .../session_X_notes.sbn
        int? currentSessionNum;
        final filename = coreInfo.filePath.split('/').last;
        final match = RegExp(r'session_(\d+)_notes').firstMatch(filename);
        if (match != null) {
          currentSessionNum = int.tryParse(match.group(1)!);
        }

        final notes = await SupabaseConsultationService.getPreviousSessionNotes(
          _patientId!,
          excludeSessionNumber: currentSessionNum,
        );

        log.info(
          'Received ${notes.length} previous notes (excluded session $currentSessionNum)',
        );
        setState(() {
          _previousNotes = notes;
          _isLoadingPreviousNotes = false;
          _showPreviousNotesOverlay = notes.isNotEmpty;
          _previousNotesOverlayPosition = null; // Use default
        });

        if (notes.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No previous session notes found')),
          );
        }
      } catch (e) {
        log.warning('Failed to load previous notes: $e');
        setState(() => _isLoadingPreviousNotes = false);
      }
    } else {
      if (_previousNotes.isNotEmpty) {
        setState(() {
          _showPreviousNotesOverlay = true;
          _previousNotesOverlayPosition = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No previous session notes found')),
        );
      }
    }
  }

  Widget _buildDraggablePreviousNotesOverlay(BoxConstraints constraints) {
    if (_previousNotes.isEmpty && !_isLoadingPreviousNotes) {
      return const SizedBox.shrink();
    }

    return Draggable(
      feedback: Opacity(
        opacity: 0.5,
        child: Material(
          child: PreviousNotesOverlayCard(
            notes: _previousNotes,
            onClose: () {},
          ),
        ),
      ),
      childWhenDragging: Container(),
      onDragEnd: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final localPos = box.globalToLocal(details.offset);
          setState(() {
            _previousNotesOverlayPosition = localPos;
          });
        }
      },
      child: PreviousNotesOverlayCard(
        notes: _previousNotes,
        onClose: () => setState(() => _showPreviousNotesOverlay = false),
      ),
    );
  }

  Widget _buildPreviousNotesButton(ColorScheme colorScheme, ThemeData theme) {
    return Tooltip(
      message: 'Previous Session Notes',
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.surface,
        child: InkWell(
          onTap: _togglePreviousNotesOverlay,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _isLoadingPreviousNotes
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.history_edu, size: 28, color: Colors.purple),
          ),
        ),
      ),
    );
  }

  void _toggleMedicationHistoryOverlay() {
    setState(() {
      final newState = !_showMedicationHistoryOverlay;
      if (newState) {
        _showIntakeOverlay = false;
        _showVitalsOverlay = false;
        _showPreviousNotesOverlay = false;
      }
      _showMedicationHistoryOverlay = newState;
      _medicationHistoryOverlayPosition = null; // Default to column
    });
  }

  Widget _buildDraggableMedicationHistoryOverlay(BoxConstraints constraints) {
    return Draggable(
      feedback: Opacity(
        opacity: 0.5,
        child: Material(
          child: MedicationHistoryOverlay(
            patientId: _patientId!,
            onClose: () {},
          ),
        ),
      ),
      childWhenDragging: Container(),
      onDragEnd: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final localPos = box.globalToLocal(details.offset);
          setState(() {
            _medicationHistoryOverlayPosition = localPos;
          });
        }
      },
      child: MedicationHistoryOverlay(
        patientId: _patientId!,
        onClose: () => setState(() => _showMedicationHistoryOverlay = false),
      ),
    );
  }

  Widget _buildMedicationHistoryButton(
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Tooltip(
      message: 'Medication History',
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.surface,
        child: InkWell(
          onTap: _toggleMedicationHistoryOverlay,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(
              Icons.medication_outlined,
              size: 28,
              color: Colors.teal,
            ),
          ),
        ),
      ),
    );
  }
}

class WindPainter extends CustomPainter {
  final double progress;
  final Color color;

  WindPainter({required this.progress, required this.color});

  @override
  void paint(ui.Canvas canvas, Size size) {
    final paint = ui.Paint()
      ..color = color.withOpacity(0.3 * (1.0 - progress))
      ..strokeWidth = 3.0
      ..style = ui.PaintingStyle.stroke;

    final random = math.Random(42);
    for (int i = 0; i < 40; i++) {
      final y = random.nextDouble() * size.height;
      // Start X moves across the screen based on progress
      final speedFactor = random.nextDouble() * 2 + 1;
      final startX =
          (random.nextDouble() * size.width) +
          (progress * size.width * speedFactor) -
          size.width;
      final length = random.nextDouble() * 300 + 100;

      canvas.drawLine(
        ui.Offset(startX, y),
        ui.Offset(startX + length, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WindPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
