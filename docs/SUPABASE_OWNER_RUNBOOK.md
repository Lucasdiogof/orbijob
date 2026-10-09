# OrbiJob — roteiro do proprietário: acessar e inspecionar o Supabase (somente leitura)

Projeto: `rpmlfxwebnlxnwadyvle` · https://supabase.com/dashboard/project/rpmlfxwebnlxnwadyvle

**Por que este roteiro existe.** O ambiente em que o assistente trabalha bloqueia `*.supabase.co` e `api.supabase.com` (HTTP 403 "Host not in allowlist"), não tem o conector Supabase instalado e não recebe credenciais. Nada do projeto foi lido até agora. Estes passos são feitos **no seu computador**; nada aqui altera o projeto.

**Regras:** nunca cole senha, token, `service_role`/`secret key` ou a connection string no chat nem no Git. O que você vai compartilhar é um JSON com **nomes de objetos e flags** (sem dados de usuários).

## 1. Instalar a Supabase CLI (métodos oficiais)
Confira a página oficial antes: https://supabase.com/docs/guides/local-development/cli/getting-started
| Sistema | Comando |
|---|---|
| macOS / Linux (Homebrew) | `brew install supabase/tap/supabase` |
| Windows (Scoop) | `scoop bucket add supabase https://github.com/supabase/scoop-bucket.git` · `scoop install supabase` |
| Qualquer um com Node 20+ | dentro do repositório: `npm install supabase --save-dev` e use `npx supabase …` (instalação global via npm não é suportada) |
| Linux sem Homebrew | pacote `.deb`/`.rpm`/`.apk` da página de *Releases* de https://github.com/supabase/cli |
Verifique: `supabase --version`. Para `supabase db dump` é preciso Docker Desktop; sem Docker o script usa `pg_dump`.
Os scripts em `scripts/supabase/*.sh` são Bash: no Windows use WSL ou Git Bash (ou siga só o caminho do SQL Editor, abaixo).

## 2. Autenticar (pelo navegador) e vincular ao projeto existente
```
supabase login                                   # abre o navegador; o token fica no cofre do sistema
supabase link --project-ref rpmlfxwebnlxnwadyvle  # vincula este checkout ao projeto (não altera o projeto)
```
Se pedir a senha do banco, você pode deixá-la em branco: ela só é necessária para comandos que falam direto com o Postgres. **Não crie outro projeto.**

## 3. Inspeção somente leitura — escolha UM caminho
**A. SQL Editor (não precisa de CLI):** Dashboard → SQL Editor → New query → cole o conteúdo de `scripts/supabase/inspect_readonly.sql` → Run. O resultado é uma única célula JSON. Copie e salve como `inspection.json`.
**B. psql:** Dashboard → Connect → copie a connection string (do *pooler*, com `[YOUR-PASSWORD]`). Defina `DB_URL` **no seu terminal** digitando a senha ali. Depois:
`psql "$DB_URL" -X -q -At -f scripts/supabase/inspect_readonly.sql > inspection.json`
**C. Script de fases:** `DB_URL=… scripts/supabase/apply.sh read` (faz B e já classifica).

O SQL só lê catálogos e o histórico de migrations (`begin read only`): tabelas, RLS, policies, grants, funções, triggers, extensões, buckets (id/público/limites), versões em `supabase_migrations.schema_migrations`. Não lê linhas de tabelas de usuários.

## 4. Classificar o resultado
```
node scripts/supabase/classify_state.mjs inspection.json
```
| Estado | Significado | O que fazer |
|---|---|---|
| `EMPTY` | nenhuma tabela/objeto/histórico do OrbiJob | as 5 migrations estão pendentes |
| `CONSISTENT_PARTIAL` | histórico e objetos concordam até a migration N | só as seguintes estão pendentes |
| `CONSISTENT_UP_TO_DATE` | tudo aplicado | nada a aplicar |
| `DRIFT` | tabelas alheias em `public`, objetos sem histórico, histórico sem objetos, versões desconhecidas ou fora de ordem | **parar**; não aplicar nada até esclarecer |
Avisos (`warning:`) não bloqueiam (ex.: `pg_trgm` já instalada, Postgres ≠ 16).

## 5. Conferir no painel o que o SQL não mostra
- **Database → Migrations:** lista de versões aplicadas (deve bater com `migration_versions`).
- **Storage:** buckets existentes (deve **não** existir `resumes` antes da migration 3; se existir, anote público/limites).
- **Authentication → Providers / URL Configuration / Password / Rate limits:** anote o estado (confirmação de e-mail ligada? Redirect URLs?).
- **Database → Extensions:** `pg_trgm` instalada? em qual schema?
- **Project Settings → API:** schemas expostos; **Database → Advisors:** avisos de segurança/performance.
- Versão do Postgres (campo `server_version` do JSON).

## 6. Devolver o resultado
Cole no chat **apenas** o conteúdo de `inspection.json` e o resultado de `classify_state.mjs`, mais as anotações da seção 5. Se preferir, salve como `docs/evidence/supabase-inspection-AAAA-MM-DD.json` e abra um PR. Revise antes: não deve haver e-mails, senhas, tokens nem URLs com senha (por construção não há).

## 7. Depois da leitura — fases de aplicação (exigem autorização específica)
Mapa completo em `docs/SUPABASE_MIGRATION_PLAN.md` (seção 3). Resumo dos scripts, que **nunca** rodam em CI:
| Fase | Comando | Escreve no projeto? |
|---|---|---|
| A Leitura | `scripts/supabase/apply.sh read` | não |
| B Segurança | `scripts/supabase/apply.sh backup` (backup + conferência + dry-run comparado com a classificação) | não |
| C Migração | `ORBIJOB_CONFIRM_APPLY=rpmlfxwebnlxnwadyvle scripts/supabase/apply.sh apply` | **sim** (`db push`, só pendentes, uma vez) |
| D Auditoria | `scripts/supabase/apply.sh audit` + Advisors do painel | não |
| E Testes | `node scripts/supabase/e2e_remote.mjs` com 2 contas de teste (`--dry-run` mostra o plano) | cria/remove dados só nas contas de teste |
O `apply` exige backup recente, inspeção recente sem DRIFT, banco inalterado desde o backup e a variável de confirmação; aborta e não repete às cegas.

### Contas de teste da Fase E
Crie 2 usuários descartáveis em Authentication → Users (e-mail confirmado, senha forte e a mesma para ambos), por exemplo `orbijob-test-a@…` e `orbijob-test-b@…`. Exporte no terminal: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` (**publishable**, Settings → API Keys), `E2E_EMAIL_A`, `E2E_EMAIL_B`, `E2E_PASSWORD`, `ORBIJOB_E2E_CONFIRM=rpmlfxwebnlxnwadyvle`. O script recusa chaves `sb_secret_…`/`service_role`. Apague as contas depois.

## 8. Se for liberar o acesso ao assistente em vez de rodar sozinho
Configurações do ambiente de nuvem (menu do ambiente na barra de título da sessão → Edit): (1) Network access: permitir `rpmlfxwebnlxnwadyvle.supabase.co` e `api.supabase.com`; (2) guardar um **token pessoal somente leitura** em *Network secrets / API credentials* (ou variável `SUPABASE_ACCESS_TOKEN`); nova sessão. Ou instale o conector *Supabase* em claude.ai e habilite-o no chat. Mesmo assim, o assistente só fará leituras até você autorizar a aplicação.
