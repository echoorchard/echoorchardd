import 'package:flutter/material.dart';

import '../audio/orchard_audio.dart';
import '../routing/app_routes.dart';
import '../theme/orchard_colors.dart';
import '../theme/orchard_text_styles.dart';
import 'orchard_icons.dart';
import 'orchard_widgets.dart';

/// "Beneath the Canopy": the pause sheet over a dimmed row.
class BeneathCanopyOverlay extends StatelessWidget {
  const BeneathCanopyOverlay({
    super.key,
    required this.rowTitle,
    required this.onResume,
    required this.onRestart,
    required this.onLeave,
    required this.onHush,
  });

  final String rowTitle;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onLeave;
  final VoidCallback onHush;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onResume,
            child: ColoredBox(color: OrchardColors.scrim),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: Duration(milliseconds: OrchardScope.reduceMotion(context) ? 1 : 300),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) =>
                Transform.translate(offset: Offset(0, 80 * t), child: child),
            child: PaperSheet(
              topOnly: true,
              padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Beneath the canopy', style: OrchardText.heading()),
                  const SizedBox(height: 4),
                  Text('$rowTitle is waiting. The trees hold their breath.',
                      style: OrchardText.body(color: OrchardColors.inkSoft)),
                  const SizedBox(height: 24),
                  StakeButton(label: 'Back to the row', icon: OIcon.play, onTap: onResume),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      QuietButton(label: 'Start over', icon: OIcon.restart, onTap: onRestart),
                      QuietButton(label: 'Wind & Hush', icon: OIcon.windmill, onTap: onHush),
                      QuietButton(label: 'Leave the row', icon: OIcon.back, onTap: onLeave),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Wind & Hush": sound, motion and accessibility toggles + reset.
Future<void> showWindAndHush(BuildContext context, {bool inRow = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: OrchardColors.scrim,
    builder: (_) => _WindAndHushSheet(scope: OrchardScope.of(context), inRow: inRow),
  );
}

class _WindAndHushSheet extends StatefulWidget {
  const _WindAndHushSheet({required this.scope, required this.inRow});

  final OrchardScope scope;
  final bool inRow;

  @override
  State<_WindAndHushSheet> createState() => _WindAndHushSheetState();
}

class _WindAndHushSheetState extends State<_WindAndHushSheet> {
  @override
  Widget build(BuildContext context) {
    final repo = widget.scope.repository;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    Widget toggle(OIcon icon, String label, String hint, bool value, Future<void> Function(bool) set) {
      return _ToggleRow(
        icon: icon,
        label: label,
        hint: hint,
        value: value,
        onChanged: (v) async {
          await set(v);
          setState(() {});
        },
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: PaperSheet(
        topOnly: true,
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OrchardColors.inkFaint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Text('Wind & Hush', style: OrchardText.heading())),
                  IconStake(icon: OIcon.close, label: 'Close', onTap: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 8),
              toggle(OIcon.sound, 'Orchard sounds', 'Harvests, rings and wind', repo.soundOn, repo.setSoundOn),
              toggle(OIcon.music, 'Ambient bed', 'Breeze, birds and crickets', repo.musicOn, (v) async {
                await repo.setMusicOn(v);
                await OrchardAudio.instance.refreshAmbient();
              }),
              toggle(OIcon.tick, 'Pulse tick', 'A soft knock on every beat', repo.pulseTickEnabled,
                  repo.setPulseTickEnabled),
              toggle(OIcon.vibration, 'Harvest tremor', 'Vibration on harvest and bruise', repo.vibrationOn,
                  repo.setVibrationOn),
              const SizedBox(height: 12),
              Text('Easier on the eyes and hands', style: OrchardText.label(size: 15, color: OrchardColors.inkSoft)),
              toggle(OIcon.eye, 'Eyes-only rhythm', 'No rhythm sounds; brighter bands', repo.eyesOnlyRhythm,
                  repo.setEyesOnlyRhythm),
              toggle(OIcon.wind, 'Gentle wind', 'Gusts come less often and push less', repo.gentleWind,
                  repo.setGentleWind),
              toggle(OIcon.motion, 'Reduce motion', 'Fewer drifting petals and effects', repo.reduceMotion,
                  repo.setReduceMotion),
              const SizedBox(height: 20),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  QuietButton(
                    label: 'How to harvest',
                    icon: OIcon.journal,
                    onTap: () => Navigator.of(context)
                      ..pop()
                      ..pushNamed(AppRoutes.lesson),
                  ),
                  QuietButton(
                    label: 'Privacy Policy',
                    icon: OIcon.privacy,
                    onTap: () => Navigator.of(context)
                      ..pop()
                      ..pushNamed(AppRoutes.privacy),
                  ),
                ],
              ),
              if (!widget.inRow) ...[
                const SizedBox(height: 16),
                Container(height: 1, color: OrchardColors.hairline),
                const SizedBox(height: 8),
                QuietButton(
                  label: 'Reset the orchard',
                  icon: OIcon.restart,
                  color: OrchardColors.dusk,
                  onTap: () => _confirmReset(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      barrierColor: OrchardColors.scrim,
      builder: (ctx) => Dialog(
        backgroundColor: OrchardColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reset the orchard?', style: OrchardText.heading(size: 22)),
              const SizedBox(height: 8),
              Text(
                'Every row, star, seed, keepsake and stat on this device will be cleared. '
                'Your sound and accessibility choices stay. This cannot be undone.',
                style: OrchardText.body(color: OrchardColors.inkSoft),
              ),
              const SizedBox(height: 24),
              Pressable(
                semanticLabel: 'Yes, clear everything',
                onTap: () => Navigator.of(ctx).pop(true),
                child: Container(
                  height: 52,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OrchardColors.dusk,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Yes, clear everything', style: OrchardText.label(color: OrchardColors.cream)),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: QuietButton(label: 'Keep my orchard', icon: OIcon.leaf, onTap: () => Navigator.of(ctx).pop(false)),
              ),
            ],
          ),
        ),
      ),
    );
    if (yes == true && context.mounted) {
      await widget.scope.repository.resetProgress();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.path, (_) => false);
    }
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final OIcon icon;
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: '$label. $hint',
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                OrchardIcon(icon, size: 22, color: value ? OrchardColors.ink : OrchardColors.inkFaint),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: OrchardText.label(size: 16)),
                      Text(hint, style: OrchardText.small()),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _LeafSwitch(value: value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A switch whose knob is a leaf: on = leaf green track + knob right + check.
class _LeafSwitch extends StatelessWidget {
  const _LeafSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: 52,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? OrchardColors.leaf : OrchardColors.hairline,
        borderRadius: BorderRadius.circular(15),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: OrchardColors.cream,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: OrchardColors.shadow, blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: value
              ? const Padding(
                  padding: EdgeInsets.all(5),
                  child: OrchardIcon(OIcon.check, size: 14, color: OrchardColors.leaf, strokeWidth: 3),
                )
              : null,
        ),
      ),
    );
  }
}
