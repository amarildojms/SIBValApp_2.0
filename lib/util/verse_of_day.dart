/// Versículo do dia (02/09/2026, pedido do usuário) — sem equivalente no
/// nativo e sem fonte de dado própria no Firestore ainda (não existe uma
/// coleção "versículo do dia" nem um campo de data associado). Solução
/// simples adotada por enquanto: uma lista curada local (texto de domínio
/// público, tradução Almeida) rotacionada de forma determinística pelo dia
/// do ano — o mesmo versículo aparece o dia inteiro pra todo mundo, muda à
/// meia-noite, sem precisar de configuração manual nem de rede. Se o usuário
/// quiser trocar isso por uma coleção gerenciável pelo admin mais pra
/// frente, é só substituir [verseOfTheDay] por uma leitura do Firestore.
class BibleVerseQuote {
  const BibleVerseQuote(this.text, this.reference);

  final String text;
  final String reference;
}

const _verses = [
  BibleVerseQuote(
    'Alegrei-me quando me disseram: Vamos à casa do Senhor.',
    'Salmos 122:1',
  ),
  BibleVerseQuote(
    'O Senhor é o meu pastor, nada me faltará.',
    'Salmos 23:1',
  ),
  BibleVerseQuote(
    'Tudo posso naquele que me fortalece.',
    'Filipenses 4:13',
  ),
  BibleVerseQuote(
    'Porque Deus amou o mundo de tal maneira que deu o seu Filho unigênito, '
        'para que todo aquele que nele crê não pereça, mas tenha a vida eterna.',
    'João 3:16',
  ),
  BibleVerseQuote(
    'Confia no Senhor de todo o teu coração, e não te estribes no teu '
        'próprio entendimento.',
    'Provérbios 3:5',
  ),
  BibleVerseQuote(
    'O Senhor é a minha luz e a minha salvação; a quem temerei?',
    'Salmos 27:1',
  ),
  BibleVerseQuote(
    'Vinde a mim, todos os que estais cansados e oprimidos, e eu vos '
        'aliviarei.',
    'Mateus 11:28',
  ),
  BibleVerseQuote(
    'Não temas, porque eu sou contigo; não te assombres, porque eu sou o '
        'teu Deus.',
    'Isaías 41:10',
  ),
  BibleVerseQuote(
    'Entrega o teu caminho ao Senhor; confia nele, e ele o fará.',
    'Salmos 37:5',
  ),
  BibleVerseQuote(
    'Tudo tem o seu tempo determinado, e há tempo para todo o propósito '
        'debaixo do céu.',
    'Eclesiastes 3:1',
  ),
  BibleVerseQuote(
    'Bendize, ó minha alma, ao Senhor, e não te esqueças de nenhum de seus '
        'benefícios.',
    'Salmos 103:2',
  ),
  BibleVerseQuote(
    'E conhecereis a verdade, e a verdade vos libertará.',
    'João 8:32',
  ),
  BibleVerseQuote(
    'Porque para Deus nada é impossível.',
    'Lucas 1:37',
  ),
  BibleVerseQuote(
    'O amor é sofredor, é benigno; o amor não é invejoso.',
    '1 Coríntios 13:4',
  ),
  BibleVerseQuote(
    'Buscai primeiro o reino de Deus, e a sua justiça, e todas essas coisas '
        'vos serão acrescentadas.',
    'Mateus 6:33',
  ),
  BibleVerseQuote(
    'Graças a Deus pelo seu dom inefável!',
    '2 Coríntios 9:15',
  ),
  BibleVerseQuote(
    'Regozijai-vos sempre no Senhor; outra vez digo, regozijai-vos.',
    'Filipenses 4:4',
  ),
  BibleVerseQuote(
    'O Senhor te abençoe, e te guarde.',
    'Números 6:24',
  ),
  BibleVerseQuote(
    'Sede fortes e corajosos... porque o Senhor teu Deus é contigo, por onde '
        'quer que andares.',
    'Josué 1:9',
  ),
  BibleVerseQuote(
    'Este é o dia que fez o Senhor; regozijemo-nos, e alegremo-nos nele.',
    'Salmos 118:24',
  ),
];

/// Determinístico por dia do ano — o mesmo índice o dia inteiro, muda à
/// meia-noite (fuso do aparelho, sem depender de America/Sao_Paulo aqui:
/// diferença de fuso não muda qual versículo aparece, só quando exatamente
/// a virada acontece).
BibleVerseQuote verseOfTheDay([DateTime? now]) {
  final today = now ?? DateTime.now();
  final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;
  return _verses[dayOfYear % _verses.length];
}
