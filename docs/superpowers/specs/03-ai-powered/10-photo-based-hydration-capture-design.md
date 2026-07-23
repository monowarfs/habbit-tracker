# Photo-Based Hydration/Meal Capture (Optional)

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Water logging today is either a preset-amount button or a manual number
entry — reliable, but it asks the user to already know and enter an
exact volume. MyFitnessPal-class apps have popularized photo-based
capture (snap what you're drinking/eating, get an estimated quantity) as
a lower-friction, more novel entry point, particularly appealing to
users who find manual number entry tedious or who simply enjoy a more
visual/tactile logging experience. This is explicitly a novelty/optional
entry point in the atlas, not a replacement for existing quick-add.

## Goals
- Let a user optionally photograph a glass/bottle/container and have the
  app estimate a volume to pre-fill Water's log-entry amount.
- Keep this strictly opt-in and always show the estimate as an editable,
  confirmable value before logging — never auto-log without user
  confirmation.
- Keep all image processing on-device — no photo ever leaves the device,
  consistent with the app's offline/no-account/no-cloud posture.

## Non-goals / out of scope
- No cloud vision API of any kind — strictly on-device vision inference.
- No meal/food-identification or calorie-counting feature — scoped to
  container-volume estimation for Water only, per the atlas item; a
  broader nutrition-tracking feature is out of scope for this app
  entirely.
- Not a primary logging path — this supplements, never replaces, the
  existing quick-add buttons and manual entry, since photo capture is
  inherently slower and less reliable for a fast, frequent action like
  logging water.
- Photos themselves are not retained/stored after the estimate is
  produced and confirmed, avoiding turning this into an implicit photo
  library feature.

## Proposed approach (high-level)
An on-device vision model (bundled with the app or downloaded once and
cached locally, never a live cloud inference call) takes a camera
capture of a container and produces a rough volume estimate — the
model's job is narrowly scoped to "how big is this container," not
open-ended image understanding. That estimate flows into the exact same
`LogWaterEntryUseCase` every other Water logging path already uses (its
amount > 0 / no-future-timestamp validation applies identically), with
the estimated number shown in an editable field the user confirms or
adjusts before it's saved — the photo itself is discarded once the
estimate is produced, unless the user explicitly wants to retry the
capture. This is additive to Water's existing logging UI: a camera-icon
entry point alongside the current quick-add grid, not a new screen
replacing it.

## Dependencies & prerequisites
- An on-device vision/object-size-estimation model — a new, non-trivial
  dependency (model size, on-device inference performance across a wide
  range of device hardware, and platform packaging both need real
  evaluation before committing).
- Camera permission handling, with a clear rationale prompt consistent
  with how other permission asks are handled in this app.
- A decision on whether the model ships bundled in the app binary
  (larger app size, works fully offline immediately) or downloaded
  on first use (smaller initial install, but a first-run network
  dependency that cuts against the offline-first story unless handled
  carefully).

## Open questions for the implementation round
- Which on-device vision approach is realistic given Flutter's plugin
  ecosystem and the need for this to work consistently across a wide
  range of Android/iOS device capability tiers?
- How accurate does the estimate need to be to be trustworthy enough that
  users don't immediately distrust and abandon the feature — is a rough
  small/medium/large container-size classification (mapped to typical
  volumes) sufficient instead of a precise ml estimate?
- Bundled-in-app vs. download-on-first-use for the model, and how that
  interacts with the app's offline-first framing if download is chosen?
- Is this worth the model-size/complexity cost given it's explicitly a
  novelty entry point rather than a primary flow — is a much simpler
  "tap a container-size icon" (no vision at all) most of the value at a
  fraction of the effort?

## Effort & sequencing notes
Complexity M as scoped in the atlas, though the open question above about
whether a non-vision container-size-icon shortcut captures most of the
value at far lower cost is worth revisiting before committing to on-
device vision infrastructure. Lowest-priority item to sequence relative
to on-device-arithmetic items in this category given the dependency and
accuracy risk.

---

## Implementation Plan (Low-Level)

### Schema changes

No new Drift tables or columns. This feature adds no persistence beyond
what `WaterLogsTable` already stores — the photo is discarded after
inference, and the estimate is passed directly into the existing
`LogWaterEntryUseCase`. A new column `source` value `'photo'` on
`WaterLogsTable.source` is the only schema-adjacent change (the column
already exists as a `TextColumn`; the new source type is a presentation-
layer enum extension).

### Domain entities

**New file:** `lib/features/water/domain/entities/volume_estimate.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'volume_estimate.freezed.dart';

/// The category the vision model classified the container as.
enum ContainerType {
  smallGlass,   // ~200-250 ml
  largeGlass,   // ~300-400 ml
  mug,          // ~300-500 ml
  bottle,       // ~500-750 ml
  largeBottle,  // ~750-1000 ml
  pitcher,      // ~1000+ ml
  unknown,
}

/// Result of on-device volume estimation from a camera capture.
@freezed
sealed class VolumeEstimate with _$VolumeEstimate {
  const factory VolumeEstimate({
    required int estimatedMl,
    required double confidence,  // 0.0 - 1.0
    required ContainerType containerType,
  }) = _VolumeEstimate;
}
```

**Modify:** `lib/features/water/domain/entities/water_entry.dart`
Add `photo` to the `WaterEntrySource` enum:

```dart
enum WaterEntrySource {
  quick,
  custom,
  photo,  // NEW — logged via photo-based volume estimation
}
```

### Use case signatures

**New file:** `lib/features/water/domain/usecases/estimate_container_volume.dart`

```dart
import 'dart:typed_data';
import 'package:habit_tracker/features/water/domain/entities/volume_estimate.dart';

/// Wraps the on-device vision model to estimate container volume from
/// an image. Pure over the model interface — no repository dependency.
class EstimateContainerVolumeUseCase {
  const EstimateContainerVolumeUseCase(this._inferenceService);

  final VolumeInferenceService _inferenceService;

  /// Estimates volume from [imageBytes] (JPEG/PNG).
  /// Returns a [VolumeEstimate] with the estimated ml, confidence,
  /// and classified container type.
  Future<VolumeEstimate> execute(Uint8List imageBytes) async {
    final raw = await _inferenceService.estimate(imageBytes);
    return VolumeEstimate(
      estimatedMl: raw.estimatedMl.clamp(50, 2000),
      confidence: raw.confidence.clamp(0.0, 1.0),
      containerType: raw.containerType,
    );
  }
}
```

### Inference service interface

**New file:** `lib/features/water/domain/services/volume_inference_service.dart`

```dart
import 'dart:typed_data';

/// Raw inference output from the on-device vision model.
class VolumeInferenceResult {
  const VolumeInferenceResult({
    required this.estimatedMl,
    required this.confidence,
    required this.containerType,
  });

  final int estimatedMl;
  final double confidence;
  final dynamic containerType; // mapped to ContainerType by the use case
}

/// Interface for on-device volume inference — implemented by the
/// platform-specific inference layer, abstracted here so the use case
/// and tests have no dependency on the vision package.
abstract class VolumeInferenceService {
  /// Runs inference on [imageBytes] and returns raw results.
  Future<VolumeInferenceResult> estimate(Uint8List imageBytes);
}
```

### Data layer

**New file:** `lib/features/water/data/services/volume_inferenceServiceImpl.dart`

Platform-specific implementation wrapping `google_mlkit_object_detection`
(or chosen package). Responsible for:
- Loading the bundled/downloaded model
- Running inference on the camera image
- Mapping raw detections to `VolumeInferenceResult`

The `WaterEntrySource` DB mapping in `water_repository_impl.dart` gains
the `'photo'` case:

```dart
// In WaterEntrySourceDb extension:
static WaterEntrySource fromDb(String value) => switch (value) {
  'quick' => WaterEntrySource.quick,
  'photo' => WaterEntrySource.photo,
  _ => WaterEntrySource.custom,
};

String toDb() => switch (this) {
  WaterEntrySource.quick => 'quick',
  WaterEntrySource.photo => 'photo',
  WaterEntrySource.custom => 'custom',
};
```

### Camera permission handling

**New file:** `lib/features/water/presentation/permissions/camera_permission.dart`

```dart
import 'package:permission_handler/permission_handler.dart';

/// Requests camera permission with a rationale flow.
/// Returns true if granted, false otherwise.
Future<bool> requestCameraPermission() async {
  var status = await Permission.camera.status;
  if (status.isGranted) return true;
  if (status.isPermanentlyDenied) return false;
  status = await Permission.camera.request();
  return status.isGranted;
}
```

Note: `permission_handler` is already widely used in Flutter; if the
project prefers to avoid it, platform-channel manual handling is
equivalent. The key is: never silently request — always show a
rationale dialog before the system prompt.

### Presentation layer

**New file:** `lib/features/water/presentation/screens/water_photo_capture_screen.dart`

Full-screen camera view with:
1. Camera preview (full bleed)
2. Capture button (center bottom)
3. On capture: image → `EstimateContainerVolumeUseCase` → loading overlay
4. Result: preview thumbnail (small) + editable amount field pre-filled
   with estimate + confidence indicator (low/medium/high label)
5. "Use This" button → calls `WaterController.logPhoto(amountMl:)` → pops
6. "Retake" button → returns to camera preview
7. Photo bytes discarded immediately after inference (not stored)

**Modify:** `lib/features/water/presentation/screens/water_home_screen.dart`

Add a camera icon button to the quick-add `Wrap` area, after the existing
quick-add chips and before the "Custom" button:

```dart
OutlinedButton.icon(
  onPressed: () => context.push('/water/photo-capture'),
  icon: const Icon(Icons.camera_alt_outlined),
  label: Text(l10n.waterHomePhotoCaptureButton),
),
```

**Modify:** `lib/features/water/presentation/providers/water_controller.dart`

Add a `logPhoto` method:

```dart
/// Logs a photo-estimated entry (FR-W-photo).
Future<void> logPhoto({required int amountMl}) => _log(
  amountMl: amountMl,
  source: WaterEntrySource.photo,
);
```

**New file:** `lib/features/water/presentation/providers/photo_capture_providers.dart`

Riverpod providers:
- `cameraControllerProvider` — manages the `CameraController` lifecycle
- `volumeEstimateProvider` — `FutureProvider<VolumeEstimate>` keyed by
  captured image bytes
- `cameraPermissionProvider` — `FutureProvider<bool>`

**Modify:** `lib/core/router/app_router.dart`

Add route under the Water branch:

```dart
GoRoute(
  path: 'photo-capture',
  builder: (context, state) => const WaterPhotoCaptureScreen(),
),
```

**Modify:** `lib/core/l10n/app_en.arb` and `lib/core/l10n/app_bn.arb`

Add localization keys:
- `waterHomePhotoCaptureButton` — "Photo"
- `waterPhotoCaptureTitle` — "Capture Container"
- `waterPhotoCaptureRetake` — "Retake"
- `waterPhotoCaptureUseThis` — "Use This"
- `waterPhotoCaptureEstimateLabel` — "Estimated volume"
- `waterPhotoCaptureLowConfidence` — "Low confidence — please verify"
- `waterPhotoCapturePermissionTitle` — "Camera Permission"
- `waterPhotoCapturePermissionBody` — "Camera access is needed to photograph your container for volume estimation. No photos are stored."

### Model strategy

**Bundled-in-app (recommended):**
- Model file (~5-15 MB) included in `assets/models/` directory
- Declared in `pubspec.yaml` under `flutter: assets:`
- Works fully offline immediately — no first-run network dependency
- Consistent with the app's offline-first framing
- Acceptable app-size increase for the novelty value

The model itself is a TFLite object-detection model fine-tuned for
containers/cups/bottles. The exact model choice is an open evaluation
item, but the architecture above abstracts it behind
`VolumeInferenceService` so the model can be swapped without changing
any domain/presentation code.

### Testing strategy

| Test file | What it covers |
|---|---|
| `test/features/water/domain/usecases/estimate_container_volume_test.dart` | Unit tests: confidence clamping, ml clamping (50-2000 range), container type passthrough. Mock `VolumeInferenceService`. |
| `test/features/water/domain/entities/volume_estimate_test.dart` | Freezed entity construction, equality, copyWith. |
| `test/features/water/data/services/volume_inference_service_test.dart` | Integration test with mock model output → `VolumeEstimate` mapping. |
| `test/features/water/presentation/providers/photo_capture_providers_test.dart` | Provider state transitions: permission granted/denied, inference loading/success/error. |
| `test/features/water/domain/usecases/log_water_entry_photo_test.dart` | Verify `LogWaterEntryUseCase` accepts `source: WaterEntrySource.photo` identically to `quick`/`custom`. |
| `test/features/water/data/repositories/water_repository_impl_test.dart` | Add a round-trip test for the `photo` source type DB mapping. |

### File paths

**Files to create:**
- `lib/features/water/domain/entities/volume_estimate.dart`
- `lib/features/water/domain/services/volume_inference_service.dart`
- `lib/features/water/domain/usecases/estimate_container_volume.dart`
- `lib/features/water/data/services/volume_inferenceServiceImpl.dart`
- `lib/features/water/presentation/permissions/camera_permission.dart`
- `lib/features/water/presentation/screens/water_photo_capture_screen.dart`
- `lib/features/water/presentation/providers/photo_capture_providers.dart`

**Files to modify:**
- `lib/features/water/domain/entities/water_entry.dart` — add `photo` source
- `lib/features/water/data/repositories/water_repository_impl.dart` — add `photo` DB mapping
- `lib/features/water/presentation/providers/water_controller.dart` — add `logPhoto` method
- `lib/features/water/presentation/screens/water_home_screen.dart` — add camera button
- `lib/core/router/app_router.dart` — add photo-capture route
- `lib/core/l10n/app_en.arb` — add localization keys
- `lib/core/l10n/app_bn.arb` — add localization keys
- `pubspec.yaml` — add `permission_handler`, `camera`, model assets

### Sequencing

| # | Task | Depends on | Effort |
|---|---|---|---|
| T1 | Add `photo` to `WaterEntrySource` enum + DB mapping + round-trip test | — | S |
| T2 | Create `VolumeEstimate` entity + `VolumeInferenceService` interface | — | S |
| T3 | Create `EstimateContainerVolumeUseCase` + unit tests | T2 | S |
| T4 | Implement `VolumeInferenceServiceImpl` with chosen vision package | T2 | M |
| T5 | Camera permission handler + rationale flow | — | S |
| T6 | Camera provider + inference providers (Riverpod) | T2, T3, T5 | M |
| T7 | `WaterPhotoCaptureScreen` (camera → estimate → edit → confirm) | T4, T6 | L |
| T8 | Add camera button to `WaterHomeScreen` + route registration | T7 | S |
| T9 | `WaterController.logPhoto` + integration with `LogWaterEntryUseCase` | T1 | S |
| T10 | Localization keys (en + bn) | — | S |
| T11 | Bundle model assets + pubspec.yaml updates | T4 | S |
| T12 | Integration tests + manual device verification | T8, T9, T10, T11 | M |

**Total estimated effort:** M (matching atlas complexity) — the dominant
cost is T4 (vision package integration + model evaluation) and T7
(camera-capture screen with loading/error states). Everything else is
small and sequential.

### Open items to resolve before implementation

1. **Vision package evaluation:** `google_mlkit_object_detection` vs
   `tflite_flutter` + custom model vs `onnxruntime`. Needs a spike on
   Android+iOS device-perf across tiers.
2. **Model accuracy bar:** Is small/medium/large classification (mapped
   to preset volumes) sufficient, or is per-container ml estimation
   reliable enough? The UI already shows an editable field, so rough
   classification may be fine.
3. **`permission_handler` vs manual:** Decide whether to add the
   `permission_handler` dependency or handle camera permission via
   platform channels directly.
