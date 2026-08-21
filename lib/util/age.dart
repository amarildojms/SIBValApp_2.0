/// Idade mínima pra se cadastrar no app (21/08/2026, a pedido do usuário) —
/// checada em `register_page.dart` e `complete_google_profile_page.dart`.
const minimumRegistrationAge = 12;

/// Idade em anos completos na data de hoje (ou [now], pra testes).
int ageInYears(DateTime birthdate, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var age = today.year - birthdate.year;
  if (today.month < birthdate.month || (today.month == birthdate.month && today.day < birthdate.day)) {
    age--;
  }
  return age;
}

/// Data de nascimento mais recente que ainda completa [minAge] anos hoje —
/// usada como `lastDate` do seletor de data de nascimento no cadastro, pra
/// nem deixar escolher/digitar uma data que reprovaria na validação de
/// [minimumRegistrationAge].
DateTime maxBirthdateForAge(int minAge, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return DateTime(today.year - minAge, today.month, today.day);
}
