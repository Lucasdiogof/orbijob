/// Identifies the language of a job text from the text itself, locally and for every platform (no network, no plugin).
///
/// Why this exists: the catalogue's `language` column is empty for real listings and the country says nothing about the text
/// (a listing in Germany is often in English; many German listings carry no country at all). Two signals are combined:
///  * script (Han, Kana, Hangul, Cyrillic, Arabic, …), which settles most non-Latin text outright;
///  * for Latin text, how many of the words are very frequent function words of each candidate language, plus a few
///    characteristic letters. The result carries a confidence; a text that is too short or ambiguous returns null,
///    never a guess.
library;

class DetectedLanguage {
  const DetectedLanguage(this.code, this.confidence, {this.script});

  /// BCP-47 primary subtag (`de`, `sv`, `zh`, …).
  final String code;

  /// 0..1: the share of the evidence that supports [code] over the runner-up.
  final double confidence;

  /// `Hant` or `Hans` for Chinese when the characters tell them apart.
  final String? script;

  @override
  String toString() => '$code${script == null ? '' : '-$script'} ($confidence)';
}

// Characters that exist only in Traditional / only in Simplified Chinese (a small, high-signal sample).
const _hantOnly = '們這個為與來時會說國學後發對從開關門問間點經現當學師電話體讓請應該義過還與務員聯歲條處響營區無開';
const _hansOnly = '们这个为与来时会说国学后发对从开关门问间点经现当师电话体让请应该义过还务员联岁条处响营区无开';

const _stop = <String, String>{
  'en': 'the and of to in for with a an is are be as on at by or this that you will our we your from have has can it their about all not more work team role experience skills working join looking ability including such who which',
  'de': 'und der die das den dem des ein eine einen einer eines mit für von zu im ist sind wir sie ihr ihre bei auf als auch oder nach über aus durch sich nicht wird werden haben unser unsere deine dein du uns wenn zum zur dass bis einer',
  'sv': 'och att som en ett är för med på av till det den har vi du vill inte om vara kan hos från din dina våra vår ska eller men även alla där ditt dig samt så vid sig när',
  'da': 'og at det en den til er som på de med for af ikke der vi du har om kan vil jeres vores din dig men eller også hos fra være',
  'no': 'og å det en den til er som på de med for av ikke vi du har om kan vil din deg men eller også hos fra være dere vår våre',
  'fi': 'ja on ei että se oli hän mutta kun sekä tai joka sinun meidän olet voit työ meille kanssa tehtävä myös ovat tämä vuotta',
  'nl': 'de het een en van in is dat op te voor met zijn niet aan er maar om ook als bij wij je jij onze ons wat naar uit worden kan heeft',
  'fr': 'le la les de des du un une et en pour dans que qui est sont avec sur au aux ce cette nous vous votre notre ses par pas plus ou ne se être poste équipe',
  'es': 'el la los las de del un una y en para con que es son por se su sus al lo como más pero o este esta nuestro nuestra trabajo equipo experiencia puesto tu usted',
  'pt': 'o a os as de do da dos das um uma e em para com que é são por se seu sua ao como mais mas ou este esta nosso nossa trabalho equipe experiência vaga você nós',
  'it': 'il lo la i gli le di del della un una e in per con che è sono da si suo sua al come più ma o questo questa nostro nostra lavoro squadra esperienza',
  'pl': 'i w na z do nie się jest to że o jak po za dla przez od ale lub oraz nasz nasza praca zespół doświadczenie będzie są',
  'cs': 'a v na se je to že do pro s o jak po za od ale nebo naše práce tým zkušenosti bude jsou',
  'ro': 'și în de la cu pe nu este care un o pentru sau mai din că ca noi echipa experiență',
  'tr': 've bir bu için ile de da çok daha olarak gibi veya ancak biz sizin deneyim ekip',
  'hu': 'és a az egy hogy nem is de van meg csapat munka tapasztalat vagy',
};

// Letters that point to a language even in short text.
const _marks = <String, String>{
  'de': 'äöüß',
  'sv': 'åäö',
  'da': 'æøå',
  'no': 'æøå',
  'fi': 'äö',
  'fr': 'éèêàçùûôîœ',
  'es': 'ñ¿¡áéíóú',
  'pt': 'ãõçáéíóúâêô',
  'it': 'àèéìòù',
  'pl': 'ąćęłńóśźż',
  'cs': 'ěščřžýáíé',
  'ro': 'ăâîșț',
  'tr': 'ğışçö',
  'hu': 'őű',
  'nl': '',
  'en': '',
};

final _wordRe = RegExp(r"[\p{L}']+", unicode: true);

DetectedLanguage? detectLanguage(String text, {int minWords = 6}) {
  final sample = text.length > 4000 ? text.substring(0, 4000) : text;
  final script = _byScript(sample);
  if (script != null) return script;

  final words = [
    for (final m in _wordRe.allMatches(sample.toLowerCase())) m.group(0)!,
  ];
  if (words.length < minWords) return null;

  final scores = <String, double>{};
  for (final e in _stopSets.entries) {
    var hits = 0;
    for (final w in words) {
      if (e.value.contains(w)) hits++;
    }
    var score = hits / words.length;
    final marks = _marks[e.key] ?? '';
    if (marks.isNotEmpty) {
      var m = 0;
      for (final r in sample.toLowerCase().runes) {
        if (marks.contains(String.fromCharCode(r))) m++;
      }
      // letters like ä/å are strong, but only a nudge: stop words stay the main evidence
      score += (m / sample.length).clamp(0, 0.04) * 1.5;
    }
    scores[e.key] = score;
  }
  final ranked = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final best = ranked.first;
  final second = ranked[1];
  // not enough function words, or two languages too close: say nothing rather than guess
  if (best.value < 0.08) return null;
  final conf = best.value <= 0 ? 0.0 : (best.value - second.value) / best.value;
  if (conf < 0.18) return null;
  return DetectedLanguage(best.key, conf.clamp(0, 1).toDouble());
}

final Map<String, Set<String>> _stopSets = {
  for (final e in _stop.entries) e.key: e.value.split(RegExp(r'\s+')).toSet(),
};

DetectedLanguage? _byScript(String s) {
  var han = 0, kana = 0, hangul = 0, cyr = 0, arab = 0, greek = 0, hebrew = 0;
  var thai = 0, deva = 0, latin = 0, total = 0;
  for (final r in s.runes) {
    if (r <= 0x40) continue; // digits, punctuation, spaces
    if ((r >= 0x4E00 && r <= 0x9FFF) || (r >= 0x3400 && r <= 0x4DBF)) {
      han++;
    } else if (r >= 0x3040 && r <= 0x30FF) {
      kana++;
    } else if ((r >= 0xAC00 && r <= 0xD7AF) || (r >= 0x1100 && r <= 0x11FF)) {
      hangul++;
    } else if (r >= 0x0400 && r <= 0x04FF) {
      cyr++;
    } else if (r >= 0x0600 && r <= 0x06FF) {
      arab++;
    } else if (r >= 0x0370 && r <= 0x03FF) {
      greek++;
    } else if (r >= 0x0590 && r <= 0x05FF) {
      hebrew++;
    } else if (r >= 0x0E00 && r <= 0x0E7F) {
      thai++;
    } else if (r >= 0x0900 && r <= 0x097F) {
      deva++;
    } else if ((r >= 0x41 && r <= 0x24F)) {
      latin++;
    } else {
      continue;
    }
    total++;
  }
  if (total < 4) return null;
  double share(int n) => n / total;
  // CJK titles are short and are often mixed with Latin brand names: a modest share of Han is enough
  final cjk = han + kana;
  if (kana > 0 && share(cjk) > 0.25 && kana >= han * 0.1) {
    return DetectedLanguage('ja', share(cjk).clamp(0, 1).toDouble());
  }
  if (share(hangul) > 0.25) {
    return DetectedLanguage('ko', share(hangul).clamp(0, 1).toDouble());
  }
  if (share(han) > 0.2) {
    var hant = 0, hans = 0;
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      if (_hantOnly.contains(c)) hant++;
      if (_hansOnly.contains(c)) hans++;
    }
    return DetectedLanguage(
      'zh',
      share(han).clamp(0, 1).toDouble(),
      script: hant > hans ? 'Hant' : (hans > hant ? 'Hans' : null),
    );
  }
  if (share(cyr) > 0.5) return const DetectedLanguage('ru', 0.6);
  if (share(arab) > 0.5) return const DetectedLanguage('ar', 0.8);
  if (share(greek) > 0.5) return const DetectedLanguage('el', 0.9);
  if (share(hebrew) > 0.5) return const DetectedLanguage('he', 0.9);
  if (share(thai) > 0.5) return const DetectedLanguage('th', 0.9);
  if (share(deva) > 0.5) return const DetectedLanguage('hi', 0.6);
  if (share(latin) > 0.5) return null; // Latin: decided by words
  return null;
}
