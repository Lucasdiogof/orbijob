# OrbiJob — segurança

> O repositório `Lucasdiogof/orbijob` é **público**: nada sensível pode entrar nele. Antes do primeiro push foram verificados working tree e histórico (ver HANDOFF).

## Modelo de ameaças (resumo)
Usuário malicioso lendo dados de outro · vazamento de segredos · abuso/DoS da API · XSS/injeção via descrições de vagas (HTML de terceiros) · JS de autofill em domínio não autorizado · scraping reverso do nosso índice.

## Controles
- **Segredos:** nunca no repo (`.gitignore`, `.env.example`, `wrangler secret`, gitleaks no CI). `anon key` é pública por desenho; `service_role` só no Worker.
- **RLS:** dono-único em todas as tabelas privadas; policies restritivas para filhos; jobs read-only para clientes. Testes: `worker/test/rls.test.ts`.
- **Currículos:** bucket privado, pasta por usuário, URL assinada curta, sem logs de conteúdo.
- **Rate limiting:** por IP/usuário no Worker (KV/DO) + respeito aos limites de cada fonte (`RateLimiter`).
- **Conteúdo de terceiros:** descrição de vaga tratada como não confiável — renderizar como texto/sanitizar HTML (allowlist); nunca `innerHTML` cru; links externos com `rel=noopener`.
- **Autofill:** allowlist de domínios, JS injetado só nelas, sem `submit` programático, relatório ao usuário, nenhum dado enviado a servidores nossos.
- **Observabilidade sem PII:** logs com ids opacos/contagens/códigos; proibido logar corpo de perfil, e-mail, currículo.
- **Auditoria de sync:** `sync_runs` (contagens, status).
- **Privacidade:** LGPD/GDPR — consentimento para dados de perfil, exportação e exclusão (a implementar).

## Testes de segurança
Feito: RLS (isolamento entre usuários, escrita cruzada, anon, jobs não redistribuíveis). Planejado: fuzz do sanitizador, teste de allowlist de autofill, SAST/dependabot, revisão de CORS, teste de rate limit.
