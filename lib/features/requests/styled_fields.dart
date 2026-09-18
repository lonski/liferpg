import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Field styling shared by [ChangeRequestForm] (lib/features/requests/
/// change_request_form.dart) and [TraitChangeField] (lib/features/requests/
/// trait_change_field.dart) -- the two places that render the crimson-boxed
/// stepper/text fields used for XP, gold and trait deltas.

const TextStyle fieldLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 12,
  letterSpacing: 2,
  color: crimson,
);

// The small, always-visible caption under a trait box (name/value). Distinct
// from fieldLabel (smaller, wider tracked) so it reads as a caption, not
// another field label -- and distinct in both font and colour from the boxed
// value text it sits under, so it can never be mistaken for a typed value.
const TextStyle captionLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 9,
  letterSpacing: 1.5,
  color: crimson,
);

const TextStyle errorStyle = TextStyle(fontSize: 10, color: crimsonBright);

// XP/gold/trait stepper nudge size. Typing an exact value still works (the
// field stays freely editable) -- this is just the tap-to-adjust increment.
const int stepSize = 5;

const double stepperWidth = 140;

// enabledBorder/focusedBorder/errorBorder/focusedErrorBorder must each be set
// explicitly: the app theme's InputDecorationTheme sets those directly (not
// just `border`), and those take precedence over an InputDecoration's own
// `border` -- setting only `border` here left the themed underline showing
// through regardless. Routing the border through OutlineInputBorder (rather
// than a wrapping Container) also means Flutter lays the error caption out
// *below* the box, not enclosed inside it.
OutlineInputBorder fieldBorder({Color color = crimsonBorderStrong}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color, width: 1.5),
    );

/// Deltas may be negative, so unlike the character editor these accept a
/// leading minus. Empty means "no change to this field", never zero.
String? validateOptionalDelta(String? value, {required bool decimal}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final parsed = decimal ? num.tryParse(text) : int.tryParse(text);
  return parsed == null ? 'Podaj liczbę' : null;
}

void stepValue(TextEditingController controller, num delta) {
  final current = num.tryParse(controller.text.trim()) ?? 0;
  final next = current + delta;
  controller.text = next % 1 == 0 ? next.toInt().toString() : '$next';
}

Widget stepButton(IconData icon, VoidCallback onPressed) => IconButton(
  icon: Icon(icon, size: 16, color: crimson),
  onPressed: onPressed,
  visualDensity: VisualDensity.compact,
  padding: EdgeInsets.zero,
);

// A bordered "plaque" with a stepper on either side of the value, so the
// sign is chosen by tapping -/+ rather than typed (the numeric keyboard has
// no + key). The value still stays freely editable by tapping into it.
// Colour reflects the sign so a gain/reduction reads at a glance. The
// minus/plus buttons ride inside the field's own border as prefix/suffix
// icons, so the whole capsule -- buttons included -- is one bordered box.
Widget stepperField({
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
          enabledBorder: fieldBorder(),
          focusedBorder: fieldBorder(color: crimsonBright),
          errorBorder: fieldBorder(),
          focusedErrorBorder: fieldBorder(color: crimsonBright),
          errorStyle: errorStyle,
          prefixIcon: stepButton(
            Icons.remove,
            () => stepValue(controller, -stepSize),
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: iconSize,
            minHeight: iconSize,
          ),
          suffixIcon: stepButton(
            Icons.add,
            () => stepValue(controller, stepSize),
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

Widget boxedField({
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
    enabledBorder: fieldBorder(),
    focusedBorder: fieldBorder(color: crimsonBright),
    errorBorder: fieldBorder(),
    focusedErrorBorder: fieldBorder(color: crimsonBright),
    errorStyle: errorStyle,
    suffixIcon: suffixIcon,
    suffixIconConstraints: suffixIcon == null
        ? null
        : const BoxConstraints(minWidth: 28, minHeight: 28),
  ),
);
