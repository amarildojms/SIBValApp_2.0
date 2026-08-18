import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../theme/app_theme.dart';

/// Resultado de [resolveApprovalState] — espelha o `AuthUiState` do app Android
/// original (ui/auth/AuthUiState.kt): depois de autenticar, ainda é preciso
/// checar o documento em `users/{uid}` porque nem toda conta autenticada pode
/// acessar o app (pendente de aprovação, bloqueada, etc.).
enum ApprovalResult { approved, pendingApproval, rejected, blocked, accountDeleted }

/// Mesma regra de app/src/main/java/com/sibval/app/ui/auth/AuthUiState.kt:
/// desloga automaticamente quando a conta não pode acessar o app.
Future<ApprovalResult> resolveApprovalState(String uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final data = doc.data();

  if (data == null) {
    await FirebaseAuth.instance.signOut();
    return ApprovalResult.accountDeleted;
  }

  final isBlocked = data['isBlocked'] as bool? ?? false;
  if (isBlocked) {
    await FirebaseAuth.instance.signOut();
    return ApprovalResult.blocked;
  }

  final status = data['status'] as String? ?? 'approved';
  switch (status) {
    case 'approved':
      return ApprovalResult.approved;
    case 'rejected':
      await FirebaseAuth.instance.signOut();
      return ApprovalResult.rejected;
    default:
      await FirebaseAuth.instance.signOut();
      return ApprovalResult.pendingApproval;
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('E-mail inválido.');
      return;
    }
    if (password.length < 6) {
      _showMessage('A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final uid = credential.user?.uid;
      if (uid == null) {
        _showMessage('Falha ao autenticar.');
        return;
      }

      final approval = await resolveApprovalState(uid);
      if (!mounted) return;
      switch (approval) {
        case ApprovalResult.approved:
          Navigator.of(context).pop();
        case ApprovalResult.pendingApproval:
          _showMessage('Seu cadastro ainda está aguardando aprovação.');
        case ApprovalResult.rejected:
          _showMessage('Seu cadastro foi rejeitado.');
        case ApprovalResult.blocked:
          _showMessage('Sua conta está bloqueada.');
        case ApprovalResult.accountDeleted:
          _showMessage('Conta não encontrada.');
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(_messageForAuthError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        _showMessage('Falha ao autenticar com Google.');
        return;
      }

      final googleCredential = GoogleAuthProvider.credential(idToken: idToken);
      final credential = await FirebaseAuth.instance.signInWithCredential(googleCredential);
      final uid = credential.user?.uid;
      if (uid == null) {
        _showMessage('Falha ao autenticar com Google.');
        return;
      }

      final approval = await resolveApprovalState(uid);
      if (!mounted) return;
      switch (approval) {
        case ApprovalResult.approved:
          Navigator.of(context).pop();
        case ApprovalResult.pendingApproval:
          _showMessage('Seu cadastro ainda está aguardando aprovação.');
        case ApprovalResult.rejected:
          _showMessage('Seu cadastro foi rejeitado.');
        case ApprovalResult.blocked:
          _showMessage('Sua conta está bloqueada.');
        case ApprovalResult.accountDeleted:
          _showMessage('Cadastro não encontrado — complete seu perfil no app atual antes de testar aqui.');
      }
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _showMessage('Falha ao autenticar com Google.');
      }
    } on FirebaseAuthException catch (_) {
      _showMessage('Falha ao autenticar com Google.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageForAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      default:
        return 'Falha ao entrar. Tente novamente.';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '2ª Igreja Batista\nem Valparaíso',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _loginWithGoogle,
                    child: const Text('Entrar com Google'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
