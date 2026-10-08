# HANDOFF — OrbiJob (atualizado 2026-10-08, rodada 3 — refinamento visual)

## Estado
- Repositório: https://github.com/Lucasdiogof/orbijob (**público**), branch `main`. Histórico da Fase 0 preservado (commit `4214c30`) e integrado ao commit inicial do remoto (`de24b41`, README placeholder) por *merge* de históricos não relacionados, sem force push.
- Rebranding **JobRadar → OrbiJob** concluído: pacote Dart `orbijob`, applicationId/bundle id `com.lucksrei.orbijob` (diretório Kotlin movido), nome exibido "OrbiJob" (Android, iOS, Web/manifest), classe `OrbiJobApp`, ARB pt/en/es, package do Worker `orbijob-worker`, docs e READMEs. "JobRadar" permanece apenas como registro histórico em `docs/BRAND_NAME_CHECK.md`. Identificadores de banco não continham o nome antigo (nada a migrar).
- App: shell de navegação (Início, Explorar, Favoritos, Candidaturas; perfil no cabeçalho), busca com estados honestos. Worker: núcleo de conectores, dedupe, ocupações, teste de RLS. Detalhes no README.
- Identidade visual (rodada 3, branch `design/identity-refinement`): três propostas refinadas (logotipos, ícones, mono, favicon, paletas, tokens, 8 telas + estados em claro/escuro, tablet/desktop) em `docs/design/identity/`, comparação navegável em `docs/design/comparison/` e verificações automáticas. **Nenhuma aprovada nem aplicada**; app, splash e ícones do Flutter inalterados.
- Issues: ver `docs/ISSUES_SEED.md` (espelho das issues do GitHub).

## Bloqueios e pendências reais
1. Rede da sessão bloqueia APIs de vagas → nenhuma validação ao vivo; nenhuma fonte `READY` (ver `GLOBAL_SOURCES.md`).
2. Chaves gratuitas (USAJOBS, Adzuna, France Travail) não obtidas — ação do proprietário.
3. Nome OrbiJob: sem conflito direto encontrado, mas busca formal de marca/lojas/domínios pendente; proximidade com "Orbyt Jobs" a avaliar (`BRAND_NAME_CHECK.md`).
4. Licença indefinida (repositório público sem LICENSE = todos os direitos reservados).
5. Fontes das propostas (Sora, Manrope, Space Grotesk, Inter, JetBrains Mono; OFL) já usadas nas prévias e nos wordmarks (subconjunto latino). Após a escolha: redesenhar o logotipo final com as famílias completas e definir fallbacks para CJK/árabe.
6. Ícones padrão do Flutter ainda nos projetos Android/iOS/Web (substituir após aprovar identidade).
7. CI executou no GitHub: jobs worker, catalog e app passaram; o job de segredos falhou na 1ª execução por configuração (a action gitleaks montava um range a partir do commit raiz) e foi trocado pelo CLI do gitleaks varrendo todo o histórico. Proteções de branch/Dependabot ainda não configuradas (issue #4).
8. Sem Supabase, sem migração aplicada, sem deploy Cloudflare, sem serviços pagos, sem publicação em lojas, lucksrei.com intocado.

## Aguardando decisão do proprietário
Escolher A, B, C ou uma combinação (ver `docs/design/comparison/`). Recomendação de design: A · Órbita, com ressalvas descritas na comparação.

## Próxima etapa recomendada
Aprovar uma identidade; obter chaves; rodar `scripts/acceptance.mjs` com internet; implementar um conector real (USAJOBS ou Adzuna); só então promover a `READY`.
