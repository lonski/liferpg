import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feature_flags.dart';
import '../../models/character.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

const TextStyle _fieldLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 9,
  letterSpacing: 2,
  color: crimson,
);

const Color _inkHeading = Color(0xFF2D0A0A);

String? _validateOptionalInt(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  return int.tryParse(text) == null ? 'Podaj liczbę' : null;
}

Widget _numberField(String fieldKey, TextEditingController controller) =>
    TextFormField(
      key: Key('field-$fieldKey'),
      controller: controller,
      keyboardType: TextInputType.number,
      validator: _validateOptionalInt,
    );

class EditCharacterScreen extends ConsumerStatefulWidget {
  const EditCharacterScreen({super.key, required this.character});

  final Character character;

  @override
  ConsumerState<EditCharacterScreen> createState() =>
      _EditCharacterScreenState();
}

class _EditCharacterScreenState extends ConsumerState<EditCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late List<Trait> _traits;
  // Stable per-row identity, independent of list position, so that removing
  // a trait in the middle of the list doesn't confuse Flutter's element
  // reconciliation into rebinding a surviving row's TextField to the wrong
  // controller. Each row's TextEditingController is owned by its own
  // _TraitValueField State (see below) and is created/disposed by Flutter
  // itself as that keyed element enters/leaves the tree — we never touch a
  // trait-value controller directly here.
  late List<int> _traitKeys;
  int _nextTraitKey = 0;
  late int _favour;
  final _newTraitName = TextEditingController();
  final _newTraitValue = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _controllers = {
      'level': TextEditingController(text: c.level?.toString() ?? ''),
      'gold': TextEditingController(text: c.gold?.toString() ?? ''),
      'gold_usd': TextEditingController(text: c.goldUsd?.toString() ?? ''),
      'current_xp': TextEditingController(text: c.currentXp.toString()),
      'next_level_xp': TextEditingController(text: c.nextLevelXp.toString()),
    };
    _traits = List<Trait>.from(c.traits);
    _traitKeys = [for (final _ in _traits) _nextTraitKey++];
    _favour = c.favour;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _newTraitName.dispose();
    _newTraitValue.dispose();
    super.dispose();
  }

  int? _intOf(String key) => int.tryParse(_controllers[key]!.text.trim());

  void _addTrait() {
    final name = _newTraitName.text.trim();
    final value = _newTraitValue.text.trim();
    if (name.isEmpty || value.isEmpty) return;
    setState(() {
      _traits = [..._traits, Trait(name: name, value: value)];
      _traitKeys = [..._traitKeys, _nextTraitKey++];
      _newTraitName.clear();
      _newTraitValue.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = widget.character.copyWith(
        level: _intOf('level'),
        gold: _intOf('gold'),
        goldUsd: _intOf('gold_usd'),
        currentXp: _intOf('current_xp') ?? 0,
        nextLevelXp: _intOf('next_level_xp') ?? 0,
        favour: _favour,
        traits: _traits,
      );
      await ref.read(characterRepositoryProvider).updateCharacter(updated);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Zapis nieudany: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final traitNames = ref.watch(traitNamesProvider);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: parchmentMuted),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: appBarGradient,
            border: Border(bottom: BorderSide(color: goldBorderFaint)),
          ),
        ),
        title: const Text(
          'Edycja Postaci',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 14,
            letterSpacing: 3,
            color: parchmentLight,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('save-character'),
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '...' : 'Zapisz',
              style: const TextStyle(
                fontFamily: fontDisplay,
                letterSpacing: 2,
                color: gold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: crimson, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    const TopBand(label: '✦ Edycja Postaci ✦'),
                    Container(
                      decoration: const BoxDecoration(gradient: cardGradient),
                      padding: const EdgeInsets.all(16),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: crimsonBorder),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Text(
                                  widget.character.name,
                                  style: const TextStyle(
                                    fontFamily: fontDisplay,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                    color: _inkHeading,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _LabelledField(
                                  label: 'Poziom',
                                  child: _numberField(
                                      'level', _controllers['level']!),
                                ),
                                _LabelledField(
                                  label: 'Złoto',
                                  child:
                                      _numberField('gold', _controllers['gold']!),
                                ),
                                _LabelledField(
                                  label: 'Dolary',
                                  child: _numberField(
                                      'gold_usd', _controllers['gold_usd']!),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('XP', style: _fieldLabel),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 64,
                                          child: _numberField('current_xp',
                                              _controllers['current_xp']!),
                                        ),
                                        const Text(' / ',
                                            style: TextStyle(color: crimson)),
                                        SizedBox(
                                          width: 64,
                                          child: _numberField('next_level_xp',
                                              _controllers['next_level_xp']!),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (kShowFavour) _favourRow(),
                                const SizedBox(height: 12),
                                const OrnamentDivider(),
                                const SizedBox(height: 12),
                                _traitEditor(traitNames),
                              ],
                            ),
                          ),
                          const Positioned(
                              top: 5, left: 5, child: CornerOrnament()),
                          const Positioned(
                            top: 5,
                            right: 5,
                            child: CornerOrnament(mirrored: true),
                          ),
                        ],
                      ),
                    ),
                    const BottomBand(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _favourRow() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Przychylność', style: _fieldLabel),
          Row(
            children: [
              IconButton(
                key: const Key('favour-down'),
                icon: const Text('👎'),
                onPressed: () => setState(() => _favour -= 1),
              ),
              Text(
                '$_favour',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _inkHeading,
                ),
              ),
              IconButton(
                key: const Key('favour-up'),
                icon: const Text('👍'),
                onPressed: () => setState(() => _favour += 1),
              ),
            ],
          ),
        ],
      );

  Widget _traitEditor(List<String> knownNames) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Cechy', style: _fieldLabel, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          for (var i = 0; i < _traits.length; i++)
            Row(
              key: ValueKey(_traitKeys[i]),
              children: [
                Expanded(
                  child: Text(
                    _traits[i].name,
                    style: const TextStyle(fontFamily: fontBody, fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: _TraitValueField(
                    fieldKey: Key('trait-value-$i'),
                    initialValue: _traits[i].value,
                    onChanged: (value) => setState(() {
                      _traits = [..._traits];
                      _traits[i] = Trait(name: _traits[i].name, value: value);
                    }),
                  ),
                ),
                IconButton(
                  key: Key('remove-trait-$i'),
                  iconSize: 18,
                  color: crimson,
                  icon: const Icon(Icons.delete),
                  onPressed: () => setState(() {
                    _traits = [..._traits]..removeAt(i);
                    _traitKeys = [..._traitKeys]..removeAt(i);
                  }),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: Autocomplete<String>(
                  optionsBuilder: (value) => value.text.isEmpty
                      ? knownNames
                      : knownNames.where((n) =>
                          n.toLowerCase().contains(value.text.toLowerCase())),
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmitted) {
                    return TextField(
                      key: const Key('new-trait-name'),
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (v) => _newTraitName.text = v,
                      onSubmitted: (_) => onSubmitted(),
                      decoration: const InputDecoration(labelText: 'Nazwa'),
                    );
                  },
                  onSelected: (v) => _newTraitName.text = v,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: TextField(
                  key: const Key('new-trait-value'),
                  controller: _newTraitValue,
                  decoration: const InputDecoration(labelText: 'Wartość'),
                ),
              ),
              IconButton(
                key: const Key('add-trait'),
                color: crimson,
                icon: const Icon(Icons.add),
                onPressed: _addTrait,
              ),
            ],
          ),
        ],
      );
}

// Owns the TextEditingController for a single trait's value. Wrapping this
// in its own StatefulWidget (keyed on a stable per-trait id by the caller)
// means Flutter creates/disposes this State — and the controller inside it
// — automatically as the row enters/leaves the tree, even when other rows
// shift position around it. No manual controller bookkeeping is needed in
// the parent screen.
class _TraitValueField extends StatefulWidget {
  const _TraitValueField({
    required this.fieldKey,
    required this.initialValue,
    required this.onChanged,
  });

  final Key fieldKey;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_TraitValueField> createState() => _TraitValueFieldState();
}

class _TraitValueFieldState extends State<_TraitValueField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        key: widget.fieldKey,
        controller: _controller,
        style: const TextStyle(
          fontFamily: fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        onChanged: widget.onChanged,
      );
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _fieldLabel),
          SizedBox(width: 64, child: child),
        ],
      );
}
