import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saber/components/intake_form/handwriting_field.dart';
import 'package:saber/components/intake_form/intake_photo_capture_screen.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/api/intake_form_extractor.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/models/psychiatric_intake.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/data/supabase/supabase_intake_service.dart';
import 'package:saber/design_system/colors.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

/// Psychiatric Intake Form Widget
/// Matches Dr. Monisha Dass's clinical intake form layout
///
/// This form is displayed for new patients with no previous sessions
/// to gather comprehensive psychiatric evaluation data
class PsychiatricIntakeForm extends StatefulWidget {
  const PsychiatricIntakeForm({
    super.key,
    required this.patient,
    this.existingIntake,
    required this.onSave,
    this.onCancel,
    this.doctorName,
    this.readOnly = false,
  });

  final Patient patient;
  final PsychiatricIntake? existingIntake;
  final Function(PsychiatricIntake) onSave;
  final VoidCallback? onCancel;
  final String? doctorName;
  final bool readOnly;

  @override
  State<PsychiatricIntakeForm> createState() => _PsychiatricIntakeFormState();
}

class _PsychiatricIntakeFormState extends State<PsychiatricIntakeForm> {
  late final ScrollController _scrollController;
  var _isSaving = false;
  var _isImporting = false;
  var _wasImportedFromPhoto = false;
  late bool _isEditing;

  // Header Fields
  DateTime? _dateOfExamination = DateTime.now();
  final _residenceController = TextEditingController();
  final _durationOfIllnessController = TextEditingController();
  final _referredByController = TextEditingController();
  final _precipitatingFactorController = TextEditingController();
  final _registrationNumberController = TextEditingController();

  // Anxiety & Related Symptoms
  var _anxietyWorry = false;
  var _panic = false;
  var _restless = false;
  var _palpitationsTremors = false;
  var _phobia = false;
  var _obsessions = false;
  var _compulsions = false;
  var _hypochondriacal = false;
  var _fitsHystEpileptic = false;
  var _possessionState = false;

  // Somatic Symptoms
  var _somaticHeadache = false;
  var _somaticBodyache = false;
  var _somaticAbdominal = false;

  // Substance Use
  var _alcoholDrugs = false;
  var _tobaccoSmoking = false;
  String? _substanceUse;

  // Sexual Dysfunction
  var _decreasedLibido = false;
  var _increasedLibido = false;
  var _erectileDysfunction = false;
  var _prematureEjaculation = false;
  var _retardedEjaculation = false;
  var _worryMasturbationNE = false;
  final _sexualDysfunctionOtherController = TextEditingController();

  // Psychotic Symptoms
  var _ideasDelPersecution = false;
  var _ideasDelReference = false;
  var _otherDelusions = false;
  var _firstRankSymptoms = false;
  var _hallucinationsAuditory = false;
  var _hallucinationsVisual = false;
  var _incoherence = false;
  var _mutteringToSelf = false;
  var _inappropriateSmiling = false;
  var _inappropriateWeeping = false;
  var _abusing = false;
  var _violence = false;
  var _withdrawalInertia = false;

  // Manic Symptoms
  var _irritableElated = false;
  var _grandiose = false;
  var _overtalkative = false;
  var _flightOfIdeas = false;
  var _overactivePMA = false;
  var _extravagant = false;

  // Depressive Symptoms
  var _sadIntermittent = false;
  var _sadPersistent = false;
  var _anhedoniaInertia = false;
  var _diurnalChange = false;
  var _weightLoss = false;
  var _weightGain = false;
  String? _insomniaType;
  var _hypersomnia = false;
  var _pmrPma = false;
  var _fatigue = false;
  var _worthlessnessGuilt = false;
  var _decreasedThinkingConcentration = false;
  var _indecisive = false;
  var _suicidalThoughts = false;
  var _suicidalPlans = false;
  var _suicidalAttempts = false;

  // Cognitive Symptoms
  var _disorientationTime = false;
  var _disorientationPlace = false;
  var _disorientationPerson = false;
  String? _forgetfulness;
  var _aphasiaApraxiaAgnosia = false;
  var _decreasedIntelligence = false;
  var _perseveration = false;
  var _losingPath = false;
  var _disinhibition = false;
  var _incontinenceUrine = false;
  var _incontinenceStools = false;
  var _emotionalLability = false;

  // Additional Information
  final _medicalIllnessesController = TextEditingController();
  final _stressesController = TextEditingController();
  final _ongoingTreatmentController = TextEditingController();
  final _otherSymptomsController = TextEditingController();
  final _clinicalNotesController = TextEditingController();
  final _provisionalDiagnosisController = TextEditingController();

  // Handwriting Controllers
  late final SignatureController _medicalIllnessesScribble;
  late final SignatureController _stressesScribble;
  late final SignatureController _ongoingTreatmentScribble;
  late final SignatureController _otherSymptomsScribble;
  late final SignatureController _clinicalNotesScribble;
  late final SignatureController _provisionalDiagnosisScribble;
  late final SignatureController _somaticOtherScribble;

  // Existing Handwriting URLs
  String? _medicalIllnessesImageUrl;
  String? _stressesImageUrl;
  String? _ongoingTreatmentImageUrl;
  String? _otherSymptomsImageUrl;
  String? _clinicalNotesImageUrl;
  String? _provisionalDiagnosisImageUrl;
  String? _somaticOtherImageUrl;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Initialize Signature Controllers
    _medicalIllnessesScribble = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _stressesScribble = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _ongoingTreatmentScribble = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _otherSymptomsScribble = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _clinicalNotesScribble = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _provisionalDiagnosisScribble = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _somaticOtherScribble = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    // Start in edit mode if creating new intake or not in readOnly mode
    // Start in view mode if readOnly and viewing existing intake
    _isEditing = !widget.readOnly || widget.existingIntake == null;

    // Pre-fill residence from patient data if available
    if (widget.patient.address != null && widget.patient.address!.isNotEmpty) {
      _residenceController.text = widget.patient.address!;
    }

    // Pre-fill referred by from patient data if available
    if (widget.patient.referencedBy != null &&
        widget.patient.referencedBy!.isNotEmpty) {
      _referredByController.text = widget.patient.referencedBy!;
    }

    if (widget.existingIntake != null) {
      _loadExistingIntake(widget.existingIntake!);
    }
  }

  void _loadExistingIntake(PsychiatricIntake intake) {
    _dateOfExamination = intake.dateOfExamination;
    _residenceController.text = intake.residence ?? '';
    _durationOfIllnessController.text = intake.durationOfIllness ?? '';
    _referredByController.text = intake.referredBy ?? '';
    _precipitatingFactorController.text = intake.precipitatingFactor ?? '';
    _registrationNumberController.text = intake.registrationNumber ?? '';

    _anxietyWorry = intake.anxietyWorry;
    _panic = intake.panic;
    _restless = intake.restless;
    _palpitationsTremors = intake.palpitationsTremors;
    _phobia = intake.phobia;
    _obsessions = intake.obsessions;
    _compulsions = intake.compulsions;
    _hypochondriacal = intake.hypochondriacal;
    _fitsHystEpileptic = intake.fitsHystEpileptic;
    _possessionState = intake.possessionState;

    _somaticHeadache = intake.somaticHeadache;
    _somaticBodyache = intake.somaticBodyache;
    _somaticAbdominal = intake.somaticAbdominal;

    _alcoholDrugs = intake.alcoholDrugs;
    _tobaccoSmoking = intake.tobaccoSmoking;
    _substanceUse = intake.substanceUse;

    _decreasedLibido = intake.decreasedLibido;
    _increasedLibido = intake.increasedLibido;
    _erectileDysfunction = intake.erectileDysfunction;
    _prematureEjaculation = intake.prematureEjaculation;
    _retardedEjaculation = intake.retardedEjaculation;
    _worryMasturbationNE = intake.worryMasturbationNE;
    _sexualDysfunctionOtherController.text =
        intake.sexualDysfunctionOther ?? '';

    _ideasDelPersecution = intake.ideasDelPersecution;
    _ideasDelReference = intake.ideasDelReference;
    _otherDelusions = intake.otherDelusions;
    _firstRankSymptoms = intake.firstRankSymptoms;
    _hallucinationsAuditory = intake.hallucinationsAuditory;
    _hallucinationsVisual = intake.hallucinationsVisual;
    _incoherence = intake.incoherence;
    _mutteringToSelf = intake.mutteringToSelf;
    _inappropriateSmiling = intake.inappropriateSmiling;
    _inappropriateWeeping = intake.inappropriateWeeping;
    _abusing = intake.abusing;
    _violence = intake.violence;
    _withdrawalInertia = intake.withdrawalInertia;

    _irritableElated = intake.irritableElated;
    _grandiose = intake.grandiose;
    _overtalkative = intake.overtalkative;
    _flightOfIdeas = intake.flightOfIdeas;
    _overactivePMA = intake.overactivePMA;
    _extravagant = intake.extravagant;

    _sadIntermittent = intake.sadIntermittent;
    _sadPersistent = intake.sadPersistent;
    _anhedoniaInertia = intake.anhedoniaInertia;
    _diurnalChange = intake.diurnalChange;
    _weightLoss = intake.weightLoss;
    _weightGain = intake.weightGain;
    _insomniaType = intake.insomniaType;
    _hypersomnia = intake.hypersomnia;
    _pmrPma = intake.pmrPma;
    _fatigue = intake.fatigue;
    _worthlessnessGuilt = intake.worthlessnessGuilt;
    _decreasedThinkingConcentration = intake.decreasedThinkingConcentration;
    _indecisive = intake.indecisive;
    _suicidalThoughts = intake.suicidalThoughts;
    _suicidalPlans = intake.suicidalPlans;
    _suicidalAttempts = intake.suicidalAttempts;

    _disorientationTime = intake.disorientationTime;
    _disorientationPlace = intake.disorientationPlace;
    _disorientationPerson = intake.disorientationPerson;
    _forgetfulness = intake.forgetfulness;
    _aphasiaApraxiaAgnosia = intake.aphasiaApraxiaAgnosia;
    _decreasedIntelligence = intake.decreasedIntelligence;
    _perseveration = intake.perseveration;
    _losingPath = intake.losingPath;
    _disinhibition = intake.disinhibition;
    _incontinenceUrine = intake.incontinenceUrine;
    _incontinenceStools = intake.incontinenceStools;
    _emotionalLability = intake.emotionalLability;

    _medicalIllnessesController.text = intake.medicalIllnesses ?? '';
    _stressesController.text = intake.stresses ?? '';
    _ongoingTreatmentController.text = intake.ongoingTreatment ?? '';
    _otherSymptomsController.text = intake.otherSymptoms ?? '';
    _clinicalNotesController.text = intake.clinicalNotes ?? '';
    _provisionalDiagnosisController.text = intake.provisionalDiagnosis ?? '';

    // Load handwriting URLs
    _medicalIllnessesImageUrl = intake.medicalIllnessesHandwriting;
    _stressesImageUrl = intake.stressesHandwriting;
    _ongoingTreatmentImageUrl = intake.ongoingTreatmentHandwriting;
    _otherSymptomsImageUrl = intake.otherSymptomsHandwriting;
    _clinicalNotesImageUrl = intake.clinicalNotesHandwriting;
    _provisionalDiagnosisImageUrl = intake.provisionalDiagnosisHandwriting;
    _somaticOtherImageUrl = intake.somaticOtherHandwriting;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _residenceController.dispose();
    _durationOfIllnessController.dispose();
    _referredByController.dispose();
    _precipitatingFactorController.dispose();
    _registrationNumberController.dispose();
    _sexualDysfunctionOtherController.dispose();
    _medicalIllnessesController.dispose();
    _stressesController.dispose();
    _ongoingTreatmentController.dispose();
    _otherSymptomsController.dispose();
    _clinicalNotesController.dispose();
    _provisionalDiagnosisController.dispose();

    _medicalIllnessesScribble.dispose();
    _stressesScribble.dispose();
    _ongoingTreatmentScribble.dispose();
    _otherSymptomsScribble.dispose();
    _clinicalNotesScribble.dispose();
    _provisionalDiagnosisScribble.dispose();
    _somaticOtherScribble.dispose();
    super.dispose();
  }

  PsychiatricIntake _buildIntake() {
    final id = widget.existingIntake?.id ?? const Uuid().v4();
    final currentUserId = supabase.auth.currentUser?.id;

    return PsychiatricIntake(
      id: id,
      patientId: widget.patient.id,
      createdAt: widget.existingIntake?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      caseNumber: widget.existingIntake?.caseNumber,
      registrationNumber: _registrationNumberController.text.isEmpty
          ? null
          : _registrationNumberController.text,
      dateOfExamination: _dateOfExamination,
      residence: _residenceController.text.isEmpty
          ? null
          : _residenceController.text,
      durationOfIllness: _durationOfIllnessController.text.isEmpty
          ? null
          : _durationOfIllnessController.text,
      referredBy: _referredByController.text.isEmpty
          ? null
          : _referredByController.text,
      precipitatingFactor: _precipitatingFactorController.text.isEmpty
          ? null
          : _precipitatingFactorController.text,
      anxietyWorry: _anxietyWorry,
      panic: _panic,
      restless: _restless,
      palpitationsTremors: _palpitationsTremors,
      phobia: _phobia,
      obsessions: _obsessions,
      compulsions: _compulsions,
      hypochondriacal: _hypochondriacal,
      fitsHystEpileptic: _fitsHystEpileptic,
      possessionState: _possessionState,
      somaticHeadache: _somaticHeadache,
      somaticBodyache: _somaticBodyache,
      somaticAbdominal: _somaticAbdominal,
      somaticOther: null,
      substanceUse: _substanceUse,
      alcoholDrugs: _alcoholDrugs,
      tobaccoSmoking: _tobaccoSmoking,
      decreasedLibido: _decreasedLibido,
      increasedLibido: _increasedLibido,
      erectileDysfunction: _erectileDysfunction,
      prematureEjaculation: _prematureEjaculation,
      retardedEjaculation: _retardedEjaculation,
      worryMasturbationNE: _worryMasturbationNE,
      sexualDysfunctionOther: _sexualDysfunctionOtherController.text.isEmpty
          ? null
          : _sexualDysfunctionOtherController.text,
      ideasDelPersecution: _ideasDelPersecution,
      ideasDelReference: _ideasDelReference,
      otherDelusions: _otherDelusions,
      firstRankSymptoms: _firstRankSymptoms,
      hallucinationsAuditory: _hallucinationsAuditory,
      hallucinationsVisual: _hallucinationsVisual,
      incoherence: _incoherence,
      mutteringToSelf: _mutteringToSelf,
      inappropriateSmiling: _inappropriateSmiling,
      inappropriateWeeping: _inappropriateWeeping,
      abusing: _abusing,
      violence: _violence,
      withdrawalInertia: _withdrawalInertia,
      irritableElated: _irritableElated,
      grandiose: _grandiose,
      overtalkative: _overtalkative,
      flightOfIdeas: _flightOfIdeas,
      overactivePMA: _overactivePMA,
      extravagant: _extravagant,
      sadIntermittent: _sadIntermittent,
      sadPersistent: _sadPersistent,
      anhedoniaInertia: _anhedoniaInertia,
      diurnalChange: _diurnalChange,
      weightLoss: _weightLoss,
      weightGain: _weightGain,
      insomniaType: _insomniaType,
      hypersomnia: _hypersomnia,
      pmrPma: _pmrPma,
      fatigue: _fatigue,
      worthlessnessGuilt: _worthlessnessGuilt,
      decreasedThinkingConcentration: _decreasedThinkingConcentration,
      indecisive: _indecisive,
      suicidalThoughts: _suicidalThoughts,
      suicidalPlans: _suicidalPlans,
      suicidalAttempts: _suicidalAttempts,
      disorientationTime: _disorientationTime,
      disorientationPlace: _disorientationPlace,
      disorientationPerson: _disorientationPerson,
      forgetfulness: _forgetfulness,
      aphasiaApraxiaAgnosia: _aphasiaApraxiaAgnosia,
      decreasedIntelligence: _decreasedIntelligence,
      perseveration: _perseveration,
      losingPath: _losingPath,
      disinhibition: _disinhibition,
      incontinenceUrine: _incontinenceUrine,
      incontinenceStools: _incontinenceStools,
      emotionalLability: _emotionalLability,
      medicalIllnesses: _medicalIllnessesController.text.isEmpty
          ? null
          : _medicalIllnessesController.text,
      stresses: _stressesController.text.isEmpty
          ? null
          : _stressesController.text,
      ongoingTreatment: _ongoingTreatmentController.text.isEmpty
          ? null
          : _ongoingTreatmentController.text,
      otherSymptoms: _otherSymptomsController.text.isEmpty
          ? null
          : _otherSymptomsController.text,
      clinicalNotes: _clinicalNotesController.text.isEmpty
          ? null
          : _clinicalNotesController.text,
      provisionalDiagnosis: _provisionalDiagnosisController.text.isEmpty
          ? null
          : _provisionalDiagnosisController.text,
      // Import metadata
      importedFromPhoto: _wasImportedFromPhoto,
      importedAt: _wasImportedFromPhoto ? DateTime.now().toUtc() : null,
      importedBy: _wasImportedFromPhoto ? currentUserId : null,
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 1. Upload handwriting if any
      String? medicalIllnessesUrl = _medicalIllnessesImageUrl;
      String? stressesUrl = _stressesImageUrl;
      String? ongoingTreatmentUrl = _ongoingTreatmentImageUrl;
      String? otherSymptomsUrl = _otherSymptomsImageUrl;
      String? clinicalNotesUrl = _clinicalNotesImageUrl;
      String? provisionalDiagnosisUrl = _provisionalDiagnosisImageUrl;
      String? somaticOtherUrl = _somaticOtherImageUrl;

      if (_medicalIllnessesScribble.isNotEmpty) {
        final bytes = await _medicalIllnessesScribble.toPngBytes();
        if (bytes != null) {
          medicalIllnessesUrl =
              await SupabaseIntakeService.uploadHandwritingImage(
                patientId: widget.patient.id,
                sectionName: 'medical_illnesses',
                imageBytes: bytes,
              );
        }
      }

      if (_stressesScribble.isNotEmpty) {
        final bytes = await _stressesScribble.toPngBytes();
        if (bytes != null) {
          stressesUrl = await SupabaseIntakeService.uploadHandwritingImage(
            patientId: widget.patient.id,
            sectionName: 'stresses',
            imageBytes: bytes,
          );
        }
      }

      if (_ongoingTreatmentScribble.isNotEmpty) {
        final bytes = await _ongoingTreatmentScribble.toPngBytes();
        if (bytes != null) {
          ongoingTreatmentUrl =
              await SupabaseIntakeService.uploadHandwritingImage(
                patientId: widget.patient.id,
                sectionName: 'ongoing_treatment',
                imageBytes: bytes,
              );
        }
      }

      if (_otherSymptomsScribble.isNotEmpty) {
        final bytes = await _otherSymptomsScribble.toPngBytes();
        if (bytes != null) {
          otherSymptomsUrl = await SupabaseIntakeService.uploadHandwritingImage(
            patientId: widget.patient.id,
            sectionName: 'other_symptoms',
            imageBytes: bytes,
          );
        }
      }

      if (_clinicalNotesScribble.isNotEmpty) {
        final bytes = await _clinicalNotesScribble.toPngBytes();
        if (bytes != null) {
          clinicalNotesUrl = await SupabaseIntakeService.uploadHandwritingImage(
            patientId: widget.patient.id,
            sectionName: 'clinical_notes',
            imageBytes: bytes,
          );
        }
      }

      if (_provisionalDiagnosisScribble.isNotEmpty) {
        final bytes = await _provisionalDiagnosisScribble.toPngBytes();
        if (bytes != null) {
          provisionalDiagnosisUrl =
              await SupabaseIntakeService.uploadHandwritingImage(
                patientId: widget.patient.id,
                sectionName: 'provisional_diagnosis',
                imageBytes: bytes,
              );
        }
      }

      if (_somaticOtherScribble.isNotEmpty) {
        final bytes = await _somaticOtherScribble.toPngBytes();
        if (bytes != null) {
          somaticOtherUrl = await SupabaseIntakeService.uploadHandwritingImage(
            patientId: widget.patient.id,
            sectionName: 'somatic_other',
            imageBytes: bytes,
          );
        }
      }

      // 2. Build intake and save
      final intake = _buildIntake().copyWith(
        medicalIllnessesHandwriting: medicalIllnessesUrl,
        stressesHandwriting: stressesUrl,
        ongoingTreatmentHandwriting: ongoingTreatmentUrl,
        otherSymptomsHandwriting: otherSymptomsUrl,
        clinicalNotesHandwriting: clinicalNotesUrl,
        provisionalDiagnosisHandwriting: provisionalDiagnosisUrl,
        somaticOtherHandwriting: somaticOtherUrl,
      );
      widget.onSave(intake);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Handle photo import workflow
  Future<void> _handlePhotoImport() async {
    try {
      setState(() => _isImporting = true);

      // Open photo capture screen
      final result = await Navigator.push<Map<String, Uint8List>>(
        context,
        MaterialPageRoute(
          builder: (context) => const IntakePhotoCaptureScreen(),
        ),
      );

      if (result == null) {
        setState(() => _isImporting = false);
        return;
      }

      final frontPhoto = result['frontPhoto']!;
      final backPhoto = result['backPhoto']!;

      // Show processing dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Extracting data from photos...'),
                const SizedBox(height: 8),
                Text(
                  'This may take a few seconds',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Extract data using Gemini Vision API
      final extractedData = await IntakeFormExtractor.extractFromPhotos(
        frontPhoto: frontPhoto,
        backPhoto: backPhoto,
      );

      // Close processing dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Pre-fill form with extracted data
      if (mounted) {
        _prefillFromExtractedData(extractedData);

        setState(() {
          _isImporting = false;
          _wasImportedFromPhoto = true;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Form pre-filled from photos. Please review and correct any errors.',
                  ),
                ),
              ],
            ),
            backgroundColor: MedicalColors.healthy,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // Close processing dialog if open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      setState(() => _isImporting = false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Import Failed'),
              ],
            ),
            content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Pre-fill form fields from extracted data
  void _prefillFromExtractedData(Map<String, dynamic> data) {
    setState(() {
      // Header fields
      if (data['residence'] != null) {
        _residenceController.text = data['residence'];
      }
      if (data['duration_of_illness'] != null) {
        _durationOfIllnessController.text = data['duration_of_illness'];
      }
      if (data['referred_by'] != null) {
        _referredByController.text = data['referred_by'];
      }
      if (data['precipitating_factor'] != null) {
        _precipitatingFactorController.text = data['precipitating_factor'];
      }

      // Anxiety symptoms
      _anxietyWorry = data['anxiety_worry'] ?? false;
      _panic = data['panic'] ?? false;
      _restless = data['restless'] ?? false;
      _palpitationsTremors = data['palpitations_tremors'] ?? false;
      _phobia = data['phobia'] ?? false;
      _obsessions = data['obsessions'] ?? false;
      _compulsions = data['compulsions'] ?? false;
      _hypochondriacal = data['hypochondriacal'] ?? false;
      _fitsHystEpileptic = data['fits_hyst_epileptic'] ?? false;
      _possessionState = data['possession_state'] ?? false;

      // Somatic symptoms
      _somaticHeadache = data['somatic_headache'] ?? false;
      _somaticBodyache = data['somatic_bodyache'] ?? false;
      _somaticAbdominal = data['somatic_abdominal'] ?? false;
      if (data['somatic_other'] != null) {}

      // Substance use
      _substanceUse = data['substance_use'];
      _alcoholDrugs = data['alcohol_drugs'] ?? false;
      _tobaccoSmoking = data['tobacco_smoking'] ?? false;

      // Sexual dysfunction
      _decreasedLibido = data['decreased_libido'] ?? false;
      _increasedLibido = data['increased_libido'] ?? false;
      _erectileDysfunction = data['erectile_dysfunction'] ?? false;
      _prematureEjaculation = data['premature_ejaculation'] ?? false;
      _retardedEjaculation = data['retarded_ejaculation'] ?? false;
      _worryMasturbationNE = data['worry_masturbation_ne'] ?? false;
      if (data['sexual_dysfunction_other'] != null) {
        _sexualDysfunctionOtherController.text =
            data['sexual_dysfunction_other'];
      }

      // Psychotic symptoms
      _ideasDelPersecution = data['ideas_del_persecution'] ?? false;
      _ideasDelReference = data['ideas_del_reference'] ?? false;
      _otherDelusions = data['other_delusions'] ?? false;
      _firstRankSymptoms = data['first_rank_symptoms'] ?? false;
      _hallucinationsAuditory = data['hallucinations_auditory'] ?? false;
      _hallucinationsVisual = data['hallucinations_visual'] ?? false;
      _incoherence = data['incoherence'] ?? false;
      _mutteringToSelf = data['muttering_to_self'] ?? false;
      _inappropriateSmiling = data['inappropriate_smiling'] ?? false;
      _inappropriateWeeping = data['inappropriate_weeping'] ?? false;
      _abusing = data['abusing'] ?? false;
      _violence = data['violence'] ?? false;
      _withdrawalInertia = data['withdrawal_inertia'] ?? false;

      // Manic symptoms
      _irritableElated = data['irritable_elated'] ?? false;
      _grandiose = data['grandiose'] ?? false;
      _overtalkative = data['overtalkative'] ?? false;
      _flightOfIdeas = data['flight_of_ideas'] ?? false;
      _overactivePMA = data['overactive_pma'] ?? false;
      _extravagant = data['extravagant'] ?? false;

      // Depressive symptoms
      _sadIntermittent = data['sad_intermittent'] ?? false;
      _sadPersistent = data['sad_persistent'] ?? false;
      _anhedoniaInertia = data['anhedonia_inertia'] ?? false;
      _diurnalChange = data['diurnal_change'] ?? false;
      _weightLoss = data['weight_loss'] ?? false;
      _weightGain = data['weight_gain'] ?? false;
      _insomniaType = data['insomnia_type'];
      _hypersomnia = data['hypersomnia'] ?? false;
      _pmrPma = data['pmr_pma'] ?? false;
      _fatigue = data['fatigue'] ?? false;
      _worthlessnessGuilt = data['worthlessness_guilt'] ?? false;
      _decreasedThinkingConcentration =
          data['decreased_thinking_concentration'] ?? false;
      _indecisive = data['indecisive'] ?? false;
      _suicidalThoughts = data['suicidal_thoughts'] ?? false;
      _suicidalPlans = data['suicidal_plans'] ?? false;
      _suicidalAttempts = data['suicidal_attempts'] ?? false;

      // Cognitive symptoms
      _disorientationTime = data['disorientation_time'] ?? false;
      _disorientationPlace = data['disorientation_place'] ?? false;
      _disorientationPerson = data['disorientation_person'] ?? false;
      _forgetfulness = data['forgetfulness'];
      _aphasiaApraxiaAgnosia = data['aphasia_apraxia_agnosia'] ?? false;
      _decreasedIntelligence = data['decreased_intelligence'] ?? false;
      _perseveration = data['perseveration'] ?? false;
      _losingPath = data['losing_path'] ?? false;
      _disinhibition = data['disinhibition'] ?? false;
      _incontinenceUrine = data['incontinence_urine'] ?? false;
      _incontinenceStools = data['incontinence_stools'] ?? false;
      _emotionalLability = data['emotional_lability'] ?? false;

      // Additional information
      if (data['medical_illnesses'] != null) {
        _medicalIllnessesController.text = data['medical_illnesses'];
      }
      if (data['stresses'] != null) {
        _stressesController.text = data['stresses'];
      }
      if (data['ongoing_treatment'] != null) {
        _ongoingTreatmentController.text = data['ongoing_treatment'];
      }
      if (data['other_symptoms'] != null) {
        _otherSymptomsController.text = data['other_symptoms'];
      }
      if (data['clinical_notes'] != null) {
        _clinicalNotesController.text = data['clinical_notes'];
      }
      if (data['provisional_diagnosis'] != null) {
        _provisionalDiagnosisController.text = data['provisional_diagnosis'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Psychiatric Intake Form'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        actions: [
          if (_isEditing) ...[
            // Import from Photo button (only in edit mode)
            OutlinedButton.icon(
              onPressed: _isImporting || _isSaving ? null : _handlePhotoImport,
              icon: _isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera, size: 18),
              label: const Text('Import from Form'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MedicalColors.info,
              ),
            ),
            const SizedBox(width: 8),

            // Save button (only in edit mode)
            FilledButton.icon(
              onPressed: _isSaving ? null : _handleSave,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('Save Changes'),
            ),
          ] else ...[
            // Edit button (only in view mode)
            FilledButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit'),
              style: FilledButton.styleFrom(
                backgroundColor: MedicalColors.info,
              ),
            ),
          ],
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 24 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card - Doctor Info
            RepaintBoundary(child: _buildHeaderCard(context)),
            const SizedBox(height: 16),

            // Registration Number Section
            RepaintBoundary(child: _buildRegistrationSection(context)),
            const SizedBox(height: 16),

            // Patient Info Header
            RepaintBoundary(child: _buildPatientInfoHeader(context)),
            const SizedBox(height: 24),

            // Main 3-Column Grid (on tablets) or Single Column (on phones)
            if (isTablet)
              _buildThreeColumnGrid(context)
            else
              _buildSingleColumnLayout(context),

            const SizedBox(height: 24),

            // Additional Information Section
            _buildAdditionalInfoSection(context),
            const SizedBox(height: 24),

            // Clinical Notes & Diagnosis
            _buildClinicalNotesSection(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? theme.colorScheme.surfaceContainer : MedicalColors.infoBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? theme.colorScheme.outlineVariant
              : MedicalColors.infoBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.medical_services_outlined,
              color: isDark ? theme.colorScheme.primary : MedicalColors.info,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.doctorName != null && widget.doctorName!.isNotEmpty
                        ? 'Dr. ${widget.doctorName}'
                        : 'Doctor',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Psychiatric Evaluation Intake Form',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                DateFormat(
                  'dd/MM/yyyy',
                ).format(_dateOfExamination ?? DateTime.now()),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationSection(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _registrationNumberController,
                label: 'Registration Number',
                hint: 'Enter patient registration number',
                prefixIcon: Icons.app_registration,
              ),
            ),
            if (widget.existingIntake?.caseNumber != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildReadOnlyField(
                  label: 'Case Number',
                  value: widget.existingIntake?.caseNumber ?? '',
                  icon: Icons.tag,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoHeader(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Name and Age Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildReadOnlyField(
                    label: 'Name',
                    value: widget.patient.fullName,
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildReadOnlyField(
                    label: 'Age/Sex',
                    value:
                        '${widget.patient.age ?? "-"}/${widget.patient.gender ?? "-"}',
                    icon: Icons.cake_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Second Row - General Info
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: isTablet ? 250 : double.infinity,
                  child: _buildTextField(
                    controller: _residenceController,
                    label: 'R/o (Residence)',
                    hint: 'City/Area',
                  ),
                ),
                SizedBox(
                  width: isTablet ? 200 : double.infinity,
                  child: _buildTextField(
                    controller: _durationOfIllnessController,
                    label: 'Duration of Illness',
                    hint: 'e.g., 6 months',
                  ),
                ),
                SizedBox(
                  width: isTablet ? 200 : double.infinity,
                  child: _buildTextField(
                    controller: _referredByController,
                    label: 'Ref. by',
                    hint: 'Referring doctor',
                  ),
                ),
                SizedBox(
                  width: isTablet ? 300 : double.infinity,
                  child: _buildTextField(
                    controller: _precipitatingFactorController,
                    label: 'Ppting. Factor',
                    hint: 'Precipitating factor',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreeColumnGrid(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column - Anxiety & Related
        Expanded(child: RepaintBoundary(child: _buildLeftColumn(context))),
        const SizedBox(width: 16),
        // Middle Column - Psychotic & Manic
        Expanded(child: RepaintBoundary(child: _buildMiddleColumn(context))),
        const SizedBox(width: 16),
        // Right Column - Cognitive & Other
        Expanded(child: RepaintBoundary(child: _buildRightColumn(context))),
      ],
    );
  }

  Widget _buildSingleColumnLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepaintBoundary(child: _buildLeftColumn(context)),
        const SizedBox(height: 16),
        RepaintBoundary(child: _buildMiddleColumn(context)),
        const SizedBox(height: 16),
        RepaintBoundary(child: _buildRightColumn(context)),
      ],
    );
  }

  Widget _buildLeftColumn(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Anxiety Related Section
        _buildSectionCard(
          context,
          title: 'Anxiety Related',
          color: Colors.orange,
          children: [
            _buildCheckboxTile(
              'Anxiety/Worry',
              _anxietyWorry,
              (v) => setState(() => _anxietyWorry = v ?? false),
            ),
            _buildCheckboxTile(
              'Panic',
              _panic,
              (v) => setState(() => _panic = v ?? false),
            ),
            _buildCheckboxTile(
              'Restless',
              _restless,
              (v) => setState(() => _restless = v ?? false),
            ),
            _buildCheckboxTile(
              'Palpitations/Tremors',
              _palpitationsTremors,
              (v) => setState(() => _palpitationsTremors = v ?? false),
            ),
            _buildCheckboxTile(
              'Phobia',
              _phobia,
              (v) => setState(() => _phobia = v ?? false),
            ),
            _buildCheckboxTile(
              'Obsessions',
              _obsessions,
              (v) => setState(() => _obsessions = v ?? false),
            ),
            _buildCheckboxTile(
              'Compulsions',
              _compulsions,
              (v) => setState(() => _compulsions = v ?? false),
            ),
            _buildCheckboxTile(
              'Hypochondriacal',
              _hypochondriacal,
              (v) => setState(() => _hypochondriacal = v ?? false),
            ),
            _buildCheckboxTile(
              'Fits-hyst./epileptic',
              _fitsHystEpileptic,
              (v) => setState(() => _fitsHystEpileptic = v ?? false),
            ),
            _buildCheckboxTile(
              'Possession state',
              _possessionState,
              (v) => setState(() => _possessionState = v ?? false),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Somatic Symptoms
        _buildSectionCard(
          context,
          title: 'Somatic Symptoms',
          color: Colors.teal,
          children: [
            _buildCheckboxTile(
              'Headache',
              _somaticHeadache,
              (v) => setState(() => _somaticHeadache = v ?? false),
            ),
            _buildCheckboxTile(
              'Bodyache',
              _somaticBodyache,
              (v) => setState(() => _somaticBodyache = v ?? false),
            ),
            _buildCheckboxTile(
              'Abd. Symptoms',
              _somaticAbdominal,
              (v) => setState(() => _somaticAbdominal = v ?? false),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: HandwritingField(
                controller: _somaticOtherScribble,
                label: 'Other',
                initialImageUrl: _somaticOtherImageUrl,
                readOnly: !_isEditing,
                height: 100,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Substance Use
        _buildSectionCard(
          context,
          title: 'Substance Use',
          color: Colors.red,
          children: [
            _buildCheckboxTile(
              'Alcohol/Drugs',
              _alcoholDrugs,
              (v) => setState(() => _alcoholDrugs = v ?? false),
            ),
            _buildCheckboxTile(
              'Tobacco/Smoking',
              _tobaccoSmoking,
              (v) => setState(() => _tobaccoSmoking = v ?? false),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Pattern: Use/Abuse/Dependence',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Sexual Dysfunction
        _buildSectionCard(
          context,
          title: 'Sexual Dysfunction',
          color: Colors.pink,
          children: [
            _buildCheckboxTile(
              '↓ Libido/↑ Libido',
              _decreasedLibido || _increasedLibido,
              (v) => setState(() {
                _decreasedLibido = v ?? false;
                _increasedLibido = v ?? false;
              }),
            ),
            _buildCheckboxTile(
              'E.D.',
              _erectileDysfunction,
              (v) => setState(() => _erectileDysfunction = v ?? false),
            ),
            _buildCheckboxTile(
              'Prematu. ejaculation',
              _prematureEjaculation,
              (v) => setState(() => _prematureEjaculation = v ?? false),
            ),
            _buildCheckboxTile(
              'Retarded ejaculation',
              _retardedEjaculation,
              (v) => setState(() => _retardedEjaculation = v ?? false),
            ),
            _buildCheckboxTile(
              'Worry rel.to Mast/NE',
              _worryMasturbationNE,
              (v) => setState(() => _worryMasturbationNE = v ?? false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiddleColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Psychotic Symptoms
        _buildSectionCard(
          context,
          title: 'Psychotic Symptoms',
          color: Colors.purple,
          children: [
            _buildCheckboxTile(
              'Ideas/Del. of persecution',
              _ideasDelPersecution,
              (v) => setState(() => _ideasDelPersecution = v ?? false),
            ),
            _buildCheckboxTile(
              'Ideas/Del. of reference',
              _ideasDelReference,
              (v) => setState(() => _ideasDelReference = v ?? false),
            ),
            _buildCheckboxTile(
              'Other delusions',
              _otherDelusions,
              (v) => setState(() => _otherDelusions = v ?? false),
            ),
            _buildCheckboxTile(
              'F.R.S. (First Rank)',
              _firstRankSymptoms,
              (v) => setState(() => _firstRankSymptoms = v ?? false),
            ),
            _buildCheckboxTile(
              'Hallucinations (auditory/visual)',
              _hallucinationsAuditory || _hallucinationsVisual,
              (v) => setState(() {
                _hallucinationsAuditory = v ?? false;
                _hallucinationsVisual = v ?? false;
              }),
            ),
            _buildCheckboxTile(
              'Incoherence',
              _incoherence,
              (v) => setState(() => _incoherence = v ?? false),
            ),
            _buildCheckboxTile(
              'Muttering to self',
              _mutteringToSelf,
              (v) => setState(() => _mutteringToSelf = v ?? false),
            ),
            _buildCheckboxTile(
              'Inappropriate (smiling/weeping)',
              _inappropriateSmiling || _inappropriateWeeping,
              (v) => setState(() {
                _inappropriateSmiling = v ?? false;
                _inappropriateWeeping = v ?? false;
              }),
            ),
            _buildCheckboxTile(
              'Abusing',
              _abusing,
              (v) => setState(() => _abusing = v ?? false),
            ),
            _buildCheckboxTile(
              'Violence',
              _violence,
              (v) => setState(() => _violence = v ?? false),
            ),
            _buildCheckboxTile(
              'Withdrawal/Inertia',
              _withdrawalInertia,
              (v) => setState(() => _withdrawalInertia = v ?? false),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Manic Symptoms
        _buildSectionCard(
          context,
          title: 'Manic Symptoms',
          color: Colors.amber,
          children: [
            _buildCheckboxTile(
              'Irritable/Elated',
              _irritableElated,
              (v) => setState(() => _irritableElated = v ?? false),
            ),
            _buildCheckboxTile(
              'Grandiose',
              _grandiose,
              (v) => setState(() => _grandiose = v ?? false),
            ),
            _buildCheckboxTile(
              'Overtalkative',
              _overtalkative,
              (v) => setState(() => _overtalkative = v ?? false),
            ),
            _buildCheckboxTile(
              'Flight of Ideas',
              _flightOfIdeas,
              (v) => setState(() => _flightOfIdeas = v ?? false),
            ),
            _buildCheckboxTile(
              'Overactive/PMA',
              _overactivePMA,
              (v) => setState(() => _overactivePMA = v ?? false),
            ),
            _buildCheckboxTile(
              'Extravagant',
              _extravagant,
              (v) => setState(() => _extravagant = v ?? false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cognitive Symptoms
        _buildSectionCard(
          context,
          title: 'Cognitive/Dementia',
          color: Colors.brown,
          children: [
            _buildCheckboxTile(
              'Disorientation (time/place/person)',
              _disorientationTime ||
                  _disorientationPlace ||
                  _disorientationPerson,
              (v) => setState(() {
                _disorientationTime = v ?? false;
                _disorientationPlace = v ?? false;
                _disorientationPerson = v ?? false;
              }),
            ),
            _buildCheckboxTile(
              'Forgetfulness',
              _forgetfulness != null,
              (v) =>
                  setState(() => _forgetfulness = (v ?? false) ? 'mild' : null),
            ),
            _buildCheckboxTile(
              'Aphasia/apraxia/agnosia',
              _aphasiaApraxiaAgnosia,
              (v) => setState(() => _aphasiaApraxiaAgnosia = v ?? false),
            ),
            _buildCheckboxTile(
              '↓ Intelligence',
              _decreasedIntelligence,
              (v) => setState(() => _decreasedIntelligence = v ?? false),
            ),
            _buildCheckboxTile(
              'Perseveration',
              _perseveration,
              (v) => setState(() => _perseveration = v ?? false),
            ),
            _buildCheckboxTile(
              'Losing path',
              _losingPath,
              (v) => setState(() => _losingPath = v ?? false),
            ),
            _buildCheckboxTile(
              'Disinhibition',
              _disinhibition,
              (v) => setState(() => _disinhibition = v ?? false),
            ),
            _buildCheckboxTile(
              'Incontinence (urine/stools)',
              _incontinenceUrine || _incontinenceStools,
              (v) => setState(() {
                _incontinenceUrine = v ?? false;
                _incontinenceStools = v ?? false;
              }),
            ),
            _buildCheckboxTile(
              'Emotional Lability',
              _emotionalLability,
              (v) => setState(() => _emotionalLability = v ?? false),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Depressive Symptoms
        _buildSectionCard(
          context,
          title: 'Depressive Symptoms',
          color: Colors.blue,
          children: [
            _buildCheckboxTile(
              'Sad (intermittent/persistent)',
              _sadIntermittent || _sadPersistent,
              (v) => setState(() {
                _sadIntermittent = v ?? false;
                _sadPersistent = v ?? false;
              }),
            ),
            _buildCheckboxTile(
              'Anhedonia/Inertia',
              _anhedoniaInertia,
              (v) => setState(() => _anhedoniaInertia = v ?? false),
            ),
            _buildCheckboxTile(
              'Diurnal change',
              _diurnalChange,
              (v) => setState(() => _diurnalChange = v ?? false),
            ),
            _buildCheckboxTile(
              'Weight (loss/gain)',
              _weightLoss || _weightGain,
              (v) => setState(() {
                _weightLoss = v ?? false;
                _weightGain = v ?? false;
              }),
            ),
            _buildCheckboxTile(
              'Insomnia/Hypersomnia',
              _insomniaType != null || _hypersomnia,
              (v) => setState(() {
                _insomniaType = (v ?? false) ? 'I' : null;
                _hypersomnia = v ?? false;
              }),
            ),
            _buildCheckboxTile(
              'PMR/PMA',
              _pmrPma,
              (v) => setState(() => _pmrPma = v ?? false),
            ),
            _buildCheckboxTile(
              'Fatigue',
              _fatigue,
              (v) => setState(() => _fatigue = v ?? false),
            ),
            _buildCheckboxTile(
              'Worthlessness/Guilt',
              _worthlessnessGuilt,
              (v) => setState(() => _worthlessnessGuilt = v ?? false),
            ),
            _buildCheckboxTile(
              '↓Thinking/Conc.',
              _decreasedThinkingConcentration,
              (v) =>
                  setState(() => _decreasedThinkingConcentration = v ?? false),
            ),
            _buildCheckboxTile(
              'Indecisive',
              _indecisive,
              (v) => setState(() => _indecisive = v ?? false),
            ),
            const Divider(),
            _buildCheckboxTile(
              'Suicidal (thoughts/plans/attempts)',
              _suicidalThoughts || _suicidalPlans || _suicidalAttempts,
              (v) => setState(() {
                _suicidalThoughts = v ?? false;
                _suicidalPlans = v ?? false;
                _suicidalAttempts = v ?? false;
              }),
              isDanger: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdditionalInfoSection(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: HandwritingField(
                    controller: _medicalIllnessesScribble,
                    label: 'Medical Illnesses',
                    initialImageUrl: _medicalIllnessesImageUrl,
                    readOnly: !_isEditing,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: HandwritingField(
                    controller: _stressesScribble,
                    label: 'Stresses',
                    initialImageUrl: _stressesImageUrl,
                    readOnly: !_isEditing,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: HandwritingField(
                    controller: _ongoingTreatmentScribble,
                    label: 'Ongoing Treatment',
                    initialImageUrl: _ongoingTreatmentImageUrl,
                    readOnly: !_isEditing,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            HandwritingField(
              controller: _otherSymptomsScribble,
              label: 'Other Symptoms',
              initialImageUrl: _otherSymptomsImageUrl,
              readOnly: !_isEditing,
              height: 100,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicalNotesSection(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clinical Notes & Diagnosis',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            HandwritingField(
              controller: _clinicalNotesScribble,
              label: 'Clinical Notes',
              initialImageUrl: _clinicalNotesImageUrl,
              readOnly: !_isEditing,
              height: 200,
            ),
            const SizedBox(height: 16),
            HandwritingField(
              controller: _provisionalDiagnosisScribble,
              label: 'Provisional Diagnosis',
              initialImageUrl: _provisionalDiagnosisImageUrl,
              readOnly: !_isEditing,
              height: 100,
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widgets
  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? color.withValues(alpha: 0.4)
              : color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? color.withValues(alpha: 0.15)
                  : color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? color.withValues(alpha: 0.9) : color,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile(
    String label,
    bool value,
    ValueChanged<bool?> onChanged, {
    bool isWarning = false,
    bool isDanger = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color? textColor;
    Color? backgroundColor;

    if (value) {
      if (isDanger) {
        textColor = isDark ? const Color(0xFFFFB4AB) : MedicalColors.critical;
        backgroundColor = isDark
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
            : MedicalColors.criticalBg.withValues(alpha: 0.7);
      } else if (isWarning) {
        textColor = isDark ? const Color(0xFFFFB871) : MedicalColors.warning;
        backgroundColor = isDark
            ? Colors.orange.withValues(alpha: 0.2)
            : MedicalColors.warningBg.withValues(alpha: 0.7);
      } else {
        textColor = isDark ? theme.colorScheme.primary : MedicalColors.info;
        backgroundColor = isDark
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : MedicalColors.infoBg.withValues(alpha: 0.5);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: CheckboxListTile(
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: textColor,
            fontWeight: value ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        value: value,
        onChanged: _isEditing ? onChanged : null,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        tileColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefixIcon,
  }) {
    return TextField(
      controller: controller,
      readOnly: !_isEditing,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    IconData? icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
