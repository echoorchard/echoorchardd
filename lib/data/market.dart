/// Market Stall catalogue: cosmetics bought with earned seeds at fixed prices.
/// Nothing here is ever sold for money.
library;

enum MarketKind { basket, keepsake }

class MarketItem {
  const MarketItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.detail,
    required this.price,
    required this.asset,
  });

  final String id;
  final MarketKind kind;
  final String name;
  final String detail;

  /// Price in seeds. 0 = owned from the start.
  final int price;
  final String asset;
}

const marketItems = <MarketItem>[
  MarketItem(
    id: 'willow',
    kind: MarketKind.basket,
    name: 'Willow Basket',
    detail: 'The one you started with.',
    price: 0,
    asset: 'assets/images/basket_willow.png',
  ),
  MarketItem(
    id: 'rush',
    kind: MarketKind.basket,
    name: 'Rush Basket',
    detail: 'Woven from green river reeds.',
    price: 120,
    asset: 'assets/images/basket_rush.png',
  ),
  MarketItem(
    id: 'birch',
    kind: MarketKind.basket,
    name: 'Birch Basket',
    detail: 'Pale bark, light as a morning.',
    price: 160,
    asset: 'assets/images/basket_birch.png',
  ),
  MarketItem(
    id: 'cedar',
    kind: MarketKind.basket,
    name: 'Cedar Basket',
    detail: 'Deep red wood that smells of rain.',
    price: 220,
    asset: 'assets/images/basket_cedar.png',
  ),
  MarketItem(
    id: 'moonweave',
    kind: MarketKind.basket,
    name: 'Moonweave Basket',
    detail: 'Dusk-dyed strands, gold at the rim.',
    price: 300,
    asset: 'assets/images/basket_moon.png',
  ),
  MarketItem(
    id: 'birdhouse',
    kind: MarketKind.keepsake,
    name: 'Birdhouse',
    detail: 'Someone to sing at dawn.',
    price: 80,
    asset: 'assets/images/keep_birdhouse.png',
  ),
  MarketItem(
    id: 'beehive',
    kind: MarketKind.keepsake,
    name: 'Beehive',
    detail: 'The blossoms will thank you.',
    price: 100,
    asset: 'assets/images/keep_beehive.png',
  ),
  MarketItem(
    id: 'swing',
    kind: MarketKind.keepsake,
    name: 'Rope Swing',
    detail: 'For the slow afternoons.',
    price: 140,
    asset: 'assets/images/keep_swing.png',
  ),
  MarketItem(
    id: 'scarecrow',
    kind: MarketKind.keepsake,
    name: 'Scarecrow',
    detail: 'Friendly. Mostly.',
    price: 180,
    asset: 'assets/images/keep_scarecrow.png',
  ),
  MarketItem(
    id: 'windmill',
    kind: MarketKind.keepsake,
    name: 'Windmill',
    detail: 'Turns with every gust of winter.',
    price: 220,
    asset: 'assets/images/keep_windmill.png',
  ),
  MarketItem(
    id: 'lantern',
    kind: MarketKind.keepsake,
    name: 'Moon Lantern',
    detail: 'Lights the path to the top of the hill.',
    price: 260,
    asset: 'assets/images/keep_lantern.png',
  ),
];

MarketItem? marketItemById(String id) {
  for (final m in marketItems) {
    if (m.id == id) return m;
  }
  return null;
}

Iterable<MarketItem> get keepsakes =>
    marketItems.where((m) => m.kind == MarketKind.keepsake);

Iterable<MarketItem> get baskets =>
    marketItems.where((m) => m.kind == MarketKind.basket);
