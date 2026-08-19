/// Known-good image URLs already used elsewhere in the app's dummy data,
/// reused as fallbacks so a broken image never has to fall back to nothing.
class ImagePools {
  ImagePools._();

  static const List<String> restaurants = [
    'https://images.unsplash.com/photo-1553979459-d2229ba7433b?auto=format&fit=crop&q=80&w=800',
    'https://images.unsplash.com/photo-1571091718767-18b5b1457add?auto=format&fit=crop&q=80&w=800',
    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&q=80&w=800',
    'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?auto=format&fit=crop&q=80&w=800',
    'https://images.unsplash.com/photo-1594007654729-407eedc4be65?auto=format&fit=crop&q=80&w=800',
    'https://images.unsplash.com/photo-1509722747041-616f39b57569?auto=format&fit=crop&q=80&w=800',
  ];

  static const List<String> foods = [
    'assets/images/burger.png',
    'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&q=80&w=600',
    'https://images.unsplash.com/photo-1607958996333-41aef7caefaa?auto=format&fit=crop&q=80&w=600',
    'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?auto=format&fit=crop&q=80&w=600',
    'https://images.unsplash.com/photo-1576107232684-1279f390859f?auto=format&fit=crop&q=80&w=600',
    'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&q=80&w=600',
    'https://images.unsplash.com/photo-1594007654729-407eedc4be65?auto=format&fit=crop&q=80&w=600',
    'https://images.unsplash.com/photo-1509722747041-616f39b57569?auto=format&fit=crop&q=80&w=600',
    'https://images.unsplash.com/photo-1481070555726-e2fe8357725c?auto=format&fit=crop&q=80&w=600',
  ];

  // Same thumbnails used for the category chips themselves, reused here so a
  // category whose own image fails to load falls back to another real
  // category dish photo rather than a generic icon.
  static const List<String> categories = [
    'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&q=80&w=300',
    'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&q=80&w=300',
    'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&q=80&w=300',
    'https://images.unsplash.com/photo-1576107232684-1279f390859f?auto=format&fit=crop&q=80&w=300',
    'https://images.unsplash.com/photo-1544145945-f90425340c7e?auto=format&fit=crop&q=80&w=300',
    'https://images.unsplash.com/photo-1565299585323-38174c4a6471?auto=format&fit=crop&q=80&w=300',
    'https://images.unsplash.com/photo-1584208632869-05fa2b2a5934?auto=format&fit=crop&q=80&w=300',
  ];

  // Bundled (never-fails) brand logos, reused so a brand whose own logo
  // (network favicon) fails to load falls back to another real logo instead
  // of an empty circle.
  static const List<String> brands = [
    'assets/images/burgerking.png',
    'assets/images/macdonals.png',
    'assets/images/starbuks.png',
  ];
}
