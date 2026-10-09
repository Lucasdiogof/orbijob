# Rodar o OrbiJob Web no Windows (um comando)

Na raiz do repositório, no PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\run_orbijob_web.ps1
```

## O que acontece
1. Lê de `app\pubspec.yaml` a versão mínima do Dart.
2. Procura um Flutter compatível: a cópia privada de uma execução anterior ou o Flutter do PATH, se já for novo o bastante. Senão instala o **Flutter 3.47.7 numa pasta privada** (`%LOCALAPPDATA%\OrbiJob\flutter\3.47.7`), uma única vez. Não precisa de administrador, não muda o PATH permanente nem o seu Flutter global ou o de outros projetos.
3. `flutter pub get` e `flutter analyze` com esse SDK (o PATH muda só dentro desse processo).
4. Confere `app\dart_defines.web.json` **sem imprimir valores**. Se o arquivo não existe, cria o modelo (já com a URL do projeto e `AUTH_REDIRECT_URL=http://localhost:3000/`) e abre o Bloco de Notas: cole **no seu computador** a chave `sb_publishable_…` (Dashboard → Project Settings → API Keys), salve e feche. Um arquivo existente nunca é sobrescrito. O arquivo é ignorado pelo Git.
5. Confere Chrome e a porta 3000 e roda `flutter run -d chrome --web-port=3000`. Abre em `http://localhost:3000` (tecle `q` para parar).

Repetir o comando não reinstala nada: a cópia privada só vale se um marcador foi gravado depois de verificar versão e Dart; uma instalação incompleta é refeita.

## Opções
`-NoRun` (só prepara e valida) · `-RunTests` (roda `flutter test`) · `-SkipAnalyze` · `-SdkRoot <pasta>` · `-FlutterVersion <x.y.z>`.

## Erros comuns
| Mensagem | O que fazer |
|---|---|
| Git was not found | instalar Git for Windows |
| git clone failed / Downloading the Flutter tools failed | internet, proxy ou antivírus; nada fica pela metade, rode de novo |
| SUPABASE_PUBLISHABLE_KEY is empty / placeholder | colar a chave publishable no arquivo aberto |
| ... holds a SECRET key | trocar por `sb_publishable_…`; **nunca** usar `sb_secret_` no app |
| Port 3000 is already in use | fechar o programa citado; a porta precisa ser 3000 (é a Redirect URL cadastrada) |
| symlink support | ativar o Modo de Desenvolvedor do Windows (Configurações → Para desenvolvedores) |

## O que foi testado
Testes automáticos (`scripts/windows/test_run_orbijob_web.ps1`) e o workflow `windows-bootstrap` rodam o script de verdade em Linux (PowerShell 7) e em um runner Windows (Windows PowerShell 5.1) com uma configuração **falsa**; nunca contatam o Supabase nem abrem o app. Abrir o Chrome e o app com o Supabase real só acontece no seu computador.
