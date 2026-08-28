import 'package:flutter/material.dart';

import 'app_theme.dart';

const TextStyle dialogActionStyle = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 2,
);

/// A parchment-surfaced yes/no confirmation, styled like the app's other
/// admin dialogs (crimson-bordered parchment card, gold-glyph confirm
/// button) so a confirm step never reads as a foreign widget dropped onto
/// the dark scaffold. Returns `true` only if [confirmKey]'s button was
/// tapped; `false` for "cancel" or dismissing the dialog any other way.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String cancelLabel,
  required String confirmLabel,
  required Key confirmKey,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: parchment,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: crimson, width: 2),
      ),
      title: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: fontDisplay,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: inkHeading,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(foregroundColor: crimson),
          child: Text(cancelLabel.toUpperCase(), style: dialogActionStyle),
        ),
        TextButton(
          key: confirmKey,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            backgroundColor: crimson,
            foregroundColor: parchmentLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
              side: const BorderSide(color: goldGlyph),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: Text(confirmLabel.toUpperCase(), style: dialogActionStyle),
        ),
      ],
    ),
  );
  return result ?? false;
}
