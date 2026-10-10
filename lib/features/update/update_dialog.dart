import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/update_info.dart';
import '../../providers/update_download_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/dialogs.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.info});

  final UpdateInfo info;

  static Future<void> show(BuildContext context, UpdateInfo info) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(info: info),
      );

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(updateDownloadControllerProvider.notifier)
          .retryAfterSettings(widget.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateDownloadControllerProvider);

    ref.listen<UpdateDownloadState>(updateDownloadControllerProvider,
        (previous, next) {
      if (next is UpdateDownloadInstallerLaunched) {
        Navigator.of(context).pop();
      }
    });

    return AlertDialog(
      scrollable: true,
      backgroundColor: context.rpg.parchment,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rpg.cardRadius),
        side: BorderSide(color: context.rpg.crimson, width: context.rpg.cardBorderWidth),
      ),
      title: Text(
        'Nowa wersja dostępna'.toUpperCase(),
        style: TextStyle(
          fontFamily: context.rpg.fontDisplay,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: context.rpg.inkHeading,
        ),
      ),
      content: _content(state),
      actions: _actions(context, state),
    );
  }

  Widget _content(UpdateDownloadState state) {
    return switch (state) {
      UpdateDownloadIdle() => Text(
          'Wersja ${widget.info.version}\n\n${widget.info.releaseNotes}',
          style: TextStyle(color: context.rpg.inkHeading),
        ),
      UpdateDownloadNeedsPermission() => Text(
          'Aby zainstalować aktualizację, zezwól na instalowanie z tego '
          'źródła.',
          style: TextStyle(color: context.rpg.inkHeading),
        ),
      UpdateDownloadInProgress(:final received, :final total) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: (total != null && total > 0) ? received / total : null,
              color: context.rpg.crimson,
            ),
            const SizedBox(height: 8),
            Text(
              'Pobieranie aktualizacji...',
              style: TextStyle(color: context.rpg.inkHeading),
            ),
          ],
        ),
      UpdateDownloadInstalling() => Text(
          'Otwieranie instalatora...',
          style: TextStyle(color: context.rpg.inkHeading),
        ),
      UpdateDownloadInstallerLaunched() => Text(
          'Otwieranie instalatora...',
          style: TextStyle(color: context.rpg.inkHeading),
        ),
      UpdateDownloadFailed(:final message) =>
        Text(message, style: TextStyle(color: context.rpg.inkHeading)),
    };
  }

  List<Widget> _actions(BuildContext context, UpdateDownloadState state) {
    final controller = ref.read(updateDownloadControllerProvider.notifier);
    final later = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      style: TextButton.styleFrom(foregroundColor: context.rpg.crimson),
      child: Text('Później'.toUpperCase(), style: dialogActionStyle(context)),
    );
    Widget primary(String label, VoidCallback onPressed) => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: context.rpg.crimson,
            foregroundColor: context.rpg.parchmentLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
              side: BorderSide(color: context.rpg.goldGlyph),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: Text(label.toUpperCase(), style: dialogActionStyle(context)),
        );

    return switch (state) {
      UpdateDownloadIdle() => [
          later,
          primary('Zaktualizuj teraz', () => controller.start(widget.info)),
        ],
      UpdateDownloadNeedsPermission() => [
          later,
          primary('Otwórz ustawienia', () => controller.openSettings()),
        ],
      UpdateDownloadFailed() => [
          later,
          primary(
            'Spróbuj ponownie',
            () => controller.retryDownload(widget.info),
          ),
        ],
      UpdateDownloadInProgress() ||
      UpdateDownloadInstalling() ||
      UpdateDownloadInstallerLaunched() =>
        const [],
    };
  }
}
