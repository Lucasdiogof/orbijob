# Automatic translation of listings (pt-BR / en / es)

Listings stay in the language of their source in the database. OrbiJob translates them **on the device, on demand**, into the
interface language, shows the original one tap away, and says plainly that the translation is automatic.

## What the catalogue really contains (checked against the live database, 2026-10-13)
- `jobs.language` is **empty for every real listing**, and the country does not tell the language: listings in DE/FR/JP/ES/MX are mostly
  English, many German listings have no country at all, Swedish listings are Swedish, Taiwan listings are Traditional Chinese.
- So the language is identified **from the text itself** (`language_detector.dart`: script analysis plus function-word profiles for
  ~16 Latin-script languages; returns nothing rather than guessing when the text is too short or ambiguous). The source's own
  declaration is used only as a fallback. Tests run it against 18 real listings.

## Options evaluated
| Option | Free & sustainable | Platforms | Verdict |
|---|---|---|---|
| **Google ML Kit on-device translation** (`google_mlkit_translation`) | Yes: no account, no quota, offline after a ~30 MB per-language download; free under ML Kit terms | Android, iOS (not web) | **Chosen for mobile.** 59 languages incl. German, Swedish, Chinese, Portuguese, Spanish, English. Non-English pairs go through English (lower quality). One "Chinese" (no Traditional/Simplified split), weaker quality |
| **Browser Translator API** (Chrome/Edge 138+, desktop) | Yes: model runs inside the browser, nothing is sent | Web, Chromium desktop only | **Chosen for web** (feature-detected; other browsers get "unavailable") |
| Cloudflare Workers AI `m2m100-1.2b` | Free tier is 10,000 neurons/day (≈0.3 M tokens: a few hundred listings/day) and needs a deployed Worker + credentials; the project decided not to deploy a Worker | all | Rejected as primary (quota too small for a global catalogue, extra infrastructure, owner credentials). Possible future shared cache |
| Self-hosted Opus-MT / NLLB (GitHub Actions batch) | Compute is free for a public repo but slow on CPU; Opus-MT is CC-BY, **NLLB is CC-BY-NC** (not usable) | all | Not built: a batch of the whole catalogue contradicts "on demand" and the scheduled runs are unreliable |
| LibreTranslate public instances, MyMemory, Lingva | Rate limits / scraping, unstable | all | Rejected |
| Apple Translation framework | Free, iOS 17.4+ only, no stable Flutter API | iOS | Not used (ML Kit covers iOS) |

## How it works
`lib/features/translation/`
- `language_detector.dart`: identification from the text (never from the country).
- `text_protection.dart`: URLs, e-mails, salary figures, reference codes, gender markers `(m/w/d)`, language levels (B2, N2…),
  licence classes and **acronyms** (professional registers such as CREFITO, certifications) and the company name are replaced by
  markers before the engine sees the text and put back after. A line is only used when every marker comes back exactly once. Second
  level for engines that mangle markers next to non-Latin text: acronyms stay in the text and must come back verbatim (case is
  restored). If neither holds, **that line stays in the original** (the result is flagged "partial"). Real run on Android: ML Kit
  turned `CREFITO` into "creço" and `(m/w/d)` into `(m / w / d)` when unprotected; with protection both are exact.
- `translation_service.dart`: line-by-line translation (keeps bullets and blank lines), cache key = job + field + target language +
  fingerprint of the ORIGINAL text (an updated listing misses the cache), at most 2 engine calls in parallel across all screens,
  identical requests share one run, failures back off for 45 s (explicit "try again" bypasses it), texts above 8,000 characters are
  cut at a line break and flagged as partial.
- `translation_cubit.dart`: what to translate and when. Cards ask for their **title** when they are built (only when the language
  data is already on the device: lists never download anything); the detail screen asks for title + description, and offers the
  download when needed. Language change: the target follows the app language immediately (`translation_target_sync.dart`); results
  for a language already done come from the cache.
- `mlkit_engine.dart` (Android/iOS), `web_translator_engine.dart` (web), `NoTranslationEngine` (everything else).
- UI: translated mark on cards, "Translated from Deutsch automatically. It may contain errors." with **Show original / Show
  translation** on the detail screen, a download offer, honest messages for unsupported, failed and partial cases, a switch and
  "clear saved translations" in Settings → Translation. A translated title is never paired with an untranslated description
  without saying so (the detail shows translated text only when both parts are translated).
- The originals are never modified or replaced in the data; search runs on the original text.
- In the in-app browser the page is the site's own: nothing is injected; a dismissible notice says the page may be in another language.

## Privacy, memory, storage, performance
- The text of a listing is translated by a model on the device; nothing is sent to a translation server.
- ML Kit language data: ~30 MB per language, downloaded only after the person agrees (detail screen); translators are closed after
  20 s of inactivity so the model does not stay in memory.
- Saved translations: at most 400 entries / ~2 MB in local storage, evicting the oldest.
- Measured on the Android emulator: 0.3–1.1 s per ~700-character text; 6–11 s per language download.

## Quality (honest)
- Swedish and German → English/Portuguese/Spanish: understandable, with typical machine-translation roughness; job-specific terms can
  be wrong (for example "Fachinformatiker" became "specialist system integration" in one title).
- Traditional Chinese: weak. Real titles came out like "Regularrants" or "Holiday Industry"; descriptions keep the sense of duties
  and pay figures but not nuance. The original is always one tap away and the note says it may contain errors.
- Requirements such as diplomas, registrations, visas, required languages and certifications can be mistranslated by any engine.
  Acronyms, levels and licence classes are kept exact; everything else is machine translation: check the original before applying.

## Verified / not verified
- Verified: unit and widget tests (detector against real listings, protection, cache, concurrency, failures, language change,
  download flow, partial results, off switch); the full app on the Android emulator (Medium_Phone, Android 16 x86_64) against the real
  catalogue with real ML Kit models: Swedish, German and Traditional Chinese titles and a Swedish description translated into English,
  with marks and notes (`docs/design/orbijob-v2/50-52-*`).
- Not verified: iOS (no Mac here); the web engine against a real browser model (the embedded browser in this environment exposes the
  API but never answers `availability()`); physical devices; Portuguese/Spanish targets in the full app (covered by the engine
  probe: sv/de/zh → pt/es translated on the emulator, and by tests).
- Limits: web translation works only in Chromium desktop browsers that ship the Translator API; Firefox, Safari and mobile browsers
  show the original with a note. ML Kit supports 59 languages; others (for example Thai script variants beyond its list) show the original.
