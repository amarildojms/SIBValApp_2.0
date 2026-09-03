# SIBVal Connect (sibval_app_2.0)

## Contexto do projeto

Este repositório é uma **reescrita em Flutter** do app Android nativo que vive
em `C:\AndroidStudioProjects\SIBValApp2` (Kotlin, package `com.sibval.app`,
arquitetura Fragments/ViewModels, backend Firebase). Não é um app novo — é uma
migração de paridade de funcionalidades, feita tela por tela.

- `SIBValApp` (sem "2") é um snapshot antigo/vazio — ignorar.
- `SIBValApp2` é a implementação de referência real: sempre que houver dúvida
  sobre como uma tela deve se comportar, o código nativo lá é a fonte da
  verdade.
- Todo arquivo Dart novo que espelha um arquivo nativo carrega um doc comment
  no topo da classe, no formato:
  `/// Espelha app/src/main/java/com/sibval/app/.../Foo.kt`
  incluindo qualquer nuance de comportamento (ex.: compressão de imagem já
  tratada pelo `image_picker`, sem precisar de um `ImageCompressor.kt`
  equivalente).

O app foi rebatizado de "SIB Val App" para **SIBVal Connect** no commit
`506d3a7` (19/08/2026).

## Padrão de código observado nas telas já migradas

- State via `flutter_riverpod`: `Provider` para o repositório,
  `FutureProvider`/`FutureProvider.autoDispose` para os dados,
  `ref.invalidate` após mutações em vez de refetch manual.
- Repositórios Firestore recebem `FirebaseFirestore`/`FirebaseStorage` via
  injeção no construtor; o nome da collection bate exatamente com o schema
  nativo (referenciado no doc comment).
- Telas admin-only são bloqueadas no ponto de chamada, em
  `lib/main_shell.dart` (`_MaisPage`, `if (isAdmin) ListTile(...)`), não
  dentro da própria tela.
- Cores/tema sempre via `context.textPrimary` / `context.textSecondary` /
  `SibValColors.*` (`lib/theme/app_theme.dart`) — nunca cor hardcoded.

Ao escrever uma nova tela migrada: primeiro grepar o(s) arquivo(s) `.kt`
nativo(s) correspondente(s) em `SIBValApp2`, depois seguir esse padrão por
padrão, a menos que o usuário peça algo diferente.

## Histórico de migração (commits, mais antigo → mais recente)

**17/08/2026 — Fundação e Fases 0-5**
- `c0702cb` Início do projeto Flutter: Fase 0 e Fase 1
- `0f2ae21` Fase 2: Eventos (abas, detalhe, curtir, compartilhar)
- `a23d7db` Fase 3: Devocionais, Bíblia e Hinários
- `b07a4eb` Fase 4: Aniversariantes, Pedido de Oração e Vínculos Institucionais
- `4859f14` Fase 5: assinatura de release Android
- `92fe26c` Tema claro/escuro/automático, revisão de cores fixas
- `379396b` Central de notificações
- `42ca0ec` Galeria de fotos (álbuns, fotos, visualizador em tela cheia)
- `190ca31` Painel Admin: Gerenciar Usuários (1ª tela)
- `385235a` Painel Admin: Membros (2ª tela)
- `e72b411` Painel Admin: Remetentes de E-mail de Eventos (3ª tela)

**18/08/2026 — Ações admin e polimento**
- `c9a8bc0` Ações de admin na Galeria (criar/excluir álbum, subir/excluir foto)
- `814878c` Painel Admin: Repositório de Flyers (4ª tela)
- `7d0acec` Barra superior fixa com logo e acesso convidado
- `54f6f15` Devocionais: cards na lista, cabeçalho fixo no detalhe
- `7899cf4` Repositório de gerenciamento de Devocionais (admin/Secretaria)
- `8b2eb87` Criação/edição de eventos pontuais e recorrentes, revisão de
  pendentes e filtro
- `8a0161b` Correção de conteúdo escondido atrás da barra de navegação do
  sistema
- `9d93033` Edição de evento pontual na tela de detalhe, ajuste de layout
- `426bb2c` Ajuste da paleta de cores da marca (azul e dourado)

**19/08/2026 — Redesign e rebranding**
- `e9869dd` Redesenho do feed de aniversário, menu Mais, login/cadastro,
  Bíblia e hinário
- `506d3a7` Rebatizado para SIBVal Connect; refinamento de notificações,
  busca e ícones nativos

## O que falta migrar (última verificação: 19/08/2026)

Comparar `SIBValApp2/app/src/main/java/com/sibval/app/ui/<feature>/` com
`lib/<feature>/` para reconfirmar antes de assumir que algo ainda falta —
esta lista já foi corrigida uma vez por estar desatualizada (o commit
`8b2eb87` e outros do dia 18/08 já tinham resolvido a maior parte do que
constava aqui antes). Itens já confirmados como completos e removidos desta
lista: CRUD de eventos recorrentes, formulário de evento + pendentes +
filtro, admin de devocionais, busca/favoritos da Bíblia, cadastro
(`register_page.dart`), o arquivamento de pedidos de oração, o fluxo de
completar perfil ao entrar com Google
(`lib/auth/complete_google_profile_page.dart`, ligado em `login_page.dart` e
`register_page.dart` via `additionalUserInfo?.isNewUser`), e agora também o
envio do pedido de oração ao responsável via WhatsApp
(`PrayerPage._sendToResponsible`, botão de envio por item da lista +
arquivamento automático como efeito colateral) e a tela de ajuste do telefone
do responsável (`PrayerPage._editResponsiblePhone`, engrenagem visível só
para admin; `SettingsRepository.getPrayerResponsiblePhone`/
`setPrayerResponsiblePhone` em `lib/data/settings_repository.dart`).

Não há mais itens pendentes conhecidos nesta lista — reconfirmar via diff
antes de assumir que a migração está 100% completa (ver seção abaixo).

**Divergência intencional do nativo (19/08/2026):** `register_page.dart` foi
incrementado com campos que **não existem** no `RegisterActivity.kt` nativo —
CPF (com dígitos verificadores), telefone, endereço, data de membresia, forma
de adesão, igreja de origem, data de batismo, estado civil, ministério e
cargo/função, todos persistidos em `users/{uid}` via
`UserRepository.createUserProfile` (`lib/data/user_repository.dart`). Nome
completo, CPF, e-mail e data de nascimento são obrigatórios (marcados com `*`
no formulário); os demais são opcionais. Também foi adicionado o checkbox
obrigatório de consentimento com a Política de Privacidade
(`lib/auth/privacy_policy_page.dart`, conteúdo placeholder — texto jurídico
definitivo ainda não fornecido), que só habilita o botão "Cadastrar" quando
marcado. `CompleteGoogleProfilePage` (fluxo de completar perfil via Google)
ganhou paridade completa com `register_page.dart` em 19/08/2026 — mesmos
campos (CPF obrigatório incluso), mesmo checkbox de privacidade, com o visual
escuro (`SibValColors.navyBlue` + texto branco) que a tela já tinha antes. Os
formatadores de CPF/telefone e o validador de dígitos verificadores foram
extraídos para `lib/util/cpf_phone_input.dart` (`CpfInputFormatter`,
`PhoneInputFormatter`, `CpfValidator`) justamente para serem compartilhados
pelas duas telas em vez de duplicados.

**CPF como identificador único, mas sem virar o ID do documento:** o
documento em `users/{uid}` continua chaveado pelo UID do Firebase Auth — NÃO
pelo CPF — porque `firestore.rules` (no repo `SIBValApp2`) usa
`request.auth.uid == userId` para todo o modelo de permissão (o próprio doc do
usuário, `isAdmin()`, `hasRole()`, que por sua vez gateiam galeria, membros,
pedidos de oração, eventos, devocionais, configurações...) e há Cloud
Functions reais em produção (`functions/index.js`: `onUserCreated`,
`onUserApproved`, `onUserPhotoUpdated`) amarradas ao path `users/{uid}`.
Trocar a chave para CPF sem reescrever regras e functions travaria login,
aprovação e toda checagem de permissão para quem se cadastra pelo Flutter.
Confirmado com o usuário em 19/08/2026 — decisão: manter `users/{uid}`.

Por causa disso, **não é possível bloquear CPF duplicado no próprio
cadastro**: a regra `allow list: if isAdmin();` em `users` impede que um
usuário recém-registrado (não-admin) faça uma consulta por CPF para checar se
já existe. O alerta de CPF duplicado só é viável no lado do admin, que já tem
`list` liberado — implementado em `manage_users_page.dart`
(`_findDuplicateCpfs`), mostrando um aviso no card do usuário pendente antes
da aprovação. Se o usuário quiser bloqueio de fato no cadastro, é necessário
alterar `firestore.rules`/`functions/index.js` no repo nativo (opção que ele
recusou nesta rodada).

**`members` (aniversariantes) usa CPF como chave de verdade (19/08/2026):**
diferente de `users`, a collection `members` não tem regra amarrada a
`request.auth.uid` — é só `isSecretaria()` — então aqui o CPF virou
literalmente o ID do documento (preferencial; cai pro e-mail normalizado, e
por fim id autogerado, pra membro sem nenhum dos dois — mesma cascata de
fallback de antes, só que com CPF na frente). Isso já existia como conceito
no nativo: `MemberRepository.kt` sempre indexou por e-mail justamente pra
Cloud Function `onUserPhotoUpdated` achar o membro certo.

O pedido do usuário — "aniversariante cadastrado manualmente, depois cria
conta no app, os dados devem ser mesclados" — **já existia no nativo** e
ainda não tinha sido portado pro Flutter: `ManageUsersViewModel.approve()`
chama `MemberRepository.upsertFromUser(user)` ao aprovar um cadastro,
criando/atualizando (`SetOptions(merge: true)`) a entrada de aniversariante
correspondente. Portado em `member_repository.dart`
(`MemberRepository.upsertFromUser`) e ligado no botão "Aprovar" de
`manage_users_page.dart` — casa primeiro por CPF, cai pro e-mail se o membro
pré-cadastrado ainda não tinha CPF, e migra o documento pro id canônico (CPF)
quando acha um registro "antigo" indexado por e-mail, preservando o que já
tinha lá (foto, storagePath) via merge.

A sincronização contínua de foto (`onUserPhotoUpdated`, em
`SIBValApp2/functions/index.js`) também foi atualizada pra casar por CPF
primeiro, com fallback pro e-mail — função `findMemberRefForUser`, extraída
pra ser reaproveitável. **Só editei o código-fonte da function — não fiz
`firebase deploy`, isso fica manual, por conta do usuário**, com o aval dele
dado explicitamente antes de eu tocar nesse arquivo (mesma cautela do caso
`users`, mas aqui ele topou porque não há trava de segurança por uid em
`members`).

**Eventos de vários dias — introduzido 20/08/2026, revertido 24/08/2026.**
`Event` chegou a ganhar `endDateTimeMillis`/`isMultiDay` (campo/getter sem
equivalente no `Event.kt` nativo), com toggle no `EventFormPage`, exibição de
intervalo em `event_card.dart`/`event_detail_page.dart`/
`event_pending_list_page.dart`, filtro de sobreposição em `events_page.dart`
e um post por dia no feed (`postEventDaysToFeed`, `postedFeedDays`, em
`SIBValApp2/functions/index.js`). O usuário pediu a remoção completa desse
recurso em 24/08/2026 (ver entrada abaixo) — **não existe mais** nem no
Flutter nem nas Cloud Functions; todo evento voltou a ser um instante único
(`dateTimeMillis`). Se algo neste arquivo ainda mencionar `endDateTimeMillis`
fora desta nota, está desatualizado.

**Reforma do feed "Início" + remoção de eventos de vários dias (24/08/2026):**
pedido do usuário foi simplificar a ordenação do feed pra sempre ser por
data/hora de publicação (`createdAt`), com essa data mudando sozinha via
regras de negócio em vez de uma ordenação especial no cliente, e tornar o
feed de verdade em tempo real. `PostRepository._compareFeedOrder`/
`_feedRank` (ranking de aniversário > evento próximo > resto) foram
removidos; `postsProvider` virou `StreamProvider` sobre
`.snapshots()` — primeiro uso de tempo real real no app (todo o resto do
projeto ainda é `FutureProvider` + `ref.invalidate`, ver seção de padrão de
código acima). `Post.eventDateTimeMillis` deixou de vir de um join ao vivo
(`PostRepository._fetchEventDates`, removido) e passou a vir direto do
documento — gravado pela Cloud Function que cria/reposta o post de evento.

Mudanças em `SIBValApp2/functions/index.js` (só editei o código-fonte —
**não fiz `firebase deploy`**, mesma cautela dos casos anteriores; fica pra
um pedido explícito separado):
- Aniversariante: post do feed separado do push. `sendBirthdayNotifications`
  (08h, só push) perdeu a criação do post; nova `postBirthdaysToFeed` (01h,
  pedido explícito do usuário) cria o post do dia, com
  `lastBirthdayFeedPostDate` no `members` pra não duplicar com o gatilho em
  tempo real `onMemberCreatedBirthdayFeedSync`/`onMemberUpdatedBirthdayFeedSync`
  (cadastro/edição de membro com aniversário hoje sobe na hora).
- Devocional: `sendDevotionalNotifications` (08h05) passou a marcar
  `postedToFeed` na devocional; novo gatilho
  `onDevotionalCreatedFeedSync`/`onDevotionalUpdatedFeedSync` sobe no feed na
  hora quando cadastrada/editada já com `dateKey` de hoje.
- Evento (pontual e recorrente **juntos**, a pedido explícito do usuário —
  recorrente deixou de esperar ~24h antes e agora entra no mesmo lote):
  `syncEventFeedPosts` (rodava a cada 30min) virou `postWeeklyEventsToFeed`,
  só segunda de madrugada (`20 3 * * 1`), postando tudo que é `published` e
  ainda não postado (`postedToFeed == false`) cuja data cai na semana atual —
  ordenado do mais distante pro mais próximo, com `createdAt` escalonado por
  segundo pra o mais próximo ficar por cima (pedido explícito: "do mais
  próximo pro mais distante"). Novo gatilho
  `onEventCreatedFeedSync`/`onEventUpdatedFeedSync` cobre "evento novo
  vigente na semana sobe automaticamente", sem esperar a segunda. Nova
  `repostUpcomingEventFeedPosts` (a cada 15min) apaga o post anterior
  (`feedPostId`, guardado no doc do evento) e cria outro — com `createdAt`
  atual (sobe pro topo) e o texto já com "Hoje"/"Amanhã" em vez do dia da
  semana (`formatEventFeedText`) — 24h e de novo 6h antes do evento
  (`feedRepost24hSent`/`feedRepost6hSent`, cada estágio dispara uma vez só).
  Isso substitui o que antes era só um troca de texto no cliente
  (`PostCard._textWithHojeAmanha`, removido) sem de fato subir o post.

`firestore.rules` (`posts/{postId}`): editar/excluir post manual passou a
exigir ser o autor (`resource.data.authorUid == request.auth.uid`) **ou**
admin — antes bastava ter o papel Publicações genérico, então um usuário
Publicações podia mexer no post manual de outro colega; agora não pode mais
(decisão confirmada com o usuário). Posts automáticos (`authorUid == ""`)
continuam só geridos pelas Cloud Functions.

`PostCard` ganhou menu (⋮) com Editar/Excluir pra post manual do autor/admin;
`PostFormPage` ganhou modo edição (`editing: Post?`); `PostRepository` ganhou
`updateManualPost`/`deleteManualPost` e passou a gravar `storagePath` nos
posts manuais (não gravava antes, então a imagem nunca era limpa do Storage
ao excluir — só o doc).

**Reversão de eventos de vários dias (mesma sessão, 24/08/2026):** ao
verificar o código durante o levantamento desta reforma, o recurso descrito
na entrada de 20/08/2026 acima ainda estava presente e commitado — o usuário
pediu a remoção completa (não é mais um recurso do app):
`Event.endDateTimeMillis`/`isMultiDay`/`endDateTimeUtc` saíram do modelo;
`EventFormPage` voltou a não ter toggle de vários dias;
`event_card.dart`/`event_detail_page.dart`/`event_pending_list_page.dart`
voltaram à linha única de data; `events_page.dart` (`_matchesFilter`) voltou
à comparação de dia único; `EventRepository.getPublishedUpcoming` voltou a
filtrar `dateTimeMillis >= agora` direto na query (sem o filtro em memória
que existia só por causa do fim diferente do início). Nas Cloud Functions,
`deleteExpiredEvents` e `sendEventReminders` voltaram a usar só
`dateTimeMillis`; `postEventDaysToFeed`/`postedFeedDays` foram removidos (a
postagem no feed agora é só a `postEventToFeed` unificada, descrita acima).

**Limpeza anual de ministérios/cargos (20/08/2026):** nova Cloud Function
`resetAnnualMinistries` (`SIBValApp2/functions/index.js`, editada e já
deployada), agendada pra todo **20 de janeiro** às 3h (horário de Brasília) —
zera `ministryIds`/`ministries` de todo documento em `members`, porque a
igreja reorganiza quem exerce qual ministério/cargo a cada ano e o vínculo do
ano anterior não deve persistir. Só limpa esses dois campos denormalizados no
membro; o resto do cadastro (nome, CPF, foto...) não é tocado, e o catálogo
em si (coleção `ministries`, gerenciada em `manage_ministries_page.dart`)
continua intacto pra reatribuição ao longo do novo ano. O pedido original do
usuário foi "limpar dos cadastros de membros **e usuários**", mas
`users/{uid}` nunca guardou ministério/cargo — esse dado é *lido* na tela de
perfil (`edit_profile_page.dart`, campo somente-leitura) direto do `Member`
vinculado, então limpar `members` já resolve os dois lugares onde isso
aparece.

**Banner de aviso de notificação desativada (20/08/2026):**
`lib/notifications/notification_permission_banner.dart`, mesmo padrão do
banner de consentimento de comunicações
(`communications_consent_banner.dart`) — intervalo de 21 dias entre
exibições, opt-out permanente via `shared_preferences`, mostrado em
`main_shell.dart` logo abaixo dele. Só aparece quando
`FirebaseMessaging.instance.getNotificationSettings().authorizationStatus`
é `denied` (o pedido de permissão em si já acontece automaticamente ao
logar, ver `PushNotificationService.requestPermissionAndRegisterToken`).
Como Android 13+/iOS não reabrem o diálogo do sistema depois de uma negativa,
o botão "Ativar" leva direto pras configurações do app via
`permission_handler` (`openAppSettings()` — pacote novo, adicionado só por
causa deste banner; não precisou de nenhuma outra permissão nova, já que
`POST_NOTIFICATIONS` já estava declarada no manifest desde a implementação
de FCM). Reavalia sozinho ao voltar do app de Configurações
(`WidgetsBindingObserver`/`AppLifecycleState.resumed`), sem esperar o
próximo intervalo.

**Notificação some da barra + marca como lida ao abrir a tela relacionada
(24/08/2026):** antes só acontecia ao tocar direto na notificação (push ou
item da Central). Pedido do usuário: também acontecer quando ele chega na
tela relacionada por outro caminho (ex.: abrir "Aniversariantes" pelo menu,
com uma notificação de aniversário ainda não lida) — nesse caso a
notificação deve sumir da barra do celular, não só ficar lida dentro do app.

Isso exigiu o app passar a controlar a exibição em **qualquer** estado
(antes só em primeiro plano — em segundo plano/fechado quem mostrava era o
próprio SDK do FCM, com um ID fora do controle do app, impossível de
cancelar depois). Mudança confirmada com o usuário, ciente do trade-off
(iOS pode atrasar/não entregar push "silencioso" com o app fechado —
limitação da Apple):
- `SIBValApp2/functions/index.js`: todo envio (~15 pontos —
  `sendBirthdayNotifications`, `onPostLiked`, `onPostCommented`,
  `sendDevotionalNotifications`, `onUserCreated`, `onPrayerRequestCreated`,
  `sendEventReminders`, `sendRecurringEventReminders`,
  `importEventsFromEmail`, `onMessageCreated`, `sendMeetingReminders`) passou
  a mandar mensagem "só com dados" (helper `dataOnlyMessage`, sem o bloco
  `notification` do FCM — `title`/`body` viajam dentro de `data`, com
  `android.priority: "high"` + `apns...content-available` pra manter a
  entrega confiável em segundo plano/app fechado).
- `lib/notifications/push_notification_service.dart`: novo
  `firebaseMessagingBackgroundHandler` (função solta, `@pragma('vm:entry-point')`,
  registrada em `main.dart` antes do `runApp`) mostra a notificação local
  também em segundo plano/app fechado — isolate separado, não reaproveita a
  instância de `PushNotificationService`, por isso a exibição foi extraída
  pro helper solto `showFcmLocalNotification`. O ID da notificação local
  virou `notificationId.hashCode` (era `message.hashCode`, não
  reproduzível) — é o que permite `cancelNotification(notificationId)`
  cancelar uma notificação específica depois.
- Novo `lib/notifications/notification_read_sync.dart`
  (`syncNotificationsForScreen`): chamado no `initState` de toda tela ligada
  a um tipo de notificação (`BirthdaysPage`, `DevotionalDetailPage`,
  `EventDetailPage`, `EventPendingListPage`, `ManageUsersPage`, `PrayerPage`,
  `PostCommentsPage`, `MessageDetailPage` — mesmo mapeamento tipo→tela de
  `navigateForNotificationType`) — marca como lida e cancela da barra toda
  notificação não lida daquele tipo (e, quando a tela tem um alvo específico,
  só as que apontam pro mesmo `targetId`). `EventPendingListPage` virou
  `ConsumerStatefulWidget` (era `ConsumerWidget`) só pra ter um `initState`
  onde chamar isso, mesmo padrão das outras.
- `ios/Runner/Info.plist` ganhou `UIBackgroundModes` com
  `remote-notification` — sem isso o iOS ignora push de dados em segundo
  plano.

Só editei o código-fonte das Cloud Functions — deploy fica pra um pedido
explícito separado, mesmo padrão desta sessão.

**Aniversário de MEMBRESIA: push pessoal + post fixado só pro aniversariante
(24/08/2026):** pedido do usuário, distinto do aniversário de nascimento
(`sendBirthdayNotifications`/`postBirthdaysToFeed`, que notifica todo mundo).
Aqui só o próprio membro é avisado. Em `SIBValApp2/functions/index.js` (só
editei o código-fonte — **não fiz `firebase deploy`**, mesma cautela de
sempre): `getTodaysMembershipAnniversaryMembers` acha quem faz aniversário de
`membershipDate` hoje (dia/mês batem, ano != o de hoje) varrendo `members` em
memória (não dá pra indexar dia/mês de um Timestamp num único `where`, ao
contrário de `birthMonth`/`birthDay` que já são campos numéricos separados);
`findLinkedUserUid` casa por e-mail contra `users`, igual
`postBirthdayForMember` já fazia. `postMembershipAnniversaryForMember` cria
um post `postType: "membership_anniversary"` com `targetId` = uid do
aniversariante (idempotente via `lastMembershipAnniversaryFeedPostDate` +
`membershipAnniversaryFeedPostId` no doc do membro) — chamado pelo cron
`postMembershipAnniversariesToFeed` (01h05), pelo cron
`sendMembershipAnniversaryNotifications` (08h10, que manda o push pessoal
"Parabéns, você completa X anos de membresia!" e grava a notificação
`audience: "user"`/`targetUid`) e pelos gatilhos em tempo real
`onMemberCreatedMembershipAnniversaryFeedSync`/
`onMemberUpdatedMembershipAnniversaryFeedSync` (Secretaria cadastra/edita a
data de membresia já no dia do aniversário). `resetWeeklyFeed` passou a
apagar `membership_anniversary` também, mesmo ciclo semanal dos posts
automáticos de aniversário/evento/devocional.

O post fixado é de leitura pública no Firestore (`posts` sempre foi, `allow
read: if true`) mas só aparece pra quem tem `targetId` igual ao uid logado —
o filtro é só no cliente (`PostType.membershipAnniversary` em
`lib/models/post.dart`; filtragem e fixação no topo em
`HomeFeedPage.build`/`lib/home/home_feed_page.dart`; card com selo "Fixado
para você" em `PostCard._buildMembershipAnniversaryCard`,
`lib/home/post_card.dart`). Notificação usa `NotificationType.
membershipAnniversary` (`lib/models/notification.dart`) com `targetId` = id
do post fixado — toque nela abre `PostCommentsPage` (mesmo destino de
curtida/comentário de aniversário de nascimento, reaproveitado em
`notification_navigation.dart`); `PostCommentsPage` ganhou uma terceira
chamada de `syncNotificationsForScreen` pra esse tipo.

Fixado só durante o dia do aniversário (mesma sessão, pedido logo em
seguida): `Post.isFromToday` (`lib/models/post.dart`) compara `createdAt` —
convertido pra America/Sao_Paulo via os helpers já existentes de
`event.dart` — com o dia de hoje; `HomeFeedPage` só fixa o post se
`isFromToday` também for verdadeiro, senão ele simplesmente não aparece (nem
fixado, nem solto no feed comum). Continua existindo no Firestore até a
limpeza semanal (`resetWeeklyFeed`), só fica invisível antes disso — não
precisou mexer nas Cloud Functions.

**Aba Contribua: campo "Operação" da conta bancária + ajuste de layout
(24/08/2026):** faltava o campo "Operação" (código exigido por alguns bancos,
principalmente Caixa Econômica Federal, além de agência/conta pra TED/DOC) —
adicionado a `BankAccountEntry` (`lib/models/contribution_info.dart`), com
input em `ContributeSettingsPage._buildBankCard` e exibição em
`_BankCard`/`contribute_page.dart`. Também: nome da igreja agora trunca em
uma linha só (`maxLines: 1`, `TextOverflow.ellipsis`), e o título "Contribua"
+ botão "Configurar" (admin) foram movidos pra uma `Row` única, substituindo
o `ScreenTitle` genérico compartilhado — layout mais compacto, sem o botão
solto numa linha própria abaixo do título.

**Caixa de Saída de mensagens, remetente fora do próprio broadcast, badge de
Devocionais em tempo real e flyer de devocional tocável (24/08/2026):**
- `MessageOutboxPage` (`lib/messages/message_outbox_page.dart`, sem
  equivalente nativo, mesma linha de `MessagesPage` de 21/08/2026): acesso
  fica **dentro de `MessagesPage`**, não um tile do menu Mais — passou por
  dois ajustes na mesma sessão a pedido do usuário: primeiro um ícone na app
  bar, depois trocado (ainda 24/08/2026) por um botão de largura cheia
  "Mensagens Enviadas" no rodapé da tela (`OutlinedButton.icon`, abaixo da
  lista de mensagens, dentro do mesmo `Column`), sempre só pra quem
  `canSendMessagesProvider`. Lista só as mensagens que **o próprio usuário
  logado enviou**
  (`sentMessagesProvider` filtra `senderUid == uid` em memória sobre
  `MessageRepository.watchSent`, mesmo padrão de índice evitável já usado em
  `AppMessage.isRecipient` — evita um `where('senderUid', ...)` que exigiria
  índice composto combinado com `orderBy('createdAt')`), cada item em
  `ExpansionTile` com o texto completo — não navega pra `MessageDetailPage` de
  propósito, porque essa tela marca como lida ao abrir
  (`_markAsReadOnceLoaded`) e contaria o próprio remetente/admin como leitor.
- `AppMessage.isRecipient` (`lib/models/app_message.dart`) passou a excluir o
  remetente de um envio `sendToAll` — antes um admin que mandava mensagem pra
  todos via `sendToAll` também recebia a própria mensagem na Caixa de Entrada;
  agora só a vê na Caixa de Saída. Continua valendo se o remetente se incluiu
  deliberadamente entre destinatários específicos (`recipientUids`).
- `devotionalsProvider` (`lib/data/devotional_repository.dart`) virou
  `StreamProvider` (era `FutureProvider`, `DevotionalRepository.getPublished`
  removido em favor de `watchPublished`) — mesmo padrão de tempo real já
  usado em mensagens/usuários pendentes/pedidos de oração. Novo
  `unreadDevotionalsCountProvider` alimenta um `Badge` no ícone "Devocionais"
  da barra inferior (`main_shell.dart`), mesmo padrão de badge já usado nos
  tiles do menu Mais — fecha o pedido do usuário de contador em tempo real
  também pra Devocionais (Mensagens/Gerenciar Usuários/Pedidos de Oração já
  eram `StreamProvider` antes desta sessão).
- Texto da devocional (`DevotionalDetailPage`) ganhou `textAlign:
  TextAlign.justify`.
- `PostCard` (`lib/home/post_card.dart`): o flyer do post automático de
  devocional (`PostType.devotional`) agora é tocável, igual já acontecia com
  evento — leva pra `DevotionalDetailPage` daquele dia via `Post.targetId`
  (já gravado como o id da devocional pela Cloud Function nativa, conferido
  em `functions/index.js`; não precisou mudar nada lá).
- Conferido nesta sessão e **já implementado antes dela**, sem mudança
  necessária: marcar notificação como lida ao entrar na tela relacionada
  mesmo sem vir de um push (`syncNotificationsForScreen`, chamado no
  `initState` de todas as telas ligadas a um tipo de notificação, `Gerenciar
  Usuários` incluso) e o % de cadastro considerando também os campos
  opcionais, não só os obrigatórios (`CurrentUserProfile.completionPercent`,
  soma nome/CPF/e-mail/data de nascimento + telefone/endereço + dados
  eclesiásticos do `Member` vinculado, 12 campos no total).

**Área Recepção + papéis Dirigentes/Pastor (24/08/2026, unificada numa só
tela em 25/08/2026):** sem equivalente no nativo — feature nova, pedida
direto pra este app. Três papéis em `UserRole`/`firestore.rules` (`recepcao`,
`dirigentes`, `pastor`), atribuíveis em `manage_users_page.dart` igual aos
demais papéis. Modelo em `lib/models/visitor.dart` (`Visitor` completo +
`VisitorSummary`, recorte sem telefone), repositório em
`lib/data/visitor_repository.dart`.

Só existe **um** tile no menu Mais ("Recepção", `lib/reception/reception_page.dart`),
visível pra quem tem qualquer um dos três papéis (ou admin) — ícone
composto `_ReceptionIcon` em `main_shell.dart` (mesa/computador
`Icons.desk_outlined` + boneco `Icons.person` no canto, mesma composição de
`_SettingsMailIcon`). O que aparece **dentro** da tela depende do papel de
quem abriu (25/08/2026, revisão pedida pelo usuário — antes eram três telas
com três tiles separados):
- `canRegisterVisitors` (Recepção): formulário de cadastro (nome\*, telefone
  opcional com `PhoneInputFormatter`, igreja opcional — vazio quando o
  visitante não frequenta nenhuma —, primeira visita como dois
  `CheckboxListTile` mutuamente exclusivos "Sim"/"Não", não mais um switch).
  Grava só em `visitors/{id}` — o resumo e a notificação pra Dirigentes são
  efeito colateral da Cloud Function.
- `canRegisterVisitors || canViewVisitorDetails` (Recepção e/ou Pastor):
  lista completa (`visitors`, telefone incluso como link `wa.me/55<dígitos>`,
  mesmo padrão de `PrayerPage._sendToResponsible`) — exclusão só aparece se
  `canRegisterVisitors`.
- Senão, `canViewVisitorSummaries` sozinho (só Dirigentes, sem Recepção nem
  Pastor): lista resumida (`visitorSummaries`, nome/igreja/primeira visita,
  **sem telefone**) — é o único caso que de fato só enxerga essa coleção,
  porque `firestore.rules` só libera `read` de `visitors` pra Recepção/Pastor
  (ver abaixo); um Dirigentes que também seja Recepção ou Pastor cai no item
  acima, na lista completa, sem seção resumida duplicada.

Decisões confirmadas com o usuário: Dirigentes e Pastor são **só leitura** —
quem cadastra/corrige/exclui um visitante é sempre a Recepção (ou admin);
Pastor **não** recebe push, só vê os dados dentro do app (diferente de
Dirigentes, que é avisado na hora).

Por que duas coleções em vez de uma só: Firestore não faz segurança por
campo dentro de um documento — pra Dirigentes de fato não conseguir ler o
telefone (não só a UI escondendo), o telefone precisa estar em outro
documento que Dirigentes não tem `read` liberado. `visitors/{id}` (completo)
e `visitorSummaries/{id}` (mesmo id, sem telefone) resolvem isso.

Em `SIBValApp2/functions/index.js`: novo trigger `onVisitorCreated`
(`visitors/{visitorId}`) espelha o resumo em `visitorSummaries` e notifica
(push + central de notificações, audience `dirigentes`) admins e quem tem o
papel Dirigentes — espelha `onPrayerRequestCreated`/
`getAdminAndIntercessaoTokens`, com o helper novo
`getAdminAndDirigentesTokens`. Em `firestore.rules`: funções `isRecepcao()`/
`isDirigentes()`/`isPastor()` (mesmo padrão de `isIntercessao()`); `visitors`
com `read` pra Recepção/Pastor e `create/update/delete` só pra Recepção;
`visitorSummaries` com `read` pra Dirigentes/Recepção/Pastor, escrita só via
Admin SDK (delete liberado pra Recepção acompanhar a exclusão do visitante
completo — `VisitorRepository.deleteVisitor` apaga os dois docs num batch).

**Deploy feito (25/08/2026):** diferente das outras vezes, aqui o deploy foi
necessário pra destravar um bug real — a Recepção conseguia ver a tela (as
permissões de UI funcionavam), mas o cadastro de visitante falhava
silenciosamente, porque `firestore.rules`/`onVisitorCreated` só existiam no
código-fonte, nunca publicados (`firebase functions:list` confirmou que
`onVisitorCreated` não estava entre as functions deployadas). Usuário deu o
aval explícito pra isso desta vez; rodei
`firebase deploy --only firestore:rules,functions:onVisitorCreated --project
sibval-app-project` — concluído com sucesso. `ReceptionPage._submit` também
ganhou tratamento de erro (antes um erro do Firestore, como permission-denied,
era engolido em silêncio pelo `try/finally` sem `catch` — o botão parecia não
fazer nada) e o sucesso virou um `AlertDialog` com botão OK, no lugar do
`SnackBar` anterior (pedido do usuário).

**Ajustes de UX na Recepção (25/08/2026):**
- Depois de cadastrar com sucesso, o foco volta pro campo Nome
  (`_nameFocusNode.requestFocus()`) pra agilizar cadastros em sequência.
- A linha do telefone (lista completa) usava `Row(mainAxisSize: MainAxisSize.min)`
  sem nenhum `Flexible`/`Expanded` no `Text` — com fonte grande (acessibilidade,
  comum em Samsung/OneUI) o número podia estourar a largura do card e ficar
  cortado. Trocado por `Flexible` + `overflow: TextOverflow.ellipsis`.
- Selo "Primeira visita"/"Já visitou" (lista resumida, papel Dirigentes): um
  `Chip` comum encolhe pro tamanho do texto, então os dois ficavam com
  tamanhos diferentes lado a lado. Virou `_VisitBadge`, um `Container` de
  largura fixa (116).
- "Sem igreja" → "Não congrega em uma igreja" (as duas listas).
- Visitantes "arquivam" no dia seguinte: `Visitor.isFromToday`/
  `VisitorSummary.isFromToday` (mesmo padrão de `Post.isFromToday`, fuso
  America/Sao_Paulo) filtram `VisitorRepository.watchAll`/`watchSummaries` —
  só quem foi cadastrado hoje aparece na lista. Puramente client-side (sem
  Cloud Function nem exclusão): cadastros de dias anteriores continuam no
  Firestore, só saem da tela. Como os providers são `autoDispose`, o corte
  de "hoje" é recalculado toda vez que a tela reabre.
- Título "Recepção" estava mais baixo/mais à direita que o das outras telas
  porque a tela inteira (título incluso) vivia dentro de um único `ListView`
  com `padding: EdgeInsets.all(16)`, somando com o padding interno do próprio
  `ScreenTitle` (16,16,16,8) — dobrava o respiro. Reestruturado pro padrão do
  resto do app: `Column(crossAxisAlignment: start, children: [ScreenTitle(...),
  Expanded(child: ListView(...))])`, sem padding extra ao redor do título.

**Aviso de atualização "não funcionava" (24/08/2026) — não era bug de
código.** Investigado a pedido do usuário; `update_gate.dart` depende 100%
de alguém atualizar manualmente `settings/appVersion.latestVersionCode` no
Console do Firebase a cada publicação nova (não há automação/CI ligando o
`pubspec.yaml` a esse documento) — o usuário confirmou que nunca chegou a
configurar esse documento, então o aviso nunca teve motivo pra aparecer.
Nenhuma mudança de código foi feita; ele precisa criar/editar
`settings/appVersion` manualmente (campos: `latestVersionCode` = build atual
do Android, ex. 25; opcionalmente `latestVersionName`, `androidUrl`,
`iosUrl`) toda vez que publicar uma nova versão daqui pra frente.

**Post de evento some do feed em tempo real ao ser excluído/cancelado
(24/08/2026):** simétrico ao `onEventCreatedFeedSync`/`onEventUpdatedFeedSync`
que já postava em tempo real (reforma de 24/08/2026 acima) — faltava o
caminho inverso. Só em `SIBValApp2/functions/index.js` (só editei o
código-fonte — **não fiz `firebase deploy`**, mesma cautela de sempre):
- Novo helper `removeEventFromFeed(db, eventDoc, evt)` apaga
  `posts/{evt.feedPostId}` via `recursiveDelete` (post + comentários) e, se
  `eventDoc` foi passado, limpa `postedToFeed`/`feedPostId` nele.
- Nova `onEventDeletedFeedSync` (`onDocumentDeleted("events/{eventId}")`):
  cobre exclusão de evento pontual (`EventRepository.delete`), de série
  recorrente inteira (`RecurringEventRepository.delete`, que apaga cada
  instância em `events` antes de apagar o molde) e de qualquer instância
  apagada avulsa — em todos os casos o documento em `events` some de
  verdade, o gatilho dispara e remove o post associado, se houver.
- `syncEventFeedOnWrite` (usada por `onEventUpdatedFeedSync`) ganhou o
  caminho inverso: antes só tratava `status !== "published"` como "nada a
  fazer"; agora, se o evento já estava postado (`postedToFeed && feedPostId`)
  e deixou de ser `"published"`, remove o post do feed. Cobre o pedido
  específico do usuário — instância recorrente desabilitada só pra aquela
  semana via `RecurringEventRepository.cancelNextOccurrenceOnly`/
  `deactivateSeries` (que só faz `status: 'cancelled'` na instância, sem
  apagar o documento) também tira o post na hora, não só a exclusão de
  verdade.
- Como a remoção zera `postedToFeed`, o job `repostUpcomingEventFeedPosts`
  (roda a cada 15min, filtra `postedToFeed == true`) automaticamente para de
  tentar repostar um evento cancelado, sem precisar de filtro extra por
  `status` nele.
- **Deploy feito na mesma sessão (24/08/2026):** `onEventDeletedFeedSync`
  (criada) e `onEventUpdatedFeedSync` (atualizada) — aval explícito do
  usuário pra esse deploy específico, mesmo padrão do caso Recepção
  (25/08/2026 abaixo). `firebase deploy --only
  functions:onEventDeletedFeedSync,functions:onEventUpdatedFeedSync
  --project sibval-app-project`.

**Botão "Remarcar" pra ocorrência recorrente cancelada avulsamente
(24/08/2026):** o usuário testou o item acima e percebeu a lacuna simétrica —
`cancelNextOccurrenceOnly`/`deactivateSeries` já existiam (marcam `status:
'cancelled'` na instância de `events`, sem apagar o documento), mas nada no
app fazia o caminho inverso: não havia jeito de voltar aquela instância pra
`published` depois de cancelada. O switch da lista de recorrentes não serve
pra isso (controla `active` do molde em `recurringEvents`, não o `status` da
instância — depois de um `cancelNextOccurrenceOnly` ele continua mostrando
ligado). Perguntado ao usuário como deveria funcionar; escolhida a opção
"botão dedicado na lista".

- `RecurringEventRepository` (`lib/data/recurring_event_repository.dart`):
  helper interno renomeado de `_findUpcomingInstanceId` pra
  `_findUpcomingInstance` (devolve o `QueryDocumentSnapshot`, não só o id,
  reaproveitado por `applyEditToUpcomingInstance`,
  `_cancelUpcomingInstance` e os dois métodos novos). Novo
  `getUpcomingInstance(recurringEventId)` devolve o `Event` da instância mais
  próxima independente do status; novo `reactivateUpcomingInstance` volta o
  `status` dela pra `published` — a Cloud Function `onEventUpdatedFeedSync`
  (já existente, ver item acima) cuida sozinha de repostar no feed em tempo
  real, sem precisar de nenhum código extra pro caminho de volta. Novo
  provider `upcomingRecurringInstanceProvider` (`FutureProvider.autoDispose
  .family<Event?, String>`).
- `recurring_event_list_page.dart` (`_RecurringEventTile`): quando a
  instância mais próxima da série está com `status == cancelled`, mostra uma
  faixa "Próxima data cancelada" com botão "Remarcar" abaixo do card — chama
  `reactivateUpcomingInstance` e invalida o provider. O mesmo provider é
  invalidado depois de cancelar (`_onActiveChanged`) e depois de editar via
  `RecurringEventFormPage` (o `onTap` do card já invalidava
  `recurringEventsProvider`; ganhou a invalidação do novo provider junto).

**Papel/área "Recepção" renomeada pra "Introdução"; papéis Introdução e
Dirigentes agora também concedidos automaticamente por ministério; campo
"Como conheceu a igreja" e sugestão de nome de quem convidou (mesma sessão,
pedido do usuário):**

- **Rename mecânico "Recepção" → "Introdução", inclusive o papel** (não é só
  rótulo): `UserRole.recepcao` virou `UserRole.introducao` (valor Firestore
  também mudou de `'recepcao'` pra `'introducao'` — contas que já tinham o
  papel antigo perdem o acesso até alguém marcar o chip "Introdução" de novo
  em `manage_users_page.dart`; não existe migração automática do valor
  antigo). Pasta `lib/reception/` virou `lib/introduction/` (`git mv`),
  `reception_page.dart` virou `introduction_page.dart`,
  `ReceptionPage`/`_ReceptionPageState` viraram `IntroductionPage`/
  `_IntroductionPageState`. Em `main_shell.dart`: `_ReceptionIcon` virou
  `_IntroductionIcon` (mesmo desenho — mesa + boneco —, só o nome da classe e
  o rótulo do tile mudaram), `canAccessReception` virou
  `canAccessIntroduction`. `SIBValApp2/firestore.rules`: `isRecepcao()` virou
  `isIntroducao()` (`hasRole('introducao')`), usada em `visitors`/
  `visitorSummaries`. **Editei só o código-fonte das regras — não fiz
  `firebase deploy`**, mesma cautela de sempre; até o deploy, as regras em
  produção ainda checam `'recepcao'` (então o rename fica incompleto em
  produção — ver decisão de deploy pendente no fim desta entrada).

- **Papéis Introdução e Dirigentes concedidos/revogados automaticamente por
  ministério** (`SIBValApp2/functions/index.js`, só código-fonte, sem
  deploy): novo `MINISTRY_ROLE_SYNC` (`introducao` ⟵ ministério "Introdução";
  `dirigentes` ⟵ ministério "Dirigente" ou "Dirigentes", singular/plural
  aceitos) e `syncMemberMinistryRoles`, chamada por dois novos triggers
  (`onMemberCreatedMinistryRoleSync`/`onMemberUpdatedMinistryRoleSync`, mesmo
  padrão dos outros pares create/update em `members/{memberId}`). Recalcula
  do zero a cada escrita no membro (não diffa antes/depois) comparando os
  nomes em `member.ministries[].ministryName` — normalizado via `normalizeKey`
  (helper já existente no arquivo, reaproveitado em vez de duplicado) — contra
  a lista acima; ganha o papel quem entra no ministério, perde quem sai,
  idempotente nas demais escritas. O nome do ministério é texto livre
  (`ManageMinistriesPage`) — o sync só funciona se o admin/Secretaria criar
  literalmente um ministério chamado "Introdução" e outro "Dirigente(s)" e
  atribuir os membros a ele em `members_page.dart`; não há vínculo
  estrutural, só comparação de string normalizada.
  `findLinkedUserUid` (já existente, usada pelo aniversário de membresia)
  ganhou prioridade pro campo `member.linkedUid` antes de cair pro match por
  e-mail — mais confiável, e é o que faz o sync funcionar mesmo pra um membro
  que só ganhou `linkedUid` depois de já estar no ministério (aprovação de
  cadastro posterior ao cadastro manual pela Secretaria), já que a função
  recalcula do zero a cada escrita.
  **Sem backfill**: quem já estava num desses ministérios antes desta
  mudança só ganha o papel na próxima vez que o documento do membro for
  escrito de novo (reatribuir o ministério, editar o membro, etc.) — não
  rodei nenhum script de migração one-off pros já cadastrados.

- **Campo "Como conheceu a igreja" no cadastro de visitante**
  (`introduction_page.dart`), **revisado três vezes na mesma sessão**:
  1. Versão original: categoria→detalhe em dois `DropdownButtonFormField`
     em cascata, campo opcional.
  2. Virou **um dropdown só** (`DropdownButtonFormField<String>`,
     `isExpanded: true`), **obrigatório** (`_howFoundError`, mesmo padrão do
     campo Nome), com todas as opções agrupadas por categoria via
     `DropdownMenuItem` com `enabled: false` fazendo de cabeçalho não
     selecionável — "Membro da Igreja" destacado em primeiro lugar, antes
     de qualquer cabeçalho (pedido do usuário — é o caso mais comum), com
     o emblema da igreja (`assets/images/icon_sibval.png`, mesmo ícone da
     tela de login) ao lado do texto.
  3. Cabeçalhos de categoria removidos a pedido do usuário — virou lista
     plana única, sem agrupamento visual (`howFoundChurchOptions` direto,
     sem `howFoundChurchCategoryOrder`, que foi removido do catálogo por
     ter ficado sem uso).
  Em todas as versões, `howFoundCategory` continua gravado a partir de
  `HowFoundChurchOption.category` (`lib/util/how_found_church_options.dart`)
  mesmo sem aparecer mais na UI — "Membro da Igreja" grava
  `howFoundCategory: 'Indicação'` por baixo. Categorias/opções: Internet
  (Instagram/Google), Indicação (Membro da Igreja/Familiar/Amigo),
  Comunidade (Evento/Convite/Culto/Evangelismo), Outros (item único, sem
  sub-detalhe). `Visitor` (`lib/models/visitor.dart`) tem
  `howFoundCategory`/`howFoundDetail`/`invitedByName` — os dois primeiros
  são campos String simples no model (obrigatoriedade é só de UI, o model
  não força). `VisitorRepository.registerVisitor` e `VisitorFullTile`
  (`visitor_tiles.dart`) inalterados desde a primeira versão. Não entrou em
  `VisitorSummary`/`visitorSummaries` (papel Dirigentes) — fora do pedido,
  mantido igual.

- **Sugestão de nomes em "Convidado por"**: campo só aparece quando a opção
  escolhida é "Membro da Igreja" (`howFoundChurchInvitedByDetail`) —
  `_InvitedByField`, um `Autocomplete<String>` (`textEditingController`
  externo, pra poder ler `.text` no `_submit` igual aos outros campos).
  **Bug real relatado pelo usuário** (o "erro ao selecionar Membro da
  Igreja" — a suspeita inicial de `DropdownButtonFormField` acima estava
  errada): `Autocomplete`/`RawAutocomplete` exige que, se
  `textEditingController` for passado, um `focusNode` também seja — doc
  do `RawAutocomplete`: "the main purpose... is to allow the use of a
  separate text field..." — faltava o `focusNode`, e o widget quebrava
  (`assert((focusNode == null) == (textEditingController == null))` em
  `flutter/src/widgets/autocomplete.dart`, exatamente o arquivo que apareceu
  no erro). Corrigido adicionando `_invitedByFocusNode` (`FocusNode`,
  mesmo padrão de `_nameFocusNode`) em `_IntroductionPageState`, passado
  pra `_InvitedByField` junto do controller e repassado pro `Autocomplete`.
  Fonte das sugestões: `membersProvider` (`lib/data/member_repository.dart`,
  já existente, `StreamProvider` em tempo real sobre `members`) — **não**
  criei coleção/Cloud Function nova pra isso. Decisão: a coleção `members`
  sozinha já cobre "membros/usuários cadastrados" (pedido literal do
  usuário), porque todo cadastro de usuário aprovado também vira um `Member`
  (`MemberRepository.upsertFromUser`, chamado em `ManageUsersViewModel`/
  `manage_users_page.dart` ao aprovar) — e `members` já tem `read` liberado
  a qualquer autenticado em `firestore.rules`, ao contrário de `users`
  (`list` é admin-only, então uma sugestão baseada em `users` exigiria afrouxar
  essa regra ou criar uma Cloud Function/coleção espelho só pra nomes —
  evitado por ser desproporcional ao pedido). Comparação case/acento-
  insensível via `_normalizeName` (helper local no arquivo, só troca as
  vogais acentuadas/ç/ñ mais comuns em português — sem pacote novo).

**Deploy feito (mesma sessão):** aval explícito do usuário —
`firebase deploy --only
firestore:rules,functions:onMemberCreatedMinistryRoleSync,functions:onMemberUpdatedMinistryRoleSync
--project sibval-app-project`. As regras em produção já checam
`'introducao'` (não mais `'recepcao'`) e os dois triggers de sincronização
por ministério já estão ativos. Continua valendo o aviso acima: quem tinha
o papel `'recepcao'` gravado no próprio usuário precisa ser marcado de novo
com o chip "Introdução" em Gerenciar Usuários — o valor antigo no banco não
foi migrado.

**Banner de aniversário de membresia (fixo, não mais post) + retratação em
tempo real (25/08/2026):** revisão do que tinha entrado em 24/08/2026 — o
usuário pediu pra não ser mais um post fixado dentro da lista rolável do
feed, e sim uma faixa fixa **fora** da lista, igual ao `ownBirthdayBanner`
original do `HomeFragment.kt`/`fragment_home.xml` nativo (TextView fora do
RecyclerView, sem curtir/comentar). `HomeFeedPage` virou
`ConsumerStatefulWidget` (era `ConsumerWidget`) só pra ter `initState` e
chamar `syncNotificationsForScreen(type: membershipAnniversary)` sem
`targetId` (mesmo padrão do tipo `birthday`) — a tela em si já basta pra
marcar como lida/cancelar da barra, sem precisar abrir `PostCommentsPage`.
`_MembershipAnniversaryBanner` (novo widget privado em `home_feed_page.dart`)
continua lendo do mesmo documento em `posts` (`postType:
membership_anniversary`, criado pela Cloud Function) via `postsProvider`
(`StreamProvider`) — só que agora filtrado pra fora da lista renderizada, não
dentro dela; `PostCard._buildMembershipAnniversaryCard` foi removido.
Depois, a pedido do usuário, o banner ficou mais compacto (padding vertical
16→8, fonte 13, `maxLines: 2` com reticências).

Notificação desse tipo passou a levar pro Início (antes abria
`PostCommentsPage`, que não faz mais sentido pra uma mensagem sem
curtir/comentar) — `NotificationType.membershipAnniversary` virou um `case`
próprio em `notification_navigation.dart` (separado de
`postLike`/`postComment`): dá `popUntil(isFirst)` e troca a aba do
`MainShell` pra Início via `ref.read(mainShellTabIndexProvider.notifier)`.
Isso exigiu abrir mão do campo `_index` local (era um `int` dentro de
`_MainShellState`) em favor de um `StateProvider<int>` de verdade
(`mainShellTabIndexProvider`, `homeTabIndex = 2`, ambos top-level em
`main_shell.dart`) — só assim dava pra trocar a aba de fora da árvore de
widgets do `MainShell` (de dentro de `navigateForNotificationType`, chamada
tanto pelo toque na Central quanto pelo toque na notificação do sistema).
`MainShell` virou `ConsumerWidget` (era `StatefulWidget` com um `Consumer`
aninhado por dentro) nesse mesmo pente-fino, eliminando o aninhamento
redundante. Precisa de `import 'package:flutter_riverpod/legacy.dart' show
StateProvider;` — `StateProvider` não é mais exportado por
`flutter_riverpod.dart` direto no Riverpod 3.x usado aqui (mesmo padrão já
usado em `event_filter.dart`/`eventFilterProvider`).

**Retratação em tempo real quando a Secretaria corrige/edita a data de
membresia** — pedido explícito do usuário ("se alterar a data de membresia
deve atualizar a mensagem instantaneamente"), com uma investigação em duas
camadas:

1. Criação (data passa a ser hoje) já funcionava em tempo real — os
   gatilhos `onMemberCreatedMembershipAnniversaryFeedSync`/
   `onMemberUpdatedMembershipAnniversaryFeedSync` (`SIBValApp2/functions/index.js`)
   já estavam deployados desde a sessão de 24/08/2026 (confirmado via
   `firebase functions:list`, apesar do texto daquela entrada dizer "não fiz
   deploy" — a nota ficou desatualizada, o deploy aconteceu em algum momento
   não documentado). `postsProvider` sendo `StreamProvider` já bastava pro
   cliente refletir na hora.
2. **Faltava o caminho inverso** (data corrigida pra deixar de ser hoje):
   nada retratava o post já fixado mais cedo no mesmo dia. Nova
   `removeMembershipAnniversaryFromFeed(db, memberDoc, birthdayUid)` (espelha
   `removeEventFromFeed`), chamada de `syncMemberMembershipAnniversaryFeed`
   quando a data deixa de bater com hoje (ou é removida).

   A primeira versão dessa function confiava só no ponteiro salvo no membro
   (`membershipAnniversaryFeedPostId`) pra achar o post a apagar — e não
   funcionou no teste do usuário. Causa raiz, achada por inspeção de código
   (não pelos logs — `firebase functions:log` se mostrou não-confiável neste
   ambiente, devolvendo recortes diferentes/incompletos a cada chamada, até
   pra janelas de tempo idênticas): `MemberRepository.update()`
   (`lib/data/member_repository.dart`) salvava a edição com `.set(data)`
   **sem `SetOptions(merge: true)`** — um `set` sem merge sobrescreve o
   documento inteiro, apagando em silêncio qualquer campo que só a Cloud
   Function escreve e que não está no mapa `data` do Flutter
   (`lastMembershipAnniversaryFeedPostDate`, `membershipAnniversaryFeedPostId`,
   e também `lastBirthdayFeedPostDate` do aniversário de nascimento). Esse
   bug pré-existia (não foi introduzido nesta sessão) e half-orfanzinhou o
   post assim que a primeira edição de teste rodou, antes mesmo da function
   de retratação existir — o ponteiro já tinha sumido do membro quando a
   function nova foi rodar. Corrigido adicionando `SetOptions(merge: true)`
   nas duas chamadas de `.set(data)` dentro de `update()` (branch normal e
   branch de migração de id canônico) — campos explícitos no mapa (inclusive
   `null`) continuam sobrescrevendo normalmente, merge só preserva o que não
   está listado.

   Como o ponteiro já podia estar perdido (e podia haver outros órfãos
   pré-existentes de testes anteriores), `removeMembershipAnniversaryFromFeed`
   foi reescrita pra **não depender do ponteiro**: consulta `posts` direto
   por `postType == "membership_anniversary" && targetId == birthdayUid` e
   apaga qualquer resultado — autorrecuperável, limpa órfãos de qualquer
   origem, não só os futuros.

**Deploy feito (mesma sessão, duas rodadas — a segunda corrigindo a
primeira):** aval explícito do usuário nas duas vezes — `firebase deploy
--only functions:onMemberCreatedMembershipAnniversaryFeedSync,functions:onMemberUpdatedMembershipAnniversaryFeedSync
--project sibval-app-project`. Como o gatilho só reage a escritas novas, a
edição de teste que o usuário já tinha feito antes do segundo deploy não
reprocessou sozinha — precisou salvar o mesmo membro de novo pra function
atualizada rodar e limpar o órfão. Confirmado funcionando pelo usuário depois
disso.

**Fluxo de instalação de build de debug no celular físico (mesma sessão) —
ver `[[feedback_debug_apk_install_workflow]]` na memória automática do
Claude Code:** `flutter install` reaproveita silenciosamente o APK antigo em
`build\app\outputs\flutter-apk\app-debug.apk` sem recompilar, mesmo com
código-fonte mais novo — já causou um "não funcionou" que na verdade era
build velha. `flutter run` funciona, mas se o celular já tinha o app de
produção instalado (assinatura de release), o Android exige desinstalar
antes de instalar a build de debug (assinatura diferente), o que apaga os
dados locais e desloga a conta. Fluxo usado a partir de então: `flutter
build apk --debug` (confirma pelo timestamp do `.apk` que é mais novo que os
`.dart` editados) seguido de `adb install -r` direto — reinstala no lugar,
sem apagar dados, contanto que a build anterior já fosse debug (mesma chave
de assinatura entre builds debug).

**Campo "Texto base" (livro/capítulo/versículo) no cadastro de devocional
(26/08/2026):** sem equivalente no `Devotional.kt` nativo — feature nova,
pedida direto pra este app. `Devotional` (`lib/models/devotional.dart`)
ganhou `baseBookId`/`baseBookName`/`baseChapter`/`baseVerse` (todos
opcionais/nulos) e o getter `baseReference` ("Livro capítulo:versículo",
`null` se algum dos três não foi preenchido). `DevotionalRepository.create`/
`update` (`lib/data/devotional_repository.dart`) gravam os quatro campos —
`update` já usava `.update()` (merge automático por campo, sem o risco do
bug de `.set()` sem `SetOptions(merge: true)` já documentado em
`members`/`MemberRepository`, ver `[[feedback_firestore_set_merge_and_log_verification]]`
na memória automática).

`DevotionalFormPage` (`lib/devotionals/devotional_form_page.dart`) ganhou o
campo "Texto base" logo abaixo do Título: `_BaseBookField` (livro digitável
com sugestões — mesmo padrão embutido-na-árvore de `_InvitedByField` em
`introduction_page.dart`, escolhido de propósito em vez de `Autocomplete`,
que já causou um bug de assert nesta base) alimentado por
`bibleBooksProvider`; `_ChapterDropdown`/`_VerseDropdown` (dropdowns comuns)
alimentados por `bibleChapterCountProvider`/`bibleVersesProvider` — mesmas
fontes já usadas pela aba Bíblia (`lib/data/bible_repository.dart`), sem
tabela nova. Capítulo só habilita depois do livro resolvido (seleção na
lista de sugestões, ou nome digitado que bate exatamente com um livro ao
perder o foco); versículo só depois do capítulo. Campo opcional — não
preencher os três deixa a devocional sem texto base, sem bloquear o salvar.

Exibição: `DevotionalsListPage`/`DevotionalRepositoryPage` mostram
"Título (Livro cap:vers)" quando há texto base; `DevotionalDetailPage`
mostra o texto base como segunda linha, abaixo do título, dentro do
`_DevotionalHeader` fixo (não rola com o texto). Em
`SIBValApp2/functions/index.js`, `postDevotionalToFeed` também compõe
"Título (Livro cap:vers)" no texto do post automático do feed — **só editei
o código-fonte, não fiz `firebase deploy`**, mesma cautela de sempre.

Ajustes na mesma sessão, todos a pedido do usuário: Livro/Capítulo/Versículo
foram pra uma linha só (`Row` com `Expanded`, flex 3/2/2/2); a lista de
sugestões de livro passou a usar `Theme.of(context).canvasColor` em vez de
`cardColor`, pra bater com a cor que `DropdownButtonFormField` já usa por
padrão no popup de Capítulo/Versículo (confirmado no código-fonte do
Flutter: sem `dropdownColor` explícito, os dois caem em
`ThemeData.canvasColor` — não precisou fixar nenhuma cor à mão, só trocar
qual cor do tema cada um lê); os três campos ganharam
`floatingLabelBehavior: FloatingLabelBehavior.always` pro rótulo já nascer
no topo da caixa, sem esperar uma seleção.

**Versículo virou uma faixa "de... até..." (27/08/2026):** `baseVerse`
(campo único) virou `baseVerseStart`/`baseVerseEnd` em
`lib/models/devotional.dart` — `baseReference` formata `Livro cap:5` quando
`end == start` e `Livro cap:5-8` numa faixa de verdade.
`DevotionalRepository.create`/`update` gravam os dois campos.
`DevotionalFormPage`: o dropdown único de Versículo virou dois
(`_VerseDropdown` ganhou `label`/`minValue`) — "De" lista todos os
versículos do capítulo; "Até" só habilita depois de "De" escolhido (recebe
`bookId`/`chapter` nulos até lá, o que zera a lista de itens e desabilita o
dropdown) e só lista números `>= minValue` (o valor de "De"), pra nunca
montar uma faixa invertida. Selecionar "De" também preenche "Até" com o
mesmo valor por padrão — continua bastando um toque pra versículo único, sem
forçar o usuário a tocar em "Até" nesse caso comum. Leitura com fallback:
`Devotional.fromFirestore` cai pro campo antigo `baseVerse` se
`baseVerseStart` não existir (nenhuma devocional de produção tinha esse
campo ainda, mas o fallback é grátis). Mesmo fallback e mesma faixa
replicados em `postDevotionalToFeed`
(`SIBValApp2/functions/index.js`, só código-fonte, sem deploy).

**Regras de ordenação do feed "Início" (27/08/2026, pedido do usuário) —
reintroduz ranking por regra, removido em 24/08/2026 em favor de só
`createdAt`:** `_feedRank`/`_compareFeedPosts`
(`lib/home/home_feed_page.dart`) classificam cada post numa de 7 faixas
antes de renderizar a lista (a query do Firestore continua só por
`createdAt` descendente — vira o desempate dentro de cada faixa, ver
`lib/data/post_repository.dart`):

0. Post manual (`PostType.manual`) publicado hoje — "urgente".
1. Aniversariante(s) do dia.
2. Evento pontual (não recorrente) não finalizado — mais próximo primeiro.
3. Devocional de hoje (`isFromToday`).
4. Evento recorrente não finalizado — mais próximo primeiro.
5. Resto (post manual/aniversariante que não é mais de hoje) — mais recente
   primeiro.
6. "Fim da lista": eventos finalizados (pontuais e recorrentes juntos) **e**
   devocional que não é mais a de hoje (27/08/2026, correção de uma
   suposição errada da rodada anterior — ver nota abaixo) — mais recente
   primeiro (evento pelo horário de início, devocional pelo `createdAt` do
   post, via `_rankSixSortDate`).

"Finalizado" mudou de critério: `Post.isPastEvent`
(`lib/models/post.dart`) era baseado no dia civil ("verdadeiro a partir do
dia seguinte ao evento"); agora é **5 horas depois do horário de início**
(pedido explícito do usuário), mesmo campo/getter reaproveitado (nome
mantido pra não mexer nos 3 pontos que já liam `post.isPastEvent` em
`post_card.dart`). Pontual vs. recorrente vem de `Post.isRecurringEvent`
(`isRecurring` no Firestore) — campo novo, gravado só em posts de evento por
`createFeedPost` em `SIBValApp2/functions/index.js`, a partir de
`!!evt.recurringEventId` (o próprio doc do evento já distinguia isso, só não
chegava até o post). **Sem retrocompatibilidade automática**: posts de
evento já existentes no Firestore antes do deploy dessa mudança não têm o
campo `isRecurring` e caem no default `false` (tratados como pontuais) até
serem repostados (reposte 24h/6h antes, ou próxima segunda-feira).

`PostCard` (`lib/home/post_card.dart`) ganhou: sombreamento leve
(`Opacity(0.6)` no card inteiro) pra evento finalizado ou devocional que não
é mais a de hoje (`!post.isFromToday`); faixa vermelha "ATENÇÃO" (ícone +
texto, cor deliberadamente fora da paleta navy/dourado da marca) no topo do
card pra post manual publicado hoje.

Cloud Function (`SIBValApp2/functions/index.js`, só código-fonte, sem
deploy — mesma cautela de sempre): `postDevotionalToFeed` passou a
acrescentar uma linha "(Devocional diário: dd/mm/aaaa)" ao texto do post,
usando `devotional.dateKey` (a data da própria devocional, não "hoje" no
momento do cron/gatilho).

**Correção da mesma sessão:** a primeira versão deixava a devocional que não
é mais "a de hoje" presa na faixa 3 (só sombreada, sem cair de posição) —
suposição errada; corrigida a pedido do usuário pra cair na faixa 6, igual
aos eventos finalizados.

**Suposições ainda assumidas sem confirmação explícita do usuário** (pedido
tinha algumas lacunas; documentado aqui pra revisar se o comportamento não
bater com o esperado):
- Dentro da faixa 6 ("fim da lista"), ordenação por mais recente primeiro
  (evento pelo horário de início, devocional pelo `createdAt` do post) —
  não o inverso.
- Faixa 5 ("resto": manual/aniversariante que não é mais de hoje) ordenada
  por `createdAt` descendente, igual ao comportamento antigo do feed.
- Evento pontual e recorrente são dois blocos sempre separados (faixa 2
  sempre acima da 4), não intercalados por data — só a ordenação *dentro*
  de cada bloco segue a data do evento.

**Reordenação por relógio, sem depender de escrita nova (mesma sessão):** as
faixas do feed dependem de condições que mudam sozinhas com o tempo
(`Post.isPastEvent` cruzando as 5h após o início, `Post.isFromToday` virando
falso à meia-noite) — sem nenhum gatilho próprio, essas transições só
apareciam na tela quando uma escrita nova chegava pelo `postsProvider`
(`StreamProvider`), não no exato momento em que aconteciam. `HomeFeedPage`
(`_HomeFeedPageState`) ganhou um `Timer.periodic` de 1 minuto que só chama
`setState(() {})` — força o `_compareFeedPosts` recalcular contra o relógio
atual, sem nenhuma leitura nova do Firestore. Cancelado em `dispose()`. A
atualização em tempo real por escrita nova (post criado/editado/curtido)
continua funcionando do jeito que já funcionava, via `.snapshots()` — o
timer só cobre o caso que faltava.

**Remoção do reposte 24h/6h de evento + faixa nova "evento do dia" no
ranking do feed + Hoje/Amanhã calculado no cliente (27/08/2026, mesma
sessão, pedidos do usuário):**

- **Reposte 24h/6h removido.** `repostUpcomingEventFeedPosts`
  (`SIBValApp2/functions/index.js`) apagava e recriava o post do evento duas
  vezes antes do horário de início só pra subir `createdAt` (posição) e
  trocar o texto pra "(Hoje)"/"(Amanhã)". Como o ranking por regra (entrada
  acima) já cuida da posição sem depender de `createdAt`, o usuário pediu
  pra cancelar esse reposte de vez. Função removida do código-fonte e
  **excluída em produção** (`firebase functions:delete
  repostUpcomingEventFeedPosts --project sibval-app-project --force`, aval
  explícito do usuário — comando rodado por ele mesmo via `!`, porque o
  sandbox deste ambiente bloqueia `functions:delete`/`deploy --force` por
  serem destrutivos em infra de produção). Campos `feedRepost24hSent`/
  `feedRepost6hSent` pararam de ser gravados (ficam órfãos nos docs antigos
  de `events`, inofensivos, sem limpeza retroativa).

- **Backfill de `isRecurring` tentado e abortado.** Antes da remoção do
  reposte, um post de evento recorrente já existente (postado antes do
  deploy que passou a gravar `isRecurring`, ver entrada anterior) ficou
  preso sem esse campo — classificado como pontual no ranking do cliente.
  Uma tentativa de corrigir via uma Cloud Function HTTP temporária
  (`backfillEventIsRecurring`, protegida só por uma senha fixa no código)
  foi **bloqueada pelo classificador de segurança do sandbox** antes mesmo
  de aplicar a edição (endpoint público de escrita autenticado só por
  segredo em texto plano — risco real, bloqueio correto). Revertida sem
  deixar resíduo. Decisão do usuário: não mexer, deixar o ciclo semanal
  (`resetWeeklyFeed` + `postWeeklyEventsToFeed`, madrugada de segunda) se
  autocorrigir sozinho — o que já é o comportamento padrão pra qualquer
  post automático desatualizado.

- **Nova faixa 2: evento (pontual ou recorrente) que acontece hoje sobe pro
  topo do feed**, ficando só abaixo de aniversariante do dia (faixa 1) e
  post manual urgente (faixa 0) — pedido explícito do usuário, distinto da
  separação pontual/recorrente que já existia. `Post.isEventToday`
  (`lib/models/post.dart`, novo getter — compara `eventDateSaoPaulo` com o
  dia de hoje, diferente de `isFromToday` que compara `createdAt`) alimenta
  o novo `_feedRank` faixa 2 em `home_feed_page.dart`. As faixas antigas 2/3/4
  (evento pontual não-hoje / devocional / evento recorrente não-hoje)
  viraram 3/4/5, e a antiga faixa 6 ("fim da lista") virou 7 — só
  renumeração, mesma regra de cada uma. `_rankSixSortDate` renomeado pra
  `_rankSevenSortDate`.

- **Texto "(Hoje)"/"(Amanhã)" volta a ser calculado no cliente**, sem
  repostar — reintroduzido em `post_card.dart` (`PostCard._textWithHojeAmanha`,
  mesmo helper/regex que existia antes da reforma de 24/08/2026, quando foi
  removido em favor do reposte no servidor). Usa `Post.isEventTomorrow`
  (novo getter, mesmo padrão de `isEventToday`) além do já existente
  `isEventToday`. Recalculado a cada rebuild — o `Timer.periodic` de 1
  minuto que já existia em `HomeFeedPage` (ver entrada anterior,
  "Reordenação por relógio") cobre a virada de dia sem precisar de nada
  novo. `PostCard` só é usado dentro de `home_feed_page.dart` — não há outra
  tela mostrando posts de evento que precise do mesmo cuidado.

**Cor do badge de % de cadastro em escala vermelho→laranja→verde
(28/08/2026, pedido do usuário):** `_CompletionBadge`/`main_shell.dart` —
o anel de progresso do card de perfil (menu Mais) era sempre
`SibValColors.goldAccent`, sem refletir o quanto falta preencher. Novo
`_CompletionBadge._colorFor` interpola em dois trechos (`Color.lerp`
vermelho→laranja de 0% a 50%, laranja→verde de 50% a 100%) em vez de um
`Color.lerp` único ponta a ponta, que passaria por um tom sem graça no meio
do caminho. Só a cor do anel muda — o texto "`$percent%`" continua branco,
pra manter contraste sobre o fundo `navyBlueLight`.

**Cadastro de família na Introdução — campo "Acompanhantes"
(27/08/2026, pedido do usuário):** sem equivalente no nativo. Visita em
família não virou um `Visitor` por pessoa (opção descartada: um `groupId`
ligando N documentos) — continua **1 documento por visita**
(`visitors/{id}`), com os dados completos (telefone, igreja, como conheceu,
convidado por) de só um responsável, e um novo campo `companions: List<String>`
guardando só os nomes dos demais familiares que vieram junto, sem telefone
nem nenhum outro dado deles. Decisão registrada no doc comment de `Visitor`
(`lib/models/visitor.dart`): a granularidade por pessoa não se paga porque o
app não tem (e não pediu) nenhuma estatística de contagem individual de
visitantes.

`IntroductionPage` (`lib/introduction/introduction_page.dart`) ganhou uma
lista dinâmica de campos "Nome do acompanhante" (`_companionControllers`,
`+`/`x` pra adicionar/remover), logo abaixo do campo Igreja e antes de "Como
conheceu a igreja" — a pergunta de como conheceu e quem convidou vale pra
família inteira, respondida uma vez só. `VisitorRepository.registerVisitor`
ganhou o parâmetro `companions` (grava a lista direto, sem filtrar vazio —
quem filtra nomes em branco antes de montar a lista é a tela). `VisitorSummary`
(o que o papel Dirigentes lê) também ganhou `companions` — só nomes, sem
telefone de ninguém, então não fere o motivo de `visitorSummaries` existir
separado de `visitors`. `VisitorFullTile`/`VisitorSummaryTile`
(`visitor_tiles.dart`) mostram "Acompanhantes: nome1, nome2" quando a lista
não é vazia.

Em `SIBValApp2/functions/index.js`, `onVisitorCreated` passou a espelhar
`companions` em `visitorSummaries` e a acrescentar "(+N da família)" no
texto da notificação push/central pra Dirigentes/Pastor/admin — **só editei
o código-fonte, não fiz `firebase deploy`**, mesma cautela de sempre.

**Ajuste de posição/destaque dos acompanhantes (mesma sessão, pedido do
usuário):** a linha "Acompanhantes: ..." tinha ficado dentro do `subtitle`
do `ListTile`, misturada com igreja/telefone/data — sem destaque visual e
longe do nome. Movida pra dentro do `title` (`_CompanionsLine`, widget novo
e compartilhado em `visitor_tiles.dart`), logo abaixo do nome do visitante
principal, como "Com: fulano, ciclano" em negrito — tanto em
`VisitorFullTile` (Introdução/Pastor) quanto em `VisitorSummaryTile`
(Dirigentes), que já enxergava `companions` desde a implementação original
(é só nomes, sem telefone — não fere o motivo de `visitorSummaries` existir
separado de `visitors`). O nome do visitante principal (`_boldTitle`,
helper compartilhado) ganhou o mesmo negrito, pedido junto.

Cor pedida como "negrito, porém branco mesmo" pra ambos: usei
`context.textPrimary` em vez de `Colors.white` fixo ou
`SibValColors.goldAccent` (cor original da primeira versão) — o card usa
fundo branco no tema claro (`cardColor` em `app_theme.dart`), então um
branco hardcoded ficaria invisível nesse tema; `textPrimary` responde ao
tema (branco no escuro, escuro no claro), mesma convenção do resto do app.
Confirmado com o usuário via pergunta direta antes de aplicar.

**Deploy feito (mesma sessão):** o usuário reportou que a visão do Dirigentes
continuava sem mostrar acompanhantes — causa raiz era a mudança em
`onVisitorCreated` (espelhar `companions` em `visitorSummaries`) ter ficado
só no código-fonte, nunca deployada, então visitantes cadastrados depois
daquela edição continuaram indo pro Firestore sem esse campo no resumo,
mesmo já preenchendo no documento completo (`visitors`). Aval explícito do
usuário pra esse deploy específico — `firebase deploy --only
functions:onVisitorCreated --project sibval-app-project`. Sem backfill: os
cadastros feitos antes desse deploy continuam com o resumo sem
`companions`, só quem for cadastrado a partir de agora aparece com
acompanhantes na visão do Dirigentes.

**"Como conheceu a igreja" no resumo do Dirigentes + aviso de dados não
salvos ao voltar (mesma sessão, pedidos do usuário):**

- `VisitorSummary` (`lib/models/visitor.dart`) ganhou `howFoundCategory`/
  `howFoundDetail`, mesmos campos já expostos em `Visitor` — o resumo pra
  Dirigentes não tinha essa informação, só o card completo de
  Introdução/Pastor. `VisitorSummaryTile` (`visitor_tiles.dart`) passou a
  mostrar "Como conheceu: ..." igual ao card completo. Espelhado em
  `onVisitorCreated` (`SIBValApp2/functions/index.js`) e **deployado** —
  aval explícito do usuário, mesmo padrão do deploy anterior de
  `companions`. Mesma ressalva de sempre: sem backfill, só visitantes
  cadastrados a partir do deploy saem com esses campos no resumo.
- `IntroductionPage` ganhou `PopScope` (`_hasUnsavedData`,
  `_confirmDiscardAndPop`) — se algum campo do formulário de cadastro
  (nome, telefone, igreja, como conheceu, convidado por, algum
  acompanhante) tiver conteúdo e o usuário tentar voltar (seta da app bar
  ou gesto/botão do sistema), aparece um diálogo "Sair sem salvar?" antes
  de sair de fato. Só entra em jogo pra quem vê o formulário (papel
  Introdução) — os controllers ficam sempre vazios pros outros papéis, que
  só leem listas.

  **Bug relatado pelo usuário na mesma sessão:** preencher Nome/Telefone/
  Igreja e voltar saía sem aviso — só "Como conheceu" (dropdown) e
  acompanhantes (que passam por `setState` nos botões +/-) disparavam o
  aviso. Causa: `canPop: !_hasUnsavedData` só é reavaliado quando `build()`
  roda de novo, e os `TextField`s de Nome/Telefone/Igreja/Convidado por não
  tinham nenhum `onChanged`/listener chamando `setState` — digitar neles não
  reconstruía a tela, então `canPop` ficava preso no valor calculado no
  primeiro build (sempre `true`, formulário vazio). Corrigido adicionando
  `_onFormFieldChanged` (só `setState(() {})`) como listener de
  `_nameController`/`_phoneController`/`_churchController`/
  `_invitedByController` (`initState`/`dispose`) e de cada controller de
  acompanhante (`_addCompanion`/`_removeCompanion`) — agora qualquer
  digitação reconstrói a tela e `canPop` fica sempre correto.

**"Convidado por" no lugar de "Como conheceu" quando for Membro da Igreja
(mesma sessão, pedido do usuário):** no resumo do Dirigentes
(`VisitorSummaryTile`), quando `howFoundDetail ==
howFoundChurchInvitedByDetail` ("Membro da Igreja"), a linha vira "Convidado
por: {invitedByName}" em vez de "Como conheceu: Membro da Igreja" — pra
qualquer outro valor, continua mostrando "Como conheceu: ...". `VisitorSummary`
ganhou `invitedByName`, espelhado em `onVisitorCreated`
(`SIBValApp2/functions/index.js`) e **deployado** — aval explícito do
usuário, mesma ressalva de sempre: sem backfill, só visitantes cadastrados a
partir do deploy saem com `invitedByName` no resumo. Rótulo usado foi
"Convidado por" (não "Convidado de", como o
pedido descreveu informalmente) pra bater com o mesmo texto já usado em
`VisitorFullTile` — evita dois rótulos diferentes pro mesmo dado entre os
dois cards.

**Selo "Primeira visita"/"Já visitou" movido pro canto superior direito do
card (mesma sessão, pedido do usuário):** em `VisitorSummaryTile`, o selo
saiu do `trailing` do `ListTile` (onde ficava centralizado verticalmente,
competindo com o resto do conteúdo) e virou um `Positioned(top: 8, right: 8)`
dentro de um `Stack` que envolve o `ListTile`. O `contentPadding` do
`ListTile` ganhou `140` de margem direita (largura do `VisitBadge`, 116, +
folga) pra nome/igreja/como-conheceu/data nunca ficarem por baixo do selo,
em qualquer linha — não só na primeira.

**Ordem de Culto — cadastro (27/08/2026, pedido do usuário):** sem
equivalente no nativo (`SIBValApp2` só tinha o rótulo placeholder "Ordem de
Culto (em breve)", nunca implementado) — feature nova, primeira etapa (só a
tela de inserção; listagem/edição/exclusão ficam pra depois). Modelo em
`lib/models/service_order.dart` (`ServiceOrder`, `PreludeStyle`,
`MissionMoment`, `BibleReference`), repositório em
`lib/data/service_order_repository.dart` (`serviceOrders`, só
`create`/`watchAll`/`getLatestDateTime` nesta etapa), tela em
`lib/service_order/service_order_form_page.dart`, tile "Ordem de Culto" em
`main_shell.dart` (ícone composto `_ServiceOrderIcon`, igreja + nota
musical).

Sequência da liturgia, na ordem exata pedida: Data/horário → Prelúdio
(Instrumental/Ministério Adorai/Outro, com campo livre se "Outro") → Oração
(texto livre, padrão "Dirigente") → Leitura bíblica (lista, pode repetir) →
Louvor (padrão "Ministério Adorai") → Boas-vindas/Avisos-Comunicações/Oração
pelas crianças (fixos, só marcam a posição, sem campo) → Participação (texto
com sugestão) → Momento Missionário (dropdown Mundiais/Nacionais/
Estaduais/Não haverá, abre Tema/Divisa se não for "Não haverá") → Dedicação
dos dízimos e ofertas (fixo) com Texto bíblico + Hino Congregacional →
Oração de gratidão (fixo) → Louvor → Momento de Intercessão (padrão "Pr.
Ronan") → Mensagem (padrão "Pr. Ronan") → Louvor → Benção Apostólica (fixo)
→ Poslúdio (mesmas opções do Prelúdio).

Data/horário pré-preenchidos: sempre o próximo domingo às 19h a partir da
última ordem cadastrada (`ServiceOrderRepository.getLatestDateTime` +
`_nextSunday` em `service_order_form_page.dart`) — sem ordem anterior, cai
pro próximo domingo a partir de hoje (hoje conta, se já for domingo).
"Leitura bíblica" (repetível) e "Texto bíblico" da seção de dízimos
reaproveitam a mesma lógica de livro/capítulo/versículo do "Texto base" de
Devocionais (`devotional_form_page.dart`) — os widgets equivalentes
(`_BookField`/`_ChapterDropdown`/`_VerseDropdown`) foram duplicados
localmente (mesmo padrão de duplicação já usado entre telas desta base),
empacotados num `BibleReferenceController` reaproveitável pelos dois casos
(campo único vs. lista). "Participação" sugere nomes via `membersProvider`
(mesmo motivo de `_InvitedByField`/Introdução: `users` não libera `list` pra
não-admin). "Hino Congregacional" sugere combinando os dois hinários
(`hymnSongsProvider(Hymnal.cantorCristao)` +
`hymnSongsProvider(Hymnal.hinarioCristao)`), sem coleção/catálogo novo.

Permissão: `CurrentUserProfile.canManageServiceOrders` (isAdmin ||
roles.contains('dirigentes')) — reaproveita o papel Dirigentes já existente,
sem criar papel novo (decisão do usuário). `SIBValApp2/firestore.rules`
ganhou `match /serviceOrders/{orderId}` (`allow create: if isDirigentes()`)
— **só editei o código-fonte, não fiz `firebase deploy`**, mesma cautela de
sempre; sem o deploy, o cadastro pelo app vai falhar com permission-denied
até alguém pedir esse deploy explicitamente.

`ServiceOrder.ownerUid`/`ownerName` já existem no model e são gravados como
o próprio criador na criação, e a regra de update/delete já está desenhada
(`isAdmin() || (isDirigentes() && resource.data.ownerUid ==
request.auth.uid)`) — mas a UI de editar/excluir/transferir propriedade
**ainda não foi construída** (o usuário descreveu esse mecanismo como
contexto pra decidir a permissão, não como pedido desta etapa: "Inicialmente
vamos implementar a página onde a ordem de culto será inserida"). Próximo
passo natural: tela de listagem das ordens cadastradas (`serviceOrdersProvider`
já existe) + edição/exclusão restritas ao dono/admin + transferência de
propriedade pelo admin.

**Ordem de Culto — fluxo em 2 etapas + ajustes de UX (28/08/2026, pedido do
usuário):**

- **Data/hora sem ordem anterior:** `_nextSunday` (`service_order_form_page.dart`)
  perdeu o parâmetro `strictlyAfter` — agora é sempre "estritamente depois de
  `from`", nunca o próprio dia mesmo que já seja domingo. Sem ordem
  cadastrada ainda, cai pro próximo domingo a partir de hoje (nunca hoje
  mesmo, mesmo em pleno domingo) — pedido explícito do usuário, que corrigiu
  a suposição da rodada anterior (hoje contava se já fosse domingo).
- **Rótulo do campo "Outro" do Prelúdio:** trocado de "Descreva o prelúdio"
  pra "Responsável pelo prelúdio" — só o Prelúdio, o Poslúdio continua
  "Descreva o poslúdio" (não foi pedido).
- **Aviso de saída sem salvar:** `PopScope` + `_dirty` (flag explícita, não
  um cálculo "algum campo não vazio" — vários campos já nascem preenchidos
  com valor padrão tipo "Dirigente"/"Ministério Adorai", o que daria falso
  positivo assim que a tela abre) — só vira `true` quando o usuário de fato
  interage com algum campo: listener nos `TextEditingController`s
  (adicionado só depois de já preenchidos os valores padrão em `initState`,
  mesma cautela do bug documentado em `introduction_page.dart`/
  `[[feedback_flutter_migration_style]]`), `_dirty = true` explícito nos
  `onChanged` de data/horário/dropdowns, e um novo parâmetro `onChanged` em
  `_BibleReferenceFields` (repassado pra dentro de `_BibleReferenceFieldsState`,
  chamado a cada seleção/edição de livro/capítulo/versículo) pra cobrir
  "Leitura bíblica" e o "Texto bíblico" dos dízimos.
- **Fluxo virou 2 etapas.** `ServiceOrderFormPage` não grava mais no
  Firestore — o botão final virou "Avançar" (`_continue`), que valida os
  mesmos campos de antes e monta um `ServiceOrder` "rascunho" (`id`/
  `createdAt` vazios), empurrado via `Navigator.push<bool>` pra
  `ServiceOrderReorderPage` (nova, `lib/service_order/service_order_reorder_page.dart`).
  Lá o dirigente arrasta os "momentos" do culto pra reordenar como quiser
  (`ReorderableListView.builder`, `ReorderableDragStartListener` como
  drag handle explícito — cada `Card` mostra o rótulo do momento + um resumo
  do dado preenchido, ex. o texto do Louvor, pra distinguir os três momentos
  "Louvor" entre si) e só então toca "Salvar", que de fato grava no
  Firestore. Volta `Navigator.pop(true)` em caso de sucesso — a tela de
  formulário recebe esse `true` e faz um `Navigator.pop()` direto (bypassa o
  `PopScope`, que só intercepta o back gesture/botão, não um `pop()`
  explícito no código — confirmado funcionando: não reabre o diálogo de
  "sair sem salvar?" depois de já ter salvo com sucesso).
- **Novo `ServiceOrderMomentType`** (`lib/models/service_order.dart`) — um
  enum por "momento" da liturgia, na mesma ordem original pedida pelo
  usuário (a ordem de declaração do enum É a ordem default,
  `ServiceOrderMomentType.values`). Os três "Louvor" (antes do Momento
  Missionário, antes da Mensagem, depois da Mensagem) viraram três valores
  distintos (`praise1`/`praise2`/`praise3`) — mesmo rótulo "Louvor" na tela,
  mas reordenáveis independentemente porque apontam pra campos diferentes
  de `ServiceOrder`. `ServiceOrder.momentOrder` (`List<ServiceOrderMomentType>`)
  é a ordem final escolhida, gravada como `List<String>` (nomes do enum) em
  `serviceOrders/{id}.momentOrder` — `ServiceOrderRepository.create` ganhou
  o parâmetro `momentOrder`.

**Ordem de Culto — polimento em lote (28/08/2026, pedidos do usuário):**

- Título fixo (não rola mais junto com o formulário) e campos mais
  compactos em `ServiceOrderFormPage` (`_fieldDecoration` — `isDense` +
  `contentPadding` menor — e espaçamentos entre seções reduzidos de
  16/8/6 pra 10/6/4).
- Bug de data/hora vindo vazia: `_prefillDateTime` engolia qualquer
  exceção da consulta (ex.: regra do Firestore não deployada — ver
  `[[feedback_deploy_requires_explicit_ask]]`) sem tratamento, então
  `setState` nunca rodava. Agora tem try/catch com fallback pro mesmo
  comportamento de "sem ordem anterior".
- Bug do cursor saindo do campo ao selecionar um livro da Bíblia:
  `_BookFieldState._select` chamava `focusNode.unfocus()` depois de
  escolher — removido; a lista de sugestões some via uma flag
  `_suppressSuggestions` local, sem tirar o foco do campo. Só corrigido em
  `_BookField` (Ordem de Culto) — `_ParticipationField`/`_HymnField` no
  mesmo arquivo e `_BaseBookField` em `devotional_form_page.dart` têm o
  mesmo padrão de `unfocus()` e não foram tocados (não foi pedido).
- Prelúdio ganhou a opção "Não haverá" (`PreludeStyle.naoHavera`), valor
  padrão agora — Poslúdio continua só com as três opções originais
  (dropdown filtra `naoHavera` fora), não foi pedido lá.
- Reordenação padrão da liturgia (`ServiceOrderMomentType`, ordem de
  declaração do enum): Prelúdio, Oração, Leitura bíblica, Louvor,
  Boas-vindas, Avisos/Comunicações, Participação Especial (renomeado de
  "Participação"), Momento Missionário, Dedicação dos dízimos e ofertas,
  Oração pelas crianças (**movido** pra depois da Dedicação — antes ficava
  logo após Avisos/Comunicações), Louvor, Momento de Intercessão,
  Mensagem, Louvor, Benção Apostólica, Poslúdio. `gratitudePrayer`
  ("Oração de gratidão") foi **removido** do enum — o pedido do usuário
  não incluiu esse item na nova sequência; interpretação: ele foi
  substituído pelo "Oração pelas crianças" realocado pra aquela posição,
  eliminando a redundância de dois momentos de oração desconectados. Se
  isso não bater com o esperado, é reversível (o enum não tem dado
  próprio associado).
- Momentos que ficam vazios saem da ordem automaticamente
  (`ServiceOrderReorderPage._buildDefaultOrder`/`_isEmptyMoment`):
  Prelúdio se `naoHavera`, Participação Especial se o texto ficou vazio,
  Momento Missionário se `naoHavera`. A exclusão só afeta a 2ª etapa
  (Organizar momentos) — o formulário continua coletando os três campos
  normalmente.
- **Momentos especiais** (novo, sem equivalente no nativo): botão
  "Adicionar momento" em `ServiceOrderReorderPage` abre um bottom sheet
  com duas seções — momentos fixos que não estão na ordem atual (ex.:
  excluídos automaticamente, ou removidos manualmente antes) e um
  catálogo de "momentos especiais" tipo Batismo/Ceia do Senhor/
  Apresentação de bebê (`defaultServiceOrderExtraMoments`, sempre
  disponíveis) mais o que o admin cadastrar em
  `manage_service_order_moments_page.dart` (coleção
  `serviceOrderExtraMoments`, tile "Momentos Especiais" no menu Mais,
  admin-only). Modelo: `ServiceOrder.momentOrder` deixou de ser
  `List<ServiceOrderMomentType>` e virou `List<ServiceOrderItem>` — ou um
  momento fixo (`type`) ou um momento extra (`extraMomentId`/
  `extraMomentName`), serializado como `Map` (`{'kind': 'fixed'|'extra',
  ...}`); `ServiceOrderItem.fromDynamic` aceita o formato antigo (`String`
  com o nome do enum) pra não quebrar ordens já salvas antes desta
  mudança (sem backfill, mesmo padrão de sempre). Só momentos extras têm
  botão de remover na lista (ícone X) — momentos fixos não, pra não
  incentivar tirar algo da liturgia padrão sem querer.
- Toque longo antes de arrastar: `ReorderableDragStartListener` virou
  `ReorderableDelayedDragStartListener` no ícone de arraste — evita
  reordenar sem querer ao tocar.
- Botão "Voltar" ao lado de "Salvar" em `ServiceOrderReorderPage` — volta
  pro formulário (`Navigator.pop()`) sem salvar, mantendo os dados
  preenchidos lá (a tela de formulário só reseta `_submitting`, não os
  campos).
- **Lista antes do cadastro:** tocar em "Ordem de Culto" no menu Mais
  agora abre `ServiceOrderListPage` (nova) — lista as ordens já
  cadastradas (`serviceOrdersProvider`) com um botão flutuante "Nova
  Ordem" que leva pro cadastro; tocar numa ordem existente abre
  `ServiceOrderDetailPage` (nova, somente leitura, mostra `momentOrder` na
  sequência salva). Edição/exclusão continuam não implementadas.
- `SIBValApp2/firestore.rules` ganhou `match /serviceOrderExtraMoments`
  (`read` pra `isDirigentes()`, `write` só `isAdmin()`) — **só editei o
  código-fonte, não fiz `firebase deploy`**, mesma cautela de sempre.

**Ordem de Culto — 2ª rodada de polimento (28/08/2026, pedidos do usuário):**

- **Momentos Especiais deixou de ser tile do menu Mais.** `ManageServiceOrderMomentsPage`
  agora abre pelo ícone de engrenagem na app bar de `ServiceOrderListPage` —
  visível pra quem já acessa Ordem de Culto (dirigentes/admin), mas só admin
  vê os controles de adicionar/renomear/excluir/marcar padrão (leitura
  liberada a `isDirigentes()` em `firestore.rules`, escrita só `isAdmin()`,
  sem mudança de regra nesta rodada).
- **Catálogo virou dados de verdade com flag "padrão"
  (`ServiceOrderExtraMomentOption.isDefault`).** Os três exemplos
  (Batismo/Ceia do Senhor/Apresentação de bebê) eram só uma constante no
  cliente (`defaultServiceOrderExtraMoments`) na rodada anterior — pra o
  admin poder desmarcá-los/editá-los/excluí-los como qualquer outro item,
  precisavam virar documentos reais em `serviceOrderExtraMoments`. Sem
  Cloud Function nem script de migração: `ManageServiceOrderMomentsPage`
  detecta catálogo vazio (`_seedIfEmpty`) e cria os três via
  `ServiceOrderExtraMomentRepository.seedDefaults()` (`isDefault: true`) na
  primeira vez que um **admin** abre a tela — como a escrita exige
  `isAdmin()`, só funciona depois que algum admin visitar a engrenagem pelo
  menos uma vez; até lá, o picker de "Adicionar momento" mostra "Nenhum
  momento especial cadastrado ainda" pra quem só é Dirigentes. `isDefault`
  só controla destaque (selo de estrela, ordenação primeiro) no catálogo e
  no picker — não afeta mais nada automaticamente (ex.: não entra sozinho
  numa ordem nova sem o dirigente escolher).
- **"Adicionar momento" mudou de tela** — pedido explícito do usuário foi
  que ficasse na 1ª etapa (`ServiceOrderFormPage`), não mais em "Organizar
  momentos". Nova seção "Momentos Especiais" no fim do formulário
  (`_pickExtraMoments`, bottom sheet de múltipla escolha,
  `_ExtraMomentPickerSheet`) grava a escolha em `_extraMoments`, carregada
  pra `ServiceOrderReorderPage` via `draft.momentOrder` (reaproveitando o
  campo — um "rascunho" nunca usava esse campo pra outra coisa antes).
  `ServiceOrderReorderPage` perdeu o botão/bottom sheet de adicionar; só
  ficou com o "X" de remover um momento extra já incluído.
- **Editar/excluir uma ordem já cadastrada** (novo — toque e segure num
  card de `ServiceOrderListPage`, só se dono da ordem ou admin, mesma regra
  de `firestore.rules` que já existia sem uso até agora):
  `ServiceOrderFormPage` ganhou o parâmetro `editing` (prefill de todos os
  campos, inclusive os momentos extras já escolhidos);
  `ServiceOrderRepository.create`/`update` foram unificados pra receber um
  `ServiceOrder` completo (`toFieldsMap()`/`ServiceOrder.copyWith`, em vez
  da lista enorme de parâmetros nomeados de antes).
  `ServiceOrderReorderPage._buildInitialOrder` reconcilia em vez de
  recomeçar do zero quando `editingOrder != null`: parte do arranjo já
  salvo, tira o que ficou vazio/desmarcado nesta edição, acrescenta no fim
  o que passou a valer (momento fixo preenchido de novo, momento extra
  recém-escolhido) — preserva a reordenação manual que o dirigente já tinha
  feito, só ajusta o que mudou. Simples exclusão sem edição
  (`ServiceOrderRepository.delete`) direto na lista, com confirmação.
- **Toque simples numa ordem abre `ServiceOrderPrecheckPage`** (nova, no
  lugar da antiga tela de detalhe somente leitura) — mostra a ordem
  completa (mesmo `ServiceOrderItem.summary`) com um contador regressivo
  (`Timer.periodic` de 1s) até `order.dateTime`. Botão "Iniciar Culto" só
  fica clicável quando `DateTime.now()` já alcançou o horário exato
  (`_canStart`) — antes disso mostra o tempo restante; depois, "Pode
  iniciar". "Voltar" sempre disponível.
- **"Iniciar Culto" leva pro "modo apresentação"** (`ServiceOrderLivePage`,
  novo, `pushReplacement` — não faz sentido voltar pra tela de contagem
  regressiva depois que o culto já começou). Layout deliberadamente
  diferente do resto do app: tela cheia, fundo navy, sem `SibValAppBar`,
  cada momento num card com ícone (`_MomentCard._icon`, mapeado por
  `ServiceOrderMomentType`), toque marca como concluído (risco no texto +
  avança o destaque dourado pro próximo) — só estado local em memória, não
  grava no Firestore. **O usuário mencionou ter salvo uma foto de um
  modelo antigo pra inspirar esse layout, mas nenhum anexo de imagem
  chegou nesta conversa** — este design é uma criação própria (moderno,
  sem tentar reproduzir o modelo antigo que eu não vi); se o usuário
  compartilhar a foto depois, vale revisar esta tela especificamente.
- **Rótulos de campo removidos do cadastro** — só Data/Horário e os campos
  de referência bíblica (Leitura bíblica/Texto bíblico, que reaproveitam
  `_BibleReferenceFields`/`_BookField`/`_ChapterDropdown`/`_VerseDropdown`)
  mantiveram `labelText` ancorado na borda. Os demais (Oração, Louvor x3,
  Participação Especial, Tema/Divisa do Momento Missionário, Hino
  Congregacional, campos "Outro" de Prelúdio/Poslúdio) viraram caixas sem
  rótulo — `hintText` só onde o cabeçalho da seção sozinho não distinguia
  o campo (ex. Tema vs. Divisa, os dois sob o mesmo cabeçalho "Momento
  Missionário").
- **Todo momento no mesmo padrão visual** — `_momentLabel` (novo helper em
  `service_order_form_page.dart`) renderiza "- Nome do momento" em itálico,
  cor `SibValColors.goldAccent` (dourado padrão do app), usado tanto pros
  cabeçalhos de seção com campo (Prelúdio, Oração, Louvor...) quanto pros
  itens fixos sem campo (Boas-vindas, Avisos/Comunicações...) — antes eram
  dois estilos diferentes (`_sectionLabel` bold cinza vs. `_fixedItem` com
  ícone "−"). `_sectionLabel` (estilo antigo) ficou restrito a rótulos que
  não são "momentos" em si: "Data e horário" e os sub-campos "Texto
  bíblico"/"Hino Congregacional" dentro de "Dedicação dos dízimos e
  ofertas".

**Ordem de Culto — 3ª rodada, correção de rumo sobre "padrão"
(28/08/2026, mesma sessão, pedido do usuário):** a rodada anterior tinha
dado um `isDefault` pros "momentos especiais" (Batismo/Ceia do Senhor/
Apresentação de bebê, auto-semeados) — o usuário corrigiu: esses **não**
são momentos do culto, são avulsos, sempre cadastrados um a um pelo admin,
sem noção de "padrão". Quem é "padrão" de verdade são os 16 momentos fixos
da liturgia (`ServiceOrderMomentType`) — e o pedido foi poder reordenar
esse conjunto dentro das configurações, não só via código.

- `ServiceOrderExtraMomentOption.isDefault` e o auto-seed
  (`seedDefaults`/`_seedIfEmpty`) foram **revertidos** — catálogo de
  momentos especiais voltou a ser CRUD simples (nome, sem mais nada),
  começa vazio, admin cadastra Batismo/Ceia/etc. manualmente.
- Nova `ServiceOrderMomentOrderRepository`
  (`lib/data/service_order_moment_order_repository.dart`) guarda a
  sequência dos 16 momentos fixos em `settings/serviceOrderMomentOrder`
  (`{order: List<String>}`, nomes do enum) — **sem regra nova no
  `firestore.rules`**, o `match /settings/{docId}` já cobre qualquer
  documento da coleção (`read` pra autenticado, `write` só admin).
  Fallback pra `ServiceOrderMomentType.values` (a ordem hardcoded de
  sempre) quando o documento não existe ou tem nomes desatualizados —
  qualquer momento do enum ausente do documento salvo é acrescentado no
  fim, então um momento novo do app nunca some por causa de configuração
  velha.
- `ServiceOrderFormPage` busca essa ordem uma vez em `initState`
  (`_loadDefaultMomentOrder`, mesmo padrão try/catch-com-fallback de
  `_prefillDateTime`) e repassa pra `ServiceOrderReorderPage` via
  `defaultMomentOrder` — só usado no modo cadastro; edição continua
  partindo do arranjo já salvo (`editingOrder.momentOrder`), sem tocar
  nesse padrão.
- `ManageServiceOrderMomentsPage` virou duas seções: "Momentos do Culto"
  (os 16 fixos, só reordenáveis — não têm botão de adicionar/excluir,
  são intrínsecos ao formulário, cada um com campo próprio) e "Momentos
  Especiais" (o catálogo CRUD de sempre, sem "padrão"). Botão de acesso
  saiu da app bar (`SibValAppBar.actions`) e virou "Configurar" ao lado do
  título "Ordem de Culto", dentro do corpo de `ServiceOrderListPage` —
  mesmo padrão visual de "Contribua" + "Configurar" em
  `contribute_page.dart` (`Row` com o título em `SibValColors.goldAccent`
  + `TextButton.icon`).
- `ServiceOrderPrecheckPage` (tela de contagem regressiva) perdeu a lista
  de momentos — só mostra data/hora, o card do contador e os dois botões
  centralizados (Iniciar Culto em cima, Voltar embaixo), pedido explícito
  do usuário. A ordem completa só aparece depois, no modo apresentação
  (`ServiceOrderLivePage`, ao tocar "Iniciar Culto").
- Frase do contador mudou pra "Tempo para o início do culto"; formato
  virou por extenso ("N dias, N horas, N minutos e N segundos"), omitindo
  as unidades maiores que já zeraram (`_CountdownCard._format`) — não
  mostra mais "0 dias, 0 horas" quando falta só alguns minutos.
- Menu Mais: Introdução e Ordem de Culto subiram pro topo do "Tier 3 —
  admin/secretaria/eventos/dirigentes/introdução" (antes ficavam no fim da
  lista inteira, depois de E-mails de eventos) — mesma faixa de
  permissão/tier, só reordenados dentro dela, a pedido do usuário.

**Ordem de Culto — 4ª rodada: modo apresentação completo + Ministério de
Louvor + Hinários (28/08/2026, mesma sessão, pedidos do usuário):**

- **Bug corrigido:** `_pickExtraMoments` (`ServiceOrderFormPage`) lia
  `ref.read(serviceOrderExtraMomentsProvider).asData?.value` — se nada mais
  tivesse observado o provider ainda, o stream não tinha tido chance de
  emitir o primeiro snapshot e vinha sempre vazio, mesmo com momentos
  especiais cadastrados. Trocado por `ref.read(provider.future)`.
- **`isDefault` reintroduzido em `ServiceOrderExtraMomentOption`** (tinha
  sido removido na rodada anterior) — desta vez com efeito de verdade: um
  momento especial marcado como padrão entra em
  `settings/serviceOrderMomentOrder` como token `"extra:<id>"`, misturado
  com os 16 momentos fixos nesse mesmo documento (`ServiceOrderMomentOrderRepository`,
  `resolveServiceOrderMomentTemplate`). `ManageServiceOrderMomentsPage`
  agora tem uma seção única "Momentos do Culto" mostrando essa sequência
  combinada (arrastar reordena; só extras têm botão de remover, que
  desmarca `isDefault` em vez de excluir — exclusão de verdade é na seção
  "Momentos Especiais"). Limite reconhecido: **não é possível
  renomear/excluir os 16 momentos fixos** — cada um tem campo de dado
  próprio no formulário (`ServiceOrder.preludeStyle`, `.prayerText`, etc.),
  generalizar isso exigiria reescrever o cadastro inteiro num form builder
  dinâmico. Só a ordem deles é configurável.
- **Progresso do culto persiste no Firestore** — `ServiceOrder` ganhou
  `completedMomentKeys`/`isFinalized`/`finalizedAt` (fora de
  `toFieldsMap()`/`copyWith`, gravados só por
  `ServiceOrderRepository.updateProgress`/`finalize`, pra uma edição normal
  nunca resetar isso). Chaves são `"<tipo>:<sub>"` (baseadas no
  tipo/id do momento, não no índice — sobrevive a reordenação numa edição
  posterior). `ServiceOrderPrecheckPage` mostra "Continuar Culto" em vez de
  "Iniciar Culto" quando já há progresso, e um card "Culto finalizado" no
  lugar do contador quando `isFinalized`. `ServiceOrderListPage` mostra selo
  "Finalizada".
- **Leitura bíblica/Texto bíblico/Hino Congregacional abrem a leitura de
  verdade antes de marcar concluído** (`ServiceOrderLivePage`) —
  reaproveita `BibleReaderPage`/`HymnDetailPage` (mesmas telas da Bíblia/
  Hinário no menu principal); marca automaticamente ao voltar de lá.
  `_resolveHymn` casa o texto salvo em `congregationalHymn` (ex. "CC 45 —
  Nome") contra os hinários de verdade via prefixo + número. "Dedicação dos
  dízimos e ofertas" sempre renderiza como grupo com as subcategorias
  Texto bíblico/Hino Congregacional (`_MomentGroupCard`), cada uma com sua
  própria marcação — mesmo mecanismo cobre "Leitura bíblica" com mais de
  uma referência.
- **Ministério de Louvor** (novo, sem equivalente no nativo) —
  `lib/praise/`: `PraiseMinistryPage` com duas abas. "Repertório Mensal"
  (`praiseSongs`) é o catálogo mestre de músicas (nome + cantor/banda) —
  "mensal" é só o nome da aba, não particiona por mês (o pedido do usuário
  foi só "cadastrar todas as músicas"). "Repertório Semanal"
  (`weeklyRepertoires/{weekKey}`, `weekKey = yyyy-MM-dd` do domingo daquela
  semana — `PraiseRepertoireRepository.weekKeyFor`) escala músicas com tom
  e "momento" (Louvor 1/2/3 sugeridos + campo livre pra "mais ou menos
  casos", pedido do usuário) e uma lista de links de playlist.
  `ServiceOrderLivePage` busca o repertório da semana do culto
  (`getForDate`) e mostra as músicas escaladas dentro do card de cada
  momento "Louvor" (`praiseSlotLabelFor` casa `praise1/2/3` com "Louvor
  1/2/3"). **Decisão de permissão sem confirmação explícita do usuário:**
  gate do tile e das regras (`praiseSongs`/`weeklyRepertoires` em
  `firestore.rules`) reaproveita `canManageServiceOrders`
  (admin/dirigentes) — não existe papel dedicado de "Ministério de Louvor"
  ainda; se o usuário quiser um papel separado, precisa pedir
  explicitamente (envolveria `UserRole`/`firestore.rules`/
  `manage_users_page.dart`).
- **Hinários**: Cantor Cristão e HCC eram dois tiles separados no menu
  Mais — viraram um só ("Hinários", `lib/hymnal/hymnals_page.dart`) que
  abre uma tela de escolha entre os dois.
- `firestore.rules`: `praiseSongs`/`weeklyRepertoires` — **só editei o
  código-fonte, não fiz `firebase deploy`**, mesma cautela de sempre;
  `settings/serviceOrderMomentOrder` não precisou de regra nova (`match
  /settings/{docId}` já cobre qualquer documento da coleção).

**Ordem de Culto — 5ª rodada (28/08/2026, mesma sessão):**

- **Bug dos momentos especiais no picker, 3ª tentativa:** as duas correções
  anteriores (`asData?.value` → `.future` do `StreamProvider`) não
  resolveram — o usuário reportou de novo. Trocado por
  `ServiceOrderExtraMomentRepository.getAll()`, uma leitura `.get()` direta
  no Firestore sem nenhum provider Riverpod no meio, e o erro (se houver)
  agora aparece num SnackBar em vez de cair num catch silencioso que
  mascarava o problema real. Se o bug persistir depois disso, o próximo
  passo é olhar o SnackBar de erro pra saber se é permissão/rede/outra
  coisa — não ficou 100% claro qual era a causa raiz das duas tentativas
  anteriores.
- **Momento "Boas-vindas" abre os visitantes do dia** no modo apresentação
  (`ServiceOrderLivePage`) — novo `VisitorRepository.getSummariesForDate`
  (query por intervalo UTC do dia, fuso America/Sao_Paulo fixo UTC-3,
  mesmo critério de `VisitorSummary.isFromToday` mas pra uma data
  específica em vez de "hoje"). Lê `visitorSummaries` (não `visitors`) de
  propósito — quem toca a Ordem de Culto normalmente só tem o papel
  Dirigentes, que só tem `read` liberado no resumo, não nos dados
  completos (telefone), exclusivos de Introdução/Pastor. Reaproveita
  `VisitorSummaryTile` (`introduction/visitor_tiles.dart`) num bottom
  sheet; mostra "Não há visitantes." se a lista vier vazia. Mesmo padrão
  de interação dos outros momentos com sub-ação (toque abre, marca
  concluído só depois de fechar).

**Ordem de Culto — 6ª rodada (28/08/2026, mesma sessão):**

- **Tom do repertório escondido do dirigente por enquanto** —
  `ServiceOrderLivePage._repertoireSummaryFor` parou de incluir "(Tom: X)"
  no resumo do momento "Louvor"; mostra só nome + cantor/banda. Pedido
  explícito do usuário: o tom deve aparecer só pro perfil do Ministério de
  Louvor — papel/permissão que ainda não existe, fica pra quando for
  pedido.
- **"Boas-vindas" mostra "Não há visitantes." direto**, sem precisar tocar
  — `ServiceOrderLivePage` busca `_visitors` já no `initState` (junto com o
  repertório); enquanto `null` (carregando) ou com visitantes, mantém o
  toque abrindo a lista completa (`_subActionsFor`/`_showVisitorsSheet`).
- **"Momentos Especiais" renomeado pra "Momentos Adicionais"** em toda a UI
  (config, picker do cadastro) — nomes de classe/arquivo (`ServiceOrderExtraMomentOption`,
  `service_order_extra_moment_repository.dart` etc.) não foram renomeados,
  só o texto visível.
- **Momentos adicionais ganharam campo próprio** (`ExtraMomentFieldKind`:
  nenhum/um nome/vários nomes/texto bíblico) — o admin define ao cadastrar/
  editar o momento (`ManageServiceOrderMomentsPage._showEditDialog`,
  unificou os diálogos de adicionar/renomear em um só); o dirigente
  preenche ao escolher o momento no cadastro
  (`_ExtraMomentPickerSheet._collectFieldData`, reescrita — trocou de
  multi-seleção por checkbox pra toque-abre-diálogo-de-preenchimento,
  reaproveitando `_BibleReferenceFields`/`BibleReferenceController` já
  existentes no arquivo pro caso "texto bíblico"). Satisfaz o pedido "mais
  um momento de Louvor, ou Leitura bíblica" — um momento adicional com
  fieldKind `bibleReference` É uma leitura bíblica extra. `ServiceOrderItem`
  ganhou `extraNames`/`extraBibleReference` (persistidos em `momentOrder`,
  com fallback nulo pra ordens salvas antes desta mudança). Um momento
  adicional com texto bíblico preenchido (ex.: "Ceia do Senhor", pedido
  explícito do usuário — "parecido com os dízimos e ofertas") ganha o
  mesmo tratamento de leitura de verdade em `ServiceOrderLivePage`
  (`BibleReaderPage`, marca concluído só ao voltar) que "Leitura bíblica"/
  "Texto bíblico" dos dízimos já tinham — mecanismo genérico, não
  específico de "Ceia do Senhor".
- **Novo tile "Configurações e Gerenciamento"** no menu Mais — agrupa Tema,
  Rol de Membros, Ministérios e Cargos, Gerenciar Usuários, Repositório de
  Flyers e E-mails de eventos (`lib/settings/settings_management_page.dart`),
  que antes eram 6 tiles soltos na grade principal. Cada um mantém seu
  próprio gate de permissão dentro da nova tela; o tile de fora é sempre
  visível (Tema não tem gate) e carrega o selo de pendentes de "Gerenciar
  Usuários" borbulhado, pra um admin notar sem precisar entrar.
  `MoreTile`/`SettingsMailIcon` (`main_shell.dart`) viraram públicos só pra
  isso — import circular entre `main_shell.dart` e
  `settings_management_page.dart` (Dart aceita, confirmado com
  `flutter analyze` limpo).

**Ordem de Culto — 7ª rodada (28/08/2026, mesma sessão):**

- **Dedicação dos dízimos marca o próprio momento quando texto+hino ficam
  concluídos** — `_MomentGroupCard` ganhou `isDone` (derivado, `leaves.every
  (_done.contains)`, não uma chave própria) e passou a refletir isso
  visualmente (badge de check, texto riscado) igual a um `_MomentCard`
  concluído — antes só as sub-linhas mudavam, o cabeçalho ficava sempre
  "ativo".
- **Texto bíblico de momento adicional aceita mais de um** —
  `ServiceOrderItem.extraBibleReference` (um só) virou `.extraBibleReferences`
  (lista) — compatível com o formato antigo salvo antes desta mudança (`fromDynamic`
  aceita a chave singular como fallback). O picker do cadastro trocou o
  diálogo de referência única por `_MultiBibleReferenceDialog` (mesmo botão
  "+ Adicionar texto"/lista dinâmica de "Leitura bíblica"); no modo
  apresentação, virou uma subcategoria por texto (mesmo mecanismo de
  "Leitura bíblica" com várias referências).
- **"Vários nomes" ganhou lista dinâmica** em vez de campo único separado
  por vírgula — pedido do usuário. Novo `_MultiNameDialog` (mesmo padrão
  "+ Adicionar" de `_MultiBibleReferenceDialog`) substitui o campo de texto
  único que existia em `_collectNames` (agora `_collectMultipleNames`);
  `ExtraMomentFieldKind.name` (singular, "um nome") continua com campo
  único simples (`_collectSingleName`), sem lista — só o plural mudou.
- **Bug "Right overflowed"**: causa mais provável era o
  `DropdownButtonFormField` sem `isExpanded: true` mostrando um rótulo
  comprido (`ExtraMomentFieldKind.label`, ex. "Vários nomes (ex.:
  batizandos)") dentro da largura estreita padrão de um `AlertDialog` —
  clássico gotcha do Flutter. Corrigido com `isExpanded: true` +
  `SizedBox(width: double.maxFinite)` no diálogo de editar momento
  (`ManageServiceOrderMomentsPage._showEditDialog`) e nos dropdowns de
  Capítulo/Versículo (`_ChapterDropdown`/`_VerseDropdown`, mais
  `overflow: ellipsis` na lista de sugestão de livro) — defensivo, já que
  não foi possível confirmar com 100% de certeza qual Row exata disparava
  o "ao selecionar o livro" sem reprodução ao vivo.
- **Texto bíblico abre só o trecho selecionado** — nova
  `ServiceOrderBibleTextPage` (`service_order_bible_text_page.dart`), sem
  navegação entre capítulos/livros nem controle de fonte, só os versículos
  entre `verseStart`/`verseEnd`. Substituiu `BibleReaderPage` (a tela cheia
  da aba Bíblia) em todos os pontos de `ServiceOrderLivePage` que abrem
  leitura bíblica (Leitura bíblica, Texto bíblico dos dízimos, texto
  bíblico de momento adicional).
- **Ícones trocados por emoji** (`_emojiFor`/`_momentIcon`,
  `service_order_live_page.dart`) — Material Icons não tem "mãos juntas em
  oração"/"abraço"/"mãos recebendo bênção" de verdade: Oração → 🙏,
  Boas-vindas → 🫂, Benção Apostólica → 🤲. Os demais momentos continuam
  com `Icon`/`IconData` normal.

**Ordem de Culto — 8ª rodada: papel Louvor + Cifras (28/08/2026, mesma
sessão, pedidos do usuário):**

- **Ajustes pequenos**: foco move sozinho pro campo novo ao tocar "Adicionar
  nome"/"Adicionar texto" nos diálogos de momento adicional
  (`WidgetsBinding.instance.addPostFrameCallback` + `FocusNode`/
  `BibleReferenceController.bookFocusNode`); `ServiceOrderBibleTextPage`
  ganhou os mesmos botões de zoom da Bíblia normal (`_fontSizeKey`
  compartilhado); `dropdownColor: colorScheme.surfaceContainerHighest`
  adicionado nos dropdowns dentro de diálogos (causa mais provável do
  "Right overflowed"/cor igual ao popup — sem isso caem em `canvasColor`,
  igual ao fundo padrão de `AlertDialog`); `ServiceOrderReorderPage._save`
  valida que o Prelúdio (quando presente) é o primeiro momento e o Poslúdio
  é sempre o último, recusando salvar caso contrário.
- **Tom das músicas virou dropdown + check "Menor"** —
  `PraiseAssignment.tone` (texto livre) virou `.toneNote`/`.toneIsMinor`
  (`toneDisplay` monta "F#m" pra exibição), com fallback de leitura do
  formato antigo. `praiseToneNotes` tem as 12 notas cromáticas — o usuário
  listou só 10 (faltavam Bb/B), completei pra cobrir todas.
- **Papel Louvor + Cifrista** (`UserRole.louvor`/`.cifrista`,
  `CurrentUserProfile.canViewPraiseOrder`/`.canEditCifras`) — chips em
  `ManageUsersPage`, mesmo padrão dos demais papéis. `firestore.rules`:
  `isLouvor()`/`isCifrista()` novos; `serviceOrders`/`praiseSongs`/
  `weeklyRepertoires` ganharam `isLouvor()` no `read` (escrita continua só
  Dirigentes); `cifras` é `read` pra Dirigentes/Louvor, `write` só
  Cifrista/admin — **só editei o código-fonte, não fiz `firebase deploy`**,
  mesma cautela de sempre.
- **`ServiceOrderPraiseViewPage`** (nova) — visão da Ordem de Culto pro
  Louvor: mesmo layout escuro do modo apresentação do dirigente, mas
  **somente leitura** — o progresso vem de `serviceOrderStreamProvider`
  (`ServiceOrderRepository.watchOne`, `.snapshots()` em tempo real), sem
  nenhuma escrita própria; quando o dirigente marca um momento em
  `ServiceOrderLivePage`, aparece aqui sozinho. Textos bíblicos/hinos
  continuam tocáveis (mesmos destinos do dirigente), só que sem marcar nada
  ao voltar — a lógica de "quais sub-referências existem" foi duplicada
  (não compartilhada com `ServiceOrderLivePage`, que é focada em
  escrever/marcar) num nível reduzido: sem a granularidade completa de
  sub-chave pro momento "Boas-vindas" (que depende de saber se há
  visitantes, estado que só o dirigente busca) — aqui um item é
  considerado concluído se a chave normal OU a de sub-ação "visitors"
  estiver marcada, uma aproximação razoável só pra fins de exibição.
  Momentos "Louvor" mostram tom (que o dirigente não vê) e tocar na música
  abre `CifraViewPage`. Acesso liberado 1h antes do horário
  (`order.dateTime - 1h`) — antes disso mostra só "ainda não disponível";
  um cronômetro fica visível no topo até o horário exato.
  `ServiceOrderListPage` roteia o toque numa ordem: quem gerencia
  (Dirigentes/admin) vai pro fluxo normal (`ServiceOrderPrecheckPage`);
  quem só é Louvor vai direto pra `ServiceOrderPraiseViewPage`. FAB "Nova
  Ordem" e botão "Configurar" (momentos do culto) ficaram restritos a quem
  gerencia.
- **Cifras** (`lib/models/cifra.dart`, `lib/data/cifra_repository.dart`,
  `lib/util/chord_transpose.dart`, `lib/praise/cifra_*.dart`) — 1 cifra por
  música do catálogo mestre (doc id = songId), texto livre com acordes
  entre colchetes (`"[G]Digno é o [D]Senhor"`). `CifraEditorPage` (só
  Cifrista/admin) define tom original + capotraste (metadados — capo é só
  informativo, não recalcula acordes) e o texto. `CifraViewPage` (qualquer
  um com acesso ao repertório) tem botões +/- que transpõem os acordes
  exibidos por semitom (`chord_transpose.dart`, client-side, não altera o
  documento salvo) — reconhece nota fundamental + baixo depois de "/" (ex.
  "D/F#"), mantém o sufixo (m, 7, sus4...) intacto. `CifraListPage` (novo
  tile "Cifras" no menu Mais, gate Dirigentes/Louvor/Cifrista/admin) lista
  todas as músicas com selo de "já tem cifra".

**Ordem de Culto — 9ª rodada: correções de UX + Cifras dentro de Ministério
de Louvor + deploy das regras do Louvor/Cifrista (28/08/2026, mesma sessão,
pedidos do usuário):**

- **Zoom do texto bíblico movido pro corpo da página**
  (`service_order_bible_text_page.dart`) — estava em `SibValAppBar.actions`,
  espremido ao lado do ícone de login da barra fixa compartilhada em todo o
  app; virou uma faixa própria dentro do corpo (título + botões +/-, mesmo
  padrão do `_ReaderHeader` de `bible_reader_page.dart`).
- **Dropdown do livro da Bíblia ainda errado**: a lista de sugestões de
  `_BookField` (`service_order_form_page.dart`) continuava em
  `Theme.of(context).canvasColor` — só os dropdowns de Capítulo/Versículo
  tinham sido corrigidos na rodada anterior, não a lista de livro. Trocado
  pra `colorScheme.surfaceContainerHighest`, mesma cor usada nos outros.
  `devotional_form_page.dart` mantém `canvasColor` de propósito (ali é
  numa página normal, não dentro de um diálogo — combina com o dropdown
  padrão do Flutter nesse contexto, decisão da sessão de 26/08/2026).
- **Tom "Menor" não refletia o "m" na lista fechada**: `DropdownButtonFormField`
  só tem um `value`/`items` (as notas puras, sem variante "m") — o checkbox
  "Menor" alterava o estado mas o texto exibido no botão fechado não
  mudava. Corrigido com `selectedItemBuilder` (recurso do próprio Flutter
  pra customizar só o que aparece fechado, sem duplicar cada nota como dois
  itens) em `weekly_repertoire_form_page.dart`
  (`_AssignmentRow`) e `cifra_editor_page.dart`.
- **Ordem do culto não carregava pro Louvor + Cifras não salvava/abria**:
  diagnosticado como as regras do Firestore desta rodada anterior
  (`isLouvor()`/`isCifrista()`, leitura de `serviceOrders`/`praiseSongs`/
  `weeklyRepertoires` pro Louvor, e o match block inteiro de `cifras`)
  nunca terem sido publicadas — só o código-fonte tinha sido editado, exatamente
  como o aviso já deixado na 8ª rodada previa. Perguntado ao usuário
  (`AskUserQuestion`), que confirmou; `firebase deploy --only
  firestore:rules --project sibval-app-project` publicado com sucesso.
- **Boas-vindas mostra "há visitantes" também, não só "não há"**: antes
  `_welcomeSummary()` (`service_order_live_page.dart`) só escrevia algo
  automático quando a lista vinha vazia — com visitantes, o card ficava mudo
  até o toque. Agora mostra "N visitante(s) hoje." também quando há, mantendo
  o toque disponível pra ver a lista completa. Confirmado que isso já era
  exclusivo do dirigente — `ServiceOrderPraiseViewPage` (visão do Louvor)
  nunca mostrou nada pro momento Boas-vindas (`ServiceOrderItem.summary()`
  retorna `null` pra esse tipo, e `_detailRowsFor` de lá não tem um caso pra
  ele) — nenhuma mudança necessária ali, só o comentário do código foi
  atualizado pra deixar isso explícito.
- **Cifras saiu do menu Mais e entrou dentro de Ministério de Louvor**: o
  tile próprio "Cifras" foi removido de `main_shell.dart`; em troca,
  `PraiseMinistryPage` ganhou um ícone de menu (☰, `PopupMenuButton`) ao
  lado do título "Ministério de Louvor" — por enquanto só com a opção
  "Cifras" (`CifraListPage`), pensado pra crescer com mais opções depois,
  sem precisar de mais tiles soltos no menu Mais. Como antes só quem
  gerencia Ordem de Culto (`canManageServiceOrders`) entrava nesta tela, o
  gate em `main_shell.dart` foi alargado pra também deixar entrar
  Louvor/Cifrista (`canViewPraiseOrder`/`canEditCifras`) — mas as duas abas
  de gerenciar repertório (Mensal/Semanal, com botões de criar/editar/
  excluir música e escala) continuam exclusivas de quem gerencia; quem
  entra só pelo papel Louvor/Cifrista vê a página sem abas, só com o menu
  (`PraiseMinistryPage._buildBody`, decisão da sessão — não foi pedido
  explicitamente permitir Louvor/Cifrista editar repertório, só acessar
  Cifras).

**Ordem de Culto — 10ª rodada: Cifrista deixa de ser papel, Cifras ganha
busca/cadastro avulso/config de editores, zoom+cor dourada nas exibições
(28/08/2026, mesma sessão, pedidos do usuário):**

- **Ícone do menu ☰ "Cifras"**: ganhou `Icons.lyrics_outlined` (mesmo ícone
  do tile solto que existia antes da 9ª rodada) — só texto sem ícone antes.
- **Papel Cifrista removido** (existiu por uma rodada só): `UserRole.cifrista`
  saiu de `lib/models/app_user.dart`, o chip "Cifrista" saiu de
  `manage_users_page.dart`, `CurrentUserProfile.canEditCifras` (baseado em
  `roles`) foi removido. Em troca — pedido explícito do usuário ("esta
  atribuição será dada individualmente direto ao usuário que o admin
  selecionar") — novo `CifraEditorsRepository`
  (`lib/data/cifra_repository.dart`) guarda uma lista de uids num único
  documento (`settings/cifraEditors.uids`), e `canEditCifrasProvider`
  (`Provider.autoDispose<bool>`) combina `isAdmin` + essa lista, substituindo
  o getter antigo em todo lugar que o usava. `SIBValApp2/firestore.rules`:
  `isCifrista()` virou `isCifraEditor()` — `get()` no documento
  `settings/cifraEditors` (com `exists()` antes, senão `get()` de doc
  inexistente derruba a regra), usado tanto no `read` quanto no `write` de
  `cifras` (antes só Dirigentes/Louvor liam; agora quem tá na lista também
  lê, mesmo sem ser Dirigentes/Louvor — precisa pra poder editar).
  **Deploy feito** — aval explícito do usuário (`AskUserQuestion`),
  `firebase deploy --only firestore:rules --project sibval-app-project`.
- **`CifraEditorsManagementPage`** (nova, `lib/praise/`) — botão de
  configuração (⚙, só admin, `profile.isAdmin`) dentro de `CifraListPage`.
  Lista usuários aprovados (`allUsersProvider`, filtrado por
  `UserStatus.approved`) com busca por nome/e-mail, `CheckboxListTile` por
  usuário (admin sempre marcado e travado) — toque salva na hora
  (`CifraEditorsRepository.setUids`, mesmo padrão de toque-e-salva dos
  `_RoleChip` de `manage_users_page.dart`).
- **Cifra avulsa, fora do repertório mestre** (pedido do usuário: "deve ser
  possível incluir cifras além do que está no repertório") — `Cifra`
  (`lib/models/cifra.dart`) ganhou `songArtist` (antes só vinha do
  `PraiseSong` linkado, uma cifra avulsa não tem de onde puxar isso).
  `CifraRepository.newStandaloneId()` gera um id novo
  (`_collection.doc().id`, sem gravar ainda) pra uma cifra sem `PraiseSong`
  correspondente. `CifraEditorPage` (`song`/`existing` agora os dois
  opcionais) ganhou um terceiro modo: os dois nulos = cifra nova avulsa,
  com campos "Nome da música"/"Cantor/Banda" editáveis (só aparecem quando
  `song == null` — linkada a um `PraiseSong`, nome/cantor continuam
  travados, editados só em Ministério de Louvor). `CifraListPage` ganhou
  FAB "+" (só `canEditCifrasProvider`) pra esse fluxo.
- **`CifraListPage` reescrita** — combina `praiseSongs` (repertório mestre,
  com ou sem cifra ainda) com `cifras` avulsas (`songId` sem música
  correspondente) numa lista só (`_buildEntries`/`_CifraEntry`), ordenada
  por nome. Barra de busca (nome/cantor, `_normalizeText` acento/case-
  insensível, mesmo helper duplicado de outras telas) filtra a lista.
  Editar uma entrada sem cifra ainda repassa `existing: entry.cifra`
  mesmo quando "sem cifra" (conteúdo vazio) — evitava um bug: sem isso, uma
  cifra avulsa com conteúdo vazio perderia o id ao reabrir pra editar
  (`CifraEditorPage` geraria outro `newStandaloneId()`, deixando o
  documento vazio original órfão no Firestore).
- **`CifraViewPage` ganhou zoom de fonte** (pedido do usuário: "exibir
  dentro da página os botões de zoom") — mesmo padrão de
  `service_order_bible_text_page.dart` (faixa própria no corpo, não na
  `SibValAppBar`), com preferência salva separada (`cifra_font_size`, não
  compartilhada com Bíblia/Hinário). A tela já era tela cheia (rota própria,
  `Navigator.push`) desde a 8ª rodada — "exibir em tela cheia" já estava
  satisfeito, só faltava o zoom.
- **Itens clicáveis em dourado** nas exibições de Ordem de Culto (pedido do
  usuário) — `service_order_live_page.dart`: `_SubActionRow.sub.label`
  (sempre navega) e `_MomentCard.item.label` (só quando o toque do card
  abre algo — `isLink: singleAction != null`, novo parâmetro; card sem
  navegação, só "marca concluído", continua branco) viraram
  `SibValColors.goldAccent`. `service_order_praise_view_page.dart`:
  `_DetailRow.label` (toda linha ali navega) idem.

**Ordem de Culto — 11ª rodada: bug real de reconciliação em momento
adicional + Ministério de Louvor fechado pra Dirigentes (28/08/2026, mesma
sessão, pedidos do usuário):**

- **Bug real encontrado — "Ceia do Senhor não atualiza ao editar"**:
  `ServiceOrderReorderPage._buildInitialOrder` (chamada ao reabrir a 2ª
  etapa numa edição) reconciliava um momento adicional já existente
  acrescentando o **item antigo** de `base` (`existing.momentOrder`, os
  dados de ANTES da edição) sempre que o `extraMomentId` já batia — e o
  loop seguinte, que acrescentaria o item **novo** vindo de
  `draft.momentOrder` (com o texto/nomes atualizados na 1ª etapa), pulava
  justamente porque já havia uma entrada com o mesmo `extraMomentId`
  em `result`. Ou seja: editar o texto de "Ceia do Senhor" e salvar
  silenciosamente descartava a edição, mantendo o texto antigo — o usuário
  só percebeu ao remover o momento e adicionar de novo (mesmo
  `extraMomentId`, mesmo sintoma). Corrigido: ao reconciliar, busca o item
  correspondente em `draft.momentOrder` (dados atuais) em vez de reusar o
  de `base` — mantém a posição já reconciliada, troca só os dados. Isso
  também resolve a reclamação separada "Ceia do Senhor deve exibir todos os
  textos que forem adicionados" — não era um bug de exibição (o card já
  mostrava todas as `extraBibleReferences` preenchidas, uma subcategoria
  cada), era o mesmo bug de reconciliação escondendo textos novos atrás dos
  antigos.
- **Ministério de Louvor fechado pra Dirigentes** (pedido explícito do
  usuário: "Dirigente não deve ter acesso a nada em Ministério de Louvor" /
  "Acesso a Ministério de Louvor deve ser a quem tem papel Louvor") — antes
  `canManageServiceOrders` (Dirigentes/admin) também abria o tile e as duas
  abas de gerenciar repertório; agora é só `canViewPraiseOrder`
  (Louvor/admin, `main_shell.dart`/`PraiseMinistryPage.canManage`). Quem o
  admin selecionou como editor de cifra continua entrando (só pra ver o
  menu ☰, sem abas). `SIBValApp2/firestore.rules`: `praiseSongs`/
  `weeklyRepertoires` — `write` de `isDirigentes()` pra `isLouvor()`; `read`
  **não mudou** (continua `isDirigentes() || isLouvor()`) — Dirigentes
  ainda precisa ler pra ver as músicas escaladas durante o culto ao vivo
  (`ServiceOrderLivePage._repertoireSummaryFor`), que é uma exibição da
  Ordem de Culto, não do Ministério de Louvor em si; só a
  escrita/gerenciamento saiu de Dirigentes. **Deploy feito** — aval
  explícito do usuário.
- **Cifra Club**: usuário pediu pra eu buscar as cifras de cada música já
  salva no Repertório Mensal e gerar o conteúdo pronto pra colar em cada
  cifra. Não tenho credencial configurada pra ler o Firestore de produção
  direto (nem pra escrever — só edito código-fonte e faço deploy quando
  autorizado), então pedi a lista de músicas (nome + cantor/banda) pro
  usuário colar — ele topou. Segue como próximo passo assim que a lista
  chegar.

**Ordem de Culto — 12ª rodada: Ceia do Senhor, Tema, import de cifra no
formato Cifra Club, visão dos membros/visitantes travada por timer,
notificações de 5min-antes/início e prévia do dirigente (28/08/2026, mesma
sessão, pedidos do usuário):**

- **Novo momento fixo "Ceia do Senhor"**: `ServiceOrderMomentType.communion`
  inserido no enum entre `message` e `praise3` — como a posição padrão é a
  própria ordem de declaração do enum, isso já garante "logo após a
  Mensagem" pra qualquer cadastro novo sem customização de
  `settings/serviceOrderMomentOrder`. Campo `ServiceOrder.communionResponsible`
  (padrão `'Pr. Ronan'`), mesmo padrão de `intercessionModerator`/`message`.
  **Limitação aceita**: se `settings/serviceOrderMomentOrder` já tiver sido
  customizado (tela "Configurar"), o momento novo é só apendado no fim da
  lista salva, não inserido na posição relativa — mesmo comportamento já
  visto em adições anteriores de momento fixo; o admin precisa arrastar
  "Ceia do Senhor" pro lugar certo uma vez, depois do deploy.
- **Campo "Tema"** (`ServiceOrder.theme`, vazio por padrão) logo abaixo de
  Data/Horário no formulário, com aviso "Preencha apenas para cultos
  especiais". Novo helper `serviceOrderDisplayName(order)` (`"Culto"` quando
  `theme` vazio) reaproveitado em toda tela/notificação que antes mostrava
  "Culto" solto (lista, Precheck, modo apresentação, visão do Louvor, visão
  de membro, e replicado em JS nas duas Cloud Functions novas abaixo, já
  que JS não importa Dart).
- **Cifras — import de arquivo + formato "Cifra Club"**: pedido do usuário
  foi explícito — não bastava importar texto bruto, a própria **exibição**
  da cifra também devia virar o formato de site de cifra (linha de acordes
  solta em cima, linha de letra embaixo), não mais `[Acorde]palavra` inline.
  `Cifra.content` continua um texto único, mas agora nesse formato de duas
  linhas — `CifraEditorPage` ganhou botão "Importar .txt"
  (`file_picker`, novo pacote) que lê o arquivo, limpa cabeçalhos de página
  de cifra (`cleanCifraClubText`, `lib/util/cifra_club_text.dart` — corta
  tudo antes do primeiro par acorde+letra reconhecível, colapsa linhas em
  branco) e joga no campo (com confirmação se já havia conteúdo). Colar
  direto de um site já funciona sem precisar de arquivo. `chord_transpose.dart`
  ganhou `isChordToken`/`transposeChordLine` (transpõe uma linha inteira de
  acordes preservando alinhamento — a diferença de comprimento entre acorde
  antigo/novo é absorvida no espaço seguinte). `CifraViewPage` detecta
  formato pelo conteúdo salvo: se tem colchetes, usa o renderizador antigo
  inline (cifras salvas antes desta mudança continuam funcionando sem
  migração); senão usa o novo renderizador de duas linhas
  (`isChordLine`/`transposeChordLine`), fonte monoespaçada pra manter
  alinhamento. Regex de reconhecimento de acorde é uma heurística
  documentada (lista ampla de sufixos, não um parser musical completo) — o
  campo continua editável em texto livre, então qualquer classificação
  errada rara é fácil de corrigir manualmente.
- **Visão da Ordem de Culto pros demais membros/visitantes** — pedido
  explícito do usuário, terceiro nível de acesso além de Dirigentes/admin
  (Precheck) e Louvor (visão própria com tom/cifra): `ServiceOrder.startedAt`
  (`DateTime?`, fora de `toFieldsMap()`/`copyWith`, mesmo tratamento de
  `isFinalized`/`finalizedAt` — só `ServiceOrderRepository.markStarted`
  escreve) + getter `isStarted`. `ServiceOrderPrecheckPage._startService`
  chama `markStarted` antes de entrar no modo apresentação. Nova
  `ServiceOrderMemberViewPage` (`lib/service_order/`): travada só numa
  contagem regressiva até `order.dateTime` enquanto `!isStarted` — **mesmo
  que o relógio já tenha passado do horário marcado, continua mostrando só
  "Aguardando o dirigente iniciar" em vez do conteúdo** (confirmado com o
  usuário: nunca abre sozinha pelo horário, só pelo toque real em "Iniciar
  Culto"). Assim que `startedAt` é gravado, o `serviceOrderStreamProvider`
  (tempo real) atualiza a tela sozinha, sem precisar reabrir. Conteúdo
  completo renderizado via `ServiceOrderReadOnlyBody` — lista somente-leitura
  extraída de dentro de `ServiceOrderPraiseViewPage` (antes vivia só lá) pra
  ser reaproveitada pelas duas telas, parametrizada por
  `showPraiseDetails: bool`: `true` na visão do Louvor (mostra tom, toque
  abre `CifraViewPage`), `false` na visão de membro (esconde tom, toque nos
  momentos "Louvor" não navega pra lugar nenhum — "igual à do Louvor, porém
  sem acesso às cifras", pedido literal do usuário).

  Tile "Ordem de Culto" no menu Mais (`main_shell.dart`) deixou de ser
  condicional (antes só Dirigentes/Louvor/admin) — agora é incondicional,
  visível pra qualquer usuário, **inclusive acesso convidado sem conta**
  (confirmado com o usuário via `AskUserQuestion`). `ServiceOrderListPage`
  (`onTap`) despacha por papel via novo helper `openServiceOrder`
  (`lib/service_order/service_order_navigation.dart`, compartilhado com a
  navegação de notificação abaixo): Dirigentes/admin → Precheck; Louvor →
  visão própria; qualquer outro (membro comum ou convidado, `profile` pode
  ser `null`) → `ServiceOrderMemberViewPage`. `SIBValApp2/firestore.rules`:
  `match /serviceOrders` — `read` virou `allow read: if true;` (leitura
  pública, mesmo padrão já usado em `posts`/`devotionals`) — `create`/
  `update`/`delete` continuam restritos a Dirigentes/dono/admin. **Só editei
  o código-fonte das regras — não fiz `firebase deploy`**, mesma cautela de
  sempre; até o deploy, a visão de membro/convidado não consegue ler
  `serviceOrders` de verdade em produção.

- **Notificações de 5 minutos antes e de início do culto** — pedido do
  usuário, ambas audiência `all` (todo mundo), texto usa
  `serviceOrderDisplayName`/`theme` no lugar de "Culto" quando preenchido.
  Novos `NotificationType.serviceOrderReminder`/`.serviceOrderStarted`
  (`lib/models/notification.dart`); `notification_navigation.dart` despacha
  os dois pra `openServiceOrder` (mesma regra por papel de cima).
  `syncNotificationsForScreen` chamado no `initState` de
  `ServiceOrderMemberViewPage`/`ServiceOrderPraiseViewPage`/
  `ServiceOrderPrecheckPage`/`ServiceOrderLivePage`, mesmo padrão das demais
  telas ligadas a um tipo de notificação. Em
  `SIBValApp2/functions/index.js` (só código-fonte, sem deploy): novo
  `sendServiceOrderReminders` (`onSchedule`, a cada minuto) consulta
  `serviceOrders` num range de 1h à frente, filtra em memória quem ainda não
  tem `reminder5MinSent` e cuja janela de 5 minutos já começou, envia e
  marca o flag (idempotência, mesmo padrão de `reminderSent` em
  `sendRecurringEventReminders`); novo `onServiceOrderStartedNotify`
  (`onDocumentUpdated`) detecta a transição de `startedAt` ausente pra
  presente e notifica na hora, em tempo real.

- **Prévia da ordem pro dirigente** — pedido do usuário ("uma maneira do
  dirigente acessar uma prévia do culto"). Nova `ServiceOrderPreviewPage`
  (`lib/service_order/`) — lista somente-leitura de `order.momentOrder`
  (rótulo + resumo de cada momento, sem tracking de progresso, sem trava de
  horário, sempre disponível) — é a lista de momentos que existia em
  `ServiceOrderPrecheckPage` antes da 3ª rodada da mesma sessão (removida de
  lá), revivida como tela própria. Dois pontos de entrada: botão "Ver
  Prévia" em `ServiceOrderPrecheckPage` (sempre habilitado, não depende da
  contagem regressiva) e item "Visualizar" no menu de toque-e-segure de
  `ServiceOrderListPage` (mesmo menu que já tinha Editar/Excluir pro
  dono/admin), disponível a qualquer momento, não só perto do horário do
  culto.

- **Nota de processo**: esta rodada foi implementada por três frentes em
  paralelo (Flutter core, import/exibição de cifra, Cloud Functions/regras).
  A frente de Cloud Functions/regras inicialmente saiu do escopo combinado
  (mexeu em arquivos Dart que não eram dela, colidindo com a frente
  principal) e nunca chegou a aplicar as mudanças em
  `firestore.rules`/`functions/index.js` — percebido só na verificação final
  (`git status` no repo nativo mostrando árvore limpa apesar do relatório
  dizer o contrário); refeito diretamente por mim depois, e toda a árvore de
  arquivos Dart revisada manualmente linha por linha (sem `flutter analyze`
  disponível neste ambiente) pra confirmar que a concorrência não deixou
  nada quebrado.

**Ordem de Culto — 13ª rodada: Ceia do Senhor vazio por padrão, texto de
import simplificado, seletor de tom na cifra, mensagem automática de escala
e popup de bênção ao finalizar (28/08/2026, mesma sessão, pedidos do
usuário):**

- **Ceia do Senhor volta a nascer vazio** — `communionResponsible` (padrão
  era `'Pr. Ronan'`, igual aos demais momentos com responsável fixo) virou
  `''`. Como o momento já saía da ordem quando vazio
  (`ServiceOrderReorderPage._isEmptyMoment`, item novo desta mesma
  entrada), um culto comum (sem Ceia) não precisa mais que o dirigente
  apague manualmente o nome padrão — só preenche quando o culto realmente
  vai ter Ceia do Senhor.
- **Texto de ajuda do import de cifra simplificado** — tirado o "formato
  Cifra Club"/"também dá pra colar direto de um site" (`cifra_editor_page.dart`),
  a pedido do usuário; ficou só "Letra e acordes — Formato: uma linha só com
  os acordes, e a linha de baixo com a letra correspondente."
- **Seletor de tom na exibição da cifra** (`CifraViewPage`) — além dos
  botões +/- de sempre (transposição por semitom), o valor central agora é
  tocável (só quando a cifra tem `baseTone` salvo — sem isso não há de onde
  calcular a distância) e abre uma lista das 12 notas cromáticas
  (`praiseToneNotes`, já usada em Ministério de Louvor); escolher uma
  calcula direto quantos semitons faltam (`noteIndex`, novo helper em
  `chord_transpose.dart`) e ajusta `_semitones` — mesmo mecanismo de
  transposição de sempre, só que "de um pulo" em vez de incremento único.
- **Mensagem automática pra quem é escalado na Participação Especial** —
  sem equivalente no nativo. Quando o texto do campo "Participação Especial"
  bate com o nome de um `Member` que já tem `linkedUid` (conta de app
  vinculada), duas Cloud Functions novas em `SIBValApp2/functions/index.js`
  (`onServiceOrderCreatedParticipationNotify`/
  `onServiceOrderUpdatedParticipationNotify`, via helper compartilhado
  `syncServiceOrderParticipationAssignment`) mandam uma mensagem de verdade
  pela Central de Mensagens (coleção `messages` — não é só um push solto;
  cria o documento e o gatilho já existente `onMessageCreated` cuida do
  push sozinho) avisando a escala, com data/hora e o Tema (ou "o culto")
  no texto. Casamento é por nome normalizado (`normalizeKey`, mesmo helper
  já usado pro sync de papel por ministério), varrendo `members` em
  memória — mesmo padrão de `getTodaysMembershipAnniversaryMembers`, sem
  índice novo. `participationAssignedUid`/`participationReminderSent`
  (campos só desta function, sem equivalente no model Dart — mesma família
  de `feedRepost24hSent`) guardam quem foi avisado por último, pra um
  `update()` que não muda a pessoa escalada não reenviar a mensagem de novo,
  e resetam o lembrete quando a pessoa escalada muda numa edição. Novo
  `sendServiceOrderParticipationReminders` (`onSchedule`, a cada 15 min,
  mesmo padrão de janela/idempotência de `sendRecurringEventReminders`)
  manda um lembrete 24h antes do culto pra quem ficou marcado como escalado.
  **Interpretação registrada aqui pra revisar se não bater com o esperado**:
  "enviada no momento que a ordem é salva" foi lido como "quando a pessoa
  escalada muda" (criação, ou edição que troca quem está na Participação
  Especial) — não a cada `update()` de qualquer campo da ordem, pra não
  reenviar a mesma mensagem numa edição que não tem nada a ver com
  Participação Especial.
- **Popup de bênção ao finalizar o culto** — sem equivalente no nativo.
  Nova `onServiceOrderFinalizedNotify` (`onDocumentUpdated`, detecta a
  transição de `isFinalized` pra `true`) manda push pra todos, audiência
  `all`, com o texto "Que a bênção do Senhor esteja sobre sua vida. Vá em
  paz! 🙏" (redigido por mim — o usuário só pediu "uma mensagem de bênção",
  sem especificar o texto exato). Novo `NotificationType.serviceOrderFinalized`
  (`lib/models/notification.dart`). Só quem está com o app **aberto em
  primeiro plano** no momento vê um popup de verdade
  (`PushNotificationService._onForegroundMessage` trata esse tipo como caso
  especial — `AlertDialog` sobre a tela atual, via `navigatorKey`, no lugar
  do banner do sistema); em segundo plano/fechado continua sendo só o banner
  normal (não dá pra abrir diálogo Flutter fora do app rodando) — tocar nele
  volta pro Início, mesmo padrão de `membershipAnniversary`.
- Nenhuma das duas rodadas de Cloud Functions desta entrada foi deployada —
  **só editei o código-fonte**, mesma cautela de sempre; a mensagem
  automática de escala e o popup de finalização só funcionam de verdade em
  produção depois de um `firebase deploy` explicitamente pedido.

**Ordem de Culto — 14ª rodada: tons menores na lista (não só no botão
fechado), texto do popup de finalização simplificado, confirmação do
encaminhamento da notificação de participação (28/08/2026, mesma sessão,
pedidos do usuário):**

- **Lista de tons mostra "m" em todo item quando menor, não só no botão
  fechado** — `weekly_repertoire_form_page.dart`/`cifra_editor_page.dart`
  (`items` do `DropdownButtonFormField`) e `CifraViewPage._openTonePicker`
  (novo desta sessão, rodada anterior) só sufixavam "m" no
  `selectedItemBuilder` (texto do botão já fechado); a lista aberta
  continuava com as notas puras. Corrigido nos três lugares — o "m" agora
  aparece em toda a lista (ex. "Em", "Dbm", "F#m") sempre que o tom em
  questão é menor (`toneIsMinor`/`_toneIsMinor` nos dois primeiros,
  `baseTone.endsWith('m')` no terceiro, já que lá não há um toggle
  separado — o "menor" vem direto do tom salvo na cifra).
- **Texto do popup/notificação de finalização simplificado** — pedido do
  usuário: só "{Culto/Tema} foi finalizado." (título) + "Que a bênção do
  Senhor esteja sobre sua vida!" (corpo), sem "Vá em paz 🙏" (removido).
  Botão do popup (`push_notification_service.dart`) virou "🙌 Amém" (o
  emoji de "mãozinhas" pedido foi pro botão, não pro texto da mensagem).
- **Encaminhamento da notificação de mensagem de participação pra
  `MessageDetailPage`** — conferido, não precisou de nenhuma mudança: as
  duas Cloud Functions novas da rodada anterior
  (`onServiceOrderCreatedParticipationNotify`/
  `onServiceOrderUpdatedParticipationNotify`) já gravam o documento em
  `messages` com exatamente o mesmo formato de campos que
  `MessageRepository.send()` usa (conferido campo a campo) — o gatilho
  `onMessageCreated` (já existente) já dispara o push com
  `type: "message", targetId: <id da mensagem>`, e
  `notification_navigation.dart` já tinha o `case NotificationType.message`
  levando pra `MessageDetailPage(messageId: targetId)` desde antes desta
  feature existir. Já funcionava por construção.

**Ordem de Culto — 15ª rodada: "Ensaios" no Ministério de Louvor,
propriedade exclusiva do dono (nem admin escapa), notificação "Culto"+tema,
Anotações após Boas-vindas e Escala de Dirigentes (28/08/2026, mesma sessão,
pedidos do usuário):**

- **"Ensaios"** — nova opção no menu ☰ do Ministério de Louvor
  (`_PraiseMenuButton`, ao lado de "Cifras"), mesma audiência
  (`canViewPraiseOrder`/`canEditCifrasProvider`). `EnsaiosListPage`
  (`lib/praise/ensaios_list_page.dart`) lista os repertórios semanais já
  cadastrados (`weeklyRepertoiresProvider`, mesma fonte da aba "Repertório
  Semanal") — toque abre `EnsaioDetailPage`, somente leitura: músicas
  escaladas com nome/cantor/tom (`PraiseAssignment.toneDisplay`) e os links
  de playlist (tocáveis, `url_launcher`, mesmo padrão de
  `partners_page.dart`). Toque numa música só navega pra `CifraViewPage`
  quando existe cifra com conteúdo pra ela (`cifrasProvider`, cruzado por
  `songId` — sem cifra, a linha fica sem link, "se houver cifra, ao tocar
  ele irá abrir a cifra", pedido literal do usuário).

- **Propriedade exclusiva do dono — nem admin escapa.** Pedido do usuário:
  "Uma ordem de culto deve ser Editada/Excluída, Iniciar culto e até
  marcado cada momento como concluído SOMENTE pelo seu criador. Nem mesmo
  admin poderá fazer estas ações." `SIBValApp2/firestore.rules`
  (`serviceOrders`): `update` passou a exigir
  `isDirigentes() && resource.data.ownerUid == request.auth.uid` — a
  exceção antiga `isAdmin() ||` foi retirada; admin só consegue gravar
  quando o `update` toca **só** `ownerUid`/`ownerName`
  (`request.resource.data.diff(resource.data).affectedKeys().hasOnly([...])`),
  ou seja, só a transferência de propriedade. `delete` virou
  `isDirigentes() && resource.data.ownerUid == request.auth.uid`, sem
  exceção nenhuma pro admin. Como `markStarted`/`updateProgress`/`finalize`
  (`ServiceOrderRepository`) também passam por `update()` nesse documento,
  a mesma regra cobre iniciar o culto e marcar momentos automaticamente,
  sem precisar de campos/regras extras.

  `ServiceOrderListPage._showActions`: Editar/Excluir só aparecem se
  `isOwner`; novo item "Alterar proprietário" só aparece se `isAdmin`
  (independente de quem é o dono atual) — leva pra
  `ServiceOrderTransferOwnerPage` (nova, `lib/service_order/
  service_order_transfer_owner_page.dart`), lista usuários aprovados com
  papel Dirigentes ou admin (mesmo critério de `isDirigentes()` nativo — só
  quem passa nessa checagem consegue editar depois de virar dono), toque
  confirma e chama `ServiceOrderRepository.transferOwner` (novo método, só
  `ownerUid`/`ownerName`). "A visão do admin para a ordem de culto será a
  mesma de um usuário comum, com o privilégio de poder alterar o
  proprietário" — `openServiceOrder` (`service_order_navigation.dart`)
  passou a despachar por **dono**, não mais por papel: só quem tem
  `order.ownerUid == uid` vai pro Precheck/"Iniciar Culto"; qualquer outro
  (Dirigentes não-dono, admin não-dono, Louvor, membro comum, convidado) cai
  nas mesmas visões somente-leitura de sempre (Louvor ou membro comum) — um
  Dirigentes/admin que não é dono nunca mais vê um botão "Iniciar Culto" que
  falharia por permissão.

- **Notificação de início: "Culto" + tema.** Pedido do usuário: "Quanto
  houver um tema coloque Culto+tema, quando não houver mantenha somente
  Culto." `onServiceOrderStartedNotify`
  (`SIBValApp2/functions/index.js`) — `displayName` virou
  `` `Culto — ${after.theme}` `` quando há tema, `"Culto"` sozinho quando
  não há (antes era só o tema puro, sem a palavra "Culto", ou "O culto"
  minúsculo sem tema). Só esse gatilho foi ajustado — o pedido foi
  especificamente sobre "notificações de início de culto"; o lembrete de 5
  minutos antes (`sendServiceOrderReminders`) e o aviso de finalização
  continuam com o texto de antes.

- **Campo "Anotações" após Boas-vindas** — `ServiceOrder.welcomeNotes`
  (String, vazio por padrão) — texto livre do dirigente, sem equivalente no
  nativo. Não é um "momento" (não entra em `momentOrder`, não reordenável,
  não marcável) — só aparece, quando preenchido, logo abaixo do card de
  "Boas-vindas" nas quatro telas que renderizam a liturgia:
  `ServiceOrderFormPage` (campo multi-linha logo após o rótulo "Boas-
  vindas"), `ServiceOrderPreviewPage`, `ServiceOrderLivePage` (novo widget
  privado `_WelcomeNotesCard`) e `ServiceOrderReadOnlyBody`
  (`service_order_praise_view_page.dart`, reaproveitada por Louvor e membro
  comum — mesmo widget duplicado localmente, privado por arquivo).

- **Escala de Dirigentes** (novo, sem equivalente no nativo) — planejamento
  antecipado de quem vai dirigir cada culto + tema, distinto da
  `ServiceOrder` em si (que só existe quando o dirigente de fato monta a
  liturgia daquele culto específico). Acessível pelo novo menu ☰ dentro de
  "Ordem de Culto" (`ServiceOrderListPage`, mesmo padrão visual do menu do
  Ministério de Louvor), item "Escala de Dirigentes" — visível a quem tem
  `canViewLeaderSchedule` (`CurrentUserProfile`, novo getter: admin, Pastor
  ou Dirigentes). Modelo `LeaderScheduleEntry`
  (`lib/models/leader_schedule.dart`): data (horário fixo 19h, sem seletor
  próprio — mesmo padrão do culto de domingo à noite), `leaderUid`/
  `leaderName`, `theme` (prévia do tema pretendido — não sincroniza
  automaticamente com `ServiceOrder.theme` quando a ordem é criada depois).
  Repositório em `lib/data/leader_schedule_repository.dart`, coleção
  `leaderSchedules`, ordenada ascendente (agenda de planejamento futuro, ao
  contrário do histórico descendente de `serviceOrders`).

  `LeaderScheduleListPage` lista as entradas; FAB "Nova Escala" só pra
  `canManageLeaderSchedule` (novo getter: admin ou Pastor — "o pastor terá
  autorização para inserir os escalados"); toque abre
  `LeaderScheduleFormPage` editável pra quem gerencia, ou em modo
  `readOnly: true` (sem Salvar/Excluir) pra Dirigentes ("terão o acesso de
  visualização"). Seleção do dirigente escalado via bottom sheet de busca
  (`_LeaderPickerSheet`) — candidatos são usuários aprovados com papel
  Dirigentes ou admin, mesmo critério já usado em
  `ServiceOrderTransferOwnerPage`.

  Duas mensagens automáticas pro dirigente escalado (Central de Mensagens,
  `SIBValApp2/functions/index.js`, só código-fonte — **não fiz `firebase
  deploy`**, mesma cautela de sempre): `sendLeaderScheduleTuesdayNotice`
  (cron toda terça-feira 8h, horário de Brasília) avisa quem está escalado
  pra alguma data dentro dos próximos 7 dias que é um bom momento pra
  preparar a direção do culto — idempotente via `tuesdayNoticeSent`, nunca
  se repete pra mesma entrada; `sendLeaderScheduleReminders` (cron a cada 15
  min, mesmo padrão de janela/idempotência de
  `sendServiceOrderParticipationReminders`) manda o lembrete 24h antes,
  idempotente via `reminder24hSent`. `SIBValApp2/firestore.rules` ganhou
  `match /leaderSchedules` (`read` pra Dirigentes/Pastor/admin, `write` só
  Pastor/admin) — também só código-fonte, sem deploy.

**Ordem de Culto — 16ª rodada: Anotações também abaixo de Avisos, "Alterar
proprietário" virou bottom sheet em vez de tela (28/08/2026, mesma sessão,
pedidos do usuário):**

- **Segundo campo de anotações.** `ServiceOrder.announcementsNotes` — mesma
  ideia de `welcomeNotes` (texto livre, opcional, sem entrar em
  `momentOrder`, não reordenável nem marcável), só que pro momento "Avisos/
  Comunicações". Mesmas quatro telas: campo no formulário logo abaixo do
  rótulo "Avisos/Comunicações", exibição condicional em
  `ServiceOrderPreviewPage`, `ServiceOrderLivePage` e
  `ServiceOrderReadOnlyBody` (Louvor/membro comum). O widget que exibe a
  anotação (antes `_WelcomeNotesCard`, só pra Boas-vindas) virou
  `_MomentNotesCard` (renomeado nos dois arquivos que o duplicam,
  `service_order_live_page.dart`/`service_order_praise_view_page.dart`) —
  genérico o bastante pra servir aos dois momentos via um `switch
  (item.type)` que escolhe `welcomeNotes` ou `announcementsNotes`.

- **"Alterar proprietário" deixou de ser uma tela.** O usuário corrigiu a
  1ª versão (`ServiceOrderTransferOwnerPage`, uma página própria,
  removida): "A funcionalidade de alterar proprietário deve ser uma opção
  direto na ordem de culto, não deve ser uma nova tela." Virou
  `_showTransferOwnerSheet`/`_TransferOwnerSheet`, um `showModalBottomSheet`
  chamado direto de dentro de `ServiceOrderListPage._showActions` (mesmo
  arquivo, mesma tela) — busca + lista de candidatos, confirmação e
  `ServiceOrderRepository.transferOwner`, sem nenhuma navegação
  (`Navigator.push`) envolvida. Mesmo critério de candidatos de antes
  (aprovado + Dirigentes/admin).

**Deploy feito (mesma sessão):** aval explícito do usuário — `firebase
deploy --only
firestore:rules,functions:onServiceOrderStartedNotify,functions:sendLeaderScheduleTuesdayNotice,functions:sendLeaderScheduleReminders
--project sibval-app-project`. Publicou a regra de `serviceOrders`
(propriedade exclusiva do dono, admin só transfere) + `match
/leaderSchedules`, o texto novo de `onServiceOrderStartedNotify`
("Culto"+tema) e as duas Cloud Functions da Escala de Dirigentes (aviso de
terça, lembrete de 24h) — as três funções desta entrada e da anterior estão
ativas em produção a partir de agora.

**Ordem de Culto — 17ª rodada: texto bíblico via internet (BLIVRE), com
crédito e fallback offline (28/08/2026, mesma sessão, pedido do usuário):**

Pedido: "Enquanto não temos versões da bíblia mais atualizadas, é possível
que a busca dos textos bíblicos na ordem de culto seja feita na internet,
buscando de um site específico, e colocando os devidos créditos?" — só a
tela que exibe o texto lido durante o culto (`ServiceOrderBibleTextPage`,
aberta a partir de Leitura bíblica/Texto bíblico dos dízimos/momento
adicional com referência bíblica), não a aba "Bíblia" principal nem a
seleção de livro/capítulo/versículo (que continuam 100% locais, Almeida
1911, `bible_database.dart`).

**Pesquisa antes de implementar** (registrada porque mudou a recomendação
inicial): a primeira ideia foi a API `abibliadigital.com.br`, mas foi
**descontinuada em 01/08/2026** (confirmado via WebFetch no GitHub do
projeto — site retornando 503). Alternativas pesquisadas: `wldeh/bible-api`
(CDN estático, MIT, mas cobertura em português inutilizável — só uma edição
parcial do NT e uma pasta vazia) e `damarals/biblias` (coletânea de 18
Bíblias em português, JSON baixável por URL direta). Dentro dessa segunda,
identificada a edição certa: **Bíblia Livre (BLIVRE), Textus Receptus**
(mesma linhagem textual do Almeida — atualização da tradução de 1819,
Bíblia completa AT+NT), licença **Creative Commons Atribuição 4.0**
(permite uso comercial, exige só crédito — confirmado em
https://ebible.org/details.php?id=porbr2018, que também confirmou não ser a
edição alternativa de texto crítico/Nestle do mesmo projeto). Antes de
implementar, o arquivo de verdade (`BLIVRE.json`, release `v1.0.0`) foi
baixado e validado por script (`node`): 66 livros, nenhum livro/capítulo
vazio, Salmos com 150 capítulos, Gênesis 1 com 31 versículos, João 3:16
conferido palavra por palavra — e a lista de abreviações dos 66 livros
comparada item a item com a real (achou 1 divergência: "Êxodo" é `"Êx"`,
com acento, não `"Ex"` como se assumiria).

**Implementação:** `lib/data/blivre_repository.dart` (`BlivreRepository`,
sem provider de estado — só um `Provider` simples) baixa o `BLIVRE.json`
inteiro (~3,8 MB) **uma vez só**, na primeira consulta, de uma URL de
release **fixada em `v1.0.0`** (não "latest" — evita quebrar em silêncio se
o formato mudar numa versão futura sem revisão manual), e cacheia em disco
(`getDatabasesPath()/blivre.json`, mesmo diretório do `alm1911.sqlite` —
reaproveita o diretório gravável do `sqflite`, sem precisar do pacote
`path_provider`). Chamadas seguintes leem do cache em disco, sem rede.
`_abbrevs` (lista fixa de 66 siglas, validada acima) mapeia `bookId` 1..66
(mesmo id do banco local) pro `abbrev` da BLIVRE, sem tabela de conversão.

`ServiceOrderBibleTextPage` ganhou `_resolvedBibleVersesProvider`
(`FutureProvider.family`, privado ao arquivo) — tenta `BlivreRepository`
primeiro; se falhar (sem internet e sem cache ainda) ou o capítulo não
existir lá por algum motivo, cai pro Almeida 1911 local
(`BibleRepository`, sempre disponível). Uma linha de crédito aparece
abaixo do título: "Fonte: Bíblia Livre (BLIVRE), licença CC BY 4.0" quando
o texto veio de lá, ou "Fonte: Almeida 1911 (offline)" no fallback (esse
segundo não é exigência legal — Almeida 1911 é domínio público — só
transparência sobre por que o texto pode ler diferente do normal quando a
busca online falha).

`http`/`path`/`sqflite` já eram dependências do projeto — nenhum pacote
novo em `pubspec.yaml`. Sem mudança em `AndroidManifest.xml` — a permissão
de internet já é herdada por outros plugins (Firebase etc.), confirmado
porque o app já faz outras chamadas de rede (ex. ViaCEP via `http`).

**Bug corrigido no primeiro teste real (mesma sessão):** usuário reportou
"vários caracteres especiais nos textos" ao testar no celular. Causa:
`response.body` do pacote `http` decodifica pelo charset do cabeçalho
`Content-Type` da resposta; o GitHub serve o `BLIVRE.json` como
`application/octet-stream`, sem charset declarado, então o pacote caía no
padrão ISO-8859-1 (Latin-1) pra decodificar um arquivo que na verdade é
UTF-8 — corrompendo todo acento. Trocado por `utf8.decode(response.bodyBytes)`
(ignora o cabeçalho, decodifica os bytes brutos como UTF-8 de propósito) em
`BlivreRepository._ensureLoaded`. O nome do arquivo de cache em disco
também mudou de `blivre.json` pra `blivre_v2.json` — só trocar o código não
bastava, quem já tinha testado (o próprio celular do usuário) já tinha um
cache local corrompido gravado; o nome novo garante um download limpo, sem
precisar de lógica de limpeza do cache antigo (ele só fica órfão, inofensivo,
no armazenamento do app).

**Aba "Bíblia" ganha as duas versões, BLIVRE como padrão (28/08/2026, mesma
sessão, pedido do usuário: "é possível implementar esta mesma versão para a
bíblia completa, mantendo as duas versões, porém a livre como padrão?"):**

Estende o que já existia só na Ordem de Culto pra aba "Bíblia" inteira
(lista de livros, capítulos, leitura, busca, favoritos) — usuário escolhe
entre **Bíblia Livre (BLIVRE)**, padrão, e **Almeida 1911** (local, sempre
disponível offline), com a mesma fonte/crédito/fallback já validados.

- `lib/data/bible_source_repository.dart` (novo): `BibleVersion` enum
  (`blivre`/`almeida1911`) + `BibleVersionNotifier`/`bibleVersionProvider`
  — mesmo padrão de `ThemeModeNotifier` (`theme_preference.dart`): estado
  síncrono já nasce em `BibleVersion.blivre` (padrão pedido), sobrescrito de
  forma assíncrona se havia escolha salva (`shared_preferences`, chave
  `bible_version`). `BibleSourceRepository` combina `BibleRepository`
  (Almeida 1911) e `BlivreRepository` (BLIVRE) atrás de uma API única —
  todo método tenta a BLIVRE quando `version == blivre` e cai pro Almeida
  1911 se falhar, devolvendo sempre `fromBlivre` (pra tela saber qual
  fonte respondeu de verdade, que pode divergir da escolha do usuário no
  fallback). `versionedChapterCountProvider`/`versionedVersesProvider`
  (`FutureProvider.family`) recalculam sozinhos quando `bibleVersionProvider`
  muda — trocar a versão atualiza a leitura na hora.
- `BlivreRepository` ganhou `getChapterCount`/`search`/`resolveRefs` — a
  busca é uma varredura em memória (~31 mil versículos já cacheados depois
  da 1ª leitura, sem SQL), cortada em 200 resultados como o Almeida 1911;
  `books` (nome/ordem/testamento) sempre vem de `BibleRepository.getBooks()`
  — estrutural, igual nas duas versões, sem motivo pra depender de rede.
- `BibleBookListPage`: dois `ChoiceChip`s ("Bíblia Livre"/"Almeida 1911"),
  mesmo padrão visual do escopo de busca — escolha persistida, vale pra
  toda a aba.
- `BibleChapterPickerPage`/`BibleReaderPage`/`BibleSearchPage`/
  `BibleFavoritesPage`: trocados pros providers/repositório versionados;
  `BibleReaderPage`/`BibleSearchPage`/`BibleFavoritesPage` ganharam a mesma
  linha de crédito da Ordem de Culto ("Fonte: Bíblia Livre (BLIVRE), licença
  CC BY 4.0"), só quando o texto exibido veio de lá. Favoritos guardam só a
  referência (`bookId:chapter:verse`), nunca o texto — trocar de versão
  muda o texto mostrado ali automaticamente, sem precisar refavoritar.
- Nenhuma mudança nos seletores de livro/capítulo/versículo da Ordem de
  Culto/Devocional (`_ChapterDropdown` etc.) nem no banco local em si — só
  a leitura de texto corrido passou a respeitar a versão escolhida.

**Ordem de Culto — realce sutil de campo vazio no formulário (28/08/2026,
mesma sessão, pedido do usuário: "destaque os campos que estão sem
preenchimento... que não fique muito gritante"):** novo helper top-level
`highlightIfEmpty(InputDecoration base, String text)`
(`service_order_form_page.dart`) — quando `text` está vazio, tinge fundo e
borda do campo em âmbar bem fraco (`alpha` 0.08 no fundo, 0.55 na borda),
deliberadamente discreto pra não parecer erro de validação (que usaria
vermelho).

Aplicado nos campos de texto livre "de conteúdo" (Prelúdio/Poslúdio
"Outro" quando visíveis, Oração, Louvor x3, Participação Especial, Tema/
Divisa do Momento Missionário, Hino Congregacional, Momento de
Intercessão, Mensagem) — **excluídos de propósito**: Tema do culto (hint já
diz "só pra cultos especiais"), as duas Anotações (Boas-vindas/Avisos, hint
já diz "opcional") e Ceia do Senhor (nasce vazio de propósito desde a 13ª
rodada — só é preenchido quando o culto realmente vai ter Ceia; destacá-lo
soaria como "faltando" toda vez, o que não é o caso na maioria dos cultos).
`_BibleReferenceFields` (Leitura bíblica, Texto bíblico dos dízimos) e os
dropdowns (Prelúdio/Poslúdio/Momento Missionário, sempre têm algum valor
selecionado) ficaram de fora desta rodada — não avaliado se fazem falta.

Pra o realce acompanhar o que o dirigente digita em tempo real,
`_markDirty()` (chamada pelos listeners de `_textControllersToTrack`)
passou a chamar `setState` em toda tecla — antes só na 1ª interação
(`if (!_dirty)`), o suficiente pro aviso de "sair sem salvar?" mas não pro
realce, que precisa recalcular a cada mudança. `_participationController`/
`_congregationalHymnController` (dentro de `_ParticipationField`/
`_HymnField`) já se reconstroem sozinhos a cada tecla via o próprio
listener interno desses widgets — não precisaram desse ajuste.

**Ordem de Culto — cada momento do formulário numa caixa (28/08/2026, mesma
sessão, pedido do usuário: "colocar cada momento do formulário dentro de
caixas, separando assim melhor cada um deles"):** novo helper top-level
`_momentBox(BuildContext context, List<Widget> children)`
(`service_order_form_page.dart`) — `Container` com borda discreta
(`Theme.of(context).colorScheme.outlineVariant`, mesmo tom neutro já usado
em `weekly_repertoire_form_page.dart`/`_AssignmentRow`), sem preencher o
fundo, `margin` inferior própria (substituiu os `SizedBox` que separavam os
momentos antes). Todo bloco do formulário — de "Data e horário" (agrupado
com "Tema" numa caixa só, exemplo dado pelo usuário) até "Momentos
Adicionais" — virou uma chamada a `_momentBox`, um por momento (inclusive
"Oração pelas crianças"/"Benção Apostólica", que não têm campo próprio —
viraram caixas só com o rótulo, pra manter a sequência visual consistente).
`highlightIfEmpty` (rodada anterior) continua funcionando igual dentro das
caixas — é só a decoração do campo, não muda com o agrupamento.

**Ordem de Culto — Leitura bíblica e Dedicação dos dízimos obrigatórios,
caixas com fundo tingido e largura consistente, texto do Tema ajustado
(28/08/2026, mesma sessão, pedidos do usuário):**

- `ServiceOrderFormPage._continue()` ganhou três validações novas, mesmo
  padrão de `_showError` já usado pra data/prelúdio/poslúdio/momento
  missionário: "Leitura bíblica" precisa de pelo menos 1 referência
  preenchida (`_bibleReadingControllers.any((c) =>
  c.toReference().isFilled)`); "Dedicação dos dízimos e ofertas" precisa
  dos dois sub-campos — Texto bíblico E Hino Congregacional (antes os dois
  eram opcionais).
- `_momentBox` (rodada anterior) ganhou `width: double.infinity` — sem
  isso, uma caixa cujo único filho é um `Text` sem campo (Oração pelas
  crianças/Benção Apostólica) encolhia pra largura do texto, já que nada
  ali força a largura máxima como um `TextField` faz; agora todas as
  caixas têm a mesma largura.
- `_momentBox` também ganhou fundo levemente tingido — `Color.alphaBlend`
  de um branco (tema escuro) ou preto (tema claro) em baixíssima opacidade
  (0.05/0.04) sobre `Theme.of(context).scaffoldBackgroundColor`, em vez de
  uma cor fixa tipo `surfaceContainerHighest` — garante que a diferença
  seja "um pouco" (pedido literal do usuário), nunca um tom muito diferente
  do fundo real da tela, e se adapta sozinho a qualquer futura mudança de
  paleta.
- Campo "Tema": hint mudou de "Preencha apenas para cultos especiais" pra
  "Preencha com tema ou cultos especiais" (pedido literal do usuário).

**Cifras — tom real no lugar de "Original", "Tom" numa linha própria,
seleção de tom com destaque dourado no original, cantor/banda no cabeçalho
(mesma sessão, pedidos do usuário):**

- `CifraViewPage`: o rótulo "Tom" saiu da mesma linha dos botões +/- (que
  usava `Spacer()` pra empurrar os botões pra direita) e virou uma linha
  própria acima deles. O texto central, quando não há transposição
  (`_semitones == 0`), mostra o tom de verdade da cifra (`baseTone`) em vez
  de "Original" — deslocado por +/-, continua mostrando o delta ("+2"/"-1"
  etc., não alterado).
- `_openTonePicker` (lista das 12 notas cromáticas): a opção que bate com o
  tom original da cifra (`rootNote`) ganhou um `Container` com borda
  dourada (`SibValColors.goldAccent`, `width: 1.5`) e cantos arredondados
  (`BorderRadius.circular(8)`) — destaque visual pra saber qual é o tom
  original sem precisar fechar o diálogo e olhar de novo.
- Cabeçalho de `CifraViewPage` ganhou o cantor/banda (`Cifra.songArtist`,
  já buscado por `cifraForSongProvider` — não precisou de parâmetro novo no
  construtor) abaixo do nome da música, mesmo padrão visual (cor
  secundária, fonte menor) já usado em outras telas desta base.
  `CifraListPage` já mostrava isso como `subtitle` do `ListTile` desde a
  10ª rodada — só a tela de visualização em si não tinha.

**Ordem de Culto — foco no primeiro campo obrigatório pendente + Cifras,
ajustes finos (28/08/2026, mesma sessão, pedidos do usuário):**

- **Validação da Ordem de Culto revisada** — em vez de parar no primeiro
  erro (`_showError` + `return`), `_continue()` agora junta **todos** os
  campos obrigatórios pendentes num `Set<_RequiredField>`
  (`_fieldErrors`, novo enum privado — declarado na mesma ordem em que os
  campos aparecem no formulário, servindo de ordem de prioridade) e só
  então decide: se houver algum, marca todos em vermelho e move o foco só
  pro primeiro (`_focusNodeFor`, novos `FocusNode` pros campos que ainda
  não tinham: `_preludeOtherFocusNode`, `_missionThemeFocusNode`,
  `_missionMottoFocusNode`, `_postludeOtherFocusNode` — os que já tinham
  `_congregationalHymnFocusNode`/`BibleReferenceController.bookFocusNode`
  foram reaproveitados). `requestFocus()` já basta pro Flutter rolar a
  tela até o campo sozinho (`Scrollable.ensureVisible` automático em
  `TextField` dentro de `SingleChildScrollView`) — não precisou de scroll
  manual.
- `highlightIfEmpty` ganhou `isError`/`highlightEmpty` — vermelho
  (`Colors.red`, borda mais grossa) sobrepõe o âmbar quando o campo está
  em `_fieldErrors` **e** ainda vazio (um campo sai do vermelho sozinho ao
  ganhar conteúdo, sem precisar tirar de `_fieldErrors` manualmente).
  `highlightEmpty: false` desliga o âmbar geral num campo que só participa
  do vermelho de erro — usado no campo "Livro" de `_BibleReferenceFields`/
  `_BookField` (Leitura bíblica, Texto bíblico dos dízimos), que nunca teve
  destaque de campo vazio antes de virar obrigatório. `_BibleReferenceFields`/
  `_BookField`/`_HymnField` ganharam o parâmetro `isError` pra repassar.
  Leitura bíblica (lista) só marca a 1ª linha em vermelho — o erro é "nenhuma
  preenchida", não uma linha específica.

- **Cifras** — cantor/banda no cabeçalho de `CifraViewPage` virou negrito +
  itálico. "Tom" voltou pra mesma linha dos botões +/- (rodada anterior
  tinha posto numa linha própria acima) — só que agora tudo (rótulo +
  botões) alinhado à direita via `MainAxisAlignment.end`, no lugar do
  `Spacer()` antigo que separava rótulo (esquerda) dos botões (direita).

**Ordem de Culto — janela de visualização antecipada unificada em 2h pra
Louvor/admin/dono; botão "Ver Prévia" na tela de espera de Louvor/admin
(29/08/2026, pedidos do usuário):** antes só Louvor/admin (`canViewPraiseOrder`
inclui `isAdmin`, então os dois sempre caíram na mesma visão) tinham acesso
antecipado à ordem completa, liberado 1h antes do horário — o dono (owner) só
via a tela de contagem regressiva (`ServiceOrderPrecheckPage`), sem o
conteúdo em si, até tocar "Iniciar Culto" exatamente na hora marcada.

- Nova `isServiceOrderViewableEarly(dateTime)`
  (`lib/service_order/service_order_countdown.dart`) — janela única de 2h
  (era 1h só pra Louvor/admin), compartilhada entre
  `ServiceOrderPraiseViewPage` (Louvor/admin) e `ServiceOrderPrecheckPage`
  (dono).
- `ServiceOrderPrecheckPage` (dono) ganhou um terceiro estado, entre a
  "espera" (`_buildWaiting`, mais de 2h antes — layout de sempre, já tinha
  "Ver Prévia") e o "finalizado" (`_buildFinalized`): dentro da janela de 2h
  e ainda não finalizado, `_buildViewable` mostra a ordem completa
  (`ServiceOrderReadOnlyBody`, reaproveitada de
  `service_order_praise_view_page.dart`, `showPraiseDetails: false` — sem
  tom, mesmo recorte que o dirigente já via no modo apresentação) dentro de
  um `Container` navy (a lista foi desenhada pro fundo escuro; o resto da
  página continua no tema claro/escuro padrão), com os botões
  "Iniciar/Continuar Culto"/"Ver Prévia"/"Voltar" fixos embaixo — **a
  permissão de marcar momento como concluído continua exclusiva de depois de
  tocar "Iniciar Culto"** (pedido explícito do usuário: "o dono da ordem só
  poderá marcar os momentos como concluído após iniciar o culto"), essa
  visão antecipada é só leitura, igual à de Louvor/admin. A página passou a
  observar `serviceOrderStreamProvider` (antes usava só o `order` estático
  recebido por parâmetro) pra refletir progresso em tempo real ao reabrir um
  culto já iniciado ("Continuar Culto") — `widget.order` virou só o valor
  inicial (`orderAsync.valueOrNull ?? widget.order`, sem tela de
  carregamento própria).
- `ServiceOrderPraiseViewPage._NotYetAvailable` (tela de espera de
  Louvor/admin antes da janela) ganhou o mesmo botão "Ver Prévia" que o dono
  já tinha em `ServiceOrderPrecheckPage` — pedido explícito do usuário ("na
  tela de espera coloque o botão de prévia para Louvor, admin e dono").
  Texto do aviso atualizado de "1 hora" pra "2 horas".

**Ordem de Culto — admin recupera Editar/Excluir de qualquer ordem; "manipular
durante o culto" continua exclusivo do dono (29/08/2026, pedido do
usuário):** revisão da regra "Nem mesmo admin poderá fazer estas ações" da
15ª rodada (28/08/2026) — o usuário pediu pra afrouxar só a parte de
edição/exclusão, mantendo Iniciar Culto/marcar momento como concluído
travado ao dono. Perguntado explicitamente (`AskUserQuestion`) se Excluir
também deveria acompanhar Editar — confirmado que sim, os dois juntos.

- `SIBValApp2/firestore.rules` (`serviceOrders`): `update` agora aceita
  `isAdmin()` desde que o diff não toque nenhum dos 4 campos de "manipular
  durante o culto" (`startedAt`/`completedMomentKeys`/`isFinalized`/
  `finalizedAt` — os mesmos que só `markStarted`/`updateProgress`/`finalize`
  escrevem, nunca uma edição normal via `toFieldsMap()`) — cobre tanto uma
  edição normal quanto a transferência de propriedade (`ownerUid`/
  `ownerName`), que deixou de precisar de uma exceção `hasOnly` própria.
  `delete` ganhou `|| isAdmin()` solto, sem restrição de campo (exclusão não
  tem "diff" pra restringir). **Só editei o código-fonte das regras — não fiz
  `firebase deploy`**, mesma cautela de sempre.
- `lib/service_order/service_order_list_page.dart` (`_showActions`):
  Editar/Excluir passaram de `if (isOwner)` pra `if (isOwner || isAdmin)` —
  "Alterar proprietário" continua exclusivo do admin, inalterado. Texto de
  confirmação de `_TransferOwnerSheet` atualizado (não menciona mais
  editar/excluir como algo que só o novo dono ganha, já que o admin edita
  direto agora).
- `lib/data/service_order_repository.dart`: doc comment de `transferOwner`
  atualizado — não é mais a única via de o admin editar uma ordem alheia,
  só a via de passar quem pode efetivamente conduzir o culto ao vivo.
- Nenhuma mudança em `ServiceOrderFormPage` (preserva `editing?.ownerUid`/
  `.ownerName` ao salvar, já era assim desde a 12ª rodada — admin editando a
  ordem de outro dono não rouba a propriedade) nem em `openServiceOrder`
  (roteamento pro modo apresentação continua só pelo dono de verdade).

**Ordem de Culto — 1 toque abre todos os textos bíblicos do mesmo momento de
uma vez (29/08/2026, pedido do usuário):** antes só a "Divisa" do Momento
Missionário (`ServiceOrderMissionMomentPage`, sessão de 28/08/2026) fazia
isso — "Leitura bíblica" e momento adicional com texto bíblico (ex.: "Ceia do
Senhor") ainda abriam uma referência por vez, uma sub-ação/linha própria por
texto. Momento Missionário ficou de fora desta mudança por já ter a própria
regra. "Texto bíblico" da Dedicação dos dízimos e ofertas é sempre um único
campo (`ServiceOrder.tithesBibleReading`, não uma lista) — não tinha "mais de
um texto" pra consolidar, só precisou trocar a chamada pro novo formato.

- `ServiceOrderBibleTextPage` (`lib/service_order/service_order_bible_text_page.dart`)
  passou a receber `references` (lista, era `reference` singular) — com 1 só,
  mantém o layout de sempre (título = a referência, zoom, versículos); com
  mais de uma, empilha uma seção por texto (`_BibleTextSection`, extraído do
  `build()` antigo), cada uma com seu próprio cabeçalho/crédito (podem vir de
  fontes diferentes — BLIVRE cacheada vs. ainda não), separadas por
  `Divider`. Zoom continua único, compartilhado por todas as seções.
- `ServiceOrderLivePage._subActionsFor`: "Leitura bíblica" e momento
  adicional com `extraBibleReferences` passaram de N sub-ações (uma por
  referência, chave `bible$j`) pra 1 só (chave `bible`, sem índice) que abre
  todos os textos filled de uma vez — como `subs.length` nunca passa de 1
  pra esses dois tipos agora, o momento vira um `_MomentCard` de toque único
  em vez de `_MomentGroupCard` (que ainda existe, só que agora só pra
  "Dedicação dos dízimos e ofertas", que tem duas subcategorias de natureza
  diferente — texto bíblico e hino — que não fazem sentido combinadas numa
  tela só).
- `ServiceOrderReadOnlyBody` (`service_order_praise_view_page.dart`,
  reaproveitada por Louvor/membro comum/dono no early-view): `_leafKeysFor`
  atualizada pra gerar a mesma chave única `'$baseKey:bible'` (tinha que
  bater exatamente com `ServiceOrderLivePage`, senão o progresso aparecia
  sempre pendente nessas visões); `_detailRowsFor` consolidou as N linhas
  cliáveis em 1 só, com o rótulo listando todas as referências ("João
  3:16-18; Salmos 23:1-6") e o toque abrindo todas juntas.
- Nenhuma mudança de `firestore.rules`/Cloud Functions — é só reorganização
  do lado do cliente (chaves de progresso, navegação).

**Ordem de Culto — "Texto bíblico" dos dízimos também vira lista repetível;
botão "+ Texto bíblico" unificado em toda lista de texto bíblico
(29/08/2026, pedidos do usuário):**

- `ServiceOrder.tithesBibleReading` (`BibleReference` único) virou
  `tithesBibleReadings` (`List<BibleReference>`) — mesmo mecanismo de
  `bibleReadings`/`missionMottoReferences`. `ServiceOrder.fromFirestore` cai
  pro campo antigo `tithesBibleReading` (singular) quando o novo
  `tithesBibleReadings` não existe no documento, sem backfill (mesmo padrão
  de sempre — só ordens salvas a partir de agora ganham a lista de verdade,
  as antigas continuam lendo certo via fallback).
- `ServiceOrderFormPage`: `_tithesBibleController` (um só) virou
  `_tithesBibleControllers` (lista) — mesmo padrão de
  `_bibleReadingControllers`/`_missionMottoControllers` (sempre 1 controller
  no mínimo, `_addTithesBible`/`_removeTithesBible` novos, validação via
  `.any(isFilled)` em vez de checar 1 campo só).
- Mesma regra de "carregar todos de uma vez" da rodada anterior (que já
  cobria "Leitura bíblica" e momento adicional) — `ServiceOrderLivePage`
  (Texto bíblico dos dízimos vira 1 sub-ação só, `'$baseKey:tithesBible'`,
  abrindo todas as referências junto) e `ServiceOrderReadOnlyBody`
  (`_leafKeysFor`/`_detailRowsFor`, mesmo ajuste). "Hino Congregacional"
  continua como sub-ação própria e separada — não é texto bíblico, fora do
  pedido.
- Botão de adicionar renomeado pra **"+ Texto bíblico"** em toda lista
  repetível de texto bíblico do app — "Leitura bíblica" (era "Adicionar
  leitura"), "Divisa" do Momento Missionário e o diálogo de momento
  adicional com `ExtraMomentFieldKind.bibleReference` (as duas eram
  "Adicionar texto"), e "Texto bíblico" dos dízimos (novo, mesmo rótulo
  desde o início). Só o texto do botão mudou — nenhuma mudança de
  comportamento nos outros três.

**Ordem de Culto/Cifras — dono com papel Louvor abre a cifra no momento de
Louvor; rótulos de seção na cifra usam chaves, não colchetes (29/08/2026,
mesma sessão, pedidos do usuário):**

- `ServiceOrderLivePage._subActionsFor` (`lib/service_order/service_order_live_page.dart`)
  ganhou um caso novo pra qualquer momento com `item.type != null`: quando
  quem está no modo apresentação (sempre o dono, por construção de
  `openServiceOrder`) também tem `canViewPraiseOrder` (papel Louvor ou
  admin) e há música(s) escalada(s) pro slot daquele momento
  (`praiseSlotLabelFor`/`_repertoire`), o toque abre `CifraViewPage` em vez
  de só marcar concluído — mesmo destino que `ServiceOrderPraiseViewPage`
  já dava a quem só tem o papel Louvor sem ser dono. Com mais de uma música
  no mesmo slot, cada uma vira uma sub-ação própria (mesmo mecanismo de
  `_MomentGroupCard`/`_SubActionRow` já usado por "Dedicação dos dízimos e
  ofertas"); sem repertório/música ou sem o papel, cai no comportamento de
  sempre (só marca concluído).
- **Bug real corrigido nas cifras**: rótulos de seção (ex. "[Intro]",
  "[Refrão]") escritos entre colchetes tinham dois problemas — (1) no
  formato antigo inline (`[Acorde]palavra`), `chordBracketPattern` tratava
  QUALQUER conteúdo entre colchetes como acorde; um rótulo começando com
  letra de nota (ex. "[Coro]") virava "[C#oro]" ao transpor 1 semitom; (2)
  no formato novo "Cifra Club" de duas linhas, a mera presença de um
  colchete em qualquer lugar do conteúdo (`_legacyBracketPattern.hasMatch`)
  reclassificava a cifra INTEIRA como formato antigo, quebrando a
  renderização de duas linhas pra música inteira. Resolvido mudando a
  convenção: rótulos de seção agora usam **chaves**, não colchetes — `{Intro}`,
  `{Refrão}` — que nunca colidem com a sintaxe de acorde nem dos dois
  detectores de formato. Novo `sectionLabelPattern`/`isSectionLabelLine`
  (`lib/util/chord_transpose.dart`); `CifraViewPage._lineSpans` (formato
  antigo) passou a reconhecer colchete (transpõe, dourado) E chave (só
  destaca, itálico/negrito em `context.textSecondary`, sem transpor) no
  mesmo texto; `_lineSpansTwoLine` (formato novo) reconhece uma linha
  inteira entre chaves como rótulo destacado, antes de checar se é linha de
  acorde. Texto de ajuda do import em `cifra_editor_page.dart` atualizado
  pra mencionar a convenção nova. Sem migração de cifras já salvas com
  colchete — mesmo padrão de sempre.

**Ordem de Culto — cores de status no modo apresentação (01/09/2026, pedido
do usuário):** o dirigente relatou dificuldade de identificar num relance o
que já foi concluído e em que momento o culto está — "concluído" e
"pendente" compartilhavam o mesmo fundo quase invisível
(`Colors.white.withValues(alpha: 0.04)`) em `service_order_live_page.dart`,
diferindo só pelo texto riscado/apagado. Novo `_doneGreen`
(`Color(0xFF43A047)`, constante de módulo só deste arquivo — a tela já é
deliberadamente fora da paleta navy/dourado do resto do app, mesma nota já
registrada sobre os emoji de ícone) vira um esquema de 3 cores tipo
semáforo: pendente continua neutro (cinza/branco translúcido), atual
continua dourado (fundo `0xFF1E3A5F` + borda dourada, inalterado), concluído
ganha fundo verde-translúcido (`_doneGreen.withValues(alpha: 0.12)`) + borda
verde fraca + badge/ícone/texto verdes — em vez do cinza-apagado antigo.
Aplicado em `_MomentCard`, `_MomentGroupCard`, `_SubActionRow` e
`_StatusBadge` (badge de check virou verde com ícone branco, era dourado com
ícone navy). Só a tela do dirigente (`ServiceOrderLivePage`) foi tocada —
`ServiceOrderReadOnlyBody` (visão do Louvor/membro/dono-antes-de-iniciar) não
mostra progresso "atual" da mesma forma e ficou fora do pedido.

**Ordem de Culto — título dos momentos numa cor só + dourado piscando no
atual (01/09/2026, mesma sessão, pedidos do usuário):**

- **Título uniforme.** `_MomentCard.isLink` deixou de colorir o título
  (`item.label`) de dourado — "Leitura bíblica"/"Louvor" (quando linkados a
  bíblia/cifra) ficavam destoando dos demais momentos, cujo título é sempre
  branco. O dourado migrou pro texto de baixo (`summary`/`extraSummary` —
  referência bíblica ou nome da música, o conteúdo de fato clicável), que
  antes era sempre cinza (`Colors.white60`) independente de ser link ou não.
  `_MomentGroupCard`/`_SubActionRow` não precisaram de mudança — o título do
  grupo já era branco, e o rótulo de cada sub-ação (que já é a
  referência/nome, ex. "Hino Congregacional: CC 45") já era dourado desde a
  9ª rodada.
- **Momento atual pisca em dourado** — "vamos testar, se fica bom" (feature
  experimental, sujeita a reverter se o usuário não gostar no teste real).
  Novo `_PulseValue` (`StatefulWidget` com `AnimationController.repeat
  (reverse: true)`, 900ms, `Curves.easeInOut`) — só o card com `isCurrent`
  roda a animação; os demais recebem um valor `t` fixo em `1.0`, sem
  `AnimationController` ocioso na lista inteira. `_MomentCard`/
  `_MomentGroupCard` calculam `goldPulse = goldAccent.withValues(alpha: 0.5 +
  0.5*t)` e usam essa cor pulsante na borda, no ícone do momento e no
  `_StatusBadge` (novo parâmetro `currentColor`, cai no dourado sólido de
  sempre quando não vem de um `_PulseValue`). O fundo navy do card atual
  (`0xFF1E3A5F`) continua estático — só os elementos dourados piscam, não o
  card inteiro.

**Ordem de Culto — desmarcar só pela bolinha de check; arquivamento mensal
com cor diferente (01/09/2026, mesma sessão, pedidos do usuário):**

- **Desmarcar exclusivo da bolinha de check.** Antes, tocar em qualquer
  lugar de um momento já concluído (`_MomentCard`/`_MomentGroupCard`/
  `_SubActionRow`, `service_order_live_page.dart`) desmarcava — o que
  impedia reabrir um link (texto bíblico, cifra, hino) depois de já ter sido
  marcado como concluído, já que o toque desfazia o progresso em vez de
  navegar de novo. Pedido do usuário: só a bolinha dourada de check
  (`_StatusBadge`, e o ícone de check de cada sub-ação em
  `_SubActionRow`) desmarca; o corpo do card/linha, quando já concluído,
  reabre o link (se houver) sem mexer no estado. `_onTapLeaf`
  (`_ServiceOrderLivePageState`) mudou de "toca de novo = desmarca" pra
  "toca de novo = reabre, sem alterar `_done`"; novo `_onToggleDone`
  (badge/ícone) é o único caminho pra `_setDone(key, false)`. Novo widget
  compartilhado `_StatusBadgeTapTarget` (`Material`+`InkWell` com
  `CircleBorder`) isola o toque da bolinha do toque do card ao redor —
  tocar na bolinha nunca também dispara o `onTap` do card (gesture arena
  padrão do Flutter: o recognizer mais interno vence). No card de grupo
  (`_MomentGroupCard`, ex. "Dedicação dos dízimos e ofertas"), a bolinha do
  cabeçalho só fica tocável quando o grupo inteiro já está concluído
  (`onToggleAllDone`, `null` antes disso — cabeçalho continua não-tocável
  como sempre foi) e desmarca todas as sub-ações de uma vez, permitindo
  refazer o grupo inteiro. `_setDone` virou um atalho de `_setDoneMany`
  (novo, aceita `Iterable<String>` — usado pra desmarcar várias chaves
  junto no toggle do grupo).
- **Arquivamento mensal com cor diferente.** `ServiceOrderListPage` já
  agrupava ordens de meses anteriores num `_MonthGroup` recolhido (28/08,
  ver entrada de "compactadas por mês") — só o mês corrente ficava solto no
  topo, mas ambos usavam a mesma cor de `Card`. Novo `_archivedCardColor`
  (`service_order_list_page.dart`) — mesmo mecanismo de `_momentBox`
  (`Color.alphaBlend` sobre a cor real do tema, não uma cor fixa), escurece
  o `cardColor` do tema (alpha 0.22 no escuro, 0.05 no claro — mais forte no
  escuro porque `cardColor` já é um azul médio, `navyBlueLight`, precisa de
  mais contraste do que o branco do tema claro). Aplicado tanto no `Card` de
  cada `_OrderTile` dentro de um mês arquivado (`isArchived: true`, novo
  parâmetro) quanto no `Card` do próprio `_MonthGroup` — o mês corrente
  continua com a cor padrão do tema.

**Ordem de Culto — ícones dos momentos num padrão de cor só (01/09/2026,
mesma sessão, pedido do usuário, revisado na mesma rodada):** Prelúdio/
Oração/Boas-vindas/Benção Apostólica/Ceia do Senhor tinham virado emoji
(28/08/2026, "Material Icons não tem [gesto] de verdade") — mas emoji são
glifos coloridos fixos que ignoram `TextStyle.color`, então esses ficavam
sempre com a cor própria do emoji enquanto os demais momentos seguiam o
padrão da lista (branco/cinza pendente, dourado piscando atual, verde
concluído) — destoando visivelmente. **Primeira tentativa** (revertida no
mesmo pedido): trocar os 5 emoji por `Icon(_iconFor(type))` monocromático
normal — o usuário corrigiu: queria manter os emoji originais, só com a
mesma cor dos demais, não trocar o glifo. **Versão final**: `_momentIcon`
(`service_order_live_page.dart`) e o equivalente duplicado em
`_PraiseMomentCard`/`service_order_praise_view_page.dart` (visão do Louvor)
mantiveram `_emojiFor`, mas passaram a envolver o `Text(emoji)` num
`ColorFiltered(colorFilter: ColorFilter.mode(color, BlendMode.srcIn))` —
usa o alfa do glifo como máscara e pinta tudo com a cor pedida (a mesma que
um `Icon` normal receberia: branco/cinza pendente, dourado piscando atual,
verde concluído na tela do dirigente; branco fixo na visão do Louvor), em
vez de deixar a cor própria do emoji aparecer. `_iconFor`'s mapeamento de
Benção Apostólica voltou pro `Icons.emoji_events` original (irrelevante na
prática — só serve de fallback pra tipos sem emoji, nunca chega a ser
desenhado pros 4 tipos que têm emoji). `ServiceOrderMemberViewPage`/
`ServiceOrderPrecheckPage` (early-view) reaproveitam
`ServiceOrderReadOnlyBody`/`_PraiseMomentCard` — ganharam o ajuste de graça,
sem tocar nesses arquivos.

**Ordem de Culto — selo "ao vivo" nas telas de apresentação, não no
repositório (01/09/2026, mesma sessão, pedido do usuário, revisado no mesmo
pedido):** primeira versão pôs um indicador no topo de `ServiceOrderListPage`
(a lista) — o usuário corrigiu: queria o selo na tela da ordem de culto em
si (quando iniciada), não no repositório de ordens; e pediu pra acrescentar
"traços dos lados" ao ponto piscando. **Versão final**: novo
`ServiceOrderLiveBadge` (`service_order_countdown.dart`, público — mesmo
arquivo de helpers já compartilhado entre as 3 telas de apresentação) usa
`Icons.sensors` (ponto + arcos de sinal nos dois lados) em vez de um
`Icons.circle` liso, piscando via `AnimationController.repeat(reverse:
true)` em vermelho — fora da paleta navy/dourado de propósito, mesmo
precedente da faixa "ATENÇÃO". Aplicado no canto esquerdo do cabeçalho de
`ServiceOrderLivePage` (dirigente, sempre visível — a tela só existe depois
de iniciado), `ServiceOrderPraiseViewPage` (Louvor, condicionado a
`order.isStarted && !order.isFinalized`) e `ServiceOrderMemberViewPage`
(membro/convidado, `_buildStarted` já garante `isStarted`, só falta checar
`!isFinalized`) — as três telas que renderizam o conteúdo de uma ordem
específica. `ServiceOrderListPage` (`_LiveIndicator`, a versão anterior)
voltou ao estado original, sem nenhum indicador — não varre mais a lista
inteira procurando um culto ao vivo.

**Ministério de Louvor — repertório com classificação/solistas/mês
referência, filtro no repertório semanal, botão "Sugestões" por tema,
repertório semanal em pastas por mês, e Termo de Compromisso com a Igreja
no 1º acesso (02/09/2026, pedidos do usuário):**

- **`PraiseSong` (repertório mensal) ganhou 3 campos novos**
  (`lib/models/praise_repertoire.dart`): `classification`
  (`PraiseSongClassification` — Chamada a adoração/Celebração/Adoração/
  Avulso, mesmo padrão de enum-com-`label` de `PreludeStyle`/`MissionMoment`
  em `service_order.dart`), `soloists` (`List<String>`, lista dinâmica no
  cadastro, mesmo padrão de `_companionControllers` em
  `introduction_page.dart`) e `referenceMonthKey` (`String?`, formato
  `yyyy-MM`, dois dropdowns Mês/Ano no cadastro — sem seletor de dia, só
  interessa o mês). `PraiseRepertoireRepository.createSong`/`updateSong`
  passaram a receber o `PraiseSong` inteiro (`toMap()`) em vez de
  `name`/`artist` soltos.
- **Filtro no Repertório Semanal**: `_WeeklyRepertoireTab`
  (`praise_ministry_page.dart`) virou `ConsumerStatefulWidget` — dropdowns
  Mês/Ano ("Todos" por padrão) filtram em memória a lista de semanas já
  cadastradas (`weeklyRepertoiresProvider`), pelo mês/ano do domingo de cada
  uma.
- **Botão "Sugestões"** (`WeeklyRepertoireFormPage`, ao lado de "Adicionar
  música") abre `PraiseSuggestionsPage` (nova) — campo "Tema" + busca no
  catálogo inteiro (`praiseSongsProvider`). **Decisão registrada aqui por
  não ter sido especificada pelo pedido**: não existe (nem foi pedido) um
  campo de tags/tema por música, então o casamento "tema → músicas" é uma
  busca de texto (`_normalizeText`, acento/case-insensível) contra
  nome+cantor/banda+rótulo da classificação — cobre bem o caso comum
  (digitar "adoração" e achar as classificadas como tal), mas não é busca
  semântica de verdade. Cada resultado mostra nome/cantor/classificação/
  solistas/mês referência e um botão "+" que adiciona à semana sendo
  montada sem fechar a tela (`onAdd` callback,
  `WeeklyRepertoireFormPage._addAssignmentFromSong`) — permite adicionar
  várias antes de voltar.
- **Repertório semanal em pastas por mês referência**: o seletor de música
  dentro de cada linha de `WeeklyRepertoireFormPage`
  (`_AssignmentRow`) deixou de ser um dropdown plano — agora abre
  `_SongFolderPickerSheet` (bottom sheet, `DraggableScrollableSheet`), com
  uma `ExpansionTile` por mês referência (`praiseReferenceMonthLabel`, mais
  recente primeiro; "Sem mês definido" sempre por último) e um campo de
  busca no topo.
- **Termo de Compromisso com a Igreja** (sem equivalente nativo — texto
  fornecido pelo usuário em `C:\TEMP\COMPROMISSO COM A IGREJA.docx`,
  transcrito na íntegra, 33 itens numerados em 8 seções, em
  `lib/praise/praise_commitment_page.dart`). Todo integrante do Ministério
  de Louvor (`canViewPraiseOrder`/`canEditCifrasProvider`, mesmo critério de
  acesso ao ícone) precisa marcar os 33 checkboxes e tocar "Concordo e
  Aceito" antes do primeiro acesso a `PraiseMinistryPage`. Aceite
  persistido em `praiseCommitments/{uid}` (`PraiseCommitmentRepository`,
  `lib/data/praise_commitment_repository.dart` — coleção própria, separada
  de `users/{uid}`, existência do doc = já aceitou); próximos acessos pulam
  direto pro Ministério. Ponto de entrada único
  (`openPraiseMinistry`, `lib/praise/praise_commitment_page.dart`) substitui
  o push direto a `PraiseMinistryPage` no tile "Ministério de Louvor"
  (`lib/home/home_quick_tiles.dart`) — decide entre mostrar o termo ou ir
  direto pro Ministério consultando o repositório antes de navegar.
  `SIBValApp2/firestore.rules` ganhou `match /praiseCommitments/{uid}`
  (leitura/escrita só do próprio uid) — **só editei o código-fonte da
  regra, não fiz `firebase deploy`**, mesma cautela de sempre; até o
  deploy, gravar o aceite em produção falha com permission-denied.

**Ministério de Louvor — letra da música, sem busca automática (02/09/2026,
pedido do usuário, revisado na mesma sessão):** pedido original foi buscar a
letra na internet automaticamente ao cadastrar a música. Pesquisado antes de
implementar: a API pública do Vagalume (única fonte gratuita de letra
completa em português conhecida) está **descontinuada** — `api.vagalume.com.br`
responde 503 em qualquer rota, e o site principal não tem mais link pra
"Desenvolvedores"/API nenhum. Alternativas (Genius/Musixmatch) só liberam
metadados ou um trecho da letra no plano gratuito — letra completa exige
plano pago. Como raspar (scraping) sites de letra é violação de termos de
uso na maioria dos casos e expõe a risco de infração de direito autoral
(diferente do texto bíblico BLIVRE, que é CC — letra de música evangélica
contemporânea normalmente não é), a busca automática de verdade foi
descartada. Perguntado ao usuário (`AskUserQuestion`) entre três caminhos;
escolhido: **botão que abre uma busca no navegador**, sem API nem scraping.

- `PraiseSong` (`lib/models/praise_repertoire.dart`) ganhou `lyrics`
  (`String`, vazio por padrão) + getter `hasLyrics`.
  `PraiseRepertoireRepository.createSong`/`updateSong` já recebiam o
  `PraiseSong` inteiro (rodada anterior), não precisou de mudança de
  assinatura.
- No cadastro/edição de música (`_showSongDialog`,
  `praise_ministry_page.dart`): botão "Buscar letra" abre
  `https://www.google.com/search?q=letra+{nome}+{cantor}` no navegador
  externo (`url_launcher`, já dependência do projeto) — o usuário copia a
  letra de onde encontrar e cola no campo multi-linha logo abaixo
  (`lyricsController`), que salva em `PraiseSong.lyrics`.
- Tocar numa música do Repertório Mensal (`_MonthlyRepertoireTab`) abre
  `PraiseLyricsPage` (nova, `lib/praise/praise_lyrics_page.dart`) — tela
  cheia com zoom de fonte (`praise_lyrics_font_size`, preferência própria,
  mesmo padrão de `CifraViewPage`/`service_order_bible_text_page.dart`) —
  só quando `song.hasLyrics`; sem letra salva, a linha não é tocável (título
  fica branco/cor normal, mesmo padrão de "hasCifra" em
  `EnsaioDetailPage._AssignmentTile` — título vira dourado só quando há algo
  pra abrir).
- **Escopo desta rodada, registrado por não ter sido pedido**: só o
  Repertório Mensal (catálogo mestre) ganhou esse fluxo. Onde a música
  aparece dentro de um repertório semanal/culto ao vivo (`EnsaioDetailPage`,
  `ServiceOrderLivePage`) continua abrindo a **cifra** ao tocar (se houver),
  não a letra — não foi pedido decidir prioridade entre as duas ali.

**Ministério de Louvor — solista sugerido pelo papel Louvor, filtro
corrigido pro Repertório Mensal, releitura do Termo, pastas também no
Repertório Semanal (02/09/2026, mesma sessão, pedidos do usuário):**

- **Correção de numeração do Termo de Compromisso** (bug relatado pelo
  usuário: rolar até o fim e voltar fazia os números aumentarem) — causa
  raiz era um `Builder` por item com um contador mutável (`var counter = 0`)
  compartilhado entre os 33 closures; como `ListView(children: [...])`
  descarta/recria os `Element`s dos itens fora do viewport durante o
  scroll, cada `Builder` recriado incrementava o mesmo contador de novo.
  Corrigido pré-computando `_commitmentRows` (lista com o índice 1-33 já
  fixo como dado, calculada uma única vez) — sem `Builder`, sem contador
  mutável (`praise_commitment_page.dart`).
- **"Adicionar solista" busca entre quem tem o papel Louvor.** Não dá pra
  consultar `users` direto pra isso — `firestore.rules` só libera `list`
  admin-only, e quem cadastra música pode ser só Louvor (não-admin). Solução:
  `settings/louvorMembers.names` (mapa uid→nome, `PraiseLouvorMembersRepository`,
  `lib/data/praise_repertoire_repository.dart`) — espelho mantido por
  `manage_users_page.dart` (`_RoleChip.onSelected`, só quando `role ==
  UserRole.louvor`) toda vez que o chip é marcado/desmarcado; não precisou de
  regra nova (`settings/{docId}` já libera leitura pra qualquer autenticado,
  escrita só admin — e quem toggla o chip já é admin). Campo de solista virou
  `_SoloistField` (novo, embutido-na-árvore, mesmo padrão de
  `_ParticipationField`/`service_order_form_page.dart`, escolhido de
  propósito no lugar de `Autocomplete`). **Sem backfill**: quem já tinha o
  papel Louvor antes desta mudança só entra no espelho na próxima vez que o
  chip for marcado/desmarcado de novo.
- **Filtro corrigido de lugar** — a rodada anterior tinha posto errado no
  Repertório Semanal; o usuário corrigiu: é no **Repertório Mensal**
  (`_MonthlyRepertoireTab`, agora `ConsumerStatefulWidget`), com três
  critérios (classificação, solista, texto livre que busca em nome **e**
  letra da música — `_normalizePraiseText`, acento/case-insensível). Filtro
  de mês/ano que eu tinha posto no Repertório Semanal foi revertido (`
  _WeeklyRepertoireTab` voltou a `ConsumerWidget` simples).
- **Termo de Compromisso relível depois do aceite** — `PraiseCommitmentTermPage`
  ganhou `readOnly` (checkboxes sempre marcados/travados, sem botão
  "Concordo e Aceito") — acessível via novo item "Termo de Compromisso" no
  menu ☰ de `PraiseMinistryPage` (`_PraiseMenuButton`), ao lado de "Cifras".
- **Repertório Semanal também em pastas por mês referência** —
  `EnsaioDetailPage` (`ensaios_list_page.dart`, visão de uma semana
  específica) agrupa as músicas escaladas em `ExpansionTile`s por mês
  referência (mesmo critério/ordem do picker de `WeeklyRepertoireFormPage`),
  casando `PraiseAssignment.songId` contra `praiseSongsProvider` pra achar o
  mês (o assignment em si não denormaliza esse campo). Só uma pasta (ou
  nenhum mês definido) cai de volta pra lista simples, sem
  `ExpansionTile` supérfluo.

**Erro "line 6281 pos 12" ao salvar música — causa raiz encontrada e
corrigida (03/09/2026).** A investigação por revisão de código não achou
nada; só foi possível achar a causa **dirigindo o celular do usuário direto
por `adb` neste ambiente** (`adb shell input tap`/`input text` +
`adb exec-out screencap`, sem precisar do usuário reproduzir manualmente) —
reproduzi o fluxo "Adicionar música" → "Salvar" eu mesmo e capturei a tela
vermelha de erro do Flutter na hora exata. Erro completo:
`'package:flutter/src/widgets/framework.dart': Failed assertion: line 6281
pos 12: '_dependents.isEmpty': is not true.` — uma asserção interna do
framework (`InheritedElement.unmount()`), não um erro do Firestore como eu
tinha suposto.

**Causa raiz**: `_showSongDialog` (`praise_ministry_page.dart`) chamava
`.dispose()` nos `soloistControllers`/`lyricsController` **antes** de
`Navigator.of(dialogContext).pop()` terminar de remover o diálogo da árvore
— `pop()` só inicia a animação de saída, o subtree continua montado durante
a transição. Isso sempre foi um padrão arriscado nesta base (mesmo
`nameController`/`artistController` nunca foram descartados, de propósito —
convenção existente que eu quebrei ao adicionar os `.dispose()` novos na
sessão anterior), mas só virou um crash de verdade porque o campo de
solista virou `_SoloistField` (`ConsumerStatefulWidget` com `FocusNode`
próprio + `ref.watch(louvorMemberNamesProvider)`, um provider
`.autoDispose`) — a combinação de widget com estado próprio + dependência
Riverpod + controller descartado enquanto ainda montado é o que dispara a
asserção do Element tree.

**Correção**: removidos os três pontos onde eu descartava esses
controllers manualmente — botão "Cancelar", botão "Salvar", e o "X" de
remover uma linha de solista (esse último tinha o mesmo problema: o
`.dispose()` rodava dentro do próprio callback do `setState`, antes do
Flutter desmontar o widget removido). Os controllers agora só saem de
escopo e são coletados pelo GC, mesmo padrão já usado em
`nameController`/`artistController` neste diálogo. Confirmado funcionando
de ponta a ponta ao vivo no celular (reproduzi "Adicionar música" de novo
depois da correção, sem crash, música salva de verdade — conferido pela
busca; depois excluída, era só teste).

**Nota de processo**: um `debugPrint` temporário foi adicionado ao
`catch` do salvar pra tentar capturar o erro via `adb logcat`, mas nunca
disparou — o app crasha com um `FlutterError` de asserção durante o
`build`/dispose da árvore, que nunca chega a entrar no `try/catch` do
Firestore. Removido depois de achar a causa real via screenshot.

**Repertório semanal — bug real de "mesma semana" em vez de "mesma data"
(03/09/2026, pedido do usuário):** relatado com um caso concreto — Ordem de
Culto cadastrada pra terça 01/09 estava puxando as músicas do repertório de
domingo 30/08. Causa raiz: `PraiseRepertoireRepository.weekKeyFor`
(`sundayOf`, removido nesta correção) sempre "arredondava" qualquer data pro
domingo da semana que a contém — então terça 01/09 e domingo 30/08 caíam na
mesma chave (`weeklyRepertoires/2026-08-30`), mesmo sendo dias diferentes.
Corrigido: `weekKeyFor` agora usa a data exata (`yyyy-MM-dd` do dia
recebido), sem "arredondar" pra domingo — música só é atribuída a um
momento "Louvor" quando existe repertório com a **mesma data exata** da
Ordem de Culto; sem repertório pra aquele dia, os momentos "Louvor" ficam
sem música (`ServiceOrderLivePage`/`ServiceOrderPraiseViewPage` já tratavam
`WeeklyRepertoire? == null` antes desta mudança, nenhum ajuste extra
necessário ali). **Sem impacto em repertórios já cadastrados** normalmente
(sempre num domingo, via o padrão de `WeeklyRepertoireFormPage`): pra uma
data que já é domingo, a chave antiga (`sundayOf(domingo) == domingo`) e a
nova (a própria data) são idênticas — só muda o comportamento pra datas que
não são domingo.

**Repertório Mensal também organizado em pastas por mês referência
(03/09/2026, pedido do usuário: "o repositório mensal continua sem
organizar as músicas por mês").** A rodada anterior só tinha aplicado
pastas ao picker de música dentro do cadastro de repertório semanal e à
visão de uma semana específica (`EnsaioDetailPage`) — a própria aba
"Repertório Mensal" (catálogo mestre, `_MonthlyRepertoireTab`) continuava
com lista plana (só filtro). `_buildSongList` (novo método) agrupa as
músicas já filtradas em `ExpansionTile`s por `referenceMonthKey` (mesmo
critério/ordem — mais recente primeiro, "Sem mês definido" por último);
linha de música virou `_SongTile` (extraída, reaproveitada dentro e fora
das pastas). Confirmado funcionando ao vivo no celular do usuário (mesma
técnica de dirigir o adb direto, ver `[[feedback_adb_ui_diagnosis]]`).

**Pastas por mês referência começam fechadas (03/09/2026, pedido do
usuário).** `initiallyExpanded: true` → `false` nas duas `ExpansionTile` de
pasta que ficavam abertas por padrão — `_MonthlyRepertoireTab._buildSongList`
(Repertório Mensal) e `EnsaioDetailPage` (Repertório Semanal, visão de uma
semana). O picker de música dentro do cadastro de repertório semanal
(`_SongFolderPickerSheet`, `weekly_repertoire_form_page.dart`) não foi
tocado — lá a regra já era diferente (`initiallyExpanded: keys.length ==
1`, só a pasta única abre sozinha), contexto de escolher uma música, não de
navegar a lista.

**Quadro de Avisos + Agenda dos ministérios (03/09/2026, pedidos do usuário,
sem equivalente no nativo):**

- **Quadro de Avisos** (`lib/models/notice.dart`, `lib/data/notice_repository.dart`,
  `lib/notices/`) — coleção própria `notices` (não reaproveita mais os posts
  manuais do Mural). Gerenciado por quem tem `canManagePublications` (papel
  Publicações ou admin — reaproveitado, decisão confirmada com o usuário via
  `AskUserQuestion` em vez de criar um papel dedicado), alcançado por um novo
  tile "Quadro de Avisos" no menu Mais (`home_quick_tiles.dart`, id
  `noticeBoard`, só visível a quem gerencia) que abre `NoticeManagementPage`
  (lista + inserir/editar/excluir, `NoticeFormPage`). Os demais usuários só
  veem os avisos pelo painel rotativo "Avisos" na Início
  (`_NoticesCard`/`home_highlights.dart`, que passou de reaproveitar posts
  manuais do Mural pra ler direto de `notices`) — um `PageView` com
  `Timer.periodic` de 5s trocando de aviso sozinho — tocando abre
  `NoticeDetailPage` em tela cheia; não existe uma "ver todos" pra quem não
  gerencia, só a Central de gerenciamento tem lista completa.

  "Buscar o link de oferta na Contribua" (`NoticeFormPage._pickOffer`): como
  `PixEntry` (`contribution_info.dart`) não tem id estável (só posição numa
  lista), o aviso guarda um **retrato** dos 4 campos necessários pra gerar o
  Pix (`offerPixKey`/`offerDescription`/`offerChurchName`/`offerCity`), não
  uma referência viva — editar/excluir a chave na Contribua depois não afeta
  avisos já publicados (decisão registrada no doc comment de `Notice`, não
  confirmada explicitamente com o usuário, mas evita a complexidade de dar
  id estável a `PixEntry` só por causa disso). `NoticeDetailPage` reaproveita
  `PixOfferPage` (`contribute/pix_offer_page.dart`) direto com esses 4
  campos — nenhuma lógica de geração de código Pix duplicada.

- **Agenda dos ministérios** (`lib/models/agenda_entry.dart`,
  `lib/data/agenda_repository.dart`, `lib/agenda/`) — substitui o ícone
  "Agenda" da grade de Início, que era só um `ComingSoonPage` (id `agenda`,
  já existia no catálogo de tiles). Líderes de cada ministério marcam
  compromissos (ensaio, reunião etc.) pro próprio ministério; os demais
  membros do ministério (liderados) só visualizam; admin vê/gerencia tudo.

  **Como o app sabe quem é "líder"** — decisão tomada via `AskUserQuestion`:
  não é um papel novo nem uma tela de seleção — é o cargo de texto livre já
  existente em `MemberMinistry.cargos` (Rol de Membros): um membro com um
  cargo cujo texto normalizado (sem acento/maiúsculas, casamento exato —
  "Vice-líder" não conta) seja "lider", dentro de um vínculo de ministério
  específico, vira líder **daquele** ministério
  (`MemberRepository.isLeaderCargo`). `Ministry.leaderUids` (novo campo,
  `lib/data/ministry_repository.dart`) é o espelho de verdade — mantido
  automaticamente por `MemberRepository.update` (diff entre o
  `member.ministries` antigo e o novo a cada edição da Secretaria, chamando
  `MinistryRepository.addLeader`/`removeLeader`) sempre que o membro já tem
  `linkedUid` (sem backfill pra quem virar líder antes de ter conta,
  mesmo padrão de sempre nesta base). Precisou virar um campo em
  `ministries/{id}` em vez de uma consulta a `members` porque
  `firestore.rules` não libera `list` em `members` pra não-admin/Secretaria
  — a regra de escrita de `agendaEntries`
  (`isMinistryLeader(ministryId)`, nova função) só pode `get()` um documento
  conhecido, não fazer uma query livre.

  **Conflito de horário** — decisão via `AskUserQuestion`: evita conflito
  **entre ministérios diferentes**, mas só quando o [location] (campo livre
  "Local/Área", com sugestão dos locais já usados —
  `_LocationField`, mesmo padrão embutido-na-árvore de `_ParticipationField`)
  bate normalizado; áreas diferentes podem coincidir livremente no mesmo
  horário (pedido explícito do usuário — "dois ou três no mesmo horário por
  utilizarem áreas diferentes da igreja"). `findAgendaConflicts`
  (`agenda_repository.dart`) é um aviso soft (`AlertDialog` "Continuar mesmo
  assim?"), não um bloqueio duro — o líder pode confirmar e salvar mesmo com
  conflito. `AgendaPage` só lista compromissos futuros (`endDateTime` ainda
  não passou), mesma filosofia de "agenda de planejamento" já usada em
  `LeaderScheduleListPage`.

  `SIBValApp2/firestore.rules` ganhou `isMinistryLeader(ministryId)` (função
  nova, dobra admin dentro de si, mesmo padrão de `isCifraEditor`),
  `match /agendaEntries` e `match /notices` — **só editei o código-fonte,
  não fiz `firebase deploy`**, mesma cautela de sempre; até o deploy, criar
  compromisso na Agenda ou aviso no Quadro falha com permission-denied em
  produção.

**Quadro de Avisos + Agenda — correções e reforma (03/09/2026, mesma sessão,
pedidos do usuário):**

- **Bug real "aviso não salva"**: `NoticeFormPage._save()` só tinha
  `try/finally`, sem `catch` — qualquer exceção (a real: `storage.rules`
  nunca ganhou um bloco `match /notices/{imageId}`, então subir a imagem do
  aviso falhava com permission-denied) ficava muda, o spinner só voltava ao
  normal sem nenhum aviso. Corrigido com `catch` mostrando a mensagem de erro
  num `SnackBar`, e um `AlertDialog` "Aviso salvo com sucesso" (mesmo padrão
  já usado em `ReceptionPage`) antes de fechar a tela — pedido explícito do
  usuário. `SIBValApp2/storage.rules` ganhou o bloco `notices/{imageId}`
  (mesma regra de `posts/`, papel Publicações ou admin) — **só código-fonte,
  sem deploy ainda**.
- **Notice ganhou "Requer inscrição" + link** (`requiresRegistration`/
  `registrationLink`, mesmo par de campos e mesmo texto de botão
  "Inscreva-se" já usado em `Event`) — segunda flag, distinta de
  `needsOffering`; os dois viraram `Row`+`Switch` (era `CheckboxListTile` só
  na de oferta), mesmo padrão visual de `EventFormPage`.
- **Seletor de imagem do aviso alinhado ao de Eventos**: `AspectRatio(16/9)`
  em vez de `Container` de altura fixa, ícone 40 (era 32), só o aviso de
  proporção recomendada (tirado o "(opcional)" solto) — pedido explícito do
  usuário ("no mesmo padrão das demais, igual nos posts e eventos").

- **Agenda virou um calendário de verdade** (`SfCalendar`, pacote
  `syncfusion_flutter_calendar` — decisão de licença Community confirmada
  com o usuário via `AskUserQuestion`, dependência nova em `pubspec.yaml`),
  com `SegmentedButton` Dia/Semana/Mês na app bar. Substituiu a lista simples
  ordenada por data da 1ª versão. Cada compromisso vira um `Appointment`
  colorido por ministério (`_colorForMinistry`, hash determinístico sobre
  uma paleta fixa — só pra distinguir visualmente vários ministérios no
  mesmo calendário, majoritariamente útil pro admin). Tocar um compromisso
  abre um bottom sheet de detalhe com Editar/Excluir quando aplicável.
- **Criar compromisso restrito aos próprios ministérios, mesmo pra admin**
  (pedido explícito do usuário: "cada líder só pode marcar horário para seus
  próprios ministérios") — `_creatableMinistryIds` (FAB "Novo Compromisso" +
  dropdown "Ministério" do formulário) deixou de ter o bypass
  `isAdmin ? todos : ledIds` que a 1ª versão tinha — agora é sempre
  `myLedMinistryIdsProvider`, sem exceção pro admin. **Editar/excluir um
  compromisso já existente continua com o bypass de admin** (oversight/
  gerenciamento, não é "criar do zero") — o bottom sheet de detalhe passa
  `{manageableIds, entry.ministryId}` pro formulário de edição, garantindo
  que o dropdown sempre tenha pelo menos o ministério atual mesmo se quem
  edita (admin) não lidera aquele ministério.
- **Local/Área virou catálogo configurável pelo admin** (pedido explícito) —
  novo `AgendaLocation`/`AgendaLocationRepository` (coleção
  `agendaLocations`), `AgendaLocationManagementPage` (CRUD simples, mesmo
  padrão de `ManageMinistriesPage`), alcançada por um ícone de local na app
  bar de `AgendaPage`, só admin. O campo "Local/Área" do formulário deixou
  de ser texto livre com sugestão — virou `DropdownButtonFormField` sobre
  esse catálogo (com fallback defensivo: o valor já salvo num compromisso
  continua aparecendo na lista mesmo se o local foi renomeado/excluído
  depois, senão o dropdown quebra com um valor fora dos `items`).
  `SIBValApp2/firestore.rules` ganhou `match /agendaLocations` (leitura
  autenticada, escrita só admin) — **só código-fonte, sem deploy ainda**.
- **Horário de término pré-preenchido** — selecionar o horário de início
  agora seta o término pro mesmo horário +1h automaticamente
  (`(hour + 1) % 24`), continua editável depois (pedido explícito do
  usuário).
- **Mensagem automática pra todo mundo do ministério + lembretes 24h/12h**
  (sem equivalente no nativo, pedido explícito do usuário) — em
  `SIBValApp2/functions/index.js` (**só código-fonte, sem deploy ainda**):
  `onAgendaEntryCreatedNotify` (`onDocumentCreated agendaEntries/{entryId}`)
  resolve os membros do ministério (`members` com `ministryIds
  array-contains` + `linkedUid`, mesma lógica de
  `MessageRepository._resolveMinistryMemberUids` no cliente, replicada aqui
  porque o gatilho roda no servidor) e manda uma mensagem de verdade pela
  Central de Mensagens (`messages`, dispara push sozinha via
  `onMessageCreated` já existente) — exclui quem criou o compromisso (o
  próprio líder) da lista de destinatários. Nova `sendAgendaEntryReminders`
  (`onSchedule`, a cada 15 min, mesmo padrão de janela/idempotência de
  `sendServiceOrderParticipationReminders`) cobre os dois lembretes
  (`reminder24hSent`/`reminder12hSent`, independentes um do outro).

- **Gerenciar Usuários: papéis compactados atrás de "Permissões"** (pedido
  explícito do usuário: "estamos ficando com muitos papéis... vamos ajustar
  a tela para que fique algo mais compacto, como um link de permissões, e
  dentro dele tenham os papéis para selecionar") — os 9 `_RoleChip`s que
  ficavam sempre visíveis num `Wrap` (deixando cada card de usuário bem
  alto) viraram um `ExpansionTile` "Permissões (N)" fechado por padrão, só
  reorganização visual — nenhuma mudança de papel/regra.

- **Papéis configuráveis pelo admin (criar/excluir papel, definir direitos de
  acesso) — avaliado, não implementado.** Hoje todo papel é hardcoded em dois
  lugares que precisam ficar sincronizados manualmente: `UserRole` (Dart,
  `lib/models/app_user.dart`, uma constante por papel) e uma função própria
  por papel em `firestore.rules` (`isPublicacoes()`, `isDirigentes()` etc.),
  além de cada tela conferir uma permissão específica
  (`profile.canManagePublications`, ...) — não existe um sistema genérico de
  "capacidades" que um papel dinâmico pudesse carregar. Tornar isso
  configurável de verdade exigiria reescrever esse modelo inteiro pra
  algo como `hasCapability('manage_notices')` lido de um documento de
  permissões por papel, tanto no Dart quanto (mais arriscado) em
  `firestore.rules` — dezenas de telas e todo `match` do banco tocados,
  risco real de destravar acesso errado em produção se algo sair torto. Não
  implementado nesta rodada; se o usuário quiser seguir com isso, vale um
  pedido à parte, tratado como uma migração própria, não um ajuste dentro de
  outra tarefa.

**Pendente de deploy (mesma sessão, aval do usuário cobre só o pedido
anterior de `firestore:rules` — as mudanças desta rodada ainda não foram
publicadas):** `firestore:rules` (bloco `agendaLocations` novo),
`storage:rules` (bloco `notices/` novo — sem ele, subir imagem de aviso
continua falhando em produção) e `functions` (`onAgendaEntryCreatedNotify`,
`sendAgendaEntryReminders` novas). Precisa de um pedido explícito separado
pra cada um, mesma cautela de sempre.

**Agenda dos ministérios — layout inspirado no Outlook mobile (03/09/2026,
pedido do usuário, com prints de referência em `C:\temp`):** troca do
`SegmentedButton` Dia/Semana/Mês por um menu de visualização (ícone no lugar
do antigo segmented control) com quatro opções — Agenda/Dia/3 Dias/Mês
(`_AgendaViewMode`, `agenda_page.dart`) — e uma faixa de semana navegável por
toque (`_WeekStrip`, letras D S T Q Q S S + `PageView` "infinito" por
semana, só na visualização Agenda) acima do `SfCalendar`, mesmo motor de
antes. Mapeamento pro Syncfusion: Agenda → `CalendarView.schedule`; Dia →
`CalendarView.day`; 3 Dias → `CalendarView.day` +
`TimeSlotViewSettings(numberOfDaysInView: 3)`; Mês → `CalendarView.month`
(`showAgenda: false`, pra bater com a grade cheia do print de referência, sem
painel de agenda embaixo). Cabeçalho nativo do `SfCalendar` ocultado
(`headerHeight: 0`) — o título "Agenda" + o menu de visualização já cobrem
esse papel; troca de mês/dia continua por gesto de arrastar.
`ScheduleViewSettings.hideEmptyScheduleWeek: true` evita uma lista infinita
de faixas semanais vazias ("set. 06-12", "set. 13-19"...) sem fim pro futuro.
`syncfusion_localizations` (já uma dependência transitiva, promovida a
direta em `pubspec.yaml`) foi ligada em `main.dart`
(`SfGlobalLocalizations.delegate`) pra textos nativos do Syncfusion saírem em
pt-BR ("Sem eventos" no lugar de "No events").

**Bug real encontrado e corrigido na mesma sessão** — trocar de visualização
atualizava o ícone/rádio do menu, mas o `SfCalendar` continuava preso na
visualização anterior. Causa: `CalendarController` guarda seu próprio `view`
internamente e só usa `SfCalendar.view` (a prop do widget) pra inicializar
**uma única vez**, na primeira montagem (`_controller.view ??= widget.view`,
código-fonte do pacote) — depois disso, mudar `view:` no widget (mesmo com
`key: ValueKey(_mode)` forçando remontagem completa) não tem efeito nenhum,
porque o controller já não está mais nulo. Corrigido setando
`_calendarController.view` explicitamente a cada troca de modo
(`_setMode`), em vez de confiar só na prop `view:` do widget. Confirmado
funcionando ao vivo no celular do usuário nas quatro visualizações (mesma
técnica de dirigir o adb direto, ver `[[feedback_adb_ui_diagnosis]]`).

**Agenda — ajustes da mesma sessão (03/09/2026, pedidos do usuário logo
após o teste da rodada anterior):**

- **"3 Dias" virou "Semana"** — `_AgendaViewMode.threeDays` renomeado pra
  `.week` (ícone `Icons.view_week_outlined`), mapeado pra
  `CalendarView.week` (7 dias, em vez de `CalendarView.day` +
  `numberOfDaysInView: 3`). Como não há mais nenhum modo com contagem de
  dias customizada, `TimeSlotViewSettings.numberOfDaysInView` saiu de cena;
  ganhou no lugar `nonWorkingDays: const []` (Dia/Semana), porque o padrão
  do pacote sombreia sábado/domingo como "não úteis" — o oposto do que faz
  sentido numa agenda de igreja, onde o fim de semana costuma ser o pico de
  atividade.
- **Mês/ano em exibição no cabeçalho** — abaixo do título "Agenda" (mesmo
  card, ainda sem tocar em `ScreenTitle` compartilhado — o título dessa
  tela virou markup próprio só pra caber a segunda linha), um texto tipo
  "Setembro 2026" que acompanha a navegação: atualizado tanto ao tocar um
  dia na faixa de semana quanto por gesto de arrastar entre
  dias/semanas/meses, via `SfCalendar.onViewChanged`
  (`details.visibleDates`, pega a data do meio do intervalo visível pra
  decidir o mês — cobre inclusive a Agenda, cujo "intervalo visível" é o
  que está no topo da lista rolável no momento).
- **Bypass do admin pra CRIAR restaurado** — a 1ª versão desta feature
  (rodada anterior, mesmo dia) tinha excluído admin da criação de
  compromisso de propósito ("cada líder só pode marcar horário pros
  próprios ministérios", pedido explícito de então). Usuário testou como
  admin sem liderar nenhum ministério e não viu o botão de inserir —
  perguntado (`AskUserQuestion`), confirmou que quer o bypass de volta:
  `creatableIds` passou a ser `isAdmin ? todos os ministérios : ledIds`,
  igual a `manageableIds` (que já tinha esse bypass desde a 1ª versão, só
  pra editar/excluir). `AgendaEntryFormPage` não precisou de nenhuma
  mudança — já aceitava genericamente qualquer conjunto de ministérios em
  `manageableMinistryIds`.

**Agenda — ícone do FAB, e bug real de crash ao alternar visualizações
(03/09/2026, mesma sessão, pedidos do usuário):**

- **Ícone do FAB "novo compromisso"** — trocado de `Icons.add` solto pra um
  ícone composto (`_NewAgendaEntryIcon`): calendário
  (`Icons.calendar_today`) com um círculo "+" no canto, mesmo padrão de
  ícone composto já usado em `main_shell.dart` (`SettingsMailIcon` etc.,
  dois `Icons` do Material empilhados via `Stack`, sem asset novo). O
  círculo do "+" usa a própria cor de fundo do FAB
  (`SibValColors.goldAccent`) — efeito de "recorte" em vez de um badge de
  cor diferente por cima.

- **Bug real de crash ao alternar Agenda/Dia/Semana/Mês repetidamente e
  tocar num dia** — reportado pelo usuário, investigado ao vivo no celular
  dele. A investigação inicial (revisão de código) apontou uma causa errada
  — suspeitei do `key: ValueKey(_mode)` que eu tinha posto no `SfCalendar`
  pra forçar remontagem completa a cada troca de modo; removê-lo **não**
  resolveu (confirmado reproduzindo de novo com o mesmo passo a passo antes
  de declarar corrigido — ver `[[feedback_adb_ui_diagnosis]]`). A causa real
  só apareceu rodando com `flutter run` anexado (em vez do fluxo normal
  `flutter build apk --debug` + `adb install`, que só mostra a tela vermelha
  sem stack trace) e lendo o stack trace completo: `_onCalendarViewChanged`
  (callback de `SfCalendar.onViewChanged`, adicionado na rodada anterior pra
  mostrar o mês em exibição no cabeçalho) chamava `setState` **de forma
  síncrona** — e o Syncfusion dispara `onViewChanged` de dentro do próprio
  `initState()` de um widget interno
  (`_CustomCalendarScrollViewState._updateVisibleDates`), ou seja, em plena
  fase de build da árvore. Isso derrubava o app com "setState() or
  markNeedsBuild() called during build", que por sua vez deixava a árvore de
  elementos inconsistente e gerava a cascata de
  `Failed assertion: '_elements.contains(element)': is not true` a cada
  frame seguinte. Corrigido adiando a atualização com
  `WidgetsBinding.instance.addPostFrameCallback` — o `key: ValueKey(_mode)`
  continua removido (redundante desde que `_calendarController.view` já é
  setado explicitamente, ver entrada anterior), mas não foi a causa deste
  crash. Confirmado resolvido repetindo a mesma sequência de teste (inclusive
  um teste de estresse de 3 ciclos completos Mês→Dia→Semana→Agenda com toque
  em dia a cada volta) sem nenhum erro.

**Ordem de Culto — remoção do "+" redundante nos botões "Texto bíblico"
(03/09/2026, pedido do usuário):** os 4 botões "+ Texto bíblico"
(`OutlinedButton.icon` de Leitura bíblica, Divisa do Momento Missionário,
Texto bíblico dos dízimos, e do diálogo de momento adicional com referência
bíblica — todos em `service_order_form_page.dart`) já tinham
`icon: Icon(Icons.add)` — o "+" no texto do label era redundante. Virou só
"Texto bíblico" nos 4 lugares.

**Agenda — régua de horários em formato 24h (03/09/2026, mesma sessão,
pedido do usuário):** `TimeSlotViewSettings.timeFormat` (visualizações
Dia/Semana) trocado do padrão do pacote (`'h a'`, ex. "1 AM") pra `'HH:mm'`
(ex. "01:00") — único lugar do `SfCalendar` que imprimia hora em texto fixo
fora do padrão 24h já usado no resto do app (o bottom sheet de detalhe do
compromisso já usava `DateFormat('HH:mm', 'pt_BR')` desde a 1ª versão). As
visualizações Agenda/Mês e os blocos de compromisso em si não imprimem
horário como texto solto (só a posição vertical/altura do bloco já
comunica isso), então não precisaram de ajuste.

## Como responder "o que falta migrar"

Diffar as pastas `ui/<feature>/` do app nativo contra `lib/<feature>/` do
Flutter, em vez de adivinhar — o app nativo é a fonte da verdade sobre o que
"completo" significa.
