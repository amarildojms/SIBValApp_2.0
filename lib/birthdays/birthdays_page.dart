import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/login_page.dart';
import '../data/member_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../models/member.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Espelha BirthdaysFragment.kt/BirthdaysViewModel.kt: calendário do mês (grade
/// de 7 colunas, domingo primeiro) com os dias que têm aniversariante
/// marcados, e a lista de quem faz aniversário no dia selecionado.
class BirthdaysPage extends ConsumerStatefulWidget {
  const BirthdaysPage({super.key});

  @override
  ConsumerState<BirthdaysPage> createState() => _BirthdaysPageState();
}

class _BirthdaysPageState extends ConsumerState<BirthdaysPage> {
  late int _month;
  late int _year;
  int? _selectedDay;

  static final _monthYearFormat = DateFormat('MMMM yyyy', 'pt_BR');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _selectedDay = now.day;
  }

  void _previousMonth() {
    setState(() {
      _month--;
      if (_month < 1) {
        _month = 12;
        _year--;
      }
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _month++;
      if (_month > 12) {
        _month = 1;
        _year++;
      }
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);

    if (uid == null) {
      return Scaffold(
        appBar: const SibValAppBar(isHome: false),
        body: SafeArea(
          bottom: true,
          top: false,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Aniversariantes'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Faça login para ver os aniversariantes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        ),
                        child: const Text('Entrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      );
    }

    final membersAsync = ref.watch(membersProvider);
    final label = _monthYearFormat.format(DateTime(_year, _month, 1));
    final capitalizedLabel = label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle('Aniversariantes'),
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
              data: (members) {
          final birthdayDays = members.where((m) => m.birthMonth == _month).map((m) => m.birthDay).toSet();
          final firstOfMonth = DateTime(_year, _month, 1);
          final leadingBlanks = firstOfMonth.weekday % 7;
          final daysInMonth = DateTime(_year, _month + 1, 0).day;

          final selectedMembers = _selectedDay == null
              ? <Member>[]
              : members.where((m) => m.birthMonth == _month && m.birthDay == _selectedDay).toList();

          return RefreshIndicator(
            onRefresh: () => ref.refresh(membersProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(onPressed: _previousMonth, icon: Icon(Icons.chevron_left, color: context.textPrimary)),
                    Text(capitalizedLabel, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: _nextMonth, icon: Icon(Icons.chevron_right, color: context.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
                    for (var day = 1; day <= daysInMonth; day++)
                      _DayCell(
                        day: day,
                        hasBirthday: birthdayDays.contains(day),
                        isSelected: day == _selectedDay,
                        onTap: () => setState(() => _selectedDay = day),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (selectedMembers.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text('Nenhum aniversariante neste dia.', style: TextStyle(color: context.textSecondary)),
                    ),
                  )
                else
                  for (final member in selectedMembers)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: member.photoUrl.isNotEmpty ? NetworkImage(member.photoUrl) : null,
                          child: member.photoUrl.isEmpty ? const Icon(Icons.cake_outlined) : null,
                        ),
                        title: Text(member.name),
                      ),
                    ),
              ],
            ),
          );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.hasBirthday, required this.isSelected, required this.onTap});

  final int day;
  final bool hasBirthday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: isSelected ? Colors.amber : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    color: isSelected ? Theme.of(context).colorScheme.onPrimary : context.textPrimary,
                    fontWeight: hasBirthday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (hasBirthday && !isSelected)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.circle, size: 4, color: Colors.amber),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
