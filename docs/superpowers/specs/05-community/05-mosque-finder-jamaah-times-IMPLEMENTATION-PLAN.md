# Implementation Plan: Mosque-Finder / Jamaah Times

**Spec:** `05-mosque-finder-jamaah-times-design.md`
**Complexity:** M · **Estimated effort:** 2 days
**Depends on:** Curated mosque dataset (content work), Prayer's location resolver

---

## Task 1: Create mosque dataset format

**File:** `assets/data/mosques.json` (new bundled asset)

```json
[
  {
    "name": "Baitul Mukarram",
    "name_bn": "বৈতুল মুকাররম",
    "lat": 23.7461,
    "lng": 90.4203,
    "city": "Dhaka",
    "jamaah_offsets": {
      "fajr": 20,
      "dhuhr": 15,
      "asr": 10,
      "maghrib": 5,
      "isha": 10
    },
    "jumuah_time": "13:00"
  }
]
```

The dataset follows Prayer's existing bundled-asset pattern (65-city
dataset). Mosques are grouped by city, with GPS coordinates for
proximity matching.

---

## Task 2: Create mosque data model

**File:** `lib/features/prayer/domain/entities/mosque.dart`

```dart
@freezed
class Mosque with _$Mosque {
  const factory Mosque({
    required String id,
    required String name,
    required String nameBn,
    required double latitude,
    required double longitude,
    required String city,
    required Map<String, int> jamaahOffsets, // prayer → minutes after Adhan
    String? jumuahTime,
  }) = _Mosque;
}
```

---

## Task 3: Create mosque dataset parser

**File:** `lib/features/prayer/data/mosque_dataset_parser.dart`

```dart
class MosqueDatasetParser {
  /// Parses the bundled mosques.json asset into Mosque entities.
  static Future<List<Mosque>> parse() async {
    final json = await rootBundle.loadString('assets/data/mosques.json');
    final list = jsonDecode(json) as List;
    return list.map((e) => Mosque.fromJson(e as Map<String, dynamic>)).toList();
  }
}
```

---

## Task 4: Create mosque finder use case

**File:** `lib/features/prayer/domain/usecases/mosque_finder_use_case.dart`

```dart
class MosqueFinderUseCase {
  final List<Mosque> _mosques;

  MosqueFinderUseCase(this._mosques);

  /// Finds mosques near [lat]/[lng] within [radiusKm].
  /// Returns sorted by distance (nearest first).
  List<MosqueWithDistance> findNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) {
    return _mosques
        .map((m) => MosqueWithDistance(
              mosque: m,
              distanceKm: _haversine(latitude, longitude, m.latitude, m.longitude),
            ))
        .where((m) => m.distanceKm <= radiusKm)
        .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }
}
```

---

## Task 5: Create mosque finder screen

**File:** `lib/features/prayer/presentation/screens/mosque_finder_screen.dart`

```dart
class MosqueFinderScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(prayerLocationProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mosqueFinderTitle)),
      body: location.when(
        data: (loc) {
          final mosques = ref.watch(nearbyMosquesProvider(loc));
          return mosques.when(
            data: (list) => list.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => MosqueTile(mosque: list[i]),
                  ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          );
        },
        loading: () => const CircularProgressIndicator(),
        error: (e, _) => _NoLocationState(),
      ),
    );
  }
}
```

---

## Task 6: Create mosque tile widget

**File:** `lib/features/prayer/presentation/widgets/mosque_tile.dart`

Shows mosque name, distance, and jamaah times for each prayer.

---

## Task 7: Add entry point to Prayer module

**File:** `lib/features/prayer/prayer_module.dart`

Add a "Nearby Mosques" entry point to Prayer's settings or home screen.

---

## Task 8: Add localization strings

**Files:** `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`

```json
"mosqueFinderTitle": "Nearby Mosques",
"mosqueFinderSubtitle": "Jamaah prayer times",
"mosqueFinderNoResults": "No mosques found near your location",
"mosqueFinderDistance": "{distance} km away",
"mosqueFinderJamaahOffset": "Jamaah: {offset} min after Adhan",
"mosqueFinderNoLocation": "Enable location to find nearby mosques",
"mosqueFinderPrayerTime": "{prayer}: {time}"
```

Run `flutter gen-l10n`.

---

## Performance considerations

- **Dataset size:** 100-500 mosques is trivial for in-memory search.
  No database needed — load once on Prayer module init, cache in memory.
- **Distance calculation:** Haversine formula is O(1) per mosque. For
  500 mosques, the full scan is <1ms.
- **Asset loading:** `rootBundle.loadString()` is async but fast for
  <1MB JSON. Cache the parsed list.

## Testing

- `test/features/prayer/mosque_dataset_parser_test.dart` — unit test
  for JSON parsing.
- `test/features/prayer/mosque_finder_use_case_test.dart` — unit test
  for proximity search and sorting.
- Widget test: mosque list renders correctly with mock data.
- Widget test: empty state shows when no mosques nearby.

## Localization

ARB keys listed in Task 8. Mosque names should support both English
and Bangla variants in the dataset (name/name_bn fields).
