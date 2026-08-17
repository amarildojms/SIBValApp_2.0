import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'bible/bible_book_list_page.dart';
import 'birthdays/birthdays_page.dart';
import 'devotionals/devotionals_list_page.dart';
import 'events/events_page.dart';
import 'home/home_feed_page.dart';
import 'hymnal/hymn_list_page.dart';
import 'main.dart';
import 'models/hymn.dart';
import 'partners/partners_page.dart';
import 'prayer/prayer_page.dart';

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
    DevotionalsListPage(),
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
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.menu_book, color: Colors.white70),
            title: const Text('Bíblia', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BibleBookListPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.library_music_outlined, color: Colors.white70),
            title: const Text('Cantor Cristão', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HymnListPage(hymnal: Hymnal.cantorCristao)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.library_music_outlined, color: Colors.white70),
            title: const Text('Hinário Cristão', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HymnListPage(hymnal: Hymnal.hinarioCristao)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cake_outlined, color: Colors.white70),
            title: const Text('Aniversariantes', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BirthdaysPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline, color: Colors.white70),
            title: const Text('Pedido de Oração', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrayerPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.handshake_outlined, color: Colors.white70),
            title: const Text('Vínculos Institucionais', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PartnersPage()),
            ),
          ),
          const Divider(color: Colors.white24),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
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
        ],
      ),
    );
  }
}
