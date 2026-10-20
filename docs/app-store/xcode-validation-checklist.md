# OrbiJob: checklist de validação que exige Mac, aparelho ou painel (NÃO VALIDADO)

Nada deste arquivo foi executado: o ambiente de desenvolvimento não tem Xcode, aparelho nem acesso ao painel do Supabase/Firebase. O CI do repositório roda só em Ubuntu (format, analyze, test, build web, SQL, Worker). Execute na ordem; cada linha tem um critério de aprovação. Marque com data e quem fez.

## A. Mac (Xcode)
| # | Passo | Critério de aprovação |
|---|---|---|
| A1 | `cd app && flutter pub get && cd ios && pod install` | termina sem erro; o diff do `Podfile.lock` mostra Firebase (Core, Installations, Messaging) e GoogleMLKit; revisar e commitar o lock |
| A2 | Xcode: abrir `ios/Runner.xcworkspace`, Signing & Capabilities com a equipe certa, Push Notifications e Background Modes > Remote notifications presentes | sem aviso de assinatura; `aps-environment` aparece na capability |
| A3 | Product > Archive | archive criado sem erro |
| A4 | Organizer > botão direito no archive > **Generate Privacy Report** e salvar o PDF | PDF gerado |
| A5 | Conferir o PDF contra `app/ios/Runner/PrivacyInfo.xcprivacy` e a seção 3 do `privacy-audit.md`: tipos agregados (inclua as pods Firebase e GoogleMLKit), purposes, linked, tracking | todo tipo do PDF existe na matriz do ASC; nenhum "tracking = yes"; nenhuma required-reason API sem motivo; se algum pod declarar tipo que a matriz não tem, atualizar manifest e matriz |
| A6 | Exportar o `.ipa` (App Store Connect) e descompactar: `codesign -d --entitlements :- Payload/Runner.app` | mostra `aps-environment` = `production` |
| A7 | `plutil -p Payload/Runner.app/Info.plist` | `UIBackgroundModes` contém `remote-notification`; nenhuma `NS*UsageDescription` inesperada; `ITSAppUsesNonExemptEncryption` = false |
| A8 | Conferir `Payload/Runner.app/PrivacyInfo.xcprivacy` no `.ipa` e os `PrivacyInfo.xcprivacy` dos frameworks em `Payload/Runner.app/Frameworks/*` | presentes; os valores batem com o repositório |
| A9 | (opcional) `WKWebsiteDataStore.removeData(ofTypes: allWebsiteDataTypes)` por canal nativo e `NSURLIsExcludedFromBackupKey`: só se o dono decidir (ver seção 15 e 14 do `privacy-audit.md`) | n/a |

## B. Push de ponta a ponta (ver também `ios-push-runbook.md`)
| # | Passo | Critério |
|---|---|---|
| B1 | Apple Developer: App ID `com.lucksrei.orbijob` com Push Notifications; perfil de distribuição regenerado | capability ligada |
| B2 | Chave APNs (.p8) enviada no Firebase Console > Project settings > Cloud Messaging > Apple app configuration | Key ID e Team ID corretos; sem aviso de erro |
| B3 | App iOS do Firebase com bundle id `com.lucksrei.orbijob`; `FIREBASE_IOS_APP_ID` e `FIREBASE_SENDER_ID` do build vêm desse app (ou `GoogleService-Info.plist` com o mesmo `BUNDLE_ID`) | iguais |
| B4 | TestFlight, app **aberto**: entrar, permitir notificações, ver a linha `push_devices` (plataforma `ios`), disparar o envio (`push-send` horário ou teste do Firebase) | notificação aparece em primeiro plano/lista |
| B5 | TestFlight, app **fechado** (forçar encerramento) e depois em segundo plano | a notificação chega e o toque abre o app na notificação |
| B6 | Sair da conta | a linha de `push_devices` some e nenhuma notificação chega depois |

## C. Aparelho Android
| # | Passo | Critério |
|---|---|---|
| C1 | Manifest mesclado do AAB: `app/build/app/intermediates/merged_manifests/release/.../AndroidManifest.xml` | contém `POST_NOTIFICATIONS`, `INTERNET`, `dataExtractionRules`, `fullBackupContent` |
| C2 | Roteiro de backup/restauração (seção 14 do `privacy-audit.md`) | sessão NÃO restaurada; app pede login sem travar |
| C3 | Navegador interno: abrir um portal, entrar na conta de teste A, sair, entrar na conta B, abrir o mesmo portal | o portal não está logado (sem cookies de A) |
| C4 | Cadastro com e-mail novo de teste: marcar a caixa, criar, confirmar o e-mail | login funciona; `user_metadata` tem `terms_version`/`privacy_version` (leitura no painel pelo dono) |

## D. SMTP do Supabase Auth (pedido ao dono)
Modelo de mensagem: "Preciso de um print de Authentication > Emails > SMTP Settings do projeto orbiJob (ref rpmlfxwebnlxnwadyvle). Pode cobrir a senha. Também preciso saber se 'Enable Custom SMTP' está ligado."
| # | Conferir | Critério |
|---|---|---|
| D1 | Enable Custom SMTP | ligado (o SMTP embutido do Supabase limita a poucos e-mails por hora e não serve à loja) |
| D2 | Sender email / name | `marketing@lucksrei.com` (contato público único) e nome "OrbiJob" |
| D3 | Host e porta | os do provedor escolhido (ex.: 465 ou 587); sem a senha no print |
| D4 | Domínio do remetente verificado (SPF, DKIM) no provedor | verificado |
| D5 | E-mail de confirmação de cadastro chega à caixa de entrada (não ao spam) com o link para `com.lucksrei.orbijob://auth-callback` | chegou e o link abre o app |
| D6 | E-mail de recuperação com código de 6 dígitos chega e o código funciona no app | chegou e funciona |
| D7 | Redirect URLs do Supabase Auth incluem `com.lucksrei.orbijob://auth-callback` | presente |

Enquanto D1-D3 não forem vistos, a política não nomeia o provedor SMTP.
