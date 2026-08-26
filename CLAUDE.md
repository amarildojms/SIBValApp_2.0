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

## Como responder "o que falta migrar"

Diffar as pastas `ui/<feature>/` do app nativo contra `lib/<feature>/` do
Flutter, em vez de adivinhar — o app nativo é a fonte da verdade sobre o que
"completo" significa.
