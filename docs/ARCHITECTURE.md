# OrbiJob — arquitetura proposta

```
Flutter (Android/iOS/Web-PWA) ──HTTPS──> Cloudflare Workers (API + cron sync) ──> Supabase (Postgres + Auth + Storage)
        │  Supabase Auth (JWT)                 │ conectores → normalização → dedupe → upsert (service role)
        └── dados privados via PostgREST + RLS └── fontes externas (apenas READY/autorizadas)
```

## Flutter (`app/`) — Clean Architecture
```
lib/
  core/{di,theme,network,error}
  features/<feature>/{domain(entities,usecases,repositories), data(datasources,models,repo impl), presentation(cubit,pages,widgets)}
  l10n/ (ARB pt/en/es)
```
Features planejadas: home, search, job_detail, profile, matching, favorites, applications, autofill, settings. BLoC/Cubit para estado; `get_it` para DI (manual, sem geração de código).
Implementado: shell de navegação adaptativa (Início, Explorar, Favoritos, Candidaturas; perfil no cabeçalho; barra inferior < 600dp, rail ≥ 600dp), `search` (entidade, repositório "sem fonte", cubit, página), páginas vazias honestas de Início/Favoritos/Candidaturas, `StateMessage` reutilizável, tema M3 claro/escuro, l10n pt/en/es, DI. Nome técnico do pacote: `orbijob`; applicationId/bundle id `com.lucksrei.orbijob`.
Design system (identidade C): `core/design` (tokens gerados de `docs/design/identity/c-minimal/tokens.json`, tipografia, tema, marca) e `core/widgets` (componentes); ver `docs/DESIGN_SYSTEM.md`. Dois entrypoints: `lib/main.dart` (real, sem dados) e `lib/main_preview.dart` (mesma UI com vagas **fictícias** e faixa de aviso, só para revisão visual). Estado de UI com Cubits: tema (`ThemeCubit`), navegação (`ShellCubit`), busca (`SearchCubit`), favoritos em memória (`FavoritesCubit`).

## Worker (`worker/`)
```
src/{types,dedupe,http,occupations}.ts, src/connectors/<id>.ts
test/ (vitest; fixtures; RLS via PGlite)
```
Planejado: rotas `/search`, `/jobs/:id`, `/sources/health`; `scheduled()` por fonte; KV para cache de buscas; Durable Object ou KV para rate limit por IP/usuário; Cron Triggers para sync; métricas por conector em `sync_runs` + Workers Analytics (sem PII). **Sem deploy nesta fase.**

## Decisões
- **Busca = índice próprio** (tsvector + trigram) alimentado por conectores autorizados; sem proxy ao vivo de portais.
- **Dedupe:** (1) `(source, external_id)`; (2) URL canônica sem tracking; (3) fingerprint empresa+título+país+cidade, acentos ignorados. Implementado e testado; cluster persistido em `job_clusters`.
- **Encerramento de vaga:** só com snapshot completo (regra testada).
- **Ranking:** motor determinístico 0–100 separado de *confiança*; cada ponto com evidência (spec em PRODUCT_REQUIREMENTS). Não implementado.
- **Autofill:** interface `ApplicationAutofillService` — ver abaixo.
- **Dados:** público (`jobs`) × privado (perfil, currículo, candidaturas) separados; currículos em bucket privado com pasta por usuário.

## ApplicationAutofillService (desenho)
```dart
abstract class ApplicationAutofillService {
  bool supports(Uri applyUrl);                        // allowlist por domínio
  Future<AutofillPlan> analyze(Uri url, Profile p);   // detecta campos, mapeia via dicionário multilíngue
  Future<AutofillReport> apply(AutofillPlan plan);    // preenche só campos inequívocos; dispara input/change
  // NUNCA expõe submit(): o usuário revisa e envia.
}
```
- **Mobile:** `flutter_inappwebview`; JS injetado **somente** em domínios da allowlist; relatório preenchidos/ignorados; seções repetidas (experiência/formação) tratadas por índice; validação pós-preenchimento; bloqueio de `form.submit()`/clique em botões de envio.
- **Web/PWA:** abre candidatura oficial + painel de respostas copiáveis; extensão de navegador no futuro. Sem garantia de compatibilidade com todos os sites. Não contorna CAPTCHA.

## Observabilidade, backup
Logs estruturados sem PII (ids opacos, contagens, códigos HTTP); Supabase PITR/backups conforme plano (verificar o que o plano gratuito oferece — **provavelmente sem PITR**; exportar `pg_dump` agendado de dados privados criptografado); runbook de restauração a escrever.
