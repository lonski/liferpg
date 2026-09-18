import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/change_request.dart';
import 'styled_fields.dart';
import 'trait_change_field.dart';

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
  TraitChange? _trait;

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
    // Only one trait is editable through this form; an `initial` carrying
    // more than one (from before this change was single-trait) only shows
    // the first -- see the design note in the design doc.
    _trait = initial?.traits.isNotEmpty == true ? initial!.traits.first : null;
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
    traits: _trait == null ? const [] : [_trait!],
  );

  void _emit() {
    final reason = _reasonController.text.trim();
    widget.onChanged(_changes, reason.isEmpty ? null : reason);
  }

  void _onTraitChanged(TraitChange? trait) {
    setState(() => _trait = trait);
    _emit();
  }

  // A bordered "plaque" with a stepper on either side of the value, so the
  // sign is chosen by tapping -/+ rather than typed (the numeric keyboard has
  // no + key). The value still stays freely editable by tapping into it.
  Widget _deltaField(String key, {required bool decimal}) => stepperField(
    fieldKey: Key('field-$key'),
    controller: _controllers[key]!,
    stepSize: stepSize,
    decimal: decimal,
    iconSize: 36,
    validator: (v) => validateOptionalDelta(v, decimal: decimal),
  );

  @override
  Widget build(BuildContext context) {
    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Labelled(
            label: 'XP',
            width: stepperWidth,
            child: _deltaField('current_xp', decimal: false),
          ),
          _Labelled(
            label: 'Złoto',
            width: stepperWidth,
            child: _deltaField('gold', decimal: true),
          ),
          const SizedBox(height: 12),
          TraitChangeField(initial: _trait, onChanged: _onTraitChanged),
          if (widget.showReason) ...[
            const SizedBox(height: 12),
            Text('Powód'.toUpperCase(), style: fieldLabel),
            const SizedBox(height: 6),
            boxedField(
              key: const Key('field-reason'),
              controller: _reasonController,
              maxLines: 2,
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
        Text(label.toUpperCase(), style: fieldLabel),
        SizedBox(width: width, child: child),
      ],
    ),
  );
}
