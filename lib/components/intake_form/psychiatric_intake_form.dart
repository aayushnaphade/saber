import 'package:flutter/material.dart';
import 'package:saber/data/models/psychiatric_intake.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/design_system/colors.dart';
import 'package:saber/design_system/spacing.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

/// Psychiatric Intake Form Widget
/// Matches Dr. Monisha Dass's clinical intake form layout
/// 
/// This form is displayed for new patients with no previous sessions
/// to gather comprehensive psychiatric evaluation data
class PsychiatricIntakeForm extends StatefulWidget {
  final Patient patient;
  final PsychiatricIntake? existingIntake;
  final Function(PsychiatricIntake) onSave;
  final VoidCallback? onCancel;

  const PsychiatricIntakeForm({
    super.key,
    required this.patient,
    this.existingIntake,
    required this.onSave,
    this.onCancel,
  });

  @override
  State<PsychiatricIntakeForm> createState() => _PsychiatricIntakeFormState();
}

class _PsychiatricIntakeFormState extends State<PsychiatricIntakeForm> {
  late final ScrollController _scrollController;
  bool _isSaving = false;

  // Header Fields
  final _caseNumberController = TextEditingController();
  DateTime? _dateOfExamination;
  final _educationController = TextEditingController();
  final _occupationController = TextEditingController();
  final _residenceController = TextEditingController();
  final _informantsController = TextEditingController();
  final _durationOfIllnessController = TextEditingController();
  final _referredByController = TextEditingController();
  final _precipitatingFactorController = TextEditingController();

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
    _dateOfExamination = DateTime.now();
    
    if (widget.existingIntake != null) {
      _loadExistingIntake(widget.existingIntake!);
    }
  }

  void _loadExistingIntake(PsychiatricIntake intake) {
    _caseNumberController.text = intake.caseNumber ?? '';
    _dateOfExamination = intake.dateOfExamination;
    _educationController.text = intake.education ?? '';
    _occupationController.text = intake.occupation ?? '';
    _residenceController.text = intake.residence ?? '';
    _informantsController.text = intake.informants ?? '';
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
    _sexualDysfunctionOtherController.text = intake.sexualDysfunctionOther ?? '';

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
    _caseNumberController.dispose();
    _educationController.dispose();
    _occupationController.dispose();
    _residenceController.dispose();
    _informantsController.dispose();
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
    return PsychiatricIntake(
      id: id,
      patientId: widget.patient.id,
      createdAt: widget.existingIntake?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      caseNumber: _caseNumberController.text.isEmpty ? null : _caseNumberController.text,
      dateOfExamination: _dateOfExamination,
      education: _educationController.text.isEmpty ? null : _educationController.text,
      occupation: _occupationController.text.isEmpty ? null : _occupationController.text,
      residence: _residenceController.text.isEmpty ? null : _residenceController.text,
      informants: _informantsController.text.isEmpty ? null : _informantsController.text,
      durationOfIllness: _durationOfIllnessController.text.isEmpty ? null : _durationOfIllnessController.text,
      referredBy: _referredByController.text.isEmpty ? null : _referredByController.text,
      precipitatingFactor: _precipitatingFactorController.text.isEmpty ? null : _precipitatingFactorController.text,
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
      somaticOther: _somaticOtherController.text.isEmpty ? null : _somaticOtherController.text,
      substanceUse: _substanceUse,
      alcoholDrugsTobacco: _alcoholDrugsTobacco,
      decreasedLibido: _decreasedLibido,
      increasedLibido: _increasedLibido,
      erectileDysfunction: _erectileDysfunction,
      prematureEjaculation: _prematureEjaculation,
      retardedEjaculation: _retardedEjaculation,
      worryMasturbationNE: _worryMasturbationNE,
      sexualDysfunctionOther: _sexualDysfunctionOtherController.text.isEmpty ? null : _sexualDysfunctionOtherController.text,
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
      medicalIllnesses: _medicalIllnessesController.text.isEmpty ? null : _medicalIllnessesController.text,
      stresses: _stressesController.text.isEmpty ? null : _stressesController.text,
      ongoingTreatment: _ongoingTreatmentController.text.isEmpty ? null : _ongoingTreatmentController.text,
      otherSymptoms: _otherSymptomsController.text.isEmpty ? null : _otherSymptomsController.text,
      clinicalNotes: _clinicalNotesController.text.isEmpty ? null : _clinicalNotesController.text,
      provisionalDiagnosis: _provisionalDiagnosisController.text.isEmpty ? null : _provisionalDiagnosisController.text,
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
          FilledButton.icon(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('Save & Continue'),
          ),
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
            Icon(Icons.medical_services_outlined, 
                 color: MedicalColors.info, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. Monisha Dass',
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
                DateFormat('dd/MM/yyyy').format(_dateOfExamination ?? DateTime.now()),
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
                    value: '${widget.patient.age ?? "-"}/${widget.patient.gender ?? "-"}',
                    icon: Icons.cake_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _caseNumberController,
                    label: 'Case No.',
                    hint: 'Enter case number',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Second Row
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: isTablet ? 200 : double.infinity,
                  child: _buildTextField(
                    controller: _educationController,
                    label: 'Education',
                    hint: 'e.g., Graduate',
                  ),
                ),
                SizedBox(
                  width: isTablet ? 200 : double.infinity,
                  child: _buildTextField(
                    controller: _occupationController,
                    label: 'Occupation',
                    hint: 'e.g., Teacher',
                  ),
                ),
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
                    controller: _informantsController,
                    label: 'Informants',
                    hint: 'Self/Family',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Third Row
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
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
            _buildCheckboxTile('Anxiety/Worry', _anxietyWorry, (v) => setState(() => _anxietyWorry = v ?? false)),
            _buildCheckboxTile('Panic', _panic, (v) => setState(() => _panic = v ?? false)),
            _buildCheckboxTile('Restless', _restless, (v) => setState(() => _restless = v ?? false)),
            _buildCheckboxTile('Palpitations/Tremors', _palpitationsTremors, (v) => setState(() => _palpitationsTremors = v ?? false)),
            _buildCheckboxTile('Phobia', _phobia, (v) => setState(() => _phobia = v ?? false)),
            _buildCheckboxTile('Obsessions', _obsessions, (v) => setState(() => _obsessions = v ?? false)),
            _buildCheckboxTile('Compulsions', _compulsions, (v) => setState(() => _compulsions = v ?? false)),
            _buildCheckboxTile('Hypochondriacal', _hypochondriacal, (v) => setState(() => _hypochondriacal = v ?? false)),
            _buildCheckboxTile('Fits-hyst./epileptic', _fitsHystEpileptic, (v) => setState(() => _fitsHystEpileptic = v ?? false)),
            _buildCheckboxTile('Possession state', _possessionState, (v) => setState(() => _possessionState = v ?? false)),
          ],
        ),
        const SizedBox(height: 16),
        
        // Somatic Symptoms
        _buildSectionCard(
          context,
          title: 'Somatic Symptoms',
          color: Colors.teal,
          children: [
            _buildCheckboxTile('Headache', _somaticHeadache, (v) => setState(() => _somaticHeadache = v ?? false)),
            _buildCheckboxTile('Bodyache', _somaticBodyache, (v) => setState(() => _somaticBodyache = v ?? false)),
            _buildCheckboxTile('Abd. Symptoms', _somaticAbdominal, (v) => setState(() => _somaticAbdominal = v ?? false)),
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
            _buildCheckboxTile('Alcohol/Drugs/Tobacco', _alcoholDrugsTobacco, (v) => setState(() => _alcoholDrugsTobacco = v ?? false)),
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
                  DropdownMenuItem(value: 'dependence', child: Text('Dependence')),
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
            _buildCheckboxTile('↓ Libido', _decreasedLibido, (v) => setState(() => _decreasedLibido = v ?? false)),
            _buildCheckboxTile('↑ Libido', _increasedLibido, (v) => setState(() => _increasedLibido = v ?? false)),
            _buildCheckboxTile('E.D.', _erectileDysfunction, (v) => setState(() => _erectileDysfunction = v ?? false)),
            _buildCheckboxTile('Prematu. ejaculation', _prematureEjaculation, (v) => setState(() => _prematureEjaculation = v ?? false)),
            _buildCheckboxTile('Retarded ejaculation', _retardedEjaculation, (v) => setState(() => _retardedEjaculation = v ?? false)),
            _buildCheckboxTile('Worry rel.to Mast/NE', _worryMasturbationNE, (v) => setState(() => _worryMasturbationNE = v ?? false)),
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
            _buildCheckboxTile('Ideas/Del. of persecution', _ideasDelPersecution, (v) => setState(() => _ideasDelPersecution = v ?? false)),
            _buildCheckboxTile('Ideas/Del. of reference', _ideasDelReference, (v) => setState(() => _ideasDelReference = v ?? false)),
            _buildCheckboxTile('Other delusions', _otherDelusions, (v) => setState(() => _otherDelusions = v ?? false)),
            _buildCheckboxTile('F.R.S. (First Rank)', _firstRankSymptoms, (v) => setState(() => _firstRankSymptoms = v ?? false)),
            _buildCheckboxTile('Hallucinations - Auditory', _hallucinationsAuditory, (v) => setState(() => _hallucinationsAuditory = v ?? false)),
            _buildCheckboxTile('Hallucinations - Visual', _hallucinationsVisual, (v) => setState(() => _hallucinationsVisual = v ?? false)),
            _buildCheckboxTile('Incoherence', _incoherence, (v) => setState(() => _incoherence = v ?? false)),
            _buildCheckboxTile('Muttering to self', _mutteringToSelf, (v) => setState(() => _mutteringToSelf = v ?? false)),
            _buildCheckboxTile('Inappropriate smiling', _inappropriateSmiling, (v) => setState(() => _inappropriateSmiling = v ?? false)),
            _buildCheckboxTile('Inappropriate weeping', _inappropriateWeeping, (v) => setState(() => _inappropriateWeeping = v ?? false)),
            _buildCheckboxTile('Abusing', _abusing, (v) => setState(() => _abusing = v ?? false)),
            _buildCheckboxTile('Violence', _violence, (v) => setState(() => _violence = v ?? false)),
            _buildCheckboxTile('Withdrawal/Inertia', _withdrawalInertia, (v) => setState(() => _withdrawalInertia = v ?? false)),
          ],
        ),
        const SizedBox(height: 16),
        
        // Manic Symptoms
        _buildSectionCard(
          context,
          title: 'Manic Symptoms',
          color: Colors.amber,
          children: [
            _buildCheckboxTile('Irritable/Elated', _irritableElated, (v) => setState(() => _irritableElated = v ?? false)),
            _buildCheckboxTile('Grandiose', _grandiose, (v) => setState(() => _grandiose = v ?? false)),
            _buildCheckboxTile('Overtalkative', _overtalkative, (v) => setState(() => _overtalkative = v ?? false)),
            _buildCheckboxTile('Flight of Ideas', _flightOfIdeas, (v) => setState(() => _flightOfIdeas = v ?? false)),
            _buildCheckboxTile('Overactive/PMA', _overactivePMA, (v) => setState(() => _overactivePMA = v ?? false)),
            _buildCheckboxTile('Extravagant', _extravagant, (v) => setState(() => _extravagant = v ?? false)),
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
            _buildCheckboxTile('Sad - intermittent', _sadIntermittent, (v) => setState(() => _sadIntermittent = v ?? false)),
            _buildCheckboxTile('Sad - persistent', _sadPersistent, (v) => setState(() => _sadPersistent = v ?? false)),
            _buildCheckboxTile('Anhedonia/Inertia', _anhedoniaInertia, (v) => setState(() => _anhedoniaInertia = v ?? false)),
            _buildCheckboxTile('Diurnal change', _diurnalChange, (v) => setState(() => _diurnalChange = v ?? false)),
            _buildCheckboxTile('Weight loss', _weightLoss, (v) => setState(() => _weightLoss = v ?? false)),
            _buildCheckboxTile('Weight gain', _weightGain, (v) => setState(() => _weightGain = v ?? false)),
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
            _buildCheckboxTile('Hypersomnia', _hypersomnia, (v) => setState(() => _hypersomnia = v ?? false)),
            _buildCheckboxTile('PMR/PMA', _pmrPma, (v) => setState(() => _pmrPma = v ?? false)),
            _buildCheckboxTile('Fatigue', _fatigue, (v) => setState(() => _fatigue = v ?? false)),
            _buildCheckboxTile('Worthlessness/Guilt', _worthlessnessGuilt, (v) => setState(() => _worthlessnessGuilt = v ?? false)),
            _buildCheckboxTile('↓Thinking/Conc.', _decreasedThinkingConcentration, (v) => setState(() => _decreasedThinkingConcentration = v ?? false)),
            _buildCheckboxTile('Indecisive', _indecisive, (v) => setState(() => _indecisive = v ?? false)),
            const Divider(),
            _buildCheckboxTile('Suicidal thoughts', _suicidalThoughts, (v) => setState(() => _suicidalThoughts = v ?? false), isWarning: true),
            _buildCheckboxTile('Suicidal plans', _suicidalPlans, (v) => setState(() => _suicidalPlans = v ?? false), isWarning: true),
            _buildCheckboxTile('Suicidal attempts', _suicidalAttempts, (v) => setState(() => _suicidalAttempts = v ?? false), isDanger: true),
          ],
        ),
        const SizedBox(height: 16),
        
        // Cognitive Symptoms
        _buildSectionCard(
          context,
          title: 'Cognitive/Dementia',
          color: Colors.brown,
          children: [
            _buildCheckboxTile('Disorientation - time', _disorientationTime, (v) => setState(() => _disorientationTime = v ?? false)),
            _buildCheckboxTile('Disorientation - place', _disorientationPlace, (v) => setState(() => _disorientationPlace = v ?? false)),
            _buildCheckboxTile('Disorientation - person', _disorientationPerson, (v) => setState(() => _disorientationPerson = v ?? false)),
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
            _buildCheckboxTile('Aphasia/apraxia/agnosia', _aphasiaApraxiaAgnosia, (v) => setState(() => _aphasiaApraxiaAgnosia = v ?? false)),
            _buildCheckboxTile('↓ Intelligence', _decreasedIntelligence, (v) => setState(() => _decreasedIntelligence = v ?? false)),
            _buildCheckboxTile('Perseveration', _perseveration, (v) => setState(() => _perseveration = v ?? false)),
            _buildCheckboxTile('Losing path', _losingPath, (v) => setState(() => _losingPath = v ?? false)),
            _buildCheckboxTile('Disinhibition', _disinhibition, (v) => setState(() => _disinhibition = v ?? false)),
            _buildCheckboxTile('Incontinence urine', _incontinenceUrine, (v) => setState(() => _incontinenceUrine = v ?? false)),
            _buildCheckboxTile('Incontinence stools', _incontinenceStools, (v) => setState(() => _incontinenceStools = v ?? false)),
            _buildCheckboxTile('Emotional Lability', _emotionalLability, (v) => setState(() => _emotionalLability = v ?? false)),
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
      onChanged: onChanged,
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
