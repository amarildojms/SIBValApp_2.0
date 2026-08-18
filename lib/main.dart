import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'main_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_preference.dart';

/// Client OAuth "web" do projeto Firebase (mesmo para todos os apps do projeto,
/// inclusive o Android nativo) — equivalente ao `default_web_client_id` que o
/// LoginActivity.kt original lê de `strings.xml` (gerado pelo google-services).
const googleSignInServerClientId =
    '1086803129414-tlk8t2139e6jgrovqdsqjbjed0j80eb8.apps.googleusercontent.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GoogleSignIn.instance.initialize(serverClientId: googleSignInServerClientId);
  await initializeDateFormatting('pt_BR');
  runApp(const ProviderScope(child: SibValApp()));
}

class SibValApp extends ConsumerWidget {
  const SibValApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'SIB Val App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const MainShell(),
    );
  }
}
