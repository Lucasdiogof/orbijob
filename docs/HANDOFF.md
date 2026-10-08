# HANDOFF — OrbiJob (atualizado 2026-10-08, rodada 2)

## Estado
- Repositório: https://github.com/Lucasdiogof/orbijob (**público**), branch `main`. Histórico da Fase 0 preservado (commit `4214c30`) e integrado ao commit inicial do remoto (`de24b41`, README placeholder) por *merge* de históricos não relacionados, sem force push.
- Rebranding **JobRadar → OrbiJob** concluído: pacote Dart `orbijob`, applicationId/bundle id `com.lucksrei.orbijob` (diretório Kotlin movido), nome exibido "OrbiJob" (Android, iOS, Web/manifest), classe `OrbiJobApp`, ARB pt/en/es, package do Worker `orbijob-worker`, docs e READMEs. "JobRadar" permanece apenas como registro histórico em `docs/BRAND_NAME_CHECK.md`. Identificadores de banco não continham o nome antigo (nada a migrar).
- App: shell de navegação (Início, Explorar, Favoritos, Candidaturas; perfil no cabeçalho), busca com estados honestos. Worker: núcleo de conectores, dedupe, ocupações, teste de RLS. Detalhes no README.
- Identidade visual: três propostas com SVG/PNG/prévias em `docs/design/identity/` — **nenhuma aprovada nem aplicada**.
- Issues: ver `docs/ISSUES_SEED.md` (espelho das issues do GitHub).

## Bloqueios e pendências reais
1. Rede da sessão bloqueia APIs de vagas → nenhuma validação ao vivo; nenhuma fonte `READY` (ver `GLOBAL_SOURCES.md`).
2. Chaves gratuitas (USAJOBS, Adzuna, France Travail) não obtidas — ação do proprietário.
3. Nome OrbiJob: sem conflito direto encontrado, mas busca formal de marca/lojas/domínios pendente; proximidade com "Orbyt Jobs" a avaliar (`BRAND_NAME_CHECK.md`).
4. Licença indefinida (repositório público sem LICENSE = todos os direitos reservados).
5. Fontes finais das propostas (Sora/Manrope/Space Grotesk) não puderam ser usadas offline: logotipos finais precisam ser redesenhados após a escolha.
6. Ícones padrão do Flutter ainda nos projetos Android/iOS/Web (substituir após aprovar identidade).
7. CI ainda não executado no GitHub nesta data (verificar após o push); proteções de branch/Dependabot não configuradas.
8. Sem Supabase, sem migração aplicada, sem deploy Cloudflare, sem serviços pagos, sem publicação em lojas, lucksrei.com intocado.

## Próxima etapa recomendada
Aprovar uma identidade; obter chaves; rodar `scripts/acceptance.mjs` com internet; implementar um conector real (USAJOBS ou Adzuna); só então promover a `READY`.
