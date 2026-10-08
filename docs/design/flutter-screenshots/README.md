# Capturas reais do app Flutter (identidade C)

São capturas do **aplicativo Flutter de verdade** (build web em modo release, Chromium headless), não mockups. Geradas por `docs/design/identity/build/flutter_screens.sh`.

- `prod-*` — build de produção (`lib/main.dart`): **fluxo real, sem dados**: Início, Explorar, estado "sem fonte integrada", Favoritos, Candidaturas e Perfil (aparência).
- `preview-*` — build de prévia (`lib/main_preview.dart`): mesma interface com vagas **fictícias**, sempre com a faixa "PREVIEW · ILLUSTRATIVE DATA, NOT REAL JOBS" fixada. Mostra resultados, cartões com compatibilidade e confiança separadas, detalhe, favoritos, carregando (`?delay=60000`), vazio, tablet (rail), desktop (rail estendido + lista/detalhe) e português.
- `web-splash-*` — splash estática da web (a captura bloqueia `main.dart.js` de propósito para ela permanecer visível).
- Sufixo `-light` / `-dark`: esquema de cores do navegador (ThemeMode.system).

Mobile 390×844 @2x, tablet 834×1112, desktop 1280×800. Não é captura de Android/iOS nativos (sem SDK/Xcode neste ambiente).
