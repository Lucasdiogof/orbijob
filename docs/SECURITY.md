# OrbiJob — segurança

> O repositório `Lucasdiogof/orbijob` é **público**: nada sensível pode entrar nele. Antes do primeiro push foram verificados working tree e histórico (ver HANDOFF).

## Modelo de ameaças (resumo)
Usuário malicioso lendo dados de outro · vazamento de segredos · abuso/DoS da API · XSS/injeção via descrições de vagas (HTML de terceiros) · JS de autofill em domínio não autorizado · scraping reverso do nosso índice.

## Controles
- **Segredos:** nunca no repo (`.gitignore`, `.env.example`, `wrangler secret`, gitleaks no CI). A chave *publishable* (ex-anon) é pública por desenho; a *secret*/`service_role` só no Worker. O app valida a configuração no início e recusa chaves privilegiadas (`AppConfig.validate`).
- **Sessão:** tokens guardados no Keystore (Android) / Keychain (iOS) via `flutter_secure_storage`; na web, o armazenamento do navegador (limite da plataforma). Erros de autenticação são traduzidos para tipos próprios; mensagens do servidor nunca aparecem na tela.
- **RLS:** dono-único em todas as tabelas privadas; policies restritivas para filhos; jobs read-only para clientes. Testes: `worker/test/rls.test.ts`.
- **Currículos:** bucket privado, pasta por usuário, URL assinada curta, sem logs de conteúdo.
- **Rate limiting:** por IP/usuário no Worker (KV/DO) + respeito aos limites de cada fonte (`RateLimiter`).
- **Conteúdo de terceiros:** descrição de vaga tratada como não confiável — renderizar como texto/sanitizar HTML (allowlist); nunca `innerHTML` cru; links externos com `rel=noopener`.
- **Autofill:** allowlist de domínios, JS injetado só nelas, sem `submit` programático, relatório ao usuário, nenhum dado enviado a servidores nossos.
- **Observabilidade sem PII:** logs com ids opacos/contagens/códigos; proibido logar corpo de perfil, e-mail, currículo.
- **Auditoria de sync:** `sync_runs` (contagens, status).
- **Privacidade / conta (7.0):** exclusão definitiva e exportação **no app** (Perfil → Privacidade → Seus dados). Edge Functions `account-delete` e `account-export` (JWT verificado):
  a identidade vem só do token (um `user_id` no corpo é ignorado); a exclusão exige a senha atual de novo + `confirm:true`, apaga os PDFs do bucket `resumes/<uid>/` e depois o usuário Auth
  (todas as tabelas privadas caem em cascata); é idempotente e, se o Storage falhar, o usuário continua existindo para repetir. A exportação roda **como o próprio usuário** (sem chave
  privilegiada; o RLS decide), não inclui senhas nem tokens de push e entrega links assinados de 1 h para os PDFs. A chave `service_role` só existe dentro da função de exclusão.
  Documentos públicos (minutas técnicas, sem revisão jurídica): `lucksrei.com/projects/orbijob/{privacy,terms,data-deletion}/` em PT/EN/ES.

## Testes de segurança
Feito: RLS (isolamento entre usuários, escrita cruzada, anon, jobs não redistribuíveis).
Feito em produção (7.0, 2026-10-14, `worker/scripts/account-e2e.mjs`, só contas descartáveis `e2e-*@orbijob-test.invalid`, 35 verificações): A não lê perfil/candidatura de B, não baixa, não gera link
assinado, não lista nem grava na pasta de B, não registra o arquivo de B como currículo seu, não altera o perfil de B; anônimo não vê perfis nem a lista de usuários do Auth; `push-send` recusa usuário
logado sem o segredo compartilhado; exclusão recusa senha errada/ausência de confirmação/senha de outra conta, ignora `user_id` do corpo, remove linhas e arquivos e invalida o token antigo.
Auditoria de grants/RLS (`supabase/tests/01_audit.paste.sql`) no projeto real: `audit: ok`. Nenhuma vulnerabilidade foi demonstrada nesta rodada. Planejado: fuzz do sanitizador, teste de allowlist de autofill, SAST/dependabot, revisão de CORS, teste de rate limit.
