import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'events/events_page.dart';
import 'home/home_feed_page.dart';
import 'main.dart';

/// Espelha o bottom_nav_menu.xml original: Devocionais, Eventos, Início,
/// Contribua, Mais. Só o Início tem conteúdo real nesta fase — os demais são
/// placeholders "em breve" até as próximas fases da migração.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 2; // Início é a aba central, igual ao app original.

  static const _pages = [
    _ComingSoonPage(title: 'Devocionais'),
    EventsPage(),
    HomeFeedPage(),
    _ComingSoonPage(title: 'Contribua'),
    _MaisPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        backgroundColor: SibValColors.navyBlue,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Devocionais'),
          NavigationDestination(icon: Icon(Icons.event_outlined), label: 'Eventos'),
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Contribua'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Mais'),
        ],
      ),
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('Em breve.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70)),
      ),
    );
  }
}

class _MaisPage extends StatelessWidget {
  const _MaisPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(FirebaseAuth.instance.currentUser?.email ?? '', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
