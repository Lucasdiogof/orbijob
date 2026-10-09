# OrbiJob — roteiro do proprietário (Windows 10/11): inspecionar o Supabase em modo somente leitura

Projeto: `rpmlfxwebnlxnwadyvle` · Dashboard: https://supabase.com/dashboard/project/rpmlfxwebnlxnwadyvle

**Objetivo desta etapa:** descobrir o estado real do banco **sem alterar nada**. O assistente não consegue ler o projeto (o ambiente dele bloqueia `*.supabase.co`, não tem o conector Supabase e não tem credenciais). Você roda um SQL de leitura no navegador, salva o resultado e (opcionalmente) classifica no seu PC.

**Regras:** não compartilhe senha do banco, connection string, chaves (`anon`/`publishable`/`secret`/`service_role`), tokens de acesso nem capturas de tela com chaves. O JSON que você vai enviar tem apenas **nomes de objetos, flags e versões de migrations** — nenhum dado de usuário.

---
## Caminho recomendado: SQL Editor do Dashboard (não instala nada)

### Passo 1 — Copiar o SQL
Escolha uma:
- **Navegador:** abra https://raw.githubusercontent.com/Lucasdiogof/orbijob/main/scripts/supabase/inspect_readonly.sql , pressione `Ctrl+A` e `Ctrl+C`. (Só funciona depois que o PR #44 estiver integrado; antes disso use a branch: troque `main` por `feat/supabase-deploy-tooling` no endereço.)
- **PowerShell**, se já tiver o repositório (ver "Obter o repositório" abaixo), dentro da pasta dele:
  ```powershell
  Get-Content scripts\supabase\inspect_readonly.sql -Raw | Set-Clipboard
  ```

### Passo 2 — Executar no Dashboard
1. Abra https://supabase.com/dashboard/project/rpmlfxwebnlxnwadyvle/sql/new e entre com sua conta.
2. Cole o SQL (`Ctrl+V`) e clique em **Run**.
3. O SQL é só `SELECT` dentro de `begin read only; … rollback;`: **não cria nem altera nada**. Se o editor reclamar de transação, apague a primeira linha (`begin read only;`) e a última (`rollback;`) e rode de novo.
4. **Saída esperada:** uma linha, uma coluna chamada `inspection`, com um JSON que começa com `{ "format": 1, …`.

### Passo 3 — Salvar o resultado
1. Clique na célula `inspection` e copie o conteúdo (botão *Copy* do visualizador de célula), **ou** use *Export → JSON/CSV* do resultado.
2. Abra o **Bloco de Notas**, cole, e salve em `Desktop\inspection.json` com *Tipo: Todos os arquivos* e *Codificação: UTF-8*.
(O classificador entende o JSON puro, a célula exportada em CSV, e o JSON exportado pelo editor; qualquer um serve.)

### Passo 4 — Compartilhar (mais simples)
Cole o **texto do `inspection.json` no chat** (ou anexe o arquivo). Não há segredos nele. O assistente classifica e responde com `EMPTY`, `CONSISTENT_PARTIAL`, `CONSISTENT_UP_TO_DATE` ou `DRIFT` e com as migrations pendentes.

### Passo 4 (alternativo) — Classificar você mesmo no PowerShell
Precisa de Node.js e do repositório.
```powershell
winget install OpenJS.NodeJS.LTS      # instala o Node.js (oficial). Feche e reabra o PowerShell depois.
node --version                         # esperado: v22.x ou v20.x
```
**Obter o repositório** (escolha uma):
```powershell
winget install Git.Git                 # se ainda não tem Git; reabra o PowerShell
cd $HOME\Documents
git clone https://github.com/Lucasdiogof/orbijob.git
cd orbijob
```
ou baixe o ZIP em https://github.com/Lucasdiogof/orbijob (botão *Code → Download ZIP*), extraia (ex.: `C:\Users\SEU_USUARIO\Downloads\orbijob-main`) e entre na pasta: `cd $HOME\Downloads\orbijob-main`.

Dentro da **pasta raiz do repositório** (onde existe `README.md` e a pasta `scripts`):
```powershell
node scripts\supabase\classify_state.mjs $HOME\Desktop\inspection.json
```
**Saídas possíveis:**
```
state: EMPTY                      → as 5 migrations estão pendentes (lista as 5)
state: CONSISTENT_PARTIAL         → lista só as pendentes (ex.: 20261012000000_quota_upsert_fix)
state: CONSISTENT_UP_TO_DATE      → pending: none
state: DRIFT                      → linhas "PROBLEM: …" explicando; NÃO aplique nada
```
Linhas `warning:` não bloqueiam (ex.: `pg_trgm` já instalada, Postgres diferente de 16).
Se aparecer `cannot read …: not an OrbiJob inspection document`, o arquivo salvo não é o resultado do SQL (confira o passo 3).

### Segunda consulta (única) — detalhes de pré-deploy
A primeira inspeção mostrou uma função da plataforma (`public.rls_auto_enable`) e deixou perguntas sobre privilégios. Uma segunda consulta, **também somente leitura**, responde a todas de uma vez:
1. Copie **`scripts/supabase/inspect_predeploy_details.paste.sql`** (`Get-Content scripts\supabase\inspect_predeploy_details.paste.sql -Raw | Set-Clipboard`, ou o endereço raw do arquivo no GitHub). É a mesma consulta, em **um único comando**, sem comentários nem `begin`/`rollback` (a versão comentada e com transação deu `42601: syntax error at end of input` no editor). Antes de colar: clique no editor, `Ctrl+A`, `Delete` (editor vazio, nada selecionado — o editor executa **só o trecho selecionado**), depois `Ctrl+V` e clique em **Run**.
2. Saída esperada: uma linha, coluna `details`, JSON que começa com `{ "predeploy_format": 1, …`. Salve como `predeploy.json` (UTF-8). **Use a versão corrigida do arquivo** (a primeira versão falhava no Supabase hospedado com `schema "$user" does not exist`); o JSON correto contém o campo `search_path_schemas`.
3. Cole o texto no chat **ou** rode `node scripts\supabase\predeploy_check.mjs $HOME\Desktop\predeploy.json`. Saída: `verdict: PRECHECK_OK` ou `verdict: BLOCKED` e uma linha por checagem (`PASS` / `FAIL` / `UNKNOWN`); o corpo da função de plataforma é impresso no fim para você ler.
O arquivo contém nomes, flags, privilégios, a definição da função da plataforma e as versões de migrations — sem dados de usuários, chaves ou senhas.

### Se aparecer `42601: syntax error at end of input`
Significa que o editor enviou um texto **incompleto** ao banco. Causas comuns: (a) havia texto selecionado no editor e só o trecho selecionado foi executado; (b) a colagem foi cortada; (c) a versão com `begin`/`rollback` foi dividida pelo editor. O que fazer: esvazie o editor (`Ctrl+A`, `Delete`), cole o arquivo `*.paste.sql`, confira que a **primeira linha** é `select jsonb_pretty(jsonb_build_object(` e a **última** é `)) as details;`, e clique em **Run** sem selecionar nada. Se o erro continuar, envie só o texto do erro e a primeira e a última linha que aparecem no editor (sem rolar o resto).

### O que enviar / o que NÃO enviar
- **Enviar:** o texto de `inspection.json` e a saída do classificador (as linhas `state:` / `pending:` / `PROBLEM:` / `warning:`).
- **Enviar também, anotando à mão (30 s no painel):** *Database → Migrations* (lista de versões), *Storage* (nomes dos buckets e se são públicos), *Authentication → Providers* (e-mail ligado? *Confirm email*?), *Authentication → URL Configuration* (Site URL), *Database → Extensions* (`pg_trgm` instalada?), versão do Postgres.
- **NÃO enviar:** senha do banco, connection string, qualquer chave de API, token pessoal, `.env`, capturas de tela que mostrem chaves.

---
## Depois da leitura: CLI e fases de aplicação (só com autorização específica)

As fases de aplicação usam scripts Bash (`scripts/supabase/apply.sh`) que precisam de `psql`. **No Windows, rode-os dentro do WSL 2** (Ubuntu), onde tudo roda sem adaptação:
```powershell
wsl --install -d Ubuntu          # PowerShell como administrador; reinicie se pedir
```
Dentro do Ubuntu (WSL):
```bash
sudo apt update && sudo apt install -y git nodejs npm postgresql-client
git clone https://github.com/Lucasdiogof/orbijob.git && cd orbijob
npm install supabase --save-dev   # CLI oficial via Node (instalação global por npm não é suportada)
npx supabase login                # abre o navegador do Windows para autenticar
npx supabase link --project-ref rpmlfxwebnlxnwadyvle
read -s -p "Senha do banco: " PGPASSWORD; export PGPASSWORD; echo
export DB_URL='postgresql://postgres@db.rpmlfxwebnlxnwadyvle.supabase.co:5432/postgres'   # SEM senha na URL
```
(Alternativa nativa no PowerShell: Scoop — `scoop bucket add supabase https://github.com/supabase/scoop-bucket.git` e `scoop install supabase`. Confirme os comandos na página oficial https://supabase.com/docs/guides/local-development/cli/getting-started antes de usar.)
Leitura via script (não escreve): `PATH="$PWD/node_modules/.bin:$PATH" bash scripts/supabase/apply.sh read` (roda as duas consultas, classifica e executa o verificador de pré-deploy). Um item `UNKNOWN` que você **leu** e aceita é liberado com `ORBIJOB_PREDEPLOY_ACK=<id>` (ex.: `function-rls_auto_enable`); um `FAIL` nunca pode ser liberado.
Mapa das fases A–E e travas de segurança: `docs/SUPABASE_MIGRATION_PLAN.md`, seção 3. **O assistente só prepara; quem autoriza e dispara a aplicação é você.**

### Fase E — validação real de Auth, RLS e Storage (duas contas descartáveis)
Nada aqui altera schema, grants, policies, buckets nem configurações do projeto. O script grava só linhas e arquivos marcados `e2e-<hora>` nas duas contas de teste e remove tudo no final.

**1. Auditoria de catálogo (somente leitura).** No SQL Editor, cole o conteúdo de `supabase/tests/01_audit.paste.sql` (ele só lê o catálogo) e clique em Run. Esperado: `audit: ok`. Qualquer falha começa com `AUDIT:` e diz o que está errado; me mande a mensagem.

**2. Duas contas descartáveis, pelo fluxo normal de cadastro.** Use dois e-mails seus (por exemplo `voce+orbijob-a@gmail.com` e `voce+orbijob-b@gmail.com`) e uma senha forte só para teste. Em `bash` (WSL) ou no PowerShell, com a chave **publishable** (Project Settings → API Keys; nunca `sb_secret_…`/`service_role`):
```bash
export SUPABASE_URL=https://rpmlfxwebnlxnwadyvle.supabase.co
export SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
export E2E_EMAIL_A=... E2E_EMAIL_B=... E2E_PASSWORD=...
export ORBIJOB_E2E_CONFIRM=rpmlfxwebnlxnwadyvle
node scripts/supabase/e2e_remote.mjs --signup
```
Cada endereço recebe um e-mail de confirmação: clique no link. Se o script avisar `e-mail confirmation is OFF`, me diga (é um achado de segurança); não desligue nem ligue nada para facilitar o teste. O limite de e-mails do Auth padrão é baixo: se o envio falhar, espere e repita.

**3. Rodar as verificações** (as contas já confirmadas):
```bash
node scripts/supabase/e2e_remote.mjs --dry-run     # só imprime o plano
node scripts/supabase/e2e_remote.mjs --quotas      # Auth, RLS em todas as tabelas, Storage, cotas pequenas
node scripts/supabase/e2e_remote.mjs --quotas-bulk # opcional: ~3.000 linhas pequenas para 1.000 favoritos e 2.000 candidaturas
```
O script nunca imprime senha, chave nem token. Cada falha mostra a tabela e a operação. Me mande a saída inteira.

**4. Limpeza.** O script apaga as linhas e os PDFs que criou e confere que não sobrou nada (linhas ou arquivos). Contas do Auth não podem ser apagadas com a chave publishable: remova as duas em *Authentication → Users*. Se a limpeza do script falhar, ele diz o que sobrou.

**O que o script não cobre**: `viewed_jobs` (precisa de uma vaga no catálogo, que está vazio; coberto pelos testes SQL locais), persistência da sessão no aparelho (código do app, testado com mocks) e o envio real do e-mail de recuperação de senha.

## Se preferir liberar o acesso ao assistente
Configurações do ambiente de nuvem (menu do ambiente na barra de título da sessão → *Edit*): (1) *Network access*: permitir `rpmlfxwebnlxnwadyvle.supabase.co` e `api.supabase.com`; (2) guardar um **token pessoal somente leitura** em *Network secrets / API credentials* (ou variável `SUPABASE_ACCESS_TOKEN`); (3) iniciar nova sessão. Ou instale o conector *Supabase* em claude.ai e habilite-o no chat. Mesmo assim, o assistente só fará leituras até você autorizar a aplicação.
