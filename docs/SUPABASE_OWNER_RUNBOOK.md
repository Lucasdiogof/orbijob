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
Leitura via script (não escreve): `PATH="$PWD/node_modules/.bin:$PATH" bash scripts/supabase/apply.sh read`.
Mapa das fases A–E e travas de segurança: `docs/SUPABASE_MIGRATION_PLAN.md`, seção 3. **O assistente só prepara; quem autoriza e dispara a aplicação é você.**

### Contas de teste da Fase E
Crie 2 usuários descartáveis em *Authentication → Users* (e-mail confirmado, mesma senha forte). Variáveis (bash/WSL): `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` (**publishable**, *Project Settings → API Keys*), `E2E_EMAIL_A`, `E2E_EMAIL_B`, `E2E_PASSWORD`, `ORBIJOB_E2E_CONFIRM=rpmlfxwebnlxnwadyvle`. O script recusa chaves `sb_secret_…`/`service_role`. Apague as contas depois.

## Se preferir liberar o acesso ao assistente
Configurações do ambiente de nuvem (menu do ambiente na barra de título da sessão → *Edit*): (1) *Network access*: permitir `rpmlfxwebnlxnwadyvle.supabase.co` e `api.supabase.com`; (2) guardar um **token pessoal somente leitura** em *Network secrets / API credentials* (ou variável `SUPABASE_ACCESS_TOKEN`); (3) iniciar nova sessão. Ou instale o conector *Supabase* em claude.ai e habilite-o no chat. Mesmo assim, o assistente só fará leituras até você autorizar a aplicação.
