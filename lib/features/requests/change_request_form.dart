import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/change_request.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';

const TextStyle _fieldLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 12,
  letterSpacing: 2,
  color: crimson,
);

/// Deltas may be negative, so unlike the character editor these accept a
/// leading minus. Empty means "no change to this field", never zero.
String? _validateOptionalDelta(String? value, {required bool decimal}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final parsed = decimal ? num.tryParse(text) : int.tryParse(text);
  return parsed == null ? 'Podaj liczbę' : null;
}

/// A pure input widget: it never writes to Firestore. The hosting screen owns
/// submission, so the requester screen and the admin's edit-before-accept
/// flow can share one implementation.
class ChangeRequestForm extends ConsumerStatefulWidget {
  const ChangeRequestForm({
    super.key,
    this.initial,
    this.reason,
    this.showReason = true,
    required this.onChanged,
  });

  final ChangeSet? initial;
  final String? reason;
  final bool showReason;
  final void Function(ChangeSet changes, String? reason) onChanged;

  @override
  ConsumerState<ChangeRequestForm> createState() => _ChangeRequestFormState();
}

class _ChangeRequestFormState extends ConsumerState<ChangeRequestForm> {
  late final Map<String, TextEditingController> _controllers;
  late final TextEditingController _reasonController;
  final _newTraitValue = TextEditingController();
  // Owned by the Autocomplete below, not by us: we capture the instance it
  // hands to fieldViewBuilder so that _addTrait can actually clear the box,
  // and we must not dispose it. Same arrangement as EditCharacterScreen.
  TextEditingController? _traitNameController;
  late List<TraitChange> _traits;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _controllers = {
      'current_xp': TextEditingController(
        text: initial?.currentXp?.toString() ?? '',
      ),
      'gold': TextEditingController(text: initial?.gold?.toString() ?? ''),
      'gold_usd': TextEditingController(
        text: initial?.goldUsd?.toString() ?? '',
      ),
    };
    _reasonController = TextEditingController(text: widget.reason ?? '');
    _traits = List<TraitChange>.from(initial?.traits ?? const <TraitChange>[]);
    for (final c in _controllers.values) {
      c.addListener(_emit);
    }
    _reasonController.addListener(_emit);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _reasonController.dispose();
    _newTraitValue.dispose();
    super.dispose();
  }

  num? _deltaOf(String key, {required bool decimal}) {
    final text = _controllers[key]!.text.trim();
    if (text.isEmpty) return null;
    return decimal ? num.tryParse(text) : int.tryParse(text);
  }

  ChangeSet get _changes => ChangeSet(
    currentXp: _deltaOf('current_xp', decimal: false),
    gold: _deltaOf('gold', decimal: true),
    goldUsd: _deltaOf('gold_usd', decimal: true),
    traits: _traits,
  );

  void _emit() {
    final reason = _reasonController.text.trim();
    widget.onChanged(_changes, reason.isEmpty ? null : reason);
  }

  void _addTrait() {
    final nameController = _traitNameController;
    final name = (nameController?.text ?? '').trim();
    // An empty value is a legitimate trait; an empty name is not.
    if (name.isEmpty) return;
    final value = _newTraitValue.text.trim();
    setState(() {
      // Re-adding a name already staged replaces it, matching the upsert
      // semantics the accept transaction uses.
      final index = _traits.indexWhere((t) => t.name == name);
      final entry = TraitChange(name: name, value: value);
      _traits = [..._traits];
      if (index >= 0) {
        _traits[index] = entry;
      } else {
        _traits.add(entry);
      }
    });
    nameController?.clear();
    _newTraitValue.clear();
    _emit();
  }

  void _removeTrait(String name) {
    setState(() {
      _traits = [
        for (final t in _traits)
          if (t.name != name) t,
      ];
    });
    _emit();
  }

  Widget _deltaField(String key, {required bool decimal}) => TextFormField(
    key: Key('field-$key'),
    controller: _controllers[key],
    keyboardType: TextInputType.numberWithOptions(
      decimal: decimal,
      signed: true,
    ),
    validator: (v) => _validateOptionalDelta(v, decimal: decimal),
    decoration: const InputDecoration(hintText: 'np. +50'),
  );

  @override
  Widget build(BuildContext context) {
    final traitNames = ref.watch(traitNamesProvider);

    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Labelled(
            label: 'XP',
            child: _deltaField('current_xp', decimal: false),
          ),
          _Labelled(label: 'Złoto', child: _deltaField('gold', decimal: true)),
          _Labelled(
            label: 'Dolary',
            child: _deltaField('gold_usd', decimal: true),
          ),
          const SizedBox(height: 12),
          Text('Cechy'.toUpperCase(), style: _fieldLabel),
          for (final trait in _traits)
            Row(
              key: Key('trait-row-${trait.name}'),
              children: [
                Expanded(
                  child: Text(
                    '${trait.name}: ${trait.value}',
                    style: const TextStyle(color: traitNameInk),
                  ),
                ),
                IconButton(
                  tooltip: 'Usuń',
                  icon: const Icon(Icons.close, size: 16, color: crimson),
                  onPressed: () => _removeTrait(trait.name),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: Autocomplete<String>(
                  optionsBuilder: (value) {
                    final text = value.text.trim().toLowerCase();
                    if (text.isEmpty) return const Iterable<String>.empty();
                    return traitNames.where(
                      (n) => n.toLowerCase().contains(text),
                    );
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        _traitNameController = controller;
                        return TextFormField(
                          key: const Key('trait-name'),
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Nazwa cechy',
                          ),
                        );
                      },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: const Key('trait-value'),
                  controller: _newTraitValue,
                  decoration: const InputDecoration(hintText: 'Wartość'),
                ),
              ),
              IconButton(
                key: const Key('add-trait'),
                tooltip: 'Dodaj cechę',
                icon: const Icon(Icons.add, color: crimson),
                onPressed: _addTrait,
              ),
            ],
          ),
          if (widget.showReason) ...[
            const SizedBox(height: 12),
            _Labelled(
              label: 'Powód',
              child: TextFormField(
                key: const Key('field-reason'),
                controller: _reasonController,
                maxLines: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label.toUpperCase(), style: _fieldLabel),
        SizedBox(width: 120, child: child),
      ],
    ),
  );
}
