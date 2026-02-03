import 'package:flutter/material.dart';
import 'package:saber/data/models/psychiatric_intake.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/design_system/colors.dart';
import 'package:saber/design_system/spacing.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:saber/components/intake_form/intake_photo_capture_screen.dart';
import 'package:saber/data/api/intake_form_extractor.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/data/api/error_handler.dart';
import 'dart:typed_data';

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
  bool _isSaving = false;
  bool _isImporting = false;
  bool _wasImportedFromPhoto = false;
  late bool _isEditing;

  // Header Fields
  DateTime? _dateOfExamination = DateTime.now();
  final TextEditingController _residenceController = TextEditingController();
  final TextEditingController _durationOfIllnessController =
      TextEditingController();
  final TextEditingController _referredByController = TextEditingController();
  final TextEditingController _precipitatingFactorController =
      TextEditingController();

  // Anxiety & Related Symptoms
  bool _anxietyWorry = false;
  bool _panic = false;
  bool _restless = false;
  bool _palpitationsTremors = false;
  bool _phobia = false;
  bool _obsessions = false;
  bool _compulsions = false;
  bool _hypochondriacal = false;
  bool _fitsHystEpileptic = false;
  bool _possessionState = false;

  // Somatic Symptoms
  bool _somaticHeadache = false;
  bool _somaticBodyache = false;
  bool _somaticAbdominal = false;
  final _somaticOtherController = TextEditingController();

  // Substance Use
  bool _alcoholDrugsTobacco = false;
  String? _substanceUse;

  // Sexual Dysfunction
  bool _decreasedLibido = false;
  bool _increasedLibido = false;
  bool _erectileDysfunction = false;
  bool _prematureEjaculation = false;
  bool _retardedEjaculation = false;
  bool _worryMasturbationNE = false;
  final _sexualDysfunctionOtherController = TextEditingController();

  // Psychotic Symptoms
  bool _ideasDelPersecution = false;
  bool _ideasDelReference = false;
  bool _otherDelusions = false;
  bool _firstRankSymptoms = false;
  bool _hallucinationsAuditory = false;
  bool _hallucinationsVisual = false;
  bool _incoherence = false;
  bool _mutteringToSelf = false;
  bool _inappropriateSmiling = false;
  bool _inappropriateWeeping = false;
  bool _abusing = false;
  bool _violence = false;
  bool _withdrawalInertia = false;

  // Manic Symptoms
  bool _irritableElated = false;
  bool _grandiose = false;
  bool _overtalkative = false;
  bool _flightOfIdeas = false;
  bool _overactivePMA = false;
  bool _extravagant = false;

  // Depressive Symptoms
  bool _sadIntermittent = false;
  bool _sadPersistent = false;
  bool _anhedoniaInertia = false;
  bool _diurnalChange = false;
  bool _weightLoss = false;
  bool _weightGain = false;
  String? _insomniaType;
  bool _hypersomnia = false;
  bool _pmrPma = false;
  bool _fatigue = false;
  bool _worthlessnessGuilt = false;
  bool _decreasedThinkingConcentration = false;
  bool _indecisive = false;
  bool _suicidalThoughts = false;
  bool _suicidalPlans = false;
  bool _suicidalAttempts = false;

  // Cognitive Symptoms
  bool _disorientationTime = false;
  bool _disorientationPlace = false;
  bool _disorientationPerson = false;
  String? _forgetfulness;
  bool _aphasiaApraxiaAgnosia = false;
  bool _decreasedIntelligence = false;
  bool _perseveration = false;
  bool _losingPath = false;
  bool _disinhibition = false;
  bool _incontinenceUrine = false;
  bool _incontinenceStools = false;
  bool _emotionalLability = false;

  // Additional Information
  final _medicalIllnessesController = TextEditingController();
  final _stressesController = TextEditingController();
  final _ongoingTreatmentController = TextEditingController();
  final _otherSymptomsController = TextEditingController();
  final _clinicalNotesController = TextEditingController();
  final _provisionalDiagnosisController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Start in edit mode if creating new intake or not in readOnly mode
    // Start in view mode if readOnly and viewing existing intake
    _isEditing = !widget.readOnly || widget.existingIntake == null;

    // Pre-fill residence from patient data if available
    if (widget.patient.address != null && widget.patient.address!.isNotEmpty) {
      _residenceController.text = widget.patient.address!;
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
    _somaticOtherController.text = intake.somaticOther ?? '';

    _alcoholDrugsTobacco = intake.alcoholDrugsTobacco;
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _residenceController.dispose();
    _durationOfIllnessController.dispose();
    _referredByController.dispose();
    _precipitatingFactorController.dispose();
    _somaticOtherController.dispose();
    _sexualDysfunctionOtherController.dispose();
    _medicalIllnessesController.dispose();
    _stressesController.dispose();
    _ongoingTreatmentController.dispose();
    _otherSymptomsController.dispose();
    _clinicalNotesController.dispose();
    _provisionalDiagnosisController.dispose();
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
      somaticOther: _somaticOtherController.text.isEmpty
          ? null
          : _somaticOtherController.text,
      substanceUse: _substanceUse,
      alcoholDrugsTobacco: _alcoholDrugsTobacco,
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
      final intake = _buildIntake();
      widget.onSave(intake);
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
          SnackBar(
            content: const Row(
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
            duration: const Duration(seconds: 5),
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
      if (data['somatic_other'] != null) {
        _somaticOtherController.text = data['somatic_other'];
      }

      // Substance use
      _substanceUse = data['substance_use'];
      _alcoholDrugsTobacco = data['alcohol_drugs_tobacco'] ?? false;

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
            _buildHeaderCard(context),
            const SizedBox(height: 16),

            // Patient Info Header
            _buildPatientInfoHeader(context),
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

    return Card(
      elevation: 0,
      color: MedicalColors.infoBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: MedicalColors.infoBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.medical_services_outlined,
              color: MedicalColors.info,
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
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                DateFormat(
                  'dd/MM/yyyy',
                ).format(_dateOfExamination ?? DateTime.now()),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
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
        Expanded(child: _buildLeftColumn(context)),
        const SizedBox(width: 16),
        // Middle Column - Psychotic & Manic
        Expanded(child: _buildMiddleColumn(context)),
        const SizedBox(width: 16),
        // Right Column - Cognitive & Other
        Expanded(child: _buildRightColumn(context)),
      ],
    );
  }

  Widget _buildSingleColumnLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLeftColumn(context),
        const SizedBox(height: 16),
        _buildMiddleColumn(context),
        const SizedBox(height: 16),
        _buildRightColumn(context),
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
              child: TextField(
                controller: _somaticOtherController,
                decoration: const InputDecoration(
                  labelText: 'Other',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                style: theme.textTheme.bodySmall,
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
              'Alcohol/Drugs/Tobacco',
              _alcoholDrugsTobacco,
              (v) => setState(() => _alcoholDrugsTobacco = v ?? false),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: DropdownButtonFormField<String>(
                value: _substanceUse,
                decoration: const InputDecoration(
                  labelText: 'Usage Pattern',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'use', child: Text('Use')),
                  DropdownMenuItem(value: 'abuse', child: Text('Abuse')),
                  DropdownMenuItem(
                    value: 'dependence',
                    child: Text('Dependence'),
                  ),
                ],
                onChanged: (v) => setState(() => _substanceUse = v),
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
              '↓ Libido',
              _decreasedLibido,
              (v) => setState(() => _decreasedLibido = v ?? false),
            ),
            _buildCheckboxTile(
              '↑ Libido',
              _increasedLibido,
              (v) => setState(() => _increasedLibido = v ?? false),
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
              'Hallucinations - Auditory',
              _hallucinationsAuditory,
              (v) => setState(() => _hallucinationsAuditory = v ?? false),
            ),
            _buildCheckboxTile(
              'Hallucinations - Visual',
              _hallucinationsVisual,
              (v) => setState(() => _hallucinationsVisual = v ?? false),
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
              'Inappropriate smiling',
              _inappropriateSmiling,
              (v) => setState(() => _inappropriateSmiling = v ?? false),
            ),
            _buildCheckboxTile(
              'Inappropriate weeping',
              _inappropriateWeeping,
              (v) => setState(() => _inappropriateWeeping = v ?? false),
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Depressive Symptoms
        _buildSectionCard(
          context,
          title: 'Depressive Symptoms',
          color: Colors.blue,
          children: [
            _buildCheckboxTile(
              'Sad - intermittent',
              _sadIntermittent,
              (v) => setState(() => _sadIntermittent = v ?? false),
            ),
            _buildCheckboxTile(
              'Sad - persistent',
              _sadPersistent,
              (v) => setState(() => _sadPersistent = v ?? false),
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
              'Weight loss',
              _weightLoss,
              (v) => setState(() => _weightLoss = v ?? false),
            ),
            _buildCheckboxTile(
              'Weight gain',
              _weightGain,
              (v) => setState(() => _weightGain = v ?? false),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: DropdownButtonFormField<String>(
                value: _insomniaType,
                decoration: const InputDecoration(
                  labelText: 'Insomnia Type',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'I', child: Text('Initial (I)')),
                  DropdownMenuItem(value: 'M', child: Text('Middle (M)')),
                  DropdownMenuItem(value: 'T', child: Text('Terminal (T)')),
                  DropdownMenuItem(value: 'To', child: Text('Total (To)')),
                ],
                onChanged: (v) => setState(() => _insomniaType = v),
              ),
            ),
            _buildCheckboxTile(
              'Hypersomnia',
              _hypersomnia,
              (v) => setState(() => _hypersomnia = v ?? false),
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
              'Suicidal thoughts',
              _suicidalThoughts,
              (v) => setState(() => _suicidalThoughts = v ?? false),
              isWarning: true,
            ),
            _buildCheckboxTile(
              'Suicidal plans',
              _suicidalPlans,
              (v) => setState(() => _suicidalPlans = v ?? false),
              isWarning: true,
            ),
            _buildCheckboxTile(
              'Suicidal attempts',
              _suicidalAttempts,
              (v) => setState(() => _suicidalAttempts = v ?? false),
              isDanger: true,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Cognitive Symptoms
        _buildSectionCard(
          context,
          title: 'Cognitive/Dementia',
          color: Colors.brown,
          children: [
            _buildCheckboxTile(
              'Disorientation - time',
              _disorientationTime,
              (v) => setState(() => _disorientationTime = v ?? false),
            ),
            _buildCheckboxTile(
              'Disorientation - place',
              _disorientationPlace,
              (v) => setState(() => _disorientationPlace = v ?? false),
            ),
            _buildCheckboxTile(
              'Disorientation - person',
              _disorientationPerson,
              (v) => setState(() => _disorientationPerson = v ?? false),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: DropdownButtonFormField<String>(
                value: _forgetfulness,
                decoration: const InputDecoration(
                  labelText: 'Forgetfulness',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'mild', child: Text('Mild')),
                  DropdownMenuItem(value: 'mod', child: Text('Moderate')),
                  DropdownMenuItem(value: 'severe', child: Text('Severe')),
                ],
                onChanged: (v) => setState(() => _forgetfulness = v),
              ),
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
              'Incontinence urine',
              _incontinenceUrine,
              (v) => setState(() => _incontinenceUrine = v ?? false),
            ),
            _buildCheckboxTile(
              'Incontinence stools',
              _incontinenceStools,
              (v) => setState(() => _incontinenceStools = v ?? false),
            ),
            _buildCheckboxTile(
              'Emotional Lability',
              _emotionalLability,
              (v) => setState(() => _emotionalLability = v ?? false),
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
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
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
                  child: _buildMultilineTextField(
                    controller: _medicalIllnessesController,
                    label: 'Medical Illnesses',
                    hint: 'DM, HTN, etc.',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMultilineTextField(
                    controller: _stressesController,
                    label: 'Stresses',
                    hint: 'Life stressors',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMultilineTextField(
                    controller: _ongoingTreatmentController,
                    label: 'Ongoing Treatment',
                    hint: 'Current medications',
                  ),
                ),
              ],
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
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
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
            _buildMultilineTextField(
              controller: _clinicalNotesController,
              label: 'Clinical Notes',
              hint: 'Detailed observations...',
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            _buildMultilineTextField(
              controller: _provisionalDiagnosisController,
              label: 'Provisional Diagnosis',
              hint: 'e.g., F32.1 Moderate Depressive Episode',
              maxLines: 2,
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
                    color: color,
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
    Color? textColor;
    if (isDanger && value) {
      textColor = MedicalColors.critical;
    } else if (isWarning && value) {
      textColor = MedicalColors.warning;
    }

    return CheckboxListTile(
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: textColor,
          fontWeight: (isWarning || isDanger) && value ? FontWeight.bold : null,
        ),
      ),
      value: value,
      onChanged: _isEditing ? onChanged : null,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      readOnly: !_isEditing,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildMultilineTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 3,
  }) {
    return TextField(
      controller: controller,
      readOnly: !_isEditing,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
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
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
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
