import 'package:flutter/material.dart';

import 'app_theme.dart';

TextStyle dialogActionStyle(BuildContext context) => TextStyle(
  fontFamily: context.rpg.fontDisplay,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 2,
);

/// A parchment-surfaced yes/no confirmation, styled like the app's other
/// admin dialogs (crimson-bordered parchment card, gold-glyph confirm
/// button) so a confirm step never reads as a foreign widget dropped onto
/// the dark scaffold. Returns `true` only if [confirmKey]'s button was
/// tapped; `false` for "cancel" or dismissing the dialog any other way.
/// [message], when given, is shown as the dialog's body.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String cancelLabel,
  required String confirmLabel,
  required Key confirmKey,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: context.rpg.parchment,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rpg.cardRadius),
        side: BorderSide(color: context.rpg.crimson, width: context.rpg.cardBorderWidth),
      ),
      title: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: context.rpg.fontDisplay,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: context.rpg.inkHeading,
        ),
      ),
      content: message == null
          ? null
          : Text(
              message,
              style: TextStyle(
                fontFamily: context.rpg.fontBody,
                fontSize: 13,
                height: 1.5,
                color: context.rpg.inkDark,
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(foregroundColor: context.rpg.crimson),
          child: Text(cancelLabel.toUpperCase(), style: dialogActionStyle(context)),
        ),
        TextButton(
          key: confirmKey,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            backgroundColor: context.rpg.crimson,
            foregroundColor: context.rpg.parchmentLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.rpg.buttonRadius),
              side: BorderSide(color: context.rpg.goldGlyph),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: Text(confirmLabel.toUpperCase(), style: dialogActionStyle(context)),
        ),
      ],
    ),
  );
  return result ?? false;
}
