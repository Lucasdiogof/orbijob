# OrbiJob: runbook de push no build iOS de loja (NÃO VALIDADO)

Nada aqui foi executado: o ambiente de desenvolvimento não tem Xcode, e o repositório não tem CI de iOS (sem runner macOS, Codemagic ou fastlane). Cada passo abaixo é uma verificação para o dono fazer num Mac.

## Estado no repositório (CONFIRMADO NO CÓDIGO)
- `app/ios/Runner/Runner.entitlements`: `aps-environment = development`.
- `app/ios/Runner/Info.plist`: `UIBackgroundModes = remote-notification`; bundle id `com.lucksrei.orbijob` (`firebase_push_messaging.dart`).
- O app inicializa o Firebase no iOS por `FirebaseOptions` vindas de `--dart-define` (`FIREBASE_IOS_API_KEY`, `FIREBASE_IOS_APP_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_PROJECT_ID`; ver `docs/ORBIJOB_3_0.md:45`): não depende de `GoogleService-Info.plist` no repositório. Sem esses valores o push fica desligado (`firebase_push_messaging.dart`, retorno `false`).
- `ios/Podfile.lock` está desatualizado (não lista Firebase): revisar o diff do `pod install`.

## Passos (marcar cada um)
1. **App ID no Apple Developer** (Certificates, Identifiers & Profiles > Identifiers > `com.lucksrei.orbijob`): capability **Push Notifications** ligada. Regenerar o perfil de provisionamento de distribuição depois de ligar. NÃO VALIDADO.
2. **Chave APNs** (Keys > + > Apple Push Notifications service): baixar o `.p8` (uma única vez), anotar Key ID e Team ID. No Firebase Console > Project settings > Cloud Messaging > Apple app configuration > **APNs Authentication Key**: enviar o `.p8` para o app iOS com o bundle id correto. NÃO VALIDADO.
3. **App iOS no Firebase** com bundle id `com.lucksrei.orbijob`; conferir que `FIREBASE_IOS_APP_ID` e `FIREBASE_SENDER_ID` usados no build são os desse app (e, se o dono usar um `GoogleService-Info.plist` em vez de dart-define, que o `BUNDLE_ID` dele seja o mesmo). NÃO VALIDADO.
4. **Xcode**: Runner > Signing & Capabilities: assinatura automática com a equipe certa, capability Push Notifications e Background Modes > Remote notifications presentes. NÃO VALIDADO.
5. **Archive**: Product > Archive. Conferir no archive/.ipa o entitlement final:
   `codesign -d --entitlements :- Runner.app` (dentro do `.ipa` descompactado, em `Payload/Runner.app`). Deve mostrar `aps-environment = production`. Se mostrar `development`, o perfil de distribuição está errado: refazer o passo 1. Só como último recurso, trocar para `production` no entitlements do build de loja. NÃO VALIDADO.
6. **Privacy Report**: Organizer > clicar no archive com o botão direito > Generate Privacy Report (ver `privacy-audit.md`, seção 10). NÃO VALIDADO.
7. **Teste de ponta a ponta no TestFlight**: instalar, entrar, permitir notificações, confirmar a linha em `push_devices` (plataforma `ios`), disparar a função `push-send` (cron horário) ou uma notificação de teste no Firebase e ver chegar com o app em segundo plano e fechado. Sair da conta e conferir que a linha some. NÃO VALIDADO.

## O que cada verificação cobre
| Item | Verificação |
|---|---|
| aps-environment production | passo 5 |
| Chave APNs no Firebase | passo 2 |
| App ID com Push | passo 1 |
| GoogleService-Info / opções do Firebase do bundle certo | passo 3 |
| UIBackgroundModes | já no `Info.plist`; conferir no `.ipa` com `plutil -p Payload/Runner.app/Info.plist` |
| Entrega real | passo 7 |
