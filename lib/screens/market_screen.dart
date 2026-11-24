import 'package:flutter/material.dart';

import '../audio/orchard_audio.dart';
import '../data/achievements.dart';
import '../data/market.dart';
import '../theme/orchard_colors.dart';
import '../theme/orchard_text_styles.dart';
import '../widgets/orchard_icons.dart';
import '../widgets/orchard_widgets.dart';

/// Market Stall: baskets and keepsakes traded for seeds earned in play.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _open(MarketItem item) async {
    final scope = OrchardScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: OrchardColors.scrim,
      builder: (_) => OrchardScope(
        repository: scope.repository,
        progression: scope.progression,
        child: _TradeSheet(item: item, onChanged: _refresh),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final repo = OrchardScope.of(context).repository;
    final gutter = MediaQuery.sizeOf(context).width < 360 ? 20.0 : 24.0;
    return Scaffold(
      backgroundColor: OrchardColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'Market Stall',
              trailing: Counter(
                icon: OIcon.seed,
                value: repo.seeds,
                semanticLabel: 'seeds',
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Group(title: 'Baskets', items: baskets.toList(), onTap: _open),
                    const SizedBox(height: 40),
                    _Group(title: 'Keepsakes', items: keepsakes.toList(), onTap: _open),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.items, required this.onTap});

  final String title;
  final List<MarketItem> items;
  final ValueChanged<MarketItem> onTap;

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: OrchardText.heading(size: 22))),
        const SizedBox(height: 16),
        for (var i = 0; i < items.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ItemTile(item: items[i], onTap: onTap)),
              const SizedBox(width: gap),
              Expanded(
                child: i + 1 < items.length
                    ? _ItemTile(item: items[i + 1], onTap: onTap)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

enum _State { forTrade, owned, inUse, placed }

_State _stateOf(BuildContext context, MarketItem item) {
  final scope = OrchardScope.of(context);
  if (!scope.progression.owns(item)) return _State.forTrade;
  if (item.kind == MarketKind.keepsake) return _State.placed;
  return scope.repository.equippedBasket == item.id ? _State.inUse : _State.owned;
}

String _stateWords(_State s) => switch (s) {
      _State.forTrade => '',
      _State.owned => 'Owned',
      _State.inUse => 'In use',
      _State.placed => 'Appears on the hillside',
    };

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onTap});

  final MarketItem item;
  final ValueChanged<MarketItem> onTap;

  @override
  Widget build(BuildContext context) {
    final state = _stateOf(context, item);
    final status = state == _State.forTrade ? '${item.price} seeds' : _stateWords(state);
    return Pressable(
      semanticLabel: '${item.name}, $status',
      onTap: () => onTap(item),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 1, child: _ItemSprite(item: item)),
            const SizedBox(height: 10),
            Text(item.name, style: OrchardText.label(size: 16)),
            const SizedBox(height: 2),
            Text(item.detail, style: OrchardText.small()),
            const SizedBox(height: 8),
            if (state == _State.forTrade)
              _Price(price: item.price)
            else
              Row(
                children: [
                  if (state == _State.inUse) ...[
                    const OrchardIcon(OIcon.check, size: 16, color: OrchardColors.leaf),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      status,
                      style: OrchardText.small(
                        color: state == _State.inUse ? OrchardColors.leaf : null,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const OrchardIcon(OIcon.seed, size: 16, fill: OrchardColors.gold, strokeWidth: 1.6),
        const SizedBox(width: 4),
        Text('$price', style: OrchardText.label(size: 15)),
      ],
    );
  }
}

/// The item's sprite, or a soft drawn placeholder while it loads or if the
/// image is missing.
class _ItemSprite extends StatelessWidget {
  const _ItemSprite({required this.item});

  final MarketItem item;

  @override
  Widget build(BuildContext context) {
    final placeholder = _SpritePlaceholder(kind: item.kind);
    return Image.asset(
      item.asset,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, sync) =>
          frame == null && !sync ? placeholder : child,
      errorBuilder: (context, error, stack) => placeholder,
    );
  }
}

class _SpritePlaceholder extends StatelessWidget {
  const _SpritePlaceholder({required this.kind});

  final MarketKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OrchardColors.hairline,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: OrchardIcon(
        kind == MarketKind.basket ? OIcon.basket : OIcon.leaf,
        size: 40,
        color: OrchardColors.inkFaint,
      ),
    );
  }
}

/// Small paper bottom sheet: confirm a trade, carry a basket, or read what
/// a keepsake does.
class _TradeSheet extends StatefulWidget {
  const _TradeSheet({required this.item, required this.onChanged});

  final MarketItem item;
  final VoidCallback onChanged;

  @override
  State<_TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends State<_TradeSheet> {
  bool _busy = false;
  bool _traded = false;
  List<Achievement> _sealsEarned = const [];

  MarketItem get item => widget.item;

  Future<void> _trade() async {
    if (_busy) return;
    setState(() => _busy = true);
    final prog = OrchardScope.of(context).progression;
    final ok = await prog.buy(item);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      return;
    }
    OrchardAudio.instance.play(Sfx.buy);
    final earned = await prog.checkCollection();
    if (earned.isNotEmpty) OrchardAudio.instance.play(Sfx.unlock);
    widget.onChanged();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _traded = true;
      _sealsEarned = earned;
    });
  }

  Future<void> _carry() async {
    if (_busy) return;
    setState(() => _busy = true);
    await OrchardScope.of(context).repository.setEquippedBasket(item.id);
    widget.onChanged();
    if (mounted) Navigator.of(context).pop();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final scope = OrchardScope.of(context);
    final seeds = scope.repository.seeds;
    final state = _stateOf(context, item);
    final isBasket = item.kind == MarketKind.basket;

    final String question;
    final String note;
    final Widget action;

    if (_traded) {
      question = 'The ${item.name} is yours';
      note = isBasket ? 'It is on your arm for the next row.' : 'Appears on the hillside.';
      action = StakeButton(label: 'Back to the stall', onTap: _close);
    } else {
      switch (state) {
        case _State.forTrade:
          final short = item.price - seeds;
          question = 'Trade ${item.price} seeds for the ${item.name}?';
          note = short > 0
              ? '$short more ${short == 1 ? 'seed' : 'seeds'}'
              : 'You have $seeds seeds.';
          action = StakeButton(
            label: 'Trade ${item.price} seeds',
            icon: OIcon.seed,
            onTap: short > 0 || _busy ? null : _trade,
          );
        case _State.owned:
          question = 'Carry the ${item.name}?';
          note = 'Your baskets are always yours to swap.';
          action = StakeButton(
            label: 'Carry this basket',
            icon: OIcon.basket,
            onTap: _busy ? null : _carry,
          );
        case _State.inUse:
          question = 'The ${item.name}';
          note = 'In use. It goes with you on every row.';
          action = StakeButton(label: 'Back to the stall', onTap: _close);
        case _State.placed:
          question = 'The ${item.name}';
          note = 'Appears on the hillside.';
          action = StakeButton(label: 'Back to the stall', onTap: _close);
      }
    }

    final shortfall = !_traded && state == _State.forTrade && item.price > seeds;

    return SafeArea(
      top: false,
      child: PaperSheet(
        topOnly: true,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_sealsEarned.isNotEmpty) ...[
                for (final a in _sealsEarned) _SealNote(achievement: a),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(dimension: 72, child: _ItemSprite(item: item)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(question, style: OrchardText.label(size: 19)),
                        ),
                        const SizedBox(height: 4),
                        Text(item.detail, style: OrchardText.small()),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                note,
                style: OrchardText.body(
                  color: shortfall ? OrchardColors.dusk : OrchardColors.inkSoft,
                ),
              ),
              const SizedBox(height: 20),
              action,
              if (!_traded && (state == _State.forTrade || state == _State.owned))
                Align(
                  alignment: Alignment.centerLeft,
                  child: QuietButton(label: 'Not now', onTap: _close),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet inline note for a seal earned by this trade.
class _SealNote extends StatelessWidget {
  const _SealNote({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Seal earned: ${achievement.title}. ${achievement.detail}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: OrchardColors.hairline,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const OrchardIcon(OIcon.star, size: 20, fill: OrchardColors.gold, strokeWidth: 1.6),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Seal earned: ${achievement.title}',
                style: OrchardText.label(size: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
