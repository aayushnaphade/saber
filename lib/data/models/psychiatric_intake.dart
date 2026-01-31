/// Psychiatric Intake Form Model
/// Based on Dr. Monisha Dass's clinical intake form format
/// This captures comprehensive psychiatric evaluation data

class PsychiatricIntake {
  final String id;
  final String patientId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Header Information
  final String? caseNumber;
  final DateTime? dateOfExamination;
  final String? education;
  final String? occupation;
  final String? residence;
  final String? informants;
  final String? durationOfIllness;
  final String? referredBy;
  final String? precipitatingFactor;
  
  // Anxiety & Related Symptoms
  final bool anxietyWorry;
  final bool panic;
  final bool restless;
  final bool palpitationsTremors;
  final bool phobia;
  final bool obsessions;
  final bool compulsions;
  final bool hypochondriacal;
  final bool fitsHystEpileptic;
  final bool possessionState;
  
  // Somatic Symptoms
  final bool somaticHeadache;
  final bool somaticBodyache;
  final bool somaticAbdominal;
  final String? somaticOther;
  
  // Substance Use
  final String? substanceUse; // use/abuse/dependence
  final bool alcoholDrugsTobacco;
  
  // Sexual Dysfunction
  final bool decreasedLibido;
  final bool increasedLibido;
  final bool erectileDysfunction;
  final bool prematureEjaculation;
  final bool retardedEjaculation;
  final bool worryMasturbationNE;
  final String? sexualDysfunctionOther;
  
  // Psychotic Symptoms
  final bool ideasDelPersecution;
  final bool ideasDelReference;
  final bool otherDelusions;
  final bool firstRankSymptoms;
  final bool hallucinationsAuditory;
  final bool hallucinationsVisual;
  final bool incoherence;
  final bool mutteringToSelf;
  final bool inappropriateSmiling;
  final bool inappropriateWeeping;
  final bool abusing;
  final bool violence;
  final bool withdrawalInertia;
  
  // Manic Symptoms
  final bool irritableElated;
  final bool grandiose;
  final bool overtalkative;
  final bool flightOfIdeas;
  final bool overactivePMA;
  final bool extravagant;
  
  // Depressive Symptoms
  final bool sadIntermittent;
  final bool sadPersistent;
  final bool anhedoniaInertia;
  final bool diurnalChange;
  final bool weightLoss;
  final bool weightGain;
  final String? insomniaType; // I-M-T-To (Initial/Middle/Terminal/Total)
  final bool hypersomnia;
  final bool pmrPma;
  final bool fatigue;
  final bool worthlessnessGuilt;
  final bool decreasedThinkingConcentration;
  final bool indecisive;
  final bool suicidalThoughts;
  final bool suicidalPlans;
  final bool suicidalAttempts;
  
  // Cognitive Symptoms
  final bool disorientationTime;
  final bool disorientationPlace;
  final bool disorientationPerson;
  final String? forgetfulness; // mild/mod/severe
  final bool aphasiaApraxiaAgnosia;
  final bool decreasedIntelligence;
  final bool perseveration;
  final bool losingPath;
  final bool disinhibition;
  final bool incontinenceUrine;
  final bool incontinenceStools;
  final bool emotionalLability;
  
  // Additional Information
  final String? medicalIllnesses;
  final String? stresses;
  final String? ongoingTreatment;
  final String? otherSymptoms;
  
  // Clinical Notes
  final String? clinicalNotes;
  final String? provisionalDiagnosis;

  const PsychiatricIntake({
    required this.id,
    required this.patientId,
    required this.createdAt,
    this.updatedAt,
    this.caseNumber,
    this.dateOfExamination,
    this.education,
    this.occupation,
    this.residence,
    this.informants,
    this.durationOfIllness,
    this.referredBy,
    this.precipitatingFactor,
    this.anxietyWorry = false,
    this.panic = false,
    this.restless = false,
    this.palpitationsTremors = false,
    this.phobia = false,
    this.obsessions = false,
    this.compulsions = false,
    this.hypochondriacal = false,
    this.fitsHystEpileptic = false,
    this.possessionState = false,
    this.somaticHeadache = false,
    this.somaticBodyache = false,
    this.somaticAbdominal = false,
    this.somaticOther,
    this.substanceUse,
    this.alcoholDrugsTobacco = false,
    this.decreasedLibido = false,
    this.increasedLibido = false,
    this.erectileDysfunction = false,
    this.prematureEjaculation = false,
    this.retardedEjaculation = false,
    this.worryMasturbationNE = false,
    this.sexualDysfunctionOther,
    this.ideasDelPersecution = false,
    this.ideasDelReference = false,
    this.otherDelusions = false,
    this.firstRankSymptoms = false,
    this.hallucinationsAuditory = false,
    this.hallucinationsVisual = false,
    this.incoherence = false,
    this.mutteringToSelf = false,
    this.inappropriateSmiling = false,
    this.inappropriateWeeping = false,
    this.abusing = false,
    this.violence = false,
    this.withdrawalInertia = false,
    this.irritableElated = false,
    this.grandiose = false,
    this.overtalkative = false,
    this.flightOfIdeas = false,
    this.overactivePMA = false,
    this.extravagant = false,
    this.sadIntermittent = false,
    this.sadPersistent = false,
    this.anhedoniaInertia = false,
    this.diurnalChange = false,
    this.weightLoss = false,
    this.weightGain = false,
    this.insomniaType,
    this.hypersomnia = false,
    this.pmrPma = false,
    this.fatigue = false,
    this.worthlessnessGuilt = false,
    this.decreasedThinkingConcentration = false,
    this.indecisive = false,
    this.suicidalThoughts = false,
    this.suicidalPlans = false,
    this.suicidalAttempts = false,
    this.disorientationTime = false,
    this.disorientationPlace = false,
    this.disorientationPerson = false,
    this.forgetfulness,
    this.aphasiaApraxiaAgnosia = false,
    this.decreasedIntelligence = false,
    this.perseveration = false,
    this.losingPath = false,
    this.disinhibition = false,
    this.incontinenceUrine = false,
    this.incontinenceStools = false,
    this.emotionalLability = false,
    this.medicalIllnesses,
    this.stresses,
    this.ongoingTreatment,
    this.otherSymptoms,
    this.clinicalNotes,
    this.provisionalDiagnosis,
  });

  /// Create from JSON (Supabase or local storage)
  factory PsychiatricIntake.fromJson(Map<String, dynamic> json) {
    return PsychiatricIntake(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
      caseNumber: json['case_number']?.toString(),
      dateOfExamination: json['date_of_examination'] != null
          ? DateTime.parse(json['date_of_examination'].toString())
          : null,
      education: json['education']?.toString(),
      occupation: json['occupation']?.toString(),
      residence: json['residence']?.toString(),
      informants: json['informants']?.toString(),
      durationOfIllness: json['duration_of_illness']?.toString(),
      referredBy: json['referred_by']?.toString(),
      precipitatingFactor: json['precipitating_factor']?.toString(),
      anxietyWorry: json['anxiety_worry'] as bool? ?? false,
      panic: json['panic'] as bool? ?? false,
      restless: json['restless'] as bool? ?? false,
      palpitationsTremors: json['palpitations_tremors'] as bool? ?? false,
      phobia: json['phobia'] as bool? ?? false,
      obsessions: json['obsessions'] as bool? ?? false,
      compulsions: json['compulsions'] as bool? ?? false,
      hypochondriacal: json['hypochondriacal'] as bool? ?? false,
      fitsHystEpileptic: json['fits_hyst_epileptic'] as bool? ?? false,
      possessionState: json['possession_state'] as bool? ?? false,
      somaticHeadache: json['somatic_headache'] as bool? ?? false,
      somaticBodyache: json['somatic_bodyache'] as bool? ?? false,
      somaticAbdominal: json['somatic_abdominal'] as bool? ?? false,
      somaticOther: json['somatic_other']?.toString(),
      substanceUse: json['substance_use']?.toString(),
      alcoholDrugsTobacco: json['alcohol_drugs_tobacco'] as bool? ?? false,
      decreasedLibido: json['decreased_libido'] as bool? ?? false,
      increasedLibido: json['increased_libido'] as bool? ?? false,
      erectileDysfunction: json['erectile_dysfunction'] as bool? ?? false,
      prematureEjaculation: json['premature_ejaculation'] as bool? ?? false,
      retardedEjaculation: json['retarded_ejaculation'] as bool? ?? false,
      worryMasturbationNE: json['worry_masturbation_ne'] as bool? ?? false,
      sexualDysfunctionOther: json['sexual_dysfunction_other']?.toString(),
      ideasDelPersecution: json['ideas_del_persecution'] as bool? ?? false,
      ideasDelReference: json['ideas_del_reference'] as bool? ?? false,
      otherDelusions: json['other_delusions'] as bool? ?? false,
      firstRankSymptoms: json['first_rank_symptoms'] as bool? ?? false,
      hallucinationsAuditory: json['hallucinations_auditory'] as bool? ?? false,
      hallucinationsVisual: json['hallucinations_visual'] as bool? ?? false,
      incoherence: json['incoherence'] as bool? ?? false,
      mutteringToSelf: json['muttering_to_self'] as bool? ?? false,
      inappropriateSmiling: json['inappropriate_smiling'] as bool? ?? false,
      inappropriateWeeping: json['inappropriate_weeping'] as bool? ?? false,
      abusing: json['abusing'] as bool? ?? false,
      violence: json['violence'] as bool? ?? false,
      withdrawalInertia: json['withdrawal_inertia'] as bool? ?? false,
      irritableElated: json['irritable_elated'] as bool? ?? false,
      grandiose: json['grandiose'] as bool? ?? false,
      overtalkative: json['overtalkative'] as bool? ?? false,
      flightOfIdeas: json['flight_of_ideas'] as bool? ?? false,
      overactivePMA: json['overactive_pma'] as bool? ?? false,
      extravagant: json['extravagant'] as bool? ?? false,
      sadIntermittent: json['sad_intermittent'] as bool? ?? false,
      sadPersistent: json['sad_persistent'] as bool? ?? false,
      anhedoniaInertia: json['anhedonia_inertia'] as bool? ?? false,
      diurnalChange: json['diurnal_change'] as bool? ?? false,
      weightLoss: json['weight_loss'] as bool? ?? false,
      weightGain: json['weight_gain'] as bool? ?? false,
      insomniaType: json['insomnia_type']?.toString(),
      hypersomnia: json['hypersomnia'] as bool? ?? false,
      pmrPma: json['pmr_pma'] as bool? ?? false,
      fatigue: json['fatigue'] as bool? ?? false,
      worthlessnessGuilt: json['worthlessness_guilt'] as bool? ?? false,
      decreasedThinkingConcentration: json['decreased_thinking_concentration'] as bool? ?? false,
      indecisive: json['indecisive'] as bool? ?? false,
      suicidalThoughts: json['suicidal_thoughts'] as bool? ?? false,
      suicidalPlans: json['suicidal_plans'] as bool? ?? false,
      suicidalAttempts: json['suicidal_attempts'] as bool? ?? false,
      disorientationTime: json['disorientation_time'] as bool? ?? false,
      disorientationPlace: json['disorientation_place'] as bool? ?? false,
      disorientationPerson: json['disorientation_person'] as bool? ?? false,
      forgetfulness: json['forgetfulness']?.toString(),
      aphasiaApraxiaAgnosia: json['aphasia_apraxia_agnosia'] as bool? ?? false,
      decreasedIntelligence: json['decreased_intelligence'] as bool? ?? false,
      perseveration: json['perseveration'] as bool? ?? false,
      losingPath: json['losing_path'] as bool? ?? false,
      disinhibition: json['disinhibition'] as bool? ?? false,
      incontinenceUrine: json['incontinence_urine'] as bool? ?? false,
      incontinenceStools: json['incontinence_stools'] as bool? ?? false,
      emotionalLability: json['emotional_lability'] as bool? ?? false,
      medicalIllnesses: json['medical_illnesses']?.toString(),
      stresses: json['stresses']?.toString(),
      ongoingTreatment: json['ongoing_treatment']?.toString(),
      otherSymptoms: json['other_symptoms']?.toString(),
      clinicalNotes: json['clinical_notes']?.toString(),
      provisionalDiagnosis: json['provisional_diagnosis']?.toString(),
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (caseNumber != null) 'case_number': caseNumber,
      if (dateOfExamination != null) 'date_of_examination': dateOfExamination!.toIso8601String(),
      if (education != null) 'education': education,
      if (occupation != null) 'occupation': occupation,
      if (residence != null) 'residence': residence,
      if (informants != null) 'informants': informants,
      if (durationOfIllness != null) 'duration_of_illness': durationOfIllness,
      if (referredBy != null) 'referred_by': referredBy,
      if (precipitatingFactor != null) 'precipitating_factor': precipitatingFactor,
      'anxiety_worry': anxietyWorry,
      'panic': panic,
      'restless': restless,
      'palpitations_tremors': palpitationsTremors,
      'phobia': phobia,
      'obsessions': obsessions,
      'compulsions': compulsions,
      'hypochondriacal': hypochondriacal,
      'fits_hyst_epileptic': fitsHystEpileptic,
      'possession_state': possessionState,
      'somatic_headache': somaticHeadache,
      'somatic_bodyache': somaticBodyache,
      'somatic_abdominal': somaticAbdominal,
      if (somaticOther != null) 'somatic_other': somaticOther,
      if (substanceUse != null) 'substance_use': substanceUse,
      'alcohol_drugs_tobacco': alcoholDrugsTobacco,
      'decreased_libido': decreasedLibido,
      'increased_libido': increasedLibido,
      'erectile_dysfunction': erectileDysfunction,
      'premature_ejaculation': prematureEjaculation,
      'retarded_ejaculation': retardedEjaculation,
      'worry_masturbation_ne': worryMasturbationNE,
      if (sexualDysfunctionOther != null) 'sexual_dysfunction_other': sexualDysfunctionOther,
      'ideas_del_persecution': ideasDelPersecution,
      'ideas_del_reference': ideasDelReference,
      'other_delusions': otherDelusions,
      'first_rank_symptoms': firstRankSymptoms,
      'hallucinations_auditory': hallucinationsAuditory,
      'hallucinations_visual': hallucinationsVisual,
      'incoherence': incoherence,
      'muttering_to_self': mutteringToSelf,
      'inappropriate_smiling': inappropriateSmiling,
      'inappropriate_weeping': inappropriateWeeping,
      'abusing': abusing,
      'violence': violence,
      'withdrawal_inertia': withdrawalInertia,
      'irritable_elated': irritableElated,
      'grandiose': grandiose,
      'overtalkative': overtalkative,
      'flight_of_ideas': flightOfIdeas,
      'overactive_pma': overactivePMA,
      'extravagant': extravagant,
      'sad_intermittent': sadIntermittent,
      'sad_persistent': sadPersistent,
      'anhedonia_inertia': anhedoniaInertia,
      'diurnal_change': diurnalChange,
      'weight_loss': weightLoss,
      'weight_gain': weightGain,
      if (insomniaType != null) 'insomnia_type': insomniaType,
      'hypersomnia': hypersomnia,
      'pmr_pma': pmrPma,
      'fatigue': fatigue,
      'worthlessness_guilt': worthlessnessGuilt,
      'decreased_thinking_concentration': decreasedThinkingConcentration,
      'indecisive': indecisive,
      'suicidal_thoughts': suicidalThoughts,
      'suicidal_plans': suicidalPlans,
      'suicidal_attempts': suicidalAttempts,
      'disorientation_time': disorientationTime,
      'disorientation_place': disorientationPlace,
      'disorientation_person': disorientationPerson,
      if (forgetfulness != null) 'forgetfulness': forgetfulness,
      'aphasia_apraxia_agnosia': aphasiaApraxiaAgnosia,
      'decreased_intelligence': decreasedIntelligence,
      'perseveration': perseveration,
      'losing_path': losingPath,
      'disinhibition': disinhibition,
      'incontinence_urine': incontinenceUrine,
      'incontinence_stools': incontinenceStools,
      'emotional_lability': emotionalLability,
      if (medicalIllnesses != null) 'medical_illnesses': medicalIllnesses,
      if (stresses != null) 'stresses': stresses,
      if (ongoingTreatment != null) 'ongoing_treatment': ongoingTreatment,
      if (otherSymptoms != null) 'other_symptoms': otherSymptoms,
      if (clinicalNotes != null) 'clinical_notes': clinicalNotes,
      if (provisionalDiagnosis != null) 'provisional_diagnosis': provisionalDiagnosis,
    };
  }

  /// Get list of active symptoms for compact display
  List<String> getActiveSymptoms() {
    final symptoms = <String>[];
    
    // Anxiety Related
    if (anxietyWorry) symptoms.add('Anxiety/Worry');
    if (panic) symptoms.add('Panic');
    if (restless) symptoms.add('Restless');
    if (palpitationsTremors) symptoms.add('Palpitations/Tremors');
    if (phobia) symptoms.add('Phobia');
    if (obsessions) symptoms.add('Obsessions');
    if (compulsions) symptoms.add('Compulsions');
    
    // Psychotic
    if (ideasDelPersecution) symptoms.add('Del. of Persecution');
    if (ideasDelReference) symptoms.add('Del. of Reference');
    if (hallucinationsAuditory) symptoms.add('Auditory Hallucinations');
    if (hallucinationsVisual) symptoms.add('Visual Hallucinations');
    if (incoherence) symptoms.add('Incoherence');
    
    // Manic
    if (irritableElated) symptoms.add('Irritable/Elated');
    if (grandiose) symptoms.add('Grandiose');
    if (flightOfIdeas) symptoms.add('Flight of Ideas');
    if (overactivePMA) symptoms.add('Overactive/PMA');
    
    // Depressive
    if (sadPersistent) symptoms.add('Persistent Sadness');
    if (sadIntermittent) symptoms.add('Intermittent Sadness');
    if (anhedoniaInertia) symptoms.add('Anhedonia');
    if (fatigue) symptoms.add('Fatigue');
    if (worthlessnessGuilt) symptoms.add('Worthlessness/Guilt');
    if (suicidalThoughts) symptoms.add('Suicidal Thoughts');
    if (suicidalPlans) symptoms.add('Suicidal Plans');
    if (suicidalAttempts) symptoms.add('Suicidal Attempts');
    
    // Cognitive
    if (disorientationTime || disorientationPlace || disorientationPerson) {
      symptoms.add('Disorientation');
    }
    if (forgetfulness != null && forgetfulness!.isNotEmpty) {
      symptoms.add('Forgetfulness ($forgetfulness)');
    }
    if (emotionalLability) symptoms.add('Emotional Lability');
    
    // Substance
    if (alcoholDrugsTobacco) symptoms.add('Substance Use');
    
    return symptoms;
  }

  /// Get symptom categories with counts for summary
  Map<String, int> getSymptomCategoryCounts() {
    return {
      'Anxiety': [anxietyWorry, panic, restless, palpitationsTremors, phobia, obsessions, compulsions]
          .where((s) => s).length,
      'Psychotic': [ideasDelPersecution, ideasDelReference, otherDelusions, firstRankSymptoms,
          hallucinationsAuditory, hallucinationsVisual, incoherence, mutteringToSelf]
          .where((s) => s).length,
      'Manic': [irritableElated, grandiose, overtalkative, flightOfIdeas, overactivePMA, extravagant]
          .where((s) => s).length,
      'Depressive': [sadIntermittent, sadPersistent, anhedoniaInertia, fatigue, worthlessnessGuilt,
          suicidalThoughts, suicidalPlans, suicidalAttempts]
          .where((s) => s).length,
      'Cognitive': [disorientationTime, disorientationPlace, disorientationPerson,
          decreasedIntelligence, emotionalLability]
          .where((s) => s).length,
    };
  }

  /// Copy with modifications
  PsychiatricIntake copyWith({
    String? id,
    String? patientId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? caseNumber,
    DateTime? dateOfExamination,
    String? education,
    String? occupation,
    String? residence,
    String? informants,
    String? durationOfIllness,
    String? referredBy,
    String? precipitatingFactor,
    bool? anxietyWorry,
    bool? panic,
    bool? restless,
    bool? palpitationsTremors,
    bool? phobia,
    bool? obsessions,
    bool? compulsions,
    bool? hypochondriacal,
    bool? fitsHystEpileptic,
    bool? possessionState,
    bool? somaticHeadache,
    bool? somaticBodyache,
    bool? somaticAbdominal,
    String? somaticOther,
    String? substanceUse,
    bool? alcoholDrugsTobacco,
    bool? decreasedLibido,
    bool? increasedLibido,
    bool? erectileDysfunction,
    bool? prematureEjaculation,
    bool? retardedEjaculation,
    bool? worryMasturbationNE,
    String? sexualDysfunctionOther,
    bool? ideasDelPersecution,
    bool? ideasDelReference,
    bool? otherDelusions,
    bool? firstRankSymptoms,
    bool? hallucinationsAuditory,
    bool? hallucinationsVisual,
    bool? incoherence,
    bool? mutteringToSelf,
    bool? inappropriateSmiling,
    bool? inappropriateWeeping,
    bool? abusing,
    bool? violence,
    bool? withdrawalInertia,
    bool? irritableElated,
    bool? grandiose,
    bool? overtalkative,
    bool? flightOfIdeas,
    bool? overactivePMA,
    bool? extravagant,
    bool? sadIntermittent,
    bool? sadPersistent,
    bool? anhedoniaInertia,
    bool? diurnalChange,
    bool? weightLoss,
    bool? weightGain,
    String? insomniaType,
    bool? hypersomnia,
    bool? pmrPma,
    bool? fatigue,
    bool? worthlessnessGuilt,
    bool? decreasedThinkingConcentration,
    bool? indecisive,
    bool? suicidalThoughts,
    bool? suicidalPlans,
    bool? suicidalAttempts,
    bool? disorientationTime,
    bool? disorientationPlace,
    bool? disorientationPerson,
    String? forgetfulness,
    bool? aphasiaApraxiaAgnosia,
    bool? decreasedIntelligence,
    bool? perseveration,
    bool? losingPath,
    bool? disinhibition,
    bool? incontinenceUrine,
    bool? incontinenceStools,
    bool? emotionalLability,
    String? medicalIllnesses,
    String? stresses,
    String? ongoingTreatment,
    String? otherSymptoms,
    String? clinicalNotes,
    String? provisionalDiagnosis,
  }) {
    return PsychiatricIntake(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      caseNumber: caseNumber ?? this.caseNumber,
      dateOfExamination: dateOfExamination ?? this.dateOfExamination,
      education: education ?? this.education,
      occupation: occupation ?? this.occupation,
      residence: residence ?? this.residence,
      informants: informants ?? this.informants,
      durationOfIllness: durationOfIllness ?? this.durationOfIllness,
      referredBy: referredBy ?? this.referredBy,
      precipitatingFactor: precipitatingFactor ?? this.precipitatingFactor,
      anxietyWorry: anxietyWorry ?? this.anxietyWorry,
      panic: panic ?? this.panic,
      restless: restless ?? this.restless,
      palpitationsTremors: palpitationsTremors ?? this.palpitationsTremors,
      phobia: phobia ?? this.phobia,
      obsessions: obsessions ?? this.obsessions,
      compulsions: compulsions ?? this.compulsions,
      hypochondriacal: hypochondriacal ?? this.hypochondriacal,
      fitsHystEpileptic: fitsHystEpileptic ?? this.fitsHystEpileptic,
      possessionState: possessionState ?? this.possessionState,
      somaticHeadache: somaticHeadache ?? this.somaticHeadache,
      somaticBodyache: somaticBodyache ?? this.somaticBodyache,
      somaticAbdominal: somaticAbdominal ?? this.somaticAbdominal,
      somaticOther: somaticOther ?? this.somaticOther,
      substanceUse: substanceUse ?? this.substanceUse,
      alcoholDrugsTobacco: alcoholDrugsTobacco ?? this.alcoholDrugsTobacco,
      decreasedLibido: decreasedLibido ?? this.decreasedLibido,
      increasedLibido: increasedLibido ?? this.increasedLibido,
      erectileDysfunction: erectileDysfunction ?? this.erectileDysfunction,
      prematureEjaculation: prematureEjaculation ?? this.prematureEjaculation,
      retardedEjaculation: retardedEjaculation ?? this.retardedEjaculation,
      worryMasturbationNE: worryMasturbationNE ?? this.worryMasturbationNE,
      sexualDysfunctionOther: sexualDysfunctionOther ?? this.sexualDysfunctionOther,
      ideasDelPersecution: ideasDelPersecution ?? this.ideasDelPersecution,
      ideasDelReference: ideasDelReference ?? this.ideasDelReference,
      otherDelusions: otherDelusions ?? this.otherDelusions,
      firstRankSymptoms: firstRankSymptoms ?? this.firstRankSymptoms,
      hallucinationsAuditory: hallucinationsAuditory ?? this.hallucinationsAuditory,
      hallucinationsVisual: hallucinationsVisual ?? this.hallucinationsVisual,
      incoherence: incoherence ?? this.incoherence,
      mutteringToSelf: mutteringToSelf ?? this.mutteringToSelf,
      inappropriateSmiling: inappropriateSmiling ?? this.inappropriateSmiling,
      inappropriateWeeping: inappropriateWeeping ?? this.inappropriateWeeping,
      abusing: abusing ?? this.abusing,
      violence: violence ?? this.violence,
      withdrawalInertia: withdrawalInertia ?? this.withdrawalInertia,
      irritableElated: irritableElated ?? this.irritableElated,
      grandiose: grandiose ?? this.grandiose,
      overtalkative: overtalkative ?? this.overtalkative,
      flightOfIdeas: flightOfIdeas ?? this.flightOfIdeas,
      overactivePMA: overactivePMA ?? this.overactivePMA,
      extravagant: extravagant ?? this.extravagant,
      sadIntermittent: sadIntermittent ?? this.sadIntermittent,
      sadPersistent: sadPersistent ?? this.sadPersistent,
      anhedoniaInertia: anhedoniaInertia ?? this.anhedoniaInertia,
      diurnalChange: diurnalChange ?? this.diurnalChange,
      weightLoss: weightLoss ?? this.weightLoss,
      weightGain: weightGain ?? this.weightGain,
      insomniaType: insomniaType ?? this.insomniaType,
      hypersomnia: hypersomnia ?? this.hypersomnia,
      pmrPma: pmrPma ?? this.pmrPma,
      fatigue: fatigue ?? this.fatigue,
      worthlessnessGuilt: worthlessnessGuilt ?? this.worthlessnessGuilt,
      decreasedThinkingConcentration: decreasedThinkingConcentration ?? this.decreasedThinkingConcentration,
      indecisive: indecisive ?? this.indecisive,
      suicidalThoughts: suicidalThoughts ?? this.suicidalThoughts,
      suicidalPlans: suicidalPlans ?? this.suicidalPlans,
      suicidalAttempts: suicidalAttempts ?? this.suicidalAttempts,
      disorientationTime: disorientationTime ?? this.disorientationTime,
      disorientationPlace: disorientationPlace ?? this.disorientationPlace,
      disorientationPerson: disorientationPerson ?? this.disorientationPerson,
      forgetfulness: forgetfulness ?? this.forgetfulness,
      aphasiaApraxiaAgnosia: aphasiaApraxiaAgnosia ?? this.aphasiaApraxiaAgnosia,
      decreasedIntelligence: decreasedIntelligence ?? this.decreasedIntelligence,
      perseveration: perseveration ?? this.perseveration,
      losingPath: losingPath ?? this.losingPath,
      disinhibition: disinhibition ?? this.disinhibition,
      incontinenceUrine: incontinenceUrine ?? this.incontinenceUrine,
      incontinenceStools: incontinenceStools ?? this.incontinenceStools,
      emotionalLability: emotionalLability ?? this.emotionalLability,
      medicalIllnesses: medicalIllnesses ?? this.medicalIllnesses,
      stresses: stresses ?? this.stresses,
      ongoingTreatment: ongoingTreatment ?? this.ongoingTreatment,
      otherSymptoms: otherSymptoms ?? this.otherSymptoms,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      provisionalDiagnosis: provisionalDiagnosis ?? this.provisionalDiagnosis,
    );
  }
}
