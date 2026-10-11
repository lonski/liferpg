import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/boss.dart';
import '../../models/character.dart';
import '../../data/boss_repository.dart';
import '../../providers/boss_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/dialogs.dart';
import '../../theme/ornaments.dart';
import 'blow_picker.dart';
import 'boss_art.dart';
import 'hero_art.dart';

const double _floorHeight = 176;
const double _bossSize = 108;

/// A boss under [character]'s card. While it lives it walks the floor. For
/// [canFight] (the character's owner) the character stands on the floor too:
/// a tap on the ground walks it there, and with a blow picked a tap on the
/// boss sends it in -- up close for a sword, club or broom, from where it
/// stands for a bow or the spellbook -- to play the blow out. Once the boss
/// is beaten the arena turns into the victory panel with the reward.
class BossArena extends ConsumerStatefulWidget {
  const BossArena({
    super.key,
    required this.boss,
    required this.character,
    required this.canFight,
    required this.isAdmin,
  });

  final Boss boss;
  final Character character;
  final bool canFight;
  final bool isAdmin;

  @override
  ConsumerState<BossArena> createState() => _BossArenaState();
}

/// A blow being played out: the hero walks up (melee), then the timeline
/// runs from 0 to 1.
class _Fight {
  _Fight(
    this.blow,
    this.weapon, {
    required this.approaching,
    required this.hpBefore,
  });

  final Blow blow;
  final Weapon weapon;
  bool approaching;
  final int hpBefore;
  double t = 0;
  int hitsFelt = 0;
}

class _BossArenaState extends ConsumerState<BossArena>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  /// Repaints the scene each frame without rebuilding the whole arena.
  final _frame = ValueNotifier<int>(0);

  double _width = 360;
  double _bossPhase = 0;
  double _heroX = 8;
  double _heroTargetX = 8;
  double _stride = 0;
  bool _heroRight = true;
  _Fight? _fight;

  Blow? _picked;
  bool _joinTried = false;
  bool _claiming = false;

  Boss get boss => widget.boss;
  Character get character => widget.character;
  Weapon? get weapon => weaponOf(character);

  static const double _heroSpeed = 150; // px per second

  @override
  void initState() {
    super.initState();
    _wake();
    _joinIfNeeded();
  }

  @override
  void didUpdateWidget(BossArena old) {
    super.didUpdateWidget(old);
    _wake();
    _joinIfNeeded();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  bool get _bossWalking => boss.isActive && BossMotion.loops && _fight == null;
  bool get _heroMoving => (_heroX - _heroTargetX).abs() > 0.5;

  /// Runs the frame loop only while something moves, so an idle arena (and
  /// a widget test) can settle.
  void _wake() {
    final busy = _bossWalking || _heroMoving || _fight != null;
    if (busy && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!busy && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_bossWalking) _bossPhase = (_bossPhase + dt / 9) % 1;

    if (_heroMoving) {
      final step = math.min((_heroTargetX - _heroX).abs(), _heroSpeed * dt);
      _heroRight = _heroTargetX > _heroX;
      _heroX += _heroRight ? step : -step;
      _stride += step;
    }

    final fight = _fight;
    if (fight != null) {
      if (fight.approaching) {
        if (!_heroMoving) {
          fight.approaching = false;
          _faceBoss();
        }
      } else {
        fight.t += dt * 1000 / fightDuration(fight.blow.tier).inMilliseconds;
        final hits = hitsFor(fight.blow.tier);
        while (fight.hitsFelt < hits.length &&
            fight.t >= hits[fight.hitsFelt]) {
          fight.hitsFelt++;
          HapticFeedback.mediumImpact();
        }
        if (fight.t >= 1) _finishFight();
      }
    }
    _frame.value++;
    _wake();
  }

  /// The boss's box on the floor this frame.
  Rect get _bossRect {
    final travel = math.max(0.0, _width - _bossSize - 16);
    final x = 8 + travel * (0.5 + 0.5 * math.sin(_bossPhase * 2 * math.pi));
    return Rect.fromLTWH(x, _floorHeight - _bossSize - 4, _bossSize, _bossSize);
  }

  void _faceBoss() =>
      _heroRight = _bossRect.center.dx > _heroX + heroSize.width / 2;

  /// A character created after the boss appeared gets its baseline now, so
  /// XP it earns from here on charges its energy.
  void _joinIfNeeded() {
    // Tried once per arena: a refused write must not retry on every rebuild.
    if (_joinTried || !widget.canFight || !boss.isActive) return;
    if (boss.baseline.containsKey(character.id)) return;
    _joinTried = true;
    ref.read(bossRepositoryProvider).join(boss.id, character.id).catchError((
      Object e,
    ) {
      debugPrint('Joining boss ${boss.id} failed: $e');
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openPicker() async {
    final w = weapon;
    if (w == null || _fight != null) return;
    final blow = await pickBlow(
      context,
      weapon: w,
      energy: boss.energyOf(character) ?? 0,
      current: _picked,
    );
    if (blow != null && mounted) setState(() => _picked = blow);
  }

  /// A tap on the empty floor walks the hero there.
  void _walkTo(double x) {
    if (!widget.canFight || _fight != null) return;
    _heroTargetX = (x - heroSize.width / 2).clamp(
      0.0,
      math.max(0.0, _width - heroSize.width),
    );
    _wake();
  }

  /// A tap on the boss: with a blow picked, the hero goes for it.
  void _strike() {
    if (!widget.canFight || _fight != null || !boss.isActive) return;
    final w = weapon;
    final blow = _picked;
    if (w == null) return;
    if (blow == null) {
      _openPicker();
      return;
    }
    final energy = boss.energyOf(character) ?? 0;
    if (energy < blow.tier.cost) {
      _snack('Za mało energii bojowej na „${blow.name}”');
      setState(() => _picked = null);
      return;
    }
    // The boss stops where it stands while it is being fought.
    final target = _bossRect;
    if (isMelee(w)) {
      final fromLeft = _heroX + heroSize.width / 2 < target.center.dx;
      final x = fromLeft
          ? target.left - heroSize.width + 22
          : target.right - 22;
      _heroTargetX = x.clamp(0.0, math.max(0.0, _width - heroSize.width));
    } else {
      _heroTargetX = _heroX;
    }
    _fight = _Fight(blow, w, approaching: _heroMoving, hpBefore: boss.hp);
    if (!_heroMoving) _faceBoss();
    setState(() {});
    _wake();
    ref
        .read(bossRepositoryProvider)
        .attack(
          bossId: boss.id,
          characterId: character.id,
          characterName: character.name,
          tier: blow.tier,
        )
        .catchError((Object e) {
          _snack('Cios nieudany: $e');
          return const AttackOutcome(damage: 0, hp: 0, defeated: false);
        });
  }

  void _finishFight() {
    final blow = _fight?.blow;
    _fight = null;
    if (!mounted) return;
    setState(() {
      final left = boss.energyOf(character) ?? 0;
      if (blow != null && left < blow.tier.cost) _picked = null;
    });
  }

  /// The HP the header shows: until the blow lands on screen, the boss
  /// keeps the HP it had when it was struck.
  int get _shownHp {
    final fight = _fight;
    if (fight == null) return boss.hp;
    return fight.t < hitsFor(fight.blow.tier).first ? fight.hpBefore : boss.hp;
  }

  Future<void> _cancelBoss() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Odwołać bossa?',
      message:
          '${boss.name} zniknie spod kart postaci. Nikt nie dostanie nagrody.',
      cancelLabel: 'Zostaw',
      confirmLabel: 'Odwołaj',
      confirmKey: const Key('confirm-cancel-boss'),
    );
    if (!ok) return;
    try {
      await ref.read(bossRepositoryProvider).cancel(boss.id);
    } catch (e) {
      _snack('Nie udało się odwołać: $e');
    }
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    try {
      final reward = await ref
          .read(bossRepositoryProvider)
          .claimReward(boss.id, character.id);
      if (mounted) await _showClaimed(reward);
    } catch (e) {
      _snack('Nie udało się odebrać nagrody: $e');
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _showClaimed(BossReward reward) => showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final t = dialogContext.rpg;
      return AlertDialog(
        backgroundColor: t.parchment,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Nagroda odebrana!',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: t.fontDisplay, color: t.inkHeading),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BossArt(boss.look, size: 72),
            const SizedBox(height: 8),
            Text(
              '${character.name} otrzymuje:',
              style: TextStyle(fontFamily: t.fontBody, color: t.inkHeading),
            ),
            const SizedBox(height: 8),
            RewardChipRow(reward: reward),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Super!', style: TextStyle(color: t.crimson)),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    final a = t.arena;
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.cardRadius),
        boxShadow: t.cardShadows(blur: 18, offset: const Offset(0, 5)),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: a.frame, width: t.cardBorderWidth),
        borderRadius: BorderRadius.circular(t.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBand(
            label: boss.isDefeated && _fight == null ? 'Zwycięstwo' : 'Boss',
            ornament: BandOrnament.star,
            gradient: a.band,
            labelColor: a.bandInk,
            trailing: widget.isAdmin && boss.isActive
                ? IconButton(
                    key: const Key('cancel-boss'),
                    tooltip: 'Odwołaj bossa',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 16,
                    color: a.bandInk,
                    icon: const Icon(Icons.close),
                    onPressed: _cancelBoss,
                  )
                : null,
          ),
          // A killing blow plays out before the victory panel takes over.
          if (boss.isDefeated && _fight == null)
            _victory(context)
          else ...[
            _header(context),
            _floor(context),
            _footer(context),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final t = context.rpg;
    final a = t.arena;
    return Container(
      color: a.panel,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  boss.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: t.fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: 1,
                    color: a.panelInk,
                  ),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (context, _, _) => Text(
                  '$_shownHp / ${boss.maxHp} HP',
                  key: const Key('boss-hp'),
                  style: TextStyle(
                    fontFamily: t.fontBody,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: a.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 13,
            decoration: BoxDecoration(
              color: a.hpTrack,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: a.frame),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (context, _, _) => TweenAnimationBuilder<double>(
                  tween: Tween(end: _shownHp / boss.maxHp),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOut,
                  builder: (context, f, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: f.clamp(0, 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: a.hpFill),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _floor(BuildContext context) {
    final t = context.rpg;
    final a = t.arena;
    final onlooker = t.decor.arenaOnlooker(context);
    return SizedBox(
      height: _floorHeight,
      child: CustomPaint(
        painter: ArenaFloorPainter(
          style: t.decor.arenaFloor,
          floor: a.floor,
          line: a.floorLine,
          grass: a.grass,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _width = constraints.maxWidth;
            if (_heroTargetX > _width - heroSize.width) {
              _heroTargetX = math.max(0, _width - heroSize.width);
            }
            return ValueListenableBuilder<int>(
              valueListenable: _frame,
              builder: (context, _, _) => _scene(context),
            );
          },
        ),
      ).withOnlooker(onlooker),
    );
  }

  Widget _scene(BuildContext context) {
    final t = context.rpg;
    final a = t.arena;
    final fight = _fight;
    final striking = fight != null && !fight.approaching;
    final ft = striking ? fight.t : 0.0;
    final tier = striking ? fight.blow.tier : null;
    final hits = tier == null ? const <double>[] : hitsFor(tier);

    // The boss flinches and flashes as each blow lands.
    var flash = 0.0;
    for (final h in hits) {
      if (ft >= h && ft < h + 0.14) {
        flash = math.max(flash, 1 - (ft - h) / 0.14);
      }
    }
    final shake = math.sin(ft * 90) * 7 * flash;
    final rect = _bossRect.shift(Offset(shake, 0));
    final bob = _bossWalking
        ? (math.sin(_bossPhase * 2 * math.pi * 10)).abs() * 4
        : 0.0;
    final bossFacesLeft = fight != null
        ? _heroX + heroSize.width / 2 < rect.center.dx
        : math.cos(_bossPhase * 2 * math.pi) < 0;

    // A hypercios rumbles the whole floor.
    final quake = tier == BlowTier.hyper && ft > 0.72 && ft < 0.9
        ? math.sin(ft * 140) * 3
        : 0.0;

    final w = weapon;
    final lift = heroLift(w, tier, ft);
    final heroTop = _floorHeight - heroSize.height - 2 - lift;
    final arm = heroArmAngle(w, tier, ft, _heroMoving ? _stride : 0);
    final heroLeft = _heroX;
    // The hand in floor coordinates, mirrored with the hero.
    final local =
        const Offset(34, 40) + Offset(math.sin(arm), math.cos(arm)) * 15;
    final hand = Offset(
      heroLeft + (_heroRight ? local.dx : heroSize.width - local.dx),
      heroTop + local.dy,
    );

    final banner = striking
        ? '${fight.blow.name}!'.toUpperCase()
        : _picked != null && widget.canFight && fight == null
        ? '${_picked!.name} — stuknij bossa!'
        : null;

    final showDamage = striking && ft >= hits.last;
    final rise = showDamage ? (ft - hits.last) / (1 - hits.last) : 0.0;
    final dealt = fight?.blow.tier.damage ?? 0;

    return Transform.translate(
      offset: Offset(quake, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The floor itself: tapping it walks the hero there.
          Positioned.fill(
            child: GestureDetector(
              key: const Key('boss-floor'),
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.canFight
                  ? (d) => _walkTo(d.localPosition.dx)
                  : null,
            ),
          ),
          if (banner != null)
            Positioned(
              top: 12,
              left: 8,
              right: 8,
              child: IgnorePointer(
                child: Text(
                  banner,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: t.fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 1.5,
                    color: a.panelInk,
                    shadows: [
                      Shadow(
                        color: a.panel.withValues(alpha: 0.9),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: rect.left,
            top: rect.top - bob,
            child: GestureDetector(
              key: const Key('boss-target'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.canFight ? _strike : null,
              child: _Ready(
                ready: _picked != null && fight == null && widget.canFight,
                color: a.accent,
                child: BossArt(
                  boss.look,
                  size: _bossSize,
                  flip: bossFacesLeft,
                  flash: flash,
                ),
              ),
            ),
          ),
          if (widget.canFight)
            Positioned(
              left: heroLeft,
              top: heroTop,
              child: IgnorePointer(
                child: CustomPaint(
                  key: const Key('boss-hero'),
                  size: heroSize,
                  painter: HeroPainter(
                    weapon: w,
                    stride: _heroMoving ? _stride : 0,
                    armAngle: arm,
                    facingRight: _heroRight,
                    drawing: w == Weapon.luk && striking
                        ? _bowDraw(ft, tier!)
                        : 0,
                    casting: w == Weapon.ksiega && striking
                        ? math.min(1, ft / 0.25)
                        : 0,
                  ),
                ),
              ),
            ),
          if (striking && w != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: FightFxPainter(
                    weapon: w,
                    tier: tier!,
                    t: ft,
                    hand: hand,
                    heroFeet: Offset(
                      heroLeft + heroSize.width / 2,
                      _floorHeight - 4,
                    ),
                    boss: rect,
                    accent: a.accent,
                  ),
                ),
              ),
            ),
          if (showDamage)
            Positioned(
              left: rect.left - 20,
              width: rect.width + 40,
              top: rect.top - 4 - rise * 44,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 1 - _clamp01((rise - 0.6) / 0.4),
                  child: Transform.scale(
                    scale: 1 + 0.5 * (1 - _clamp01(rise * 4)),
                    child: Text(
                      '−$dealt',
                      key: const Key('boss-damage'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: t.fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: 30 + (tier?.index ?? 0) * 5,
                        color: spellFireCore,
                        shadows: const [
                          Shadow(color: spellFire, blurRadius: 10),
                          Shadow(color: spellRockDark, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// How far the bow string is pulled: drawn back before each shot,
  /// released as it flies.
  double _bowDraw(double t, BlowTier tier) {
    final release = switch (tier) {
      BlowTier.combo => 0.3,
      BlowTier.hyper => 0.5,
      _ => hitsFor(tier).first - 0.2,
    };
    return t < release ? _clamp01(t / release) : 0;
  }

  static double _clamp01(double v) => v.clamp(0.0, 1.0);

  Widget _footer(BuildContext context) {
    final t = context.rpg;
    final a = t.arena;
    final label = TextStyle(
      fontFamily: t.fontDisplay,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      letterSpacing: 1.5,
      color: a.panelInk,
    );
    final small = TextStyle(
      fontFamily: t.fontBody,
      fontSize: 12,
      fontStyle: FontStyle.italic,
      color: a.panelInk,
    );
    final target = boss.targetCharacterName == null
        ? 'dla wszystkich'
        : 'dla: ${boss.targetCharacterName}';

    if (!widget.canFight) {
      final fighters = boss.fighters.length;
      return Container(
        color: a.panel,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Text(
          '$target · ${fighters == 0 ? 'nikt jeszcze nie walczył' : 'walczących: $fighters'}',
          style: small,
        ),
      );
    }

    final w = weapon;
    final energy = boss.energyOf(character) ?? 0;
    return Container(
      color: a.panel,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          Tooltip(
            message: w == null ? 'Brak broni' : '${w.label} — wybierz cios',
            child: Material(
              shape: CircleBorder(
                side: BorderSide(color: a.weaponBorder, width: 2.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(gradient: a.weaponFill),
                child: InkWell(
                  key: const Key('boss-weapon'),
                  onTap: w == null ? null : _openPicker,
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: Center(
                      child: w == null
                          ? Icon(Icons.block, color: a.weaponInk)
                          : WeaponIcon(w, size: 28, color: a.weaponInk),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w == null
                      ? 'Brak broni'.toUpperCase()
                      : _picked == null
                      ? w.label.toUpperCase()
                      : 'Cios: ${_picked!.name}'.toUpperCase(),
                  style: label,
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '⚡ $energy ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: a.accent,
                        ),
                      ),
                      const TextSpan(text: 'energii bojowej'),
                    ],
                  ),
                  key: const Key('boss-energy'),
                  style: small.copyWith(fontSize: 13),
                ),
                Text(
                  w == null
                      ? 'Poproś admina o broń'
                      : _picked == null
                      ? 'Stuknij ${w == Weapon.ksiega ? 'księgę' : 'broń'} i wybierz cios · $target'
                      : 'Stuknij bossa · stuknij broń, by zmienić cios',
                  style: small.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _victory(BuildContext context) {
    final t = context.rpg;
    final a = t.arena;
    final mine = boss.damageBy(character.id);
    final canClaim = widget.canFight || widget.isAdmin;
    final ink = TextStyle(fontFamily: t.fontBody, color: t.inkHeading);
    return Container(
      decoration: BoxDecoration(gradient: t.cardGradient),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        children: [
          Transform.rotate(
            angle: -math.pi / 2.2,
            child: Opacity(opacity: 0.85, child: BossArt(boss.look, size: 78)),
          ),
          Text(
            '${boss.name} pokonany!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: t.fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 19,
              color: t.inkHeading,
            ),
          ),
          if (boss.lastAttackerName != null)
            Text(
              'Ostatni cios: ${boss.lastAttackerName}',
              style: ink.copyWith(
                fontStyle: FontStyle.italic,
                fontSize: 13,
                color: t.crimson,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '${character.name} zadaje $mine obrażeń · walczących: ${boss.fighters.length}',
            textAlign: TextAlign.center,
            style: ink.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 10),
          const LabelledDivider(label: 'Nagroda'),
          const SizedBox(height: 8),
          RewardChipRow(reward: boss.reward),
          const SizedBox(height: 12),
          if (canClaim)
            ArenaButton(
              key: const Key('claim-boss-reward'),
              label: _claiming ? 'Odbieram…' : 'Odbierz nagrodę',
              onTap: _claiming ? null : _claim,
            )
          else
            Text(
              'Nagroda czeka na ${character.name}',
              style: ink.copyWith(fontStyle: FontStyle.italic, color: a.accent),
            ),
        ],
      ),
    );
  }
}

extension on Widget {
  /// Puts the theme's onlooker in the floor's corner, if it has one.
  Widget withOnlooker(Widget? onlooker) => onlooker == null
      ? this
      : Stack(
          children: [
            Positioned.fill(child: this),
            Positioned(
              right: 6,
              bottom: 4,
              child: IgnorePointer(child: onlooker),
            ),
          ],
        );
}

/// A gold pulse round the boss while a blow is picked and waiting.
class _Ready extends StatefulWidget {
  const _Ready({required this.ready, required this.color, required this.child});

  final bool ready;
  final Color color;
  final Widget child;

  @override
  State<_Ready> createState() => _ReadyState();
}

class _ReadyState extends State<_Ready> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Ready old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.ready && BossMotion.loops) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ready) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.55 * (1 - _c.value)),
              blurRadius: 6 + 18 * _c.value,
              spreadRadius: 2 + 10 * _c.value,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// "+50 XP", "+20 zł", "Odwaga +1" as chips.
class RewardChipRow extends StatelessWidget {
  const RewardChipRow({super.key, required this.reward});

  final BossReward reward;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final part in reward.parts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: t.crimsonFaint,
              border: Border.all(color: t.arena.frame),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              part,
              style: TextStyle(
                fontFamily: t.fontBody,
                fontWeight: FontWeight.w700,
                color: t.inkHeading,
              ),
            ),
          ),
      ],
    );
  }
}
