/// Shared brand-name → logo lookup, used by both the "Popular Brands" strip
/// on Home and the restaurant grouping on the Cart screen, so the mapping
/// lives in one place instead of being duplicated.
///
/// Local bundled logos are used where available; the rest come from
/// Google's favicon service, which serves actual PNG raster images (Simple
/// Icons' CDN only serves SVG, a format Image.network can't decode).
class BrandLogos {
  static const Map<String, String> _byName = {
    'McDonald\'s': 'assets/images/macdonals.png',
    'Burger King': 'assets/images/burgerking.png',
    'Domino\'s': 'https://www.google.com/s2/favicons?domain=dominos.com&sz=128',
    'KFC': 'https://www.google.com/s2/favicons?domain=kfc.com&sz=128',
    'Subway': 'https://www.google.com/s2/favicons?domain=subway.com&sz=128',
    'Starbucks': 'assets/images/starbuks.png',
    'Pizza Hut': 'https://www.google.com/s2/favicons?domain=pizzahut.com&sz=128',
    'Taco Bell': 'https://www.google.com/s2/favicons?domain=tacobell.com&sz=128',
  };

  static List<String> get orderedNames => _byName.keys.toList(growable: false);

  static String? urlFor(String name) => _byName[name];
}
