import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/orchard_audio.dart';
import '../data/progress_repository.dart';
import '../data/progression_service.dart';
import '../theme/orchard_colors.dart';
import '../theme/orchard_text_styles.dart';
import 'orchard_icons.dart';

/// Gives every screen access to saves and progression.
class OrchardScope extends InheritedWidget {
  const OrchardScope({
    super.key,
    required this.repository,
    required this.progression,
    required super.child,
  });

  final ProgressRepository repository;
  final ProgressionService progression;

  static OrchardScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OrchardScope>()!;

  /// True when Reduce Motion is on or the OS asks for fewer animations.
  static bool reduceMotion(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OrchardScope>();
    return (scope?.repository.reduceMotion ?? false) ||
        MediaQuery.maybeDisableAnimationsOf(context) == true;
  }

  @override
  bool updateShouldNotify(OrchardScope oldWidget) => true;
}

/// Squash-and-stretch press feedback + menu sound + semantics.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.sound = true,
    this.minSize = 48,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String semanticLabel;
  final bool sound;
  final double minSize;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  // 1 → 0.92 → 1.05 → 1
  double _scale(double t) {
    if (t < 0.35) return 1 - 0.08 * (t / 0.35);
    if (t < 0.7) return 0.92 + 0.13 * ((t - 0.35) / 0.35);
    return 1.05 - 0.05 * ((t - 0.7) / 0.3);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    if (widget.onTap == null) return;
    if (widget.sound) OrchardAudio.instance.play(Sfx.menu);
    if (!OrchardScope.reduceMotion(context)) _c.forward(from: 0);
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      // excludeSemantics drops the GestureDetector's own tap action, so
      // expose it here or screen readers can't press the button.
      onTap: enabled ? _tap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _tap : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.minSize,
            minHeight: widget.minSize,
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Transform.scale(
              scale: _c.isAnimating ? _scale(_c.value) : 1,
              child: child,
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// The one primary action on a screen.
class StakeButton extends StatelessWidget {
  const StakeButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final OIcon? icon;
  final bool expand;

  /// Tighter padding for crowded rows (the hub shelf).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final content = Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 24),
      decoration: BoxDecoration(
        color: enabled ? OrchardColors.leaf : OrchardColors.inkFaint,
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled
            ? [BoxShadow(color: OrchardColors.shadow, blurRadius: 14, offset: const Offset(0, 5))]
            : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            OrchardIcon(icon!, color: OrchardColors.cream, size: compact ? 18 : 22),
            SizedBox(width: compact ? 6 : 10),
          ],
          Flexible(
            child: Text(
              label,
              style: OrchardText.label(color: OrchardColors.cream),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: expand ? SizedBox(width: double.infinity, child: content) : content,
    );
  }
}

/// Secondary action: drawn icon + label, no fill.
class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = OIcon.leaf,
    this.color = OrchardColors.ink,
  });

  final String label;
  final VoidCallback? onTap;
  final OIcon icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrchardIcon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label, style: OrchardText.label(color: color, size: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round icon-only control (pause, back, close) with a 48dp target.
class IconStake extends StatelessWidget {
  const IconStake({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.onArt = false,
  });

  final OIcon icon;
  final String label;
  final VoidCallback? onTap;

  /// Sits directly on painted art: gets a cream disc for contrast.
  final bool onArt;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: onArt
            ? BoxDecoration(
                color: OrchardColors.cream.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: OrchardColors.shadow, blurRadius: 10, offset: const Offset(0, 3))],
              )
            : null,
        child: OrchardIcon(icon, size: 24),
      ),
    );
  }
}

/// Cream paper surface with one soft shadow. Never nest these.
class PaperSheet extends StatelessWidget {
  const PaperSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 20,
    this.topOnly = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool topOnly;

  @override
  Widget build(BuildContext context) {
    final r = Radius.circular(radius);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: OrchardColors.cream,
        borderRadius: topOnly
            ? BorderRadius.only(topLeft: r, topRight: r)
            : BorderRadius.all(r),
        boxShadow: [BoxShadow(color: OrchardColors.shadow, blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }
}

/// Earned stars are gold-filled; empty ones are outline only (shape differs).
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 16, this.total = 3});

  final int stars;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stars of $total stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            Padding(
              padding: EdgeInsets.only(right: i == total - 1 ? 0 : size * 0.12),
              child: OrchardIcon(
                OIcon.star,
                size: size,
                fill: i < stars ? OrchardColors.gold : null,
                color: i < stars ? OrchardColors.ink : OrchardColors.inkFaint,
                strokeWidth: 1.6,
              ),
            ),
        ],
      ),
    );
  }
}

/// Icon + number, e.g. seeds or dewdrops.
class Counter extends StatelessWidget {
  const Counter({
    super.key,
    required this.icon,
    required this.value,
    required this.semanticLabel,
    this.fill = OrchardColors.gold,
    this.color = OrchardColors.ink,
  });

  final OIcon icon;
  final int value;
  final String semanticLabel;
  final Color fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $semanticLabel',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrchardIcon(icon, size: 20, fill: fill, color: color, strokeWidth: 1.6),
          const SizedBox(width: 6),
          Text('$value', style: OrchardText.label(color: color)),
        ],
      ),
    );
  }
}

/// Three leaves: full = leaf-green fill; lost = dusk outline (shape + colour).
class LifeLeaves extends StatelessWidget {
  const LifeLeaves({super.key, required this.lives, this.max = 3, this.shields = 0});

  final int lives;
  final int max;
  final int shields;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$lives of $max leaves left${shields > 0 ? ', $shields dewdrops' : ''}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < max; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: OrchardIcon(
                  OIcon.leaf,
                  key: ValueKey(i < lives),
                  size: 26,
                  fill: i < lives ? OrchardColors.leaf : null,
                  color: i < lives ? OrchardColors.ink : OrchardColors.dusk,
                  strokeWidth: 1.6,
                ),
              ),
            ),
          for (var i = 0; i < shields; i++)
            const Padding(
              padding: EdgeInsets.only(left: 2),
              child: OrchardIcon(OIcon.dewdrop, size: 20, fill: Color(0xFFE4F1F4), strokeWidth: 1.6),
            ),
        ],
      ),
    );
  }
}

/// Back control + heading for paper screens.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconStake(
            icon: OIcon.back,
            label: 'Back',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: OrchardText.heading(), overflow: TextOverflow.ellipsis),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Fade + slight scale (or a plain fade with Reduce Motion).
class OrchardRoute<T> extends PageRouteBuilder<T> {
  OrchardRoute({required WidgetBuilder builder, super.settings, bool reduceMotion = false})
      : super(
          transitionDuration: Duration(milliseconds: reduceMotion ? 180 : 320),
          reverseTransitionDuration: Duration(milliseconds: reduceMotion ? 160 : 260),
          pageBuilder: (context, _, _) => builder(context),
          transitionsBuilder: (context, animation, _, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            if (reduceMotion) return FadeTransition(opacity: curved, child: child);
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween(begin: 1.02, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// Damped horizontal shake for gentle failure.
class Shake extends StatelessWidget {
  const Shake({super.key, required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final dx = math.sin(t * math.pi * 6) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: child,
    );
  }
}
