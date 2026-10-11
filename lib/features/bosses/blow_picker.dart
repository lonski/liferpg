import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/boss.dart';
import '../../theme/app_theme.dart';
import 'boss_art.dart';

const _roman = ['I', 'II', 'III', 'IV'];

/// Asks which blow to strike with: an open spellbook for the księga, a
/// sheet for every other weapon. Null when dismissed.
Future<Blow?> pickBlow(
  BuildContext context, {
  required Weapon weapon,
  required int energy,
  Blow? current,
}) {
  if (weapon == Weapon.ksiega) {
    return showGeneralDialog<Blow>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Zamknij księgę',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, _, _) => SpellbookView(energy: energy, current: current),
      transitionBuilder: (_, animation, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }
  return showModalBottomSheet<Blow>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => BlowSheet(weapon: weapon, energy: energy, current: current),
  );
}

/// The four blows of an ordinary weapon, cheapest first.
class BlowSheet extends StatelessWidget {
  const BlowSheet({
    super.key,
    required this.weapon,
    required this.energy,
    this.current,
  });

  final Weapon weapon;
  final int energy;
  final Blow? current;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    return Container(
      decoration: BoxDecoration(
        gradient: t.cardGradient,
        border: Border(top: BorderSide(color: t.crimson, width: 3)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: t.crimsonBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WeaponIcon(weapon, size: 22, color: t.crimson),
                const SizedBox(width: 8),
                Text(
                  'Wybierz cios'.toUpperCase(),
                  style: TextStyle(
                    fontFamily: t.fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: 3,
                    color: t.crimson,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '⚡ $energy energii bojowej',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: t.fontBody,
                fontSize: 14,
                color: t.inkHeading,
              ),
            ),
            const SizedBox(height: 10),
            for (final blow in weapon.blows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BlowTile(
                  blow: blow,
                  energy: energy,
                  selected: current?.name == blow.name,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BlowTile extends StatelessWidget {
  const _BlowTile({
    required this.blow,
    required this.energy,
    required this.selected,
  });

  final Blow blow;
  final int energy;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    final missing = blow.tier.cost - energy;
    final locked = missing > 0;
    final fg = selected ? t.parchmentLight : t.inkHeading;
    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: Material(
        color: selected ? t.crimson : t.crimsonBgFaint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? t.crimsonDeep : t.crimsonBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          key: Key('blow-${blow.tier.name}'),
          borderRadius: BorderRadius.circular(10),
          onTap: locked ? null : () => Navigator.of(context).pop(blow),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: t.arena.weaponFill,
                    border: Border.all(color: t.arena.weaponBorder),
                  ),
                  child: Text(
                    _roman[blow.tier.index],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: t.arena.weaponInk,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        blow.name,
                        style: TextStyle(
                          fontFamily: t.fontBody,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: fg,
                        ),
                      ),
                      Text(
                        locked
                            ? '${blow.tier.kind} · brakuje $missing energii'
                            : blow.tier.kind,
                        style: TextStyle(
                          fontFamily: t.fontBody,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${blow.tier.cost} ⚡',
                      style: TextStyle(fontWeight: FontWeight.w700, color: fg),
                    ),
                    Text(
                      '−${blow.tier.damage} HP',
                      style: TextStyle(fontWeight: FontWeight.w700, color: fg),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The spellbook: one spell per two-page spread, turned with arrows or
/// dots. A spell the character cannot afford is sealed.
class SpellbookView extends StatefulWidget {
  const SpellbookView({super.key, required this.energy, this.current});

  final int energy;
  final Blow? current;

  @override
  State<SpellbookView> createState() => _SpellbookViewState();
}

class _SpellbookViewState extends State<SpellbookView> {
  static final _spells = Weapon.ksiega.blows;
  late int _page;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    final current = _spells.indexWhere((b) => b.name == widget.current?.name);
    // Open on the chosen spell, else the strongest one the energy pays for.
    _page = current >= 0
        ? current
        : math.max(
            0,
            _spells.lastIndexWhere((b) => b.tier.cost <= widget.energy),
          );
  }

  void _go(int page) {
    if (page < 0 || page >= _spells.length || page == _page) return;
    setState(() {
      _forward = page > _page;
      _page = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    final a = t.arena;
    final keeper = t.decor.spellbookKeeper(context);
    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '✦  ${'Księga zaklęć'.toUpperCase()}  ✦',
                  style: TextStyle(
                    fontFamily: t.fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: 4,
                    color: a.overlayTitle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '⚡ ${widget.energy} energii bojowej',
                  style: TextStyle(
                    fontFamily: t.fontBody,
                    fontSize: 14,
                    color: a.overlayTitle,
                  ),
                ),
                SizedBox(height: keeper == null ? 14 : 44),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _cover(context),
                      if (keeper != null)
                        Positioned(
                          top: -42,
                          right: 18,
                          child: IgnorePointer(child: keeper),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _navButton(
                      context,
                      Icons.chevron_left,
                      'Poprzednia strona',
                      _page > 0 ? () => _go(_page - 1) : null,
                    ),
                    const SizedBox(width: 14),
                    for (var i = 0; i < _spells.length; i++)
                      GestureDetector(
                        onTap: () => _go(i),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _page
                                  ? a.overlayTitle
                                  : Colors.transparent,
                              border: Border.all(
                                color: a.overlayTitle,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 14),
                    _navButton(
                      context,
                      Icons.chevron_right,
                      'Następna strona',
                      _page < _spells.length - 1 ? () => _go(_page + 1) : null,
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Zamknij księgę'.toUpperCase(),
                    style: TextStyle(
                      fontFamily: t.fontDisplay,
                      fontSize: 12,
                      letterSpacing: 3,
                      color: a.overlayTitle,
                      decoration: TextDecoration.underline,
                      decorationColor: a.overlayTitle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback? onTap,
  ) {
    final a = context.rpg.arena;
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Tooltip(
        message: tooltip,
        child: Material(
          shape: CircleBorder(
            side: BorderSide(color: a.buttonBorder, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(gradient: a.buttonFill),
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(icon, color: a.buttonInk),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cover(BuildContext context) {
    final t = context.rpg;
    final a = t.arena;
    final radius = t.cardRadius + 6;
    final spread = AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(_page);
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            // The new spread swings in about the spine; the old one fades.
            final turn = (1 - animation.value) * (_forward ? -1.2 : 1.2);
            return Opacity(
              opacity: animation.value.clamp(0, 1),
              child: incoming
                  ? Transform(
                      alignment: _forward
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(turn),
                      child: child,
                    )
                  : child,
            );
          },
        );
      },
      child: _Spread(
        key: ValueKey(_page),
        blow: _spells[_page],
        energy: widget.energy,
      ),
    );
    final inner = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: spread,
    );
    return Container(
      decoration: BoxDecoration(
        gradient: a.bookCover,
        borderRadius: BorderRadius.circular(radius),
        border: a.bookStitched
            ? null
            : Border.all(color: a.bookFrame, width: 2),
        boxShadow: [
          BoxShadow(
            color: t.dialogShadowColor,
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: a.bookStitched
          ? DashedFrame(
              color: a.bookFrame,
              radius: radius - 6,
              child: Padding(padding: const EdgeInsets.all(7), child: inner),
            )
          : inner,
    );
  }
}

class _Spread extends StatelessWidget {
  const _Spread({super.key, required this.blow, required this.energy});

  final Blow blow;
  final int energy;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    final a = t.arena;
    final missing = blow.tier.cost - energy;
    final locked = missing > 0;
    BoxDecoration page(bool left) => BoxDecoration(
      gradient: a.bookPaper,
      boxShadow: [
        BoxShadow(
          color: a.bookSigil.withValues(alpha: 0.35),
          blurRadius: 12,
          spreadRadius: -6,
          offset: Offset(left ? 10 : -10, 0),
        ),
      ],
    );
    final body = TextStyle(
      fontFamily: t.fontBody,
      fontSize: 14,
      color: a.bookInk,
    );
    return SizedBox(
      height: 320,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: page(true),
              padding: const EdgeInsets.all(10),
              child: Stack(
                children: [
                  Text(
                    _roman[blow.tier.index],
                    style: TextStyle(
                      fontFamily: t.fontDisplay,
                      fontWeight: FontWeight.w700,
                      color: a.bookSigil,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Glow(
                          on: !locked,
                          child: SpellSigil(
                            tier: blow.tier,
                            weapon: Weapon.ksiega,
                            ink: a.bookSigil,
                            size: 124,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          blow.tier.kind.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: t.fontDisplay,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 2.5,
                            color: a.bookSigil,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: page(false),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    blow.name,
                    style: TextStyle(
                      fontFamily: t.fontDisplay,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      height: 1.1,
                      color: a.bookTitle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    blow.flavor,
                    style: body.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.3,
                    ),
                  ),
                  const Spacer(),
                  _Stat(
                    label: 'Koszt',
                    value: '⚡ ${blow.tier.cost}',
                    style: body,
                  ),
                  _Stat(
                    label: 'Obrażenia',
                    value: '−${blow.tier.damage} HP',
                    style: body,
                    valueColor: a.bookDamage,
                  ),
                  const SizedBox(height: 8),
                  if (locked)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: a.bookDamage.withValues(alpha: 0.6),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          t.decor.spellbookSeal(context),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${t.decor.sealedSpellLabel}\n',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: 'brakuje $missing energii'),
                                ],
                              ),
                              style: body.copyWith(
                                fontSize: 12,
                                height: 1.2,
                                color: a.bookDamage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ArenaButton(
                      key: Key('spell-${blow.tier.name}'),
                      label: 'Wybierz zaklęcie',
                      onTap: () => Navigator.of(context).pop(blow),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Koszt ⚡ 10" on a book page: the value never wraps, the label gives way.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.style,
    this.valueColor,
  });

  final String label;
  final String value;
  final TextStyle style;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Text(
        value,
        style: style.copyWith(fontWeight: FontWeight.w700, color: valueColor),
      ),
    ],
  );
}

class _Glow extends StatefulWidget {
  const _Glow({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.on && BossMotion.loops) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) return Opacity(opacity: 0.55, child: widget.child);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: spellSpark.withValues(alpha: 0.25 + 0.35 * _c.value),
              blurRadius: 10 + 14 * _c.value,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// A button in the book or the arena, in the theme's arena colours.
class ArenaButton extends StatelessWidget {
  const ArenaButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    final a = t.arena;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(t.buttonRadius),
      side: BorderSide(color: a.buttonBorder, width: 1.5),
    );
    return Material(
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(gradient: a.buttonFill),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: t.fontDisplay,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 2,
                color: a.buttonInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
