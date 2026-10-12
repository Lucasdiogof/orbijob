/// Health specialties offered inside the Health area.
///
/// Same principle as [JobArea]: a deterministic rule on the job TITLE (case-insensitive, any language listed), nothing
/// guessed from the description or the employer. A specialty is narrower than the Health area on purpose: the area keeps
/// broad words such as "clinical" or "hospital", a specialty only names the profession itself, so a "Medical Billing
/// Specialist" or a hospital receptionist is never filed as a clinician. Gendered and plural forms are covered by stems
/// ("fisioterapeut" matches fisioterapeuta/fisioterapeutas; "enfermeir" matches enfermeiro/enfermeira).
///
/// [pelvicPhysio] is a refinement of [physiotherapy]: its titles also match physiotherapy, never the other way around.
enum HealthSpecialty {
  physiotherapy([
    'physiotherap',
    'physical therapist',
    'physical therapy',
    'fisioterap',
    'kinesiolog',
    'cinesiolog',
    'krankengymnast',
    'fysioterapeut',
    'sjukgymnast',
    '物理治療',
  ]),
  pelvicPhysio([
    'pelvic',
    'pélvic',
    'pelvic floor',
    'assoalho pélvico',
    'piso pélvico',
    'beckenboden',
    'uroginecol',
    'urogynecol',
    'urogynaecol',
    "women's health physio",
    'womens health physio',
    'saúde da mulher',
    'bäckenbotten',
    'kvinnohälsa',
    '骨盆底',
  ]),
  nursing([
    'nurse',
    'nursing',
    'enfermeir',
    'enfermagem',
    'enfermer',
    'técnico de enfermagem',
    'krankenpfleg',
    'pflegefachkraft',
    'gesundheits- und krankenpfleg',
    'krankenschwester',
    'sjuksköterska',
    '護理師',
    '護士',
  ]),
  medicine([
    'physician',
    'doctor of medicine',
    'medical doctor',
    'médico',
    'médica',
    'surgeon',
    'cirurgi',
    'psychiatrist',
    'psiquiatra',
    'cardiologist',
    'cardiologista',
    'oncologist',
    'oncologista',
    'neurologist',
    'neurologista',
    'pediatrician',
    'pediatra',
    'anesthesiologist',
    'anestesista',
    'radiologist',
    'assistenzarzt',
    'oberarzt',
    'ärztin',
    'facharzt',
    'läkare',
    '醫師',
  ]),
  psychology([
    'psycholog',
    'psicólog',
    'psicolog',
    'psychotherap',
    'psicoterap',
    'counselor',
    'counsellor',
    'psykolog',
    '心理師',
  ]),
  occupationalTherapy([
    'occupational therap',
    'terapeuta ocupacional',
    'terapia ocupacional',
    'ergotherap',
    'arbetsterapeut',
    '職能治療',
  ]),
  nutrition([
    'dietitian',
    'dietician',
    'nutritionist',
    'nutricionista',
    'ernährungsberat',
    'dietist',
    '營養師',
  ]),
  dentistry([
    'dentist',
    'dental hygienist',
    'dentista',
    'odontolog',
    'cirurgião-dentista',
    'zahnarzt',
    'zahnärzt',
    'tandläkare',
    'tandsköterska',
    'tandhygienist',
    '牙醫',
  ]),
  pharmacy([
    'pharmacist',
    'pharmacy technician',
    'farmacêutic',
    'farmacéutic',
    'apotheker',
    'apotekare',
    'receptarie',
    '藥師',
  ]),
  speechTherapy([
    'speech therap',
    'speech-language',
    'speech language',
    'fonoaudiólog',
    'fonoaudiolog',
    'logopäd',
    'logopeda',
    'logoped',
    '語言治療',
  ]),
  radiology([
    'radiolog',
    'radiographer',
    'sonographer',
    'ultrasound tech',
    'técnico em radiologia',
    'tecnólogo em radiologia',
    'mri tech',
    'röntgen',
    '放射師',
  ]),
  hospitalManagement([
    'hospital administrator',
    'healthcare administrator',
    'health services manager',
    'clinic manager',
    'practice manager',
    'gestor hospitalar',
    'gestão hospitalar',
    'administrador hospitalar',
    'gerente de clínica',
  ]);

  const HealthSpecialty(this.keywords);

  /// Lower-case fragments searched in the title.
  final List<String> keywords;

  /// The specialty this one refines, if any.
  HealthSpecialty? get parent =>
      this == pelvicPhysio ? HealthSpecialty.physiotherapy : null;

  /// PostgREST `or=(...)` body. For a refinement, the title must ALSO be a physiotherapy title (a "Pelvic Floor
  /// Ultrasound Sonographer" is not a pelvic physiotherapist).
  String get orFilter =>
      [for (final k in keywords) 'title.ilike.*$k*'].join(',');

  /// The same rule locally (previews and tests).
  bool matches(String title) {
    final t = title.toLowerCase();
    // "tandläkare" (dentist) contains "läkare" (doctor): a dentist is filed under dentistry, not medicine.
    if (this == medicine && _dentistWords.any(t.contains)) return false;
    final own = keywords.any(t.contains);
    final p = parent;
    return own && (p == null || p.matches(title));
  }

  static List<HealthSpecialty> of(String title) => [
    for (final s in HealthSpecialty.values)
      if (s.matches(title)) s,
  ];
}

const _dentistWords = ['tandläkare'];
