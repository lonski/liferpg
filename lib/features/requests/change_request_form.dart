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

// The small, always-visible caption under a trait box (name/value). Distinct
// from _fieldLabel (smaller, wider tracked) so it reads as a caption, not
// another field label -- and distinct in both font and colour from the boxed
// value text it sits under, so it can never be mistaken for a typed value.
const TextStyle _captionLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 9,
  letterSpacing: 1.5,
  color: crimson,
);

const TextStyle _errorStyle = TextStyle(fontSize: 10, color: crimsonBright);

// XP/gold stepper nudge size. Typing an exact value still works (the field
// stays freely editable) -- this is just the tap-to-adjust increment.
const int _stepSize = 5;

const double _stepperWidth = 140;

// enabledBorder/focusedBorder/errorBorder/focusedErrorBorder must each be set
// explicitly: the app theme's InputDecorationTheme sets those directly (not
// just `border`), and those take precedence over an InputDecoration's own
// `border` -- setting only `border` here left the themed underline showing
// through regardless. Routing the border through OutlineInputBorder (rather
// than a wrapping Container) also means Flutter lays the error caption out
// *below* the box, not enclosed inside it.
OutlineInputBorder _fieldBorder({Color color = crimsonBorderStrong}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color, width: 1.5),
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
    traits: _traits,
  );

  void _emit() {
    final reason = _reasonController.text.trim();
    widget.onChanged(_changes, reason.isEmpty ? null : reason);
  }

  void _step(TextEditingController controller, num delta) {
    final current = num.tryParse(controller.text.trim()) ?? 0;
    final next = current + delta;
    controller.text = next % 1 == 0 ? next.toInt().toString() : '$next';
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
    // Clearing the name field while it's still focused would otherwise
    // immediately reopen the suggestions dropdown (empty text matches every
    // known trait name).
    FocusScope.of(context).unfocus();
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

  // A bordered "plaque" with a stepper on either side of the value, so the
  // sign is chosen by tapping -/+ rather than typed (the numeric keyboard has
  // no + key). The value still stays freely editable by tapping into it.
  // Colour reflects the sign so a gain/reduction reads at a glance. The
  // minus/plus buttons ride inside the field's own border as prefix/suffix
  // icons, so the whole capsule -- buttons included -- is one bordered box.
  Widget _deltaField(String key, {required bool decimal}) => _stepperField(
    fieldKey: Key('field-$key'),
    controller: _controllers[key]!,
    stepSize: _stepSize,
    decimal: decimal,
    iconSize: 36,
    validator: (v) => _validateOptionalDelta(v, decimal: decimal),
  );

  Widget _stepperField({
    required Key fieldKey,
    required TextEditingController controller,
    required int stepSize,
    bool decimal = false,
    double iconSize = 32,
    String? Function(String?)? validator,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final parsed = num.tryParse(controller.text.trim());
        final valueColor = parsed == null || parsed == 0
            ? inkHeading
            : parsed > 0
            ? gold
            : crimsonBright;
        return TextFormField(
          key: fieldKey,
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(
            decimal: decimal,
            signed: true,
          ),
          validator: validator,
          style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: parchmentLight,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: _fieldBorder(),
            focusedBorder: _fieldBorder(color: crimsonBright),
            errorBorder: _fieldBorder(),
            focusedErrorBorder: _fieldBorder(color: crimsonBright),
            errorStyle: _errorStyle,
            prefixIcon: _stepButton(
              Icons.remove,
              () => _step(controller, -stepSize),
            ),
            prefixIconConstraints: BoxConstraints(
              minWidth: iconSize,
              minHeight: iconSize,
            ),
            suffixIcon: _stepButton(
              Icons.add,
              () => _step(controller, stepSize),
            ),
            suffixIconConstraints: BoxConstraints(
              minWidth: iconSize,
              minHeight: iconSize,
            ),
          ),
        );
      },
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onPressed) => IconButton(
    icon: Icon(icon, size: 16, color: crimson),
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
  );

  Widget _boxedField({
    required Key key,
    required TextEditingController controller,
    FocusNode? focusNode,
    int maxLines = 1,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) => TextFormField(
    key: key,
    controller: controller,
    focusNode: focusNode,
    maxLines: maxLines,
    validator: validator,
    style: const TextStyle(color: inkHeading, fontSize: 14),
    decoration: InputDecoration(
      isDense: true,
      filled: true,
      fillColor: parchmentLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      enabledBorder: _fieldBorder(),
      focusedBorder: _fieldBorder(color: crimsonBright),
      errorBorder: _fieldBorder(),
      focusedErrorBorder: _fieldBorder(color: crimsonBright),
      errorStyle: _errorStyle,
      suffixIcon: suffixIcon,
      suffixIconConstraints: suffixIcon == null
          ? null
          : const BoxConstraints(minWidth: 28, minHeight: 28),
    ),
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
            width: _stepperWidth,
            child: _deltaField('current_xp', decimal: false),
          ),
          _Labelled(
            label: 'Złoto',
            width: _stepperWidth,
            child: _deltaField('gold', decimal: true),
          ),
          const SizedBox(height: 12),
          Text('Cechy'.toUpperCase(), style: _fieldLabel),
          const SizedBox(height: 6),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Autocomplete<String>(
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
                            _traitNameController = controller;
                            return _boxedField(
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
                      child: Text(
                        'Nazwa cechy'.toUpperCase(),
                        style: _captionLabel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _stepperField(
                      fieldKey: const Key('trait-value'),
                      controller: _newTraitValue,
                      stepSize: 1,
                      iconSize: 32,
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Wartość'.toUpperCase(),
                        style: _captionLabel,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: IconButton(
                  key: const Key('add-trait'),
                  tooltip: 'Dodaj cechę',
                  icon: const Icon(Icons.add, color: crimson),
                  onPressed: _addTrait,
                ),
              ),
            ],
          ),
          if (widget.showReason) ...[
            const SizedBox(height: 12),
            _Labelled(
              label: 'Powód',
              width: _stepperWidth,
              child: _boxedField(
                key: const Key('field-reason'),
                controller: _reasonController,
                maxLines: 2,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Podaj powód' : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child, this.width = 120});

  final String label;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label.toUpperCase(), style: _fieldLabel),
        SizedBox(width: width, child: child),
      ],
    ),
  );
}
