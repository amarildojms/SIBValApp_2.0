/// Espelha app/src/main/java/com/sibval/app/data/model/Hymn.kt.
class Hymn {
  final int id;
  final String number;
  final String title;
  final String lyrics;

  const Hymn({required this.id, required this.number, required this.title, this.lyrics = ''});
}

/// Espelha o enum Hymnal.kt: ambos os hinários usam o mesmo schema OpenLP
/// "songs", só muda o arquivo/prefixo do número no título bruto.
enum Hymnal {
  cantorCristao('assets/hymnals/cc.sqlite', 'cc.sqlite', 'CC', 'Cantor Cristão'),
  hinarioCristao('assets/hymnals/hcc.sqlite', 'hcc.sqlite', 'HCC', 'Hinário Cristão');

  const Hymnal(this.assetPath, this.dbName, this.titlePrefix, this.displayTitle);

  final String assetPath;
  final String dbName;
  final String titlePrefix;
  final String displayTitle;
}
