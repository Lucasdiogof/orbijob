# Offline reading and automatic translation (ORBI-001)

What the person already saw opens again without a connection, says when it was saved, and is replaced by itself when the connection returns. It never replaces a fresh answer and
never invents one. A search that was never made on the device needs the internet and says so; it does not show an error of the app.

## Searches, Home, Explore (`lib/features/search/data/`)
* `OfflineFirstSearchRepository` wraps the catalogue. The network is ALWAYS tried first (10 s limit, so a poor connection falls back instead of showing a skeleton for ever).
  Only when the catalogue could not be reached (`isConnectivityProblem`: no network, timeout, 5xx or statement timeout) and only for the FIRST page of a search already made
  does it answer from the cache; that result carries `cachedAt` and has no further pages. A denied/invalid answer, another search, another filter or a later page rethrows
  the original error.
* `PrefsSearchResultsCache` (shared preferences; in memory when storage is missing): key = sanitised text + country + filters; at most 12 searches, 40 jobs each, descriptions cut at 6,000 characters
  (the original language: translations are NEVER stored there), expiry 14 days (listings are volatile), a damaged entry or store is ignored. Only pages with jobs are stored.
* Screens: Explore and Home show a quiet "No connection · data saved on <date>" line (PT/EN/ES) with a try-again action; an unreachable catalogue with nothing saved says
  "No connection" / "Job catalogue unavailable" with what is needed, distinct from the generic error. While saved results (or an offline message) are on screen the search is retried
  quietly every 20 s (and by the button); only a fresh answer replaces them, with no loading state in between.
* Cleared at sign-out and after account deletion.

## The signed-in user's own lists (`ListMirror`, `lib/core/data/list_mirror.dart`)
* Favourites and applications: after every successful read the list is copied to the device, one copy per list and per user id (another account never reads it);
  without a connection the copy opens, dated. Reading only: saving a job, changing a stage, a note or a date, deleting, and the stage history still go to the server and fail with the usual
  message when offline (nothing is queued, so nothing is promised that does not exist). Removed at sign-out and after account deletion.

## Translation (docs/TRANSLATION.md)
* Translation stays on the device (ML Kit on Android/iOS, the browser translator on the web), no paid API, nothing stored in Supabase; the cache is local, keyed by job, field, language and
  a hash of the ORIGINAL text. The language data (≈ 30 MB per language) downloads by policy (`DownloadPolicy`: Wi-Fi only by default, always, or ask), in the background, shared between screens, with
  offline and waiting-for-Wi-Fi states. The original is always one tap away.
* Limits kept honest: the web translator exists only in Chromium desktop; Traditional Chinese quality is weak; requirements (diplomas, registrations, visas) can be mistranslated by any engine.

## Not done / to validate on a device
No device test of airplane mode, of reconnection on a real network or of the download policy over mobile data (all covered by automated tests with fakes). The job detail of a notification
(`jobById`) still needs the connection. Reconnection is detected by retrying, not by a connectivity plugin (no new dependency).
