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
  ]),
  psychology([
    'psycholog',
    'psicólog',
    'psicolog',
    'psychotherap',
    'psicoterap',
    'counselor',
    'counsellor',
  ]),
  occupationalTherapy([
    'occupational therap',
    'terapeuta ocupacional',
    'terapia ocupacional',
    'ergotherap',
  ]),
  nutrition([
    'dietitian',
    'dietician',
    'nutritionist',
    'nutricionista',
    'ernährungsberat',
  ]),
  dentistry([
    'dentist',
    'dental hygienist',
    'dentista',
    'odontolog',
    'cirurgião-dentista',
    'zahnarzt',
    'zahnärzt',
  ]),
  pharmacy([
    'pharmacist',
    'pharmacy technician',
    'farmacêutic',
    'farmacéutic',
    'apotheker',
  ]),
  speechTherapy([
    'speech therap',
    'speech-language',
    'speech language',
    'fonoaudiólog',
    'fonoaudiolog',
    'logopäd',
    'logopeda',
  ]),
  radiology([
    'radiolog',
    'radiographer',
    'sonographer',
    'ultrasound tech',
    'técnico em radiologia',
    'tecnólogo em radiologia',
    'mri tech',
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
    final own = keywords.any(t.contains);
    final p = parent;
    return own && (p == null || p.matches(title));
  }

  static List<HealthSpecialty> of(String title) => [
    for (final s in HealthSpecialty.values)
      if (s.matches(title)) s,
  ];
}
