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

## Como responder "o que falta migrar"

Diffar as pastas `ui/<feature>/` do app nativo contra `lib/<feature>/` do
Flutter, em vez de adivinhar — o app nativo é a fonte da verdade sobre o que
"completo" significa.
