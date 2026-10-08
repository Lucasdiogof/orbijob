# Issues sugeridas (não criadas no GitHub: repositório não pôde ser criado)

Cada item = uma issue; milestone = fase do ROADMAP.

**M1 — Fontes reais**
- Obter chaves gratuitas USAJOBS / Adzuna / France Travail (ação humana)
- Rodar `scripts/acceptance.mjs` com internet e arquivar evidência
- Ler e registrar termos oficiais: Himalayas, Jobicy, Greenhouse, Ashby, Reed, Adzuna (cache)
- Investigar serviços públicos: IEFP (PT), MyCareersFuture (SG), Bayt (AE), Job Bank (CA), SAPS (ZA), Bundesagentur (DE – permissão)
- Conector USAJOBS + fixtures reais
- Conector Adzuna com atribuição obrigatória na UI
- Job de sync com `sync_runs` e métricas por conector
**M2 — Backend**
- Criar projeto Supabase de staging (aprovação) e aplicar migração
- Repetir testes de RLS no Supabase real
- Worker: `/search`, cache KV, rate limit
- Política de backup e runbook de restauração
**M3 — Perfil/Auth**
- Login Supabase (e-mail + OAuth), perfis múltiplos, bucket de currículos
- Exportar/excluir dados do usuário (LGPD/GDPR)
**M4 — Ranking**
- Motor determinístico + confiança + evidências; fixtures de 8+ profissões
**M5 — Favoritos & candidaturas**
- Favoritos/notas/pesquisas salvas/histórico; candidaturas e etapas; lembretes
**M6 — Autofill**
- `ApplicationAutofillService` mobile; dicionário multilíngue de campos; allowlist; relatório; guarda anti-submit
- Web: painel de respostas copiáveis
**M7 — Ocupações**
- Importar ESCO/ISCO (confirmar licença dos dados); revisão nativa de rótulos
**M8 — Marca/Lançamento**
- Busca formal de marca; escolher identidade; assets; material do portfólio Lucksrei
