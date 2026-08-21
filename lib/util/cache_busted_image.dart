/// Firebase Storage mantém a mesma URL (mesmo token) quando uma foto é
/// sobrescrita no mesmo caminho (`users/{uid}.jpg`, `members/{id}.jpg`) — o
/// cache de imagem do Flutter (e do SO) então continua servindo a versão
/// antiga pra qualquer usuário que já tenha visto essa URL antes, mesmo após
/// o dono trocar a foto. Anexar `photoUpdatedAt` como query param força uma
/// nova chave de cache a cada troca, sem precisar de caminho de arquivo novo.
String cacheBustedPhotoUrl(String url, DateTime? updatedAt) {
  if (url.isEmpty || updatedAt == null) return url;
  final separator = url.contains('?') ? '&' : '?';
  return '$url${separator}v=${updatedAt.millisecondsSinceEpoch}';
}
