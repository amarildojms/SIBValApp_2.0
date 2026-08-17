import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'auth/login_page.dart';
import 'main_shell.dart';

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

// Paleta reaproveitada de app/src/main/res/values/colors.xml do app Android original.
class SibValColors {
  static const navyBlue = Color(0xFF112D39);
  static const navyBlueLight = Color(0xFF1C4A5E);
  static const navyBlueDark = Color(0xFF0A1D24);
  static const goldAccent = Color(0xFFC9A24B);
}

class SibValApp extends StatelessWidget {
  const SibValApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIB Val App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: SibValColors.navyBlueDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SibValColors.goldAccent,
          brightness: Brightness.dark,
          primary: SibValColors.goldAccent,
          surface: SibValColors.navyBlue,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: SibValColors.navyBlue,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: SibValColors.goldAccent,
            foregroundColor: SibValColors.navyBlueDark,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Decide entre a tela de login e o placeholder pós-login com base no estado
/// de autenticação do Firebase — equivalente ao check de `currentUser` que o
/// LoginActivity.kt original faz no onCreate.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data != null) {
          return const MainShell();
        }
        return const LoginPage();
      },
    );
  }
}
