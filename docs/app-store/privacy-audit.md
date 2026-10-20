# OrbiJob: auditoria de privacidade de loja (20/10/2026)

Legenda: **CONFIRMADO NO CÓDIGO** (lido no repositório), **CONFIRMADO NA DOC OFICIAL** (página da Apple/Google lida hoje), **A CONFIRMAR** (precisa de Mac/Xcode, aparelho, painel de loja ou decisão do dono). Nada aqui foi comprovado em execução em aparelho: não havia Xcode nem build iOS neste ambiente.

## 1. URLs para as lojas

| Campo | URL |
|---|---|
| Marketing | https://lucksrei.com/projects/orbijob/ (HTTP 200) |
| Suporte | https://lucksrei.com/projects/orbijob/support/ (200) |
| Privacidade | https://lucksrei.com/projects/orbijob/privacy/ (200) |
| Termos | https://lucksrei.com/projects/orbijob/terms/ (200) |
| Exclusão de conta | https://lucksrei.com/projects/orbijob/data-deletion/ (200) |

O app aponta para as três últimas em `app/lib/features/privacy/presentation/your_data_section.dart:360-362`. Idiomas do app: pt, en, es (`app/lib/l10n/app_{pt,en,es}.arb`). As páginas do site também existem em en, pt e es.

## 2. PrivacyInfo.xcprivacy: manifest x App Store Connect

- O manifest (`app/ios/Runner/PrivacyInfo.xcprivacy`, já incluído em Resources do Runner no `project.pbxproj`) é lido pelo Xcode: ele junta o manifest do app com os dos SDKs no "Privacy Report" (Product > Archive > Generate Privacy Report). É verificado na carga para os "required reason APIs".
- O **rótulo de privacidade (App Privacy) no App Store Connect é separado**: é digitado pelo dono e é o que o público vê. A Apple diz que o relatório serve de referência para preenchê-lo. Os dois precisam ser coerentes, mas um não gera o outro. CONFIRMADO NA DOC OFICIAL (Describing data use in privacy manifests).
- A Apple diz que o manifest do app **não precisa cobrir dados coletados por SDKs de terceiros** (cada SDK declara os seus). Já o rótulo do App Store Connect **precisa incluir** os dados que os SDKs coletam. CONFIRMADO NA DOC OFICIAL.
- Os valores de chave devem ser exatamente os da Apple (a doc avisa que o Xcode não gera o relatório com valores inventados). As strings usadas abaixo foram lidas na referência oficial `NSPrivacyCollectedDataType` e `...Purposes` hoje.

### Linhas do manifest novo (todas Linked = true, Tracking = false)

| Tipo | Finalidades | Justificativa (evidência) |
|---|---|---|
| EmailAddress | AppFunctionality | Conta e-mail+senha no Supabase Auth (`supabase_auth_repository.dart`) |
| Name | AppFunctionality | Nome do perfil profissional (`professional_profiles`) |
| PhoneNumber | AppFunctionality | Telefone opcional do perfil; usado no kit de candidatura (cópia local) |
| OtherUserContactInfo | AppFunctionality | E-mail de contato, links profissionais do perfil |
| UserID | AppFunctionality | `user_id` (uuid do Supabase) em todas as tabelas com RLS |
| DeviceID | AppFunctionality | Token FCM em `push_devices.token` (`supabase_push_devices_repository.dart:6-64`; migration `20261024000000_push_devices.sql:16-25`) |
| SearchHistory | AppFunctionality, ProductPersonalization | `saved_searches` ligadas à conta; texto da busca enviado como filtro |
| ProductInteraction | AppFunctionality, ProductPersonalization | `saved_jobs`, `hidden_jobs`, `viewed_jobs`, candidaturas; base do "compatibilidade" |
| OtherUserContent | AppFunctionality, ProductPersonalization | Perfil, experiências, formação, certificados, anotações, PDFs de currículo (bucket privado `resumes`) |

Tracking = false, `NSPrivacyTrackingDomains` vazio: nenhum SDK de anúncio/analytics no `pubspec.yaml`, nenhum cruzamento de dados com terceiros para publicidade, sem IDFA/ATT. CONFIRMADO NO CÓDIGO (pubspec e `grep` de analytics/advertising em `lib/`). Isso é a definição da Apple de tracking (ATT).

`NSPrivacyAccessedAPITypes` continua **vazio de propósito**: o código próprio do Runner (`AppDelegate.swift`, `SceneDelegate.swift`) não usa APIs de "required reason" (UserDefaults, timestamps de arquivo, boot time, espaço em disco, teclados ativos). O uso por plugins é declarado pelos próprios plugins; a Apple exige que o SDK declare o seu e não aceita que o app declare por ele. CONFIRMADO NA DOC OFICIAL (Describing use of required reason API). Manifests dos plugins no pub-cache nas versões do `pubspec.lock`:

| Plugin | Manifest próprio | API required-reason declarada |
|---|---|---|
| shared_preferences_foundation 2.5.7 | sim | UserDefaults 1C8F.1 |
| firebase_messaging 16.7.0 | sim | UserDefaults CA92.1 |
| flutter_secure_storage_darwin 0.4.3, webview_flutter_wkwebview 3.26.2, share_plus 13.3.1, url_launcher_ios 6.4.2, connectivity_plus 7.3.2, file_picker_darwin 2.1.3, app_links 7.2.2 | sim | nenhuma, coleta vazia |
| path_provider_foundation 2.6.0, google_mlkit_translation 0.15.1, google_mlkit_commons 0.13.0, firebase_core 4.15.0 | não no pacote Dart | **A CONFIRMAR**: as pods nativas (Firebase, GoogleMLKit, GoogleDataTransport) trazem o manifest delas; só dá para ver no Privacy Report de um archive no Mac |

Observação: o `app/ios/Podfile.lock` do repositório está **antigo** (não lista Firebase; tem MLKit + GoogleDataTransport). Será regenerado no `pod install` do Mac; revise o diff.

### Não incluído no manifest, por decisão
- PhysicalAddress (cidade/país de residência digitados no perfil): A CONFIRMAR se a Apple os classifica como "Physical Address" ou como Location. Não é localização do aparelho. Decisão do dono (ver seção 8).
- Sensitive Info: "autorizações de trabalho" (visto) não consta da lista da Apple (raça, religião, deficiência etc.), mas pode ser sensível em leis locais. A CONFIRMAR.
- Diagnostics/Usage Data: o app não coleta por conta própria; ver SDKs abaixo.

## 3. Matriz App Privacy (App Store Connect, taxonomia atual)

Origem comum: digitado pelo usuário no app. Destino comum: Supabase (projeto orbiJob, ref rpmlfxwebnlxnwadyvle, São Paulo, confirmado por `npx supabase projects list`), exceto onde dito. Todos Tracking = Não.

| Tipo | Coletado? | Finalidade | Vinculado? | Opcional? | Evidência | Observações |
|---|---|---|---|---|---|---|
| Contact Info: e-mail | Sim | App Functionality | Sim | Não (para ter conta; catálogo sem conta) | `supabase_auth_repository.dart`; `auth_cubit.dart:173-183` | E-mail de confirmação/recuperação enviado pelo Supabase Auth. Provedor SMTP: A CONFIRMAR (Resend não aparece no código/funções) |
| Contact Info: nome | Sim | App Functionality | Sim | Sim | `professional_profiles` | |
| Contact Info: telefone | Sim | App Functionality | Sim | Sim | `profile_page`/kit | |
| Contact Info: endereço físico | A CONFIRMAR | App Functionality | Sim | Sim | cidade/país no perfil | decisão do dono |
| Contact Info: outros | Sim | App Functionality | Sim | Sim | e-mail de contato, links | |
| Health & Fitness | Não | n/a | n/a | n/a | sem uso no código | Vaga de saúde é só conteúdo do catálogo |
| Financial Info | Não | n/a | n/a | n/a | sem pagamentos; salário é dado da vaga | |
| Location | Não | n/a | n/a | n/a | sem permissão de localização; WebView nega geolocalização (`webview_engine.dart:108-110`) | |
| Sensitive Info | A CONFIRMAR | n/a | n/a | n/a | "autorização de trabalho" no perfil | ver seção 2 |
| Contacts | Não | n/a | n/a | n/a | sem acesso à agenda | |
| User Content: outros | Sim | App Functionality, Personalization | Sim | Sim | perfil, experiências, formação, certificados, anotações de candidatura, PDFs ≤5 MiB no bucket privado `resumes` | Texto do PDF é lido no aparelho (`resumeImportIntro`), o arquivo vai ao Supabase só como upload do usuário |
| Browsing History | Não | n/a | n/a | n/a | histórico do navegador interno não é guardado (`browser_engine.dart:23-24`) | `viewed_jobs` conta como interação |
| Search History | Sim | App Functionality, Personalization | Sim | Sim | `saved_searches`; busca enviada ao Supabase como filtro com ou sem conta | Se o Supabase/API guarda logs do texto da busca de anônimos: A CONFIRMAR |
| Identifiers: User ID | Sim | App Functionality | Sim | Não | uuid do Supabase | |
| Identifiers: Device ID | Sim | App Functionality | Sim | Sim (só se permitir notificações) | `push_devices.token`, `platform`, `locale` | Google diz que FCM associa o APNs token a um installation ID (CONFIRMADO NA DOC OFICIAL do Firebase) |
| Purchases | Não | n/a | n/a | n/a | sem compras | |
| Usage Data: interação com produto | Sim | App Functionality, Personalization | Sim | Sim | favoritos, ocultas, vistas, candidaturas | |
| Usage Data: publicidade | Não | n/a | n/a | n/a | sem anúncios | |
| Diagnostics | Do app: não. De SDK: **A CONFIRMAR** | Analytics/diagnóstico | provavelmente não | n/a | ver SDKs | |
| Other Data | Não identificado | n/a | n/a | n/a | | |

### Dados que vão a SDKs/serviços

| Serviço | O que recebe | Evidência | Para o rótulo |
|---|---|---|---|
| Supabase (Auth, Postgres, Storage, Edge Functions) | tudo da conta | `pubspec.yaml` supabase_flutter; RLS nas migrations | linhas da matriz acima |
| Firebase Cloud Messaging | token do aparelho, texto da notificação | `firebase_push_messaging.dart`; `supabase/functions/push-send` | Device ID; Google lista ainda "Firebase user agent" (dispositivo, SO, bundle id) e, em tópicos, modelo/idioma/fuso (doc oficial Firebase); **A CONFIRMAR** marcar Diagnostics |
| ML Kit Translate (on-device) | o texto da vaga não sai do aparelho; modelos são baixados. Na doc do Google (Android), o Translate envia ao Google idiomas origem/destino, métricas de desempenho, info do aparelho, versão do app e IDs por instalação (via Firebase Installations/Remote Config) | CONFIRMADO NA DOC OFICIAL (Android); iOS: A CONFIRMAR | **declarar Diagnostics/Usage (não vinculado) no App Store Connect e Data safety**, a menos que se prove o contrário; a política publicada diz que não há SDK de análise: ver seção 6 |
| Resend | nada no código | grep em `supabase/functions` e `app/lib` sem ocorrência | n/a |
| Cloudflare/GitHub | só catálogo público | docs | n/a |

## 4. Permissões

| Item | Estado | Evidência |
|---|---|---|
| iOS NS*UsageDescription | nenhuma presente e nenhuma necessária hoje: PDF via seletor de documentos (`FilePickerPdfPicker`); notificações não têm chave; sem câmera/microfone/fotos/localização/contatos no app. O upload de arquivo em páginas externas só existe no Android (`setOnShowFileSelector`). Câmera/microfone pedidos por páginas no iOS ficam sem chave. | `Info.plist`; `webview_engine.dart:110-111` |
| iOS UIBackgroundModes | `remote-notification` (necessário para push silencioso/de dados) | `Info.plist` |
| iOS `aps-environment` | `development` no repositório. Na App Store o perfil de distribuição exige `production`; com assinatura automática o Xcode grava `production` ao fazer Archive. **A CONFIRMAR** no `.ipa`: `codesign -d --entitlements :- Runner.app` deve mostrar `production`. Se não, mudar para `production` só no build de loja. Também é preciso a chave APNs (.p8) no Firebase. | `Runner.entitlements` |
| Android INTERNET | declarada no app | `AndroidManifest.xml` |
| Android POST_NOTIFICATIONS | **não está no manifest do app**; vem por merge do manifest do plugin firebase_messaging 16.7.0 (linha `uses-permission POST_NOTIFICATIONS` em `android/src/main/AndroidManifest.xml` do plugin). O plugin checa a permissão em runtime (`FlutterFirebaseMessagingPlugin.java:435`). **A CONFIRMAR** no manifest mesclado do AAB (`build/app/intermediates/merged_manifests`); não foi gerado build aqui. | pub-cache |
| Android backup | `allowBackup` não está definido (padrão = ligado). Sessão fica em armazenamento seguro (Keystore) que não é restaurado em outro aparelho. Recomendação: avaliar `allowBackup=false` ou regras de exclusão. Não alterado. | `AndroidManifest.xml` |

## 5. WebView e preenchimento assistido (auditoria do código)

CONFIRMADO NO CÓDIGO:
- Nenhum dado do perfil vai ao portal da vaga: o navegador recebe só `Uri initial` (`webview_engine.dart:116`, `in_app_browser_page.dart:277`), que é o link da vaga do catálogo; a API do engine só expõe `load/reload/goBack/goForward` (`browser_engine.dart:7-14`). Não há `JavaScriptChannel`, `runJavaScript` nem script injetado (`webview_engine.dart:13-14`); `JavaScriptMode.unrestricted` é só para o próprio JavaScript do site funcionar. Eventos de volta só carregam URL/progresso/erro (`browser_engine.dart:23-24`).
- Não existe barra de endereço: só se chega a páginas pelos links de vagas e pelos links dentro das páginas (esquemas permitidos: http/https; `mailto/tel/sms` vão ao sistema; arquivos baixáveis vão ao navegador do sistema; resto bloqueado, `url_policy.dart`).
- O kit de candidatura copia campos do perfil para a área de transferência só por toque do usuário (`application_kit.dart:112-125`). O app não lê a área de transferência. A área de transferência é visível a outros apps no Android < 13 e o iOS mostra aviso de colagem: risco inerente, documentado ao usuário na tela do kit ("Nada é enviado").
- Currículo: o kit gera link assinado de curta duração e abre no **navegador do sistema** (`openExternalLink`, `launchUrl externalApplication`), não no WebView.
- Cookies: persistem pelo padrão da plataforma; terceiros aceitos no Android (`webview_engine.dart:112-114`). Antes desta auditoria, **nada limpava cookies** no logout, na exclusão de conta nem em troca de usuário: o próximo usuário do aparelho herdaria sessões de portais de vagas. Corrigido: ver abaixo. A limpeza cobre cookies (armazenamento compartilhado da plataforma). Cache de página e localStorage dos sites só se limpam com um controller vivo: ficou como limitação.
- Sem logs/telemetria próprios: nenhum `print/debugPrint/developer.log`, analytics, crashlytics, advertising ID, device_info ou package_info em `lib/` (grep). O `push_devices.token` é o único identificador de aparelho; sai do export (`account-export/core.ts:23`) e é apagado na exclusão (cascade `on delete cascade`, migration linha 18) e no logout (`push_registrar.dart:48`, `deleteToken` em `firebase_push_messaging.dart:99`). `firebase_installations` é dependência transitiva do firebase_messaging (A CONFIRMAR no lock).
- WebView Android: acesso a arquivo/conteúdo desligado, geolocalização desligada, permissões de câmera/microfone negadas, erros TLS nunca ignorados (`webview_engine.dart:103-111,94-99`).

## 6. Política publicada x código

Corretas (confirmadas): preferências sincronizadas com a conta; busca vai ao servidor; tradução on-device Android/iOS e do navegador na web; cookies do navegador interno com terceiros no Android; "não injeta dados nessas páginas"; export sem senha e sem token (`core.ts:23`: só id/plataforma/idioma/datas); exclusão por Edge Function `account-delete` (remove pasta do bucket e o usuário; cascade); retenção de notificações 60 dias/300; PDF até 5 MiB; push_devices guarda token, plataforma e idioma; app não usa localização.

Divergências **comprovadas** ou riscos para corrigir no site:
1. Seção 3 (última frase): "não inclui SDKs de publicidade ou de análise". O ML Kit Translate envia telemetria de desempenho/uso ao Google (doc oficial do Google para Android; iOS A CONFIRMAR) e o FCM/Firebase Installations envia user agent e identificador de instalação. Sugestão: mencionar "dados técnicos de diagnóstico que o ML Kit e o Firebase enviam ao Google, não ligados à sua conta".
2. Seção 5: acrescentar que, a partir desta branch, o app limpa os cookies do navegador interno ao sair da conta e ao excluí-la (só depois de a branch ser publicada); até lá a frase não deve ser publicada.
3. `data-deletion` diz "O app também limpa as buscas recentes e o cache de tradução" no aparelho: correto, e também limpa a cópia local de listas e o cache de resultados (`injector.dart:148-153`); com esta branch também os cookies.
4. Telas do app (`your_data_section.dart`, chaves `privacyKeeps*`/`privacyNever*` em `app_*.arb`): o resumo "O que é guardado" cita e-mail, perfil/favoritos/candidaturas/preferências e currículos, mas omite o token de push, as buscas salvas e o texto de busca enviado ao servidor. Não é falso, é incompleto. Não alterei textos do app.
5. Seção 7 omite o provedor SMTP dos e-mails de autenticação (A CONFIRMAR qual; Supabase Auth envia).
6. A política dá "Minuta técnica": ok, mas a data dos termos (2026-10-14) é anterior à da política.
7. Termos, seção 4: não fixam idade mínima; política, seção 11: "não é direcionado a crianças". Ver seção 7 abaixo.

## 7. Idade mínima, aceite de termos e classificação etária

CONFIRMADO NO CÓDIGO: o cadastro (`authSignUp*` em `app_*.arb`) pede só e-mail e senha: **não há checkbox de aceite dos termos nem idade mínima nem data de nascimento**. Os termos dizem "ao usar o OrbiJob você concorda" (seção 1). Decisão do dono: se quer aceite explícito no cadastro (não implementado, por não ter sido pedido).

Apple (questionário atual, tabela de definições lida hoje; faixas 4+, 9+, 13+, 16+, 18+): "Unrestricted Web Access: users can navigate to any webpage within the app or freely browse the web. May include: embedded browser functionality" e, na tabela, **"16+: Capabilities: Unrestricted web access"**. CONFIRMADO NA DOC OFICIAL. Candidatas:
- User-Generated Content: **Não** (nenhum conteúdo de um usuário é exibido a outro; perfil/currículo só o dono lê).
- Messaging and Chat: **Não**. Advertising: **Não**. Parental Controls / Age Assurance: **Não**. Medical/Wellness, Mature, Violence, Gambling: **Nenhum**.
- Unrestricted Web Access: **candidata a Sim (16+)**, porque o navegador interno segue qualquer link http(s) dentro das páginas dos portais, embora não haja barra de endereço. Se o dono considerar que só se abrem páginas de vagas, "Não" daria 4+; é uma decisão do dono e uma resposta que a Apple pode contestar. Sugestão conservadora: responder Sim (16+) ou restringir o navegador a hosts de vagas (mudança de produto, não feita).
Google Play (IARC, A CONFIRMAR no painel): perguntas equivalentes de navegação irrestrita e conteúdo de usuário; a política de Dados do Usuário exige formulário Data safety coerente com a seção 3. Não foi possível ler as páginas do Play Console hoje.

## 8. Decisões pendentes e riscos

1. Rótulo Diagnostics/Usage (ML Kit, Firebase): declarar ou comprovar ausência pelo Privacy Report do archive.
2. PhysicalAddress e Sensitive Info (autorização de trabalho): decidir classificação.
3. Resposta de Unrestricted Web Access (16+ x 4+) e eventual aceite de termos no cadastro.
4. `aps-environment` production e chave APNs no Firebase.
5. Provedor SMTP do Supabase Auth.
6. `allowBackup` Android.
7. Podfile.lock desatualizado (sem Firebase).
8. Riscos: cache/localStorage de sites não limpos no logout; cookies de terceiros no Android; área de transferência pelo kit; política ainda sem revisão jurídica.

## 9. Validação

Ver resultados reais no relatório da sessão; comandos: `flutter analyze`, `flutter test`, validação por `plistlib` de `PrivacyInfo.xcprivacy`, `Info.plist` e `Runner.entitlements`, `curl` nas cinco URLs.
