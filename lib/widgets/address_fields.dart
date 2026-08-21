import 'package:flutter/material.dart';

import '../models/address.dart';
import '../util/address_lookup.dart';

/// Endereço quebrado em campos (21/08/2026, a pedido do usuário): CEP (com
/// preenchimento automático de rua/bairro/cidade/estado via ViaCEP),
/// Rua/Avenida, Número (com opção "Sem número"), Complemento (opcional),
/// Bairro, Cidade, Estado. Usado em `register_page.dart`,
/// `complete_google_profile_page.dart`, `edit_profile_page.dart` e no diálogo
/// de membro em `members_page.dart` — todas essas telas têm estilos de campo
/// diferentes (claro/escuro, com/sem `OutlineInputBorder`), daí
/// [decorationBuilder]/[style]/[iconColor] em vez de decoração fixa.
///
/// Diferente de `DateField`, não é "controlado": os controllers são donos do
/// próprio texto (mesmo padrão dos outros campos de texto do app, ex.
/// `_MemberDialog`) — quem usa lê o valor final via a [AddressFieldsState]
/// (`GlobalKey<AddressFieldsState>().currentState!.value`) no momento de
/// salvar, em vez de reconstruir a cada tecla digitada.
class AddressFields extends StatefulWidget {
  const AddressFields({
    super.key,
    required this.initial,
    this.enabled = true,
    this.decorationBuilder,
    this.style,
    this.iconColor,
    this.dropdownColor,
    this.onAnyChange,
  });

  final Address initial;
  final bool enabled;
  final InputDecoration Function(String label)? decorationBuilder;
  final TextStyle? style;
  final Color? iconColor;
  final Color? dropdownColor;

  /// Sinal "algo mudou", sem o valor — pra telas que rastreiam alterações
  /// não salvas (ver `edit_profile_page.dart`) sem precisar reconstruir a
  /// cada tecla digitada. Quem precisa do valor final lê `value` direto no
  /// momento de salvar.
  final VoidCallback? onAnyChange;

  @override
  State<AddressFields> createState() => AddressFieldsState();
}

class AddressFieldsState extends State<AddressFields> {
  late final _cepController = TextEditingController(text: widget.initial.cep)..addListener(_notifyChange);
  late final _streetController = TextEditingController(text: widget.initial.street)..addListener(_notifyChange);
  late final _numberController = TextEditingController(text: widget.initial.number)..addListener(_notifyChange);
  late final _complementController = TextEditingController(text: widget.initial.complement)
    ..addListener(_notifyChange);
  late final _neighborhoodController = TextEditingController(text: widget.initial.neighborhood)
    ..addListener(_notifyChange);
  late final _cityController = TextEditingController(text: widget.initial.city)..addListener(_notifyChange);
  late bool _noNumber = widget.initial.noNumber;
  late String? _state = widget.initial.state.isNotEmpty ? widget.initial.state : null;
  bool _looking = false;

  void _notifyChange() => widget.onAnyChange?.call();

  Address get value => Address(
        cep: _cepController.text.trim(),
        street: _streetController.text.trim(),
        number: _noNumber ? '' : _numberController.text.trim(),
        noNumber: _noNumber,
        complement: _complementController.text.trim(),
        neighborhood: _neighborhoodController.text.trim(),
        city: _cityController.text.trim(),
        state: _state ?? '',
      );

  @override
  void dispose() {
    _cepController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _onCepChanged(String text) async {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;
    setState(() => _looking = true);
    final found = await lookupCep(text);
    if (!mounted) return;
    setState(() {
      _looking = false;
      if (found != null) {
        _streetController.text = found.street;
        _neighborhoodController.text = found.neighborhood;
        _cityController.text = found.city;
        if (found.state.isNotEmpty) _state = found.state;
        _notifyChange();
      }
    });
  }

  InputDecoration _decoration(String label) =>
      widget.decorationBuilder?.call(label) ?? InputDecoration(labelText: label);

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _cepController,
          enabled: widget.enabled,
          style: style,
          keyboardType: TextInputType.number,
          inputFormatters: [CepInputFormatter()],
          onChanged: _onCepChanged,
          decoration: _decoration('CEP').copyWith(
            suffixIcon: _looking
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: widget.iconColor),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _streetController,
          enabled: widget.enabled,
          style: style,
          textCapitalization: TextCapitalization.words,
          decoration: _decoration('Rua/Avenida'),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _numberController,
                enabled: widget.enabled && !_noNumber,
                style: style,
                keyboardType: TextInputType.number,
                decoration: _decoration('Número'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text('Sem número', style: style),
                value: _noNumber,
                onChanged: widget.enabled
                    ? (checked) => setState(() {
                          _noNumber = checked ?? false;
                          if (_noNumber) _numberController.clear();
                          _notifyChange();
                        })
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _complementController,
          enabled: widget.enabled,
          style: style,
          textCapitalization: TextCapitalization.sentences,
          decoration: _decoration('Complemento (opcional)'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _neighborhoodController,
          enabled: widget.enabled,
          style: style,
          textCapitalization: TextCapitalization.words,
          decoration: _decoration('Bairro'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _cityController,
                enabled: widget.enabled,
                style: style,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('Cidade'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _state,
                decoration: _decoration('UF'),
                style: style,
                dropdownColor: widget.dropdownColor,
                items: [for (final uf in brazilianStateAbbreviations) DropdownMenuItem(value: uf, child: Text(uf))],
                onChanged: widget.enabled
                    ? (value) => setState(() {
                          _state = value;
                          _notifyChange();
                        })
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

const brazilianStateAbbreviations = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO',
  'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI',
  'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
];
