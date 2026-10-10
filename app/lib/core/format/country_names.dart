/// Names of countries by ISO 3166-1 alpha-2 code in the three interface languages (en, pt, es).
///
/// Only codes in this table are translated; any other value (a region such as EMEA, a name the source wrote, an unknown code)
/// is shown exactly as stored. A place is never invented or guessed.
const Map<String, (String en, String pt, String es)> _countries = {
  'AE': (
    'United Arab Emirates',
    'Emirados Árabes Unidos',
    'Emiratos Árabes Unidos',
  ),
  'AR': ('Argentina', 'Argentina', 'Argentina'),
  'AT': ('Austria', 'Áustria', 'Austria'),
  'AU': ('Australia', 'Austrália', 'Australia'),
  'BE': ('Belgium', 'Bélgica', 'Bélgica'),
  'BG': ('Bulgaria', 'Bulgária', 'Bulgaria'),
  'BO': ('Bolivia', 'Bolívia', 'Bolivia'),
  'BR': ('Brazil', 'Brasil', 'Brasil'),
  'CA': ('Canada', 'Canadá', 'Canadá'),
  'CH': ('Switzerland', 'Suíça', 'Suiza'),
  'CL': ('Chile', 'Chile', 'Chile'),
  'CN': ('China', 'China', 'China'),
  'CO': ('Colombia', 'Colômbia', 'Colombia'),
  'CR': ('Costa Rica', 'Costa Rica', 'Costa Rica'),
  'CY': ('Cyprus', 'Chipre', 'Chipre'),
  'CZ': ('Czechia', 'Tchéquia', 'Chequia'),
  'DE': ('Germany', 'Alemanha', 'Alemania'),
  'DK': ('Denmark', 'Dinamarca', 'Dinamarca'),
  'DO': ('Dominican Republic', 'República Dominicana', 'República Dominicana'),
  'EC': ('Ecuador', 'Equador', 'Ecuador'),
  'EE': ('Estonia', 'Estônia', 'Estonia'),
  'EG': ('Egypt', 'Egito', 'Egipto'),
  'ES': ('Spain', 'Espanha', 'España'),
  'FI': ('Finland', 'Finlândia', 'Finlandia'),
  'FR': ('France', 'França', 'Francia'),
  'GB': ('United Kingdom', 'Reino Unido', 'Reino Unido'),
  'GR': ('Greece', 'Grécia', 'Grecia'),
  'GT': ('Guatemala', 'Guatemala', 'Guatemala'),
  'HK': ('Hong Kong', 'Hong Kong', 'Hong Kong'),
  'HR': ('Croatia', 'Croácia', 'Croacia'),
  'HU': ('Hungary', 'Hungria', 'Hungría'),
  'ID': ('Indonesia', 'Indonésia', 'Indonesia'),
  'IE': ('Ireland', 'Irlanda', 'Irlanda'),
  'IL': ('Israel', 'Israel', 'Israel'),
  'IN': ('India', 'Índia', 'India'),
  'IT': ('Italy', 'Itália', 'Italia'),
  'JP': ('Japan', 'Japão', 'Japón'),
  'KE': ('Kenya', 'Quênia', 'Kenia'),
  'KR': ('South Korea', 'Coreia do Sul', 'Corea del Sur'),
  'LT': ('Lithuania', 'Lituânia', 'Lituania'),
  'LV': ('Latvia', 'Letônia', 'Letonia'),
  'MX': ('Mexico', 'México', 'México'),
  'MY': ('Malaysia', 'Malásia', 'Malasia'),
  'NG': ('Nigeria', 'Nigéria', 'Nigeria'),
  'NL': ('Netherlands', 'Países Baixos', 'Países Bajos'),
  'NO': ('Norway', 'Noruega', 'Noruega'),
  'NZ': ('New Zealand', 'Nova Zelândia', 'Nueva Zelanda'),
  'PA': ('Panama', 'Panamá', 'Panamá'),
  'PE': ('Peru', 'Peru', 'Perú'),
  'PH': ('Philippines', 'Filipinas', 'Filipinas'),
  'PL': ('Poland', 'Polônia', 'Polonia'),
  'PT': ('Portugal', 'Portugal', 'Portugal'),
  'PY': ('Paraguay', 'Paraguai', 'Paraguay'),
  'RO': ('Romania', 'Romênia', 'Rumania'),
  'RS': ('Serbia', 'Sérvia', 'Serbia'),
  'SE': ('Sweden', 'Suécia', 'Suecia'),
  'SG': ('Singapore', 'Singapura', 'Singapur'),
  'SI': ('Slovenia', 'Eslovênia', 'Eslovenia'),
  'SK': ('Slovakia', 'Eslováquia', 'Eslovaquia'),
  'TH': ('Thailand', 'Tailândia', 'Tailandia'),
  'TR': ('Türkiye', 'Turquia', 'Turquía'),
  'UA': ('Ukraine', 'Ucrânia', 'Ucrania'),
  'US': ('United States', 'Estados Unidos', 'Estados Unidos'),
  'UY': ('Uruguay', 'Uruguai', 'Uruguay'),
  'VN': ('Vietnam', 'Vietnã', 'Vietnam'),
  'ZA': ('South Africa', 'África do Sul', 'Sudáfrica'),
};

/// Localized country name, or null when [code] is not a recognised ISO alpha-2 code (the caller then shows the value as stored).
String? countryName(String code, String languageCode) {
  final c = _countries[code.trim().toUpperCase()];
  if (c == null || code.trim().length != 2) return null;
  return switch (languageCode) {
    'pt' => c.$2,
    'es' => c.$3,
    _ => c.$1,
  };
}

/// Region names published by the source. Acronyms are kept; only the plain word is translated. Never expanded into countries.
const Set<String> regionAcronyms = {'EMEA', 'APAC', 'LATAM'};

String? regionName(String token, String languageCode) {
  if (regionAcronyms.contains(token)) return token;
  if (token == 'Europe') {
    return switch (languageCode) {
      'pt' || 'es' => 'Europa',
      _ => 'Europe',
    };
  }
  return null;
}
