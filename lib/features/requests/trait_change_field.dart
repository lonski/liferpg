import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/change_request.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';
import 'styled_fields.dart';

/// A single optional trait delta, collapsed by default behind an "Dodaj
/// zmianę cechy" button so a user can't accidentally add several -- only one
/// trait may be changed per request/reward. Tapping the button reveals the
/// name (autocompleted from [traitNamesProvider], still free text so a new
/// trait name can be introduced) and value fields; a remove button collapses
/// back to just the button and clears the selection. Shared by
/// [ChangeRequestForm] and [NewQuestScreen].
class TraitChangeField extends ConsumerStatefulWidget {
  const TraitChangeField({super.key, this.initial, required this.onChanged});

  final TraitChange? initial;
  final ValueChanged<TraitChange?> onChanged;

  @override
  ConsumerState<TraitChangeField> createState() => _TraitChangeFieldState();
}

class _TraitChangeFieldState extends ConsumerState<TraitChangeField> {
  late bool _expanded;
  final _valueController = TextEditingController();
  // Owned by the Autocomplete below, not by us: we capture the instance it
  // hands to fieldViewBuilder so we can read/clear/listen to it. Same
  // arrangement as EditCharacterScreen. Must not be disposed here.
  TextEditingController? _nameController;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initial != null;
    _valueController.text = widget.initial?.value ?? '';
    _valueController.addListener(_emit);
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _emit() {
    if (!_expanded) {
      widget.onChanged(null);
      return;
    }
    final name = (_nameController?.text ?? widget.initial?.name ?? '').trim();
    // An empty value is a legitimate trait delta; an empty name is not.
    if (name.isEmpty) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(
      TraitChange(name: name, value: _valueController.text.trim()),
    );
  }

  void _expand() {
    setState(() => _expanded = true);
    _emit();
  }

  void _collapse() {
    setState(() {
      _expanded = false;
      _valueController.clear();
    });
    _nameController?.clear();
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('add-trait-button'),
          onPressed: _expand,
          icon: const Icon(Icons.add, color: crimson, size: 16),
          label: Text('Dodaj zmianę cechy'.toUpperCase(), style: fieldLabel),
        ),
      );
    }

    final traitNames = ref.watch(traitNamesProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Autocomplete<String>(
                initialValue: TextEditingValue(
                  text: widget.initial?.name ?? '',
                ),
                optionsBuilder: (value) {
                  final text = value.text.trim().toLowerCase();
                  if (text.isEmpty) return traitNames;
                  return traitNames.where(
                    (n) => n.toLowerCase().contains(text),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(4),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Text(
                                  option,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: inkHeading,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      if (_nameController != controller) {
                        _nameController = controller;
                        controller.addListener(_emit);
                      }
                      return boxedField(
                        key: const Key('trait-name'),
                        controller: controller,
                        focusNode: focusNode,
                        suffixIcon: const Icon(
                          Icons.expand_more,
                          size: 16,
                          color: crimson,
                        ),
                      );
                    },
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('Nazwa cechy'.toUpperCase(), style: captionLabel),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              stepperField(
                fieldKey: const Key('trait-value'),
                controller: _valueController,
                stepSize: 1,
                iconSize: 32,
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('Wartość'.toUpperCase(), style: captionLabel),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: IconButton(
            key: const Key('remove-trait'),
            tooltip: 'Usuń',
            icon: const Icon(Icons.close, color: crimson),
            onPressed: _collapse,
          ),
        ),
      ],
    );
  }
}
