# HANDOFF — OrbiJob (atualizado 2026-10-08, rodada 4 — identidade C aplicada)

## Estado
- Repositório: https://github.com/Lucasdiogof/orbijob (**público**). Trabalho desta rodada no PR #38, branch `design/identity-refinement` (**sem merge**; aguarda autorização do proprietário).
- **Identidade oficial: C — Minimal Tech** (decisão do proprietário). Aplicada ao app Flutter real: tokens gerados de `tokens.json`, Space Grotesk/Inter, logotipo e símbolo SVG, ícones Android/iOS/Web, splash estática, temas claro/escuro/sistema, componentes e telas (Início, Explorar, Favoritos, Candidaturas, Perfil), responsividade (barra, rail, rail estendido, lista/detalhe) e acessibilidade. `kProvisionalSeed` removido. A e B ficam só como histórico.
- Documentação: `docs/design/identity/c-minimal/APPLIED.md` (tokens, fontes, logotipo, ícones, splash, padrões, limitações), `docs/DESIGN_SYSTEM.md` (estrutura, testes), `docs/design/flutter-screenshots/` (capturas reais).
- Verificado nesta rodada: `dart format`, `flutter analyze` (limpo), **139 testes Flutter**, 43 testes do Worker, `flutter build web --release` (produção e prévia), `aapt2` compile+link dos recursos Android, gitleaks. Worker, conectores, Supabase e Cloudflare **não foram tocados**.

## O que NÃO foi verificado (e por quê)
1. **APK Android:** `flutter build apk --debug` falha com "No Android SDK found"; o SDK vem de `dl.google.com`, bloqueado neste ambiente. Os recursos (ícone adaptativo, monocromático, splash) foram validados com `aapt2`, mas **não** houve build, instalação nem teste em aparelho/emulador. Fazer em CI/máquina com SDK.
2. **iOS:** sem macOS/Xcode. Ícones (PNG opacos, dimensões, `Contents.json`) e storyboard foram validados por testes estruturais; o storyboard (cor nomeada `LaunchBackground`) **nunca foi aberto no Xcode**. Ícones iOS 18 escuro/tingido não incluídos.
3. Splash em inicialização fria/quente em dispositivo real; leitores de tela em aparelho; simulação de daltonismo; teste com usuários.

## Pendências
- Build e teste em aparelho Android/iOS; revisar a splash nativa.
- Busca formal de marca "OrbiJob" (INPI/USPTO/EUIPO/WIPO), lojas e domínios; proteção de branch/Dependabot (issue #4).
- Persistir preferência de tema e favoritos; nomes de países localizados; fontes não latinas (CJK, árabe) se for necessário embutir.
- Fonte de vagas real (chaves gratuitas, termos, 1º conector) — nenhuma fonte `READY` ainda (ver `GLOBAL_SOURCES.md`).
- Licença do repositório; Supabase/Cloudflare só com aprovação.

## Próxima etapa recomendada
Autorizar o merge do PR #38 após revisar as capturas; em seguida validar em dispositivos (Android/iOS) e retomar a Fase 1 de fontes de vagas (chaves, termos, primeiro conector real).
