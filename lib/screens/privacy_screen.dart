import 'package:flutter/material.dart';

import '../theme/orchard_colors.dart';
import '../theme/orchard_text_styles.dart';
import '../widgets/orchard_icons.dart';
import '../widgets/orchard_widgets.dart';

/// Privacy Policy: what the game does (and doesn't) do with your data.
/// Deliberately holds no developer contact details or links: players are
/// pointed to the Google Play store listing for support.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const points = [
    'Ripe Rhythm does not collect any data. Nothing about you or how you '
        'play is gathered, stored elsewhere or shared.',
    'No account or sign-in is needed. Just open the game and play.',
    'Your progress is saved only on this device.',
  ];

  static const deleteSteps = [
    'Open Wind & Hush and choose Reset the orchard.',
    "Clear the game's app data in your device settings.",
    'Uninstall the game.',
  ];

  static const support =
      "For questions or support, please use the developer contact details shown "
      "on this game's Google Play store listing.";

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width < 360 ? 20.0 : 24.0;
    return Scaffold(
      backgroundColor: OrchardColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(title: 'Privacy Policy'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
                child: PaperSheet(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, p) in points.indexed) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _Point(text: p),
                      ],
                      const SizedBox(height: 28),
                      Semantics(
                        header: true,
                        child: Text(
                          'Deleting your progress',
                          style: OrchardText.label(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final (i, s) in deleteSteps.indexed) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _Point(text: s),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Container(height: 1, color: OrchardColors.hairline),
                      ),
                      Text(support, style: OrchardText.body(color: OrchardColors.inkSoft)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: ExcludeSemantics(
            child: OrchardIcon(OIcon.leaf, size: 14, strokeWidth: 1.6),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: OrchardText.body())),
      ],
    );
  }
}
