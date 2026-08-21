import 'package:flutter/widgets.dart';

/// Rola até o fim do conteúdo — usado pra revelar o botão "Salvar" (com o
/// spinner de carregando) quando o usuário toca em salvar estando no topo da
/// tela e o botão fica fora da área visível (22/08/2026, a pedido do
/// usuário). Chamado no início do handler de salvar, antes do `await`, pra
/// já animar enquanto a operação roda. Sem efeito se a tela já estiver perto
/// do fim, ou se o conteúdo nem for rolável.
extension ScrollToSaveButton on ScrollController {
  void scrollToSaveButton() {
    if (!hasClients) return;
    animateTo(
      position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}
