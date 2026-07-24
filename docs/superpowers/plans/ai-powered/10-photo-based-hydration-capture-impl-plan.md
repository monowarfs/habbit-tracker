# Photo-Based Hydration Capture — Implementation Plan

**Spec:** [10-photo-based-hydration-capture-design.md](./10-photo-based-hydration-capture-design.md)
**Run:** TBD
**Estimated effort:** M
**Dependencies:** Water module (complete), `core/notifications` (complete), `permission_handler` package (new)

## Pre-requisites

- Water module fully functional with `LogWaterEntryUseCase`, `WaterEntrySource` enum, and `water_repository_impl.dart` DB mapping.
- Decision made on vision package: `google_mlkit_object_detection` vs `tflite_flutter` vs `onnxruntime`.
- Decision made on bundled-in-app vs download-on-first-use for the model file.
- Decision made on `permission_handler` package vs manual platform-channel camera permission.
- Model accuracy validated: small/medium/large classification mapped to preset volumes is sufficient, or per-container ml estimation is reliable enough.

## Tasks

### Task 1: Add `photo` to `WaterEntrySource` enum + DB mapping
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/water/domain/entities/water_entry.dart`
- `lib/features/water/data/repositories/water_repository_impl.dart`

**Description:** Add `photo` variant to the `WaterEntrySource` enum. Update the `WaterEntrySourceDb` extension's `fromDb` and `toDb` methods to handle the `'photo'` string mapping alongside existing `'quick'` and `'custom'` values.

**Acceptance criteria:**
- `WaterEntrySource.photo` exists in the enum.
- `fromDb('photo')` returns `WaterEntrySource.photo`.
- `WaterEntrySource.photo.toDb()` returns `'photo'`.
- No schema migration needed — `source` is already a `TextColumn`.

**Test:** `test/features/water/data/repositories/water_repository_impl_test.dart` — add round-trip test for `photo` source type.

---

### Task 2: Create `VolumeEstimate` entity + `VolumeInferenceService` interface
**Effort:** S
**Files to create:**
- `lib/features/water/domain/entities/volume_estimate.dart`
- `lib/features/water/domain/services/volume_inference_service.dart`

**Files to modify:** (none)

**Description:** Create the `VolumeEstimate` Freezed entity with `estimatedMl`, `confidence`, and `containerType` fields. Create the `ContainerType` enum (`smallGlass`, `largeGlass`, `mug`, `bottle`, `largeBottle`, `pitcher`, `unknown`). Create the abstract `VolumeInferenceService` interface with the `estimate(Uint8List)` method, and the `VolumeInferenceResult` raw output class.

**Acceptance criteria:**
- `VolumeEstimate` compiles with generated `.freezed.dart`.
- `VolumeInferenceService` is abstract with a single `estimate` method.
- `VolumeInferenceResult` has `estimatedMl`, `confidence`, `containerType` fields.

**Test:** `test/features/water/domain/entities/volume_estimate_test.dart` — Freezed construction, equality, copyWith.

---

### Task 3: Create `EstimateContainerVolumeUseCase` + unit tests
**Effort:** S
**Files to create:**
- `lib/features/water/domain/usecases/estimate_container_volume.dart`

**Files to modify:** (none)

**Description:** Implement the use case that wraps `VolumeInferenceService`. It clamps `estimatedMl` to 50–2000, clamps `confidence` to 0.0–1.0, and passes through the `containerType`. Pure over the service interface — no repository dependency.

**Acceptance criteria:**
- `execute(Uint8List)` returns a `VolumeEstimate`.
- Values are clamped correctly at boundaries (49→50, 2001→2000, -0.1→0.0, 1.1→1.0).
- `containerType` passes through unchanged.

**Test:** `test/features/water/domain/usecases/estimate_container_volume_test.dart` — mock `VolumeInferenceService`, verify clamping logic at boundary values and passthrough.

---

### Task 4: Implement `VolumeInferenceServiceImpl` with chosen vision package
**Effort:** M
**Files to create:**
- `lib/features/water/data/services/volume_inference_service_impl.dart`

**Files to modify:** (none)

**Description:** Implement `VolumeInferenceService` using the chosen on-device vision package (`google_mlkit_object_detection` or equivalent). Load the bundled model, run inference on camera image bytes, map raw detections to `VolumeInferenceResult`. Handle model loading failures and inference errors gracefully (return a low-confidence `unknown` result rather than throwing).

**Acceptance criteria:**
- Implements `VolumeInferenceService`.
- Model loads from bundled assets on first call.
- Returns `VolumeInferenceResult` with reasonable defaults on inference failure.
- No network calls — strictly on-device.

**Test:** `test/features/water/data/services/volume_inference_service_test.dart` — integration test with mock model output mapped to `VolumeEstimate`.

---

### Task 5: Camera permission handler
**Effort:** S
**Files to create:**
- `lib/features/water/presentation/permissions/camera_permission.dart`

**Files to modify:** (none)

**Description:** Implement a `requestCameraPermission()` async function that checks current status, shows a rationale dialog before requesting if not yet determined, and handles permanently-denied state. Returns `true` if granted, `false` otherwise. Use `permission_handler` package or manual platform channels per the decision in pre-requisites.

**Acceptance criteria:**
- Returns `true` when permission is already granted.
- Requests permission only after rationale is shown.
- Returns `false` when permanently denied (directs user to settings).
- Never silently requests without user knowledge.

**Test:** Manual test on device — verify rationale dialog appears, grant/deny flows work.

---

### Task 6: Camera provider + inference providers (Riverpod)
**Effort:** M
**Files to create:**
- `lib/features/water/presentation/providers/photo_capture_providers.dart`

**Files to modify:** (none)

**Description:** Create Riverpod providers: `cameraControllerProvider` (manages `CameraController` lifecycle), `volumeEstimateProvider` (keyed by captured image bytes, returns `FutureProvider<VolumeEstimate>`), `cameraPermissionProvider` (`FutureProvider<bool>`). Wire `cameraControllerProvider` to initialize/dispose the camera properly. Wire `volumeEstimateProvider` to call `EstimateContainerVolumeUseCase`.

**Acceptance criteria:**
- `cameraControllerProvider` initializes camera on first watch and disposes on unmount.
- `volumeEstimateProvider` triggers inference and returns `VolumeEstimate`.
- `cameraPermissionProvider` returns permission status.
- Providers handle error/loading states correctly.

**Test:** `test/features/water/presentation/providers/photo_capture_providers_test.dart` — permission granted/denied, inference loading/success/error state transitions.

---

### Task 7: `WaterPhotoCaptureScreen`
**Effort:** L
**Files to create:**
- `lib/features/water/presentation/screens/water_photo_capture_screen.dart`

**Files to modify:** (none)

**Description:** Build the full-screen camera capture flow: camera preview (full bleed), capture button (center bottom), on capture show loading overlay while inference runs, display result with a small preview thumbnail, editable amount field pre-filled with estimate, confidence indicator (low/medium/high label), "Use This" button that calls `WaterController.logPhoto(amountMl:)` and pops, "Retake" button that returns to camera preview. Photo bytes are discarded immediately after inference.

**Acceptance criteria:**
- Camera preview renders full bleed.
- Capture button triggers image capture.
- Loading overlay shown during inference.
- Estimate displayed in editable field with confidence label.
- "Use This" saves entry and navigates back.
- "Retake" returns to camera view.
- Photo bytes are not retained after inference.

**Test:** Manual device test — capture photo, verify estimate appears, edit amount, confirm, verify entry logged.

---

### Task 8: Add camera button to `WaterHomeScreen` + route registration
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/water/presentation/screens/water_home_screen.dart`
- `lib/core/router/app_router.dart`

**Description:** Add a camera icon `OutlinedButton.icon` to the quick-add `Wrap` area on the Water home screen, after existing quick-add chips and before the "Custom" button. Register the `/water/photo-capture` route under the Water branch in `app_router.dart`.

**Acceptance criteria:**
- Camera button visible on Water home screen in the quick-add area.
- Tapping camera button navigates to `/water/photo-capture`.
- Route is registered and accessible.

**Test:** Widget test — verify camera button exists and navigates on tap.

---

### Task 9: `WaterController.logPhoto` method
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/water/presentation/providers/water_controller.dart`

**Description:** Add `logPhoto({required int amountMl})` method to `WaterController` that calls the existing `_log(amountMl: amountMl, source: WaterEntrySource.photo)`. This reuses the identical validation and persistence path as quick/custom logging.

**Acceptance criteria:**
- `logPhoto` method exists on `WaterController`.
- Calling it with `amountMl: 250` creates a `WaterEntry` with `source: WaterEntrySource.photo`.
- Entry appears in water logs with `photo` source.

**Test:** `test/features/water/domain/usecases/log_water_entry_photo_test.dart` — verify `LogWaterEntryUseCase` accepts `source: WaterEntrySource.photo` identically to `quick`/`custom`.

---

### Task 10: Localization keys (en + bn)
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**Description:** Add all new localization keys for the photo capture feature in both English and Bangla.

**Acceptance criteria:**
- All keys present in both ARB files.
- `flutter gen-l10n` succeeds without errors.

**Test:** `flutter gen-l10n` compiles cleanly; verify keys in `AppLocalizations`.

---

### Task 11: Bundle model assets + pubspec.yaml updates
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `pubspec.yaml`
- `assets/models/` (add model file)

**Description:** Add the TFLite object-detection model file (~5-15 MB) to `assets/models/`. Declare the assets directory in `pubspec.yaml` under `flutter: assets:`. Add `permission_handler` and `camera` packages to `pubspec.yaml` dependencies.

**Acceptance criteria:**
- Model file exists in `assets/models/`.
- `pubspec.yaml` declares the model assets and new dependencies.
- `flutter pub get` succeeds.

**Test:** `flutter pub get` succeeds; verify asset is accessible at runtime.

---

### Task 12: Integration tests + manual device verification
**Effort:** M
**Files to create:** (none)
**Files to modify:** (none)

**Description:** Run all unit/widget tests from prior tasks. Perform manual end-to-end verification on both Android and iOS: camera opens, photo captures, inference returns estimate, user can edit and confirm, entry logs with `photo` source, photo bytes discarded. Test permission denied flow. Test low-confidence indicator display.

**Acceptance criteria:**
- All prior test files pass.
- End-to-end flow works on Android and iOS.
- Camera permission denied flow degrades gracefully.
- No photos retained after inference.

**Test:** Run `flutter test` for all new test files; manual device verification checklist.

## Schema Migration

No schema migration needed. The `source` column already exists as a `TextColumn` on `WaterLogsTable`. Adding `'photo'` as a new value is a presentation-layer enum extension, not a DB change.

## Localization Keys

| Key | English | Bangla |
|-----|---------|--------|
| `waterHomePhotoCaptureButton` | Photo | ছবি |
| `waterPhotoCaptureTitle` | Capture Container | কাপ/বোতলের ছবি তুন |
| `waterPhotoCaptureRetake` | Retake | আবার তুলুন |
| `waterPhotoCaptureUseThis` | Use This | এটি ব্যবহার করুন |
| `waterPhotoCaptureEstimateLabel` | Estimated volume | আনুমানিক পরিমাণ |
| `waterPhotoCaptureLowConfidence` | Low confidence — please verify | কম নির্ভরযোগ্যতা — অনুগ্রহ করে যাচাই করুন |
| `waterPhotoCapturePermissionTitle` | Camera Permission | ক্যামেরার অনুমতি |
| `waterPhotoCapturePermissionBody` | Camera access is needed to photograph your container for volume estimation. No photos are stored. | পরিমাণ অনুমানের জন্য আপনার কাপ/বোতলের ছবি তুলতে ক্যামেরার অনুমতি প্রয়োজন। কোনো ছবি সংরক্ষিত হয় না। |

## Risk Notes

1. **Vision package evaluation spike required** — `google_mlkit_object_detection` vs `tflite_flutter` + custom model vs `onnxruntime` must be validated on Android+iOS device tiers before committing to T4.
2. **Model accuracy may be insufficient** — if container classification is unreliable, consider falling back to a simpler "tap a container-size icon" (no vision) approach that captures most of the value at a fraction of the cost.
3. **App size increase** — bundling a 5-15 MB model increases app binary size; acceptable for a novelty feature but should be communicated to stakeholders.
4. **Camera permission UX** — the rationale dialog must be clear that no photos are stored, to address privacy concerns upfront.
5. **`permission_handler` dependency** — evaluate whether adding this package aligns with the project's dependency philosophy; manual platform channels are an alternative.
