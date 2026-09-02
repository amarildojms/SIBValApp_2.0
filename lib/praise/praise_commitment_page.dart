import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post_repository.dart' show currentUidProvider;
import '../data/praise_commitment_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'praise_ministry_page.dart';

class _CommitmentSection {
  const _CommitmentSection({this.title, required this.items});

  final String? title;
  final List<String> items;
}

/// Texto integral de "COMPROMISSO COM A IGREJA" (fornecido pelo usuário em
/// `C:\TEMP\COMPROMISSO COM A IGREJA.docx`, 02/09/2026) — transcrito na
/// íntegra, item por item, preservando a numeração original (1 a 33)
/// sequencial entre as seções. A 1ª seção não tem título no documento
/// original (só as seções 2 a 7 têm cabeçalho numerado); a última
/// ("COMPROMISSO FINAL") também não é numerada.
const _commitmentSections = [
  _CommitmentSection(
    items: [
      'Comprometo-me a participar regularmente da vida congregacional da '
          'Segunda Igreja Batista em Valparaíso, mesmo quando não estiver '
          'escalado para ministrar.',
      'Participarei regularmente da EBD, cultos semanais e atividades da '
          'igreja, exceto quando estiver em escala de serviço ou por um '
          'motivo plausível (≠ evento social). Entendo que é inviável '
          'pertencer ao Ministério de Louvor sendo apenas participante do '
          'culto dominical noturno.',
      'Entendo que o Ministério de Louvor não é um grupo independente, mas '
          'um ministério da igreja, submetido à sua liderança, doutrina e '
          'orientações. Com isso, manterei uma vida e um testemunho '
          'compatíveis com alguém que exerce um ministério público na '
          'igreja.',
    ],
  ),
  _CommitmentSection(
    title: 'ESCALA, ENSAIOS E PONTUALIDADE',
    items: [
      'Ao aceitar uma escala, assumo o compromisso de comparecer ao culto e '
          'cumprir integralmente minha responsabilidade.',
      'Comprometo-me a participar dos ensaios para os quais for convocado e '
          'a chegar no horário determinado.',
      'Comprometo-me a estudar previamente as músicas e preparar minha '
          'parte antes dos ensaios.',
      'Comprometo-me a chegar aos cultos com antecedência suficiente para '
          'estar preparado no horário determinado para a ministração.',
      'Caso tenha um imprevisto ou não possa cumprir uma escala ou ensaio, '
          'comunicarei a liderança o mais rápido possível.',
      'Não faltarei a uma escala ou ensaio sem justificativa plausível e '
          'sem comunicação à liderança.',
      'Entendo que faltas injustificadas, atrasos recorrentes, ausência nos '
          'ensaios ou falta de preparo técnico poderão resultar na retirada '
          'da escala e por consequência do ministério.',
    ],
  ),
  _CommitmentSection(
    title: 'SUBMISSÃO À LIDERANÇA',
    items: [
      'Comprometo-me a respeitar as orientações da liderança do Ministério '
          'e da igreja. Sabendo que não cumprir normas pré estabelecidas '
          'poderão me levar a saída do ministério.',
      'Entendo que decisões sobre músicas e suas escolhas, escalas, '
          'instrumentos, posições, arranjos e demais aspectos do ministério '
          'serão tomadas pela liderança.',
      'Posso apresentar sugestões e opiniões, mas comprometo-me a respeitar '
          'a decisão final da liderança.',
      'Entendo que desobediência deliberada, desrespeito à liderança ou '
          'resistência contínua às orientações do ministério não serão '
          'considerados compatíveis com a permanência na escala.',
    ],
  ),
  _CommitmentSection(
    title: 'COMPORTAMENTO E RELACIONAMENTO',
    items: [
      'Comprometo-me a tratar os demais integrantes com respeito, humildade '
          'e espírito de equipe.',
      'Não participarei de fofocas, intrigas, provocações, grupos de '
          'oposição ou conversas que possam causar divisão dentro do '
          'ministério ou da igreja.',
      'Não transformarei preferências pessoais, musicais ou ministeriais em '
          'motivo de conflito.',
      'Comprometo-me a resolver discordâncias de maneira respeitosa, '
          'procurando diretamente a liderança ou a pessoa envolvida, quando '
          'necessário.',
      'Entendo que talento, experiência ou tempo de ministério não dão ao '
          'integrante o direito de desrespeitar outros membros ou a '
          'liderança. Entendo que comportamentos que provoquem divisão, '
          'desrespeito, conflitos recorrentes ou prejuízo à unidade do '
          'ministério poderão resultar em afastamento da escala.',
    ],
  ),
  _CommitmentSection(
    title: 'POSTURA DURANTE O CULTO',
    items: [
      'Comprometo-me a manter postura de reverência, atenção e respeito '
          'durante o culto. Evitarei conversas, brincadeiras, uso '
          'inadequado do celular ou qualquer comportamento que possa '
          'distrair a congregação ou os demais integrantes no período que '
          'estarei no púlpito.',
      'Usarei roupas adequadas, que não sejam tão apertadas ou roupas que '
          'venham mostrar o corpo demais. Para as mulheres, evitando '
          'decotes, vestidos e saias curtas (acima do joelho). Para os '
          'homens sabendo que no culto não usaremos roupas de clube de '
          'futebol, desenho animado ou que demonstre alguma preferência '
          'ideológica.',
      'Quando estiver no púlpito, compreenderei meu lugar de servo e que '
          'não devo buscar destaque pessoal.',
      'Comprometo-me a não usar do microfone ou do púlpito para estabelecer '
          'minhas e ideias pessoais sobre assuntos sociais ou ideológicos.',
    ],
  ),
  _CommitmentSection(
    title: 'EQUIPAMENTOS E ORGANIZAÇÃO',
    items: [
      'Comprometo-me a cuidar dos instrumentos, equipamentos e materiais '
          'utilizados pelo Ministério de Louvor.',
      'Utilizarei os equipamentos de maneira responsável e comunicarei '
          'qualquer problema ou dano à liderança.',
      'Comprometo-me a colaborar com a organização, montagem e '
          'desmontagem dos equipamentos quando solicitado.',
    ],
  ),
  _CommitmentSection(
    title: 'REDES SOCIAIS E TESTEMUNHO',
    items: [
      'Entendo que minha conduta pública nas redes sociais pode refletir '
          'sobre meu testemunho e sobre a igreja. Principalmente postagens '
          'que mostram pensamentos anti cristãos e que exiba meu corpo.',
      'Não utilizarei minha posição no Ministério de Louvor para expor '
          'conflitos internos, atacar integrantes, provocar divisões ou '
          'promover situações que prejudiquem o testemunho da igreja.',
    ],
  ),
  _CommitmentSection(
    title: 'COMPROMISSO FINAL',
    items: [
      'Entendo que fazer parte do Ministério de Louvor é um privilégio, mas '
          'também uma responsabilidade.',
      'Entendo que o cumprimento destes compromissos é necessário para a '
          'permanência na escala de ministrações.',
      'Entendo que o descumprimento destes compromissos poderá levar a uma '
          'conversa com a liderança e, conforme a gravidade ou a '
          'recorrência, à suspensão ou retirada da escala.',
      'Comprometo-me a não interpretar eventual retirada da escala como '
          'perseguição ou punição pessoal, mas como uma decisão ministerial '
          'que poderá ser tomada para preservar a ordem, a unidade e o bom '
          'funcionamento do Ministério de Louvor.',
      'Comprometo-me a servir com fidelidade, pontualidade, preparo, '
          'humildade, respeito e espírito de equipe.',
    ],
  ),
];

final _totalCommitmentItems = _commitmentSections.fold<int>(
  0,
  (sum, section) => sum + section.items.length,
);

class _CommitmentRow {
  const _CommitmentRow.header(this.sectionTitle)
    : itemIndex = null,
      itemText = null;
  const _CommitmentRow.item(this.itemIndex, this.itemText) : sectionTitle = null;

  final String? sectionTitle;
  final int? itemIndex;
  final String? itemText;
}

/// Achatado uma única vez (não a cada `build()`) — cada item já nasce com o
/// número global (1 a 33) fixo. Corrige um bug relatado pelo usuário: a
/// versão anterior calculava o número dentro de um `Builder` por item, com
/// um contador (`var counter = 0`) compartilhado e mutável capturado pelos
/// 33 closures — como `ListView(children: [...])` descarta e recria os
/// `Element`s dos itens que saem/voltam pro viewport durante o scroll (sem
/// que `PraiseCommitmentTermPage.build()` rode de novo), cada `Builder`
/// recriado incrementava o mesmo contador de novo a partir de onde ele
/// tinha ficado, então rolar até o fim e voltar fazia a numeração continuar
/// subindo. Guardar o índice como dado (não recalculado por closure a cada
/// rebuild de widget) elimina o problema — não há mais nenhum `Builder`
/// nem contador mutável.
final List<_CommitmentRow> _commitmentRows = () {
  final rows = <_CommitmentRow>[];
  var index = 0;
  for (final section in _commitmentSections) {
    if (section.title != null) rows.add(_CommitmentRow.header(section.title!));
    for (final item in section.items) {
      rows.add(_CommitmentRow.item(index, item));
      index++;
    }
  }
  return rows;
}();

/// Ponto de entrada único do tile "Ministério de Louvor"
/// (`lib/home/home_quick_tiles.dart`) — checa se o usuário já aceitou o
/// Termo de Compromisso; se não, mostra o termo primeiro
/// (`PraiseCommitmentTermPage`, que só libera `PraiseMinistryPage` depois do
/// aceite). Sem uid (não deveria acontecer — o tile só aparece pra quem tem
/// papel Louvor/editor de cifra, sempre autenticado) cai direto no termo por
/// segurança.
Future<void> openPraiseMinistry(BuildContext context, WidgetRef ref) async {
  final uid = ref.read(currentUidProvider);
  var accepted = false;
  if (uid != null) {
    try {
      accepted = await ref.read(praiseCommitmentRepositoryProvider).hasAccepted(uid);
    } catch (_) {
      accepted = false;
    }
  }
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          accepted ? const PraiseMinistryPage() : const PraiseCommitmentTermPage(),
    ),
  );
}

/// Termo de Compromisso com a Igreja — todo integrante do Ministério de
/// Louvor precisa ler o termo inteiro, marcar cada um dos 33 itens e tocar
/// "Concordo e Aceito" antes do primeiro acesso à área do ministério
/// (02/09/2026, pedido do usuário). O aceite é permanente
/// (`PraiseCommitmentRepository`) — próximas visitas ao ícone pulam direto
/// pra `PraiseMinistryPage` (`openPraiseMinistry`).
///
/// [readOnly] (02/09/2026, pedido do usuário: "deve ser possível acessar os
/// termos para visualização posteriormente") — usado pelo menu ☰ de
/// `PraiseMinistryPage` pra quem já aceitou reler o termo: todos os
/// checkboxes aparecem marcados e travados (`onChanged: null`), sem o botão
/// "Concordo e Aceito" no rodapé.
class PraiseCommitmentTermPage extends ConsumerStatefulWidget {
  const PraiseCommitmentTermPage({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  ConsumerState<PraiseCommitmentTermPage> createState() =>
      _PraiseCommitmentTermPageState();
}

class _PraiseCommitmentTermPageState
    extends ConsumerState<PraiseCommitmentTermPage> {
  final Set<int> _checked = {};
  bool _saving = false;

  bool get _allChecked => widget.readOnly || _checked.length == _totalCommitmentItems;

  Future<void> _accept() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || !_allChecked) return;
    setState(() => _saving = true);
    try {
      await ref.read(praiseCommitmentRepositoryProvider).accept(uid);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PraiseMinistryPage()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Termo de Compromisso com a Igreja'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                widget.readOnly
                    ? 'Termo já aceito — somente leitura.'
                    : 'Leia todo o termo e marque cada item para liberar seu '
                          'acesso ao Ministério de Louvor.',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final row in _commitmentRows)
                    if (row.sectionTitle != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        row.sectionTitle!,
                        style: const TextStyle(
                          color: SibValColors.goldAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ] else
                      CheckboxListTile(
                        value: widget.readOnly || _checked.contains(row.itemIndex),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          '${row.itemIndex! + 1}. ${row.itemText}',
                          style: TextStyle(color: context.textPrimary),
                        ),
                        onChanged: widget.readOnly
                            ? null
                            : (value) {
                                setState(() {
                                  if (value ?? false) {
                                    _checked.add(row.itemIndex!);
                                  } else {
                                    _checked.remove(row.itemIndex!);
                                  }
                                });
                              },
                      ),
                ],
              ),
            ),
            if (!widget.readOnly)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_allChecked)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Marque todos os $_totalCommitmentItems itens '
                            'para continuar (${_checked.length}/$_totalCommitmentItems).',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.textSecondary, fontSize: 12),
                          ),
                        ),
                      ElevatedButton(
                        onPressed: (_allChecked && !_saving) ? _accept : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Concordo e Aceito'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
