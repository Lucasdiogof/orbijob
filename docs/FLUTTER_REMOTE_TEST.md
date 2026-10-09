# OrbiJob — teste real do Flutter contra o Supabase (duas contas descartáveis)

Estado: **procedimento preparado; nada disto foi executado contra o Supabase real** (o ambiente do assistente não alcança `*.supabase.co` e não tem Android SDK nem Xcode). Cada item abaixo só passa a contar como "validado" depois que você o executa e registra o resultado.

## 0. Pré-requisitos (uma vez)
1. **Redirect URLs** no Dashboard → Authentication → URL Configuration (você altera; o assistente não):
   | URL | Para quê |
   |---|---|
   | `http://localhost:3000/**` | desenvolvimento Web (`flutter run -d chrome --web-port=3000`) |
   | `com.lucksrei.orbijob://auth-callback` | Android e iOS |
   | _(futura)_ `https://<domínio-de-produção>/**` | só quando houver hospedagem definida — **não existe ainda; não inventar** |
   **Site URL** hoje é `http://localhost:3000` (serve para teste Web em desenvolvimento). Troque pela URL pública só quando ela existir. Sem a URL do esquema móvel na lista, o Supabase ignora o `redirectTo` e o link do e-mail cai no Site URL (localhost) — no celular isso não abre o app.
2. Duas contas **descartáveis** (ex.: Gmail `+orbijob-a` / `+orbijob-b`). Nunca use contas reais de pessoas.
3. **Windows (Web):** `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\run_orbijob_web.ps1` faz tudo (SDK isolado, validações, `localhost:3000`); ver `docs/WINDOWS_WEB_RUN.md`.
   Demais plataformas: em um computador com Flutter (Android Studio / Xcode):
   ```
   cd app
   copy dart_defines.example.json dart_defines.dev.json      (preencha URL e chave PUBLISHABLE; o arquivo é ignorado pelo git)
   flutter run --dart-define-from-file=dart_defines.dev.json -d chrome --web-port=3000      # Web
   flutter run --dart-define-from-file=dart_defines.dev.json                                  # Android/iOS (AUTH_REDIRECT_URL=com.lucksrei.orbijob://auth-callback)
   ```
   Para Web use `AUTH_REDIRECT_URL=http://localhost:3000/`. Nunca coloque `sb_secret_…`/service_role (o app recusa iniciar).
4. Catálogo de vagas está vazio: **não crie vagas fictícias no banco**. Favoritos só podem ser testados em dois modos: (a) `flutter run -t lib/main_preview.dart` (dados fictícios em memória, nada vai ao banco; **não** testa persistência) ou (b) sem vagas reais o item "persistência de favoritos" fica **pendente** até existir uma fonte real.

## 1. Conta e sessão (A)
- [ ] Criar conta A → mensagem "confirmação enviada". Abrir o e-mail **no mesmo aparelho** e tocar no link → o app abre e fica logado.
- [ ] Link aberto com o app **fechado** · com o app **aberto** · com sessão **já existente** · tocar o mesmo link **duas vezes** (esperado: aviso "link expirou ou já foi usado", sem travar) · link adulterado (aviso) · link antigo.
- [ ] Logout → telas mostram "Entre para continuar", sem dados da conta A.
- [ ] Login · fechar o app (matar o processo) · reabrir → continua logado.
- [ ] "Esqueci a senha" → e-mail → link → tela **Escolha uma nova senha** (não dá para voltar) → salvar → aviso "Senha atualizada". Repetir e tocar **Cancelar** → sessão encerrada.
- [ ] Reiniciar o app **durante** a tela de nova senha: a sessão de recuperação é uma sessão normal (comportamento do Supabase); confira que você consegue sair.
## 2. Troca A ↔ B e isolamento
- [ ] Com A logada e dados criados, sair, entrar com B: nenhuma tela de B mostra dados de A (perfil, favoritos, candidaturas, pesquisas salvas, países). Voltar a A: dados de A intactos.
- [ ] Tema/idioma de A não "vazam" como dado: ao entrar B, valem as preferências de B assim que carregam.
## 3. Perfil profissional
- [ ] Criar perfil (qualquer profissão; só o nome é obrigatório) · editar · competências · modalidade · cidade/país.
- [ ] Experiência: criar, editar, "trabalho atual", excluir. Formação: criar só com instituição, editar, excluir.
- [ ] Preferências: tema, idioma (PT/EN/ES), países de interesse (`DE`, `PT`…); reiniciar o app e conferir.
## 4. Currículos
- [ ] PDF válido (< 5 MiB) sobe e aparece · **Abrir** gera link que expira em ~60 s · excluir remove da lista.
- [ ] Rejeição: arquivo `.txt` renomeado para `.pdf`, arquivo vazio, PDF > 5 MiB, 11º arquivo.
- [ ] Sem órfãos: no Dashboard → Storage → `resumes` → pasta `<id da conta>`: só os arquivos listados no app. (Falha forçada: modo avião logo após escolher o arquivo.)
## 5. Candidaturas (sem enviar nada)
- [ ] Registrar manualmente (empresa, cargo, link opcional `https://…`, data, canal, nota) · mudar etapa (aparece no **Histórico**) · editar nota · excluir · reiniciar o app e conferir.
- [ ] Link `ftp://` ou texto solto é recusado.
## 6. Falhas (nada pode parecer salvo)
- [ ] Modo avião e tentar salvar perfil / candidatura / pesquisa: mensagem de conexão e a tela **não** mostra o item como salvo.
- [ ] Recarregar uma lista sem rede: erro com **Tentar novamente**, não lista vazia.
## 7. Registrar
Para cada item: aparelho/OS, versão do app, data, aprovado/falhou, observação. Prints **sem** tokens ou e-mails reais.
Depois do teste, limpe: exclua as duas contas no Dashboard → Authentication e confirme que `resumes` está vazio (a exclusão em cascata remove as linhas; arquivos do Storage precisam ser apagados à mão).

## O que já foi verificado sem o Supabase real
- Backend simulado (testes Flutter) e build Web de verdade contra rede simulada: inicialização, sessão, cabeçalhos `apikey`/`Authorization`, persistência após recarregar (local, descartável).
- Manifestos nativos: testes estáticos de `INTERNET`, esquema `com.lucksrei.orbijob://auth-callback`, `launchMode=singleTop`, deep link nativo do Flutter desligado. **Não** prova que o link abre o app.
