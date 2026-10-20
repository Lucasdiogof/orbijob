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

## P0 fix: endless "Baixando dados de idioma..." and untranslated Explorar (20/10/2026)

**Before.** (1) `MlKitTranslationEngine.prepare` awaited `downloadModel`, which reports no progress and never answers when the Wi-Fi interface is up
but nothing reaches the internet: the detail screen stayed on "downloading" for ever, with no timeout, failure state or retry. (2) Lists never
fetched language data ("a list never downloads anything by itself"), so with no model on the device the Explorar cards kept German titles and
German contract text, and the detail showed the whole German description under the banner. (3) Contract and language chips were the source's raw
text ("Unbefristeter arbeitsvertrag, berufserfahren", "Deutsch").

**Root cause of the endless download:** an unbounded native future behind a status that has no other exit. The connectivity probe only says which
interface is up, not whether the internet answers, so Wi-Fi did not prove the download could finish.

**After.**
* `TranslationService.prepare` ends in `PrepareOutcome { ready, failed, timedOut }` and never waits more than `downloadTimeout` (3 min: two ~30 MB
  models at about 3 Mbit/s). Each translated chunk is bounded by `translateTimeout` (30 s). A late native download is not cancelled: the engine keeps
  one native download per language, so a retry joins it, and the next readiness check finds the installed data.
* State machine in `TranslationCubit` (detail): none, loading, ready/partial, needsDownload (policy "ask"/unknown network), waitingWifi, offlineNoModel,
  downloading, **downloadFailed** (new: failure or timeout), failed, unsupported. Every state has an exit; "Tentar novamente" on downloadFailed fetches
  again, on failed re-runs.
* Back-off for automatic downloads: 30 s after the first failure, doubling to 15 min; a tap on retry ignores it. One download per language pair at a
  time (shared by all cards and screens).
* Lists now start the download themselves when the policy allows (Wi-Fi/unmetered by default; mobile data only with "Sempre"; never with "Perguntar" or an
  unknown network, never on the web) and the cards that were waiting ask again when the data lands (`TranslationState.modelsVersion`). Requests are
  lazy (only built cards), deduplicated and served by the existing 2-way queue. `warmUp()` fetches only the interface language's own data (en -> target)
  once per language, from `TranslationTargetSync` and when the policy changes.
* Detail: while the translation is pending or failed, the foreign description is **not** shown; a card explains it and offers "Ver texto original". The banner
  texts no longer say "showing the original". Title, description, contract/seniority chip follow the same rule.
* Structured terms: `core/format/contract_labels.dart` maps contract/seniority words (de, fr, es, pt, sv, nl, en, fi, da/no) to the interface language through a
  fixed table, never free translation; unknown terms fall back to the on-device translation of that short text (field `contract`, same cache), then to the
  original. Language names use the interface language ("Alemão", "German", "Alemán") through `languageName`.
* Diagnostics: `developer.log` under `orbijob.translation` with language codes, outcome, duration and engine name; never any text.
* Cache (unchanged, verified by tests): persistent, key `jobId|field|target|hash(original)`, original never overwritten, survives restart, works offline.

**Per platform.** Android/iOS: ML Kit as above. Web: the browser's Translator API where present; policy downloads never start by themselves on the web
(the detail asks); the same timeouts apply. The title translation keeps the company name as written; URLs, ids, amounts and dates are not translated.

**Tests** (`app/test/translation/reliability_test.dart` and updates): de/fr/sv/es to pt translated, pt to pt untouched; hanging download ends in
downloadFailed and works after the data lands; back-off and manual retry; stuck engine ends as failed; 40 cards start one download and are translated
afterwards within the queue limit; mobile data and unknown network download nothing; warm-up once; persistence offline in a new session; language change;
contract table and language names; pt UI: card text, withheld description, "Ver texto original", large text. No test uses a paid or remote service.

**Not validated.** The real ML Kit download on the owner's iPhone (no device here): the fix is proven with a hanging fake engine, not with the real plugin.
Real translation quality of ML Kit is not asserted by tests (the fake wraps text). Still open on iOS/Chrome translator as before.
