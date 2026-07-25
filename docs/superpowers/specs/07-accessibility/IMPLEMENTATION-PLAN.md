# Implementation Plan: Accessibility Features (07-accessibility)

**Specs:** 12 files | **Total estimated effort:** 12-15 days
**Created:** 2026-07-25

---

## Dependency Graph

```
Spec 01 (TalkBack Audit)          — foundational, prerequisite for 02, 06, 10, 12
Spec 02 (Chart Data Table)        — depends on 01
Spec 03 (Colorblind Palette)      — standalone, precede 06
Spec 04 (Haptic Feedback)         — standalone
Spec 05 (Text Scaling)            — pairs with 01
Spec 06 (Simple Mode)             — depends on 01, 03, 05
Spec 07 (Reduce Motion)           — standalone, preventive
Spec 08 (Audio Cues)              — standalone
Spec 09 (RTL Audit)               — standalone, precede 06
Spec 10 (Keyboard Navigation)     — pairs with 01, 05
Spec 11 (Captioned Onboarding)    — blocked on future onboarding
Spec 12 (Screen-Reader Onboarding)— blocked on future onboarding
```

## Recommended Implementation Order

### Wave 1: Audits and quick fixes (4-5 days)
| Spec | Effort | Notes |
|---|---|---|
| 01 TalkBack/VoiceOver Audit | 2 days | Foundational — all screens |
| 03 Colorblind Palette | 0.5 day | One-time audit + fixes |
| 04 Haptic Feedback | 0.5 day | Add HapticFeedback calls |
| 07 Reduce Motion | 0.5 day | Preventive rule + existing animations |
| 09 RTL Audit | 0.5 day | Structural sweep |

### Wave 2: Depends on Wave 1 (5-6 days)
| Spec | Effort | Notes |
|---|---|---|
| 02 Chart Data Table | 1 day | Builds on 01's chart labeling |
| 05 Text Scaling | 1 day | Pairs with 01's screen walkthrough |
| 08 Audio Cues | 1 day | Notification action sounds |
| 10 Keyboard Navigation | 1 day | Pairs with 01, 05 |
| 06 Simple Mode | 3 days | Depends on 01, 03, 05 — largest item |

### Blocked
| Spec | Effort | Notes |
|---|---|---|
| 11 Captioned Onboarding | 0.5 day | Blocked on future onboarding animation |
| 12 Screen-Reader Onboarding | 0.5 day | Blocked on future onboarding screen |

---

## Per-Spec Task Breakdown

### 01 TalkBack/VoiceOver Navigation Audit
1. Walk every screen with TalkBack (Android) and VoiceOver (iOS)
2. Add `Semantics` labels to icon-only buttons
3. Add semantic labels to fl_chart widgets
4. Add semantic labels to calendar day cells
5. Verify live-region announcements for snackbars
6. Fix gesture-only controls with alternative actions
7. Test with Bangla locale
8. Document findings in audit checklist
9. Tests

### 02 Chart Data-Table Fallback
1. Create `lib/core/widgets/chart_data_table.dart`
2. Extend `period_bar_chart.dart` to expose series data
3. Add toggle to reveal table (with Semantics action)
4. Handle empty data state
5. Add en/bn ARB keys
6. Tests

### 03 Colorblind-Safe Palette Audit
1. Run `AppSemanticColors` through CVD simulation (Sim Daltonism or equivalent)
2. Run per-module history calendar colors through simulation
3. Adjust hue/lightness where red/green fails
4. Add non-color cues (patterns, icons) where needed
5. Test dark theme separately
6. Document findings
7. Tests

### 04 Haptic Feedback on Log/Complete
1. Add `HapticFeedback.lightImpact()` to Water log success path
2. Add to Medicine dose-done success path
3. Add to Prayer checklist toggle success path
4. Consider adding to notification action handler
5. Add Settings toggle for haptics (optional)
6. Handle devices without vibration motor
7. Tests

### 05 Dynamic Text Scaling Stress Test
1. Set OS text size to maximum (200%+)
2. Walk every screen across all modules
3. Fix clipped text, overflowing rows, truncated labels
4. Allow wrapping/scrolling where rigid layouts break
5. Test both light/dark themes
6. Test both en/bn locales
7. Document fixes
8. Tests

### 06 Simple Mode Large-Button Layout
1. Add `simple_mode_enabled` column to `app_settings` Drift table
2. Create Simple Mode presentation layer (alternative layouts)
3. Build dashboard Simple Mode layout (single-column, large targets)
4. Build one primary action screen per module in Simple Mode
5. Add Settings toggle (SwitchListTile)
6. Ensure Simple Mode is itself accessible (text scaling, keyboard)
7. Add en/bn ARB keys
8. Tests

### 07 Reduce-Motion Respect
1. Audit existing animations for `MediaQuery.disableAnimations`
2. Wrap any found animations in reduce-motion check
3. Add instant state-change fallback for suppressed animations
4. Document standing rule in `docs/engineering/coding-standards.md`
5. Verify route transitions respect the setting
6. Tests

### 08 Audio Cue Alternative for Notification Actions
1. Source or create 3 short audio assets (done/snooze/skip)
2. Add audio playback to `notification_action_handler.dart`
3. Verify platform background audio constraints
4. Respect DND mode
5. Add Settings toggle for audio cues
6. Add en/bn ARB keys
7. Tests

### 09 RTL-Readiness Structural Audit
1. Force app into pseudo-RTL locale (`locale: Locale('ar')`)
2. Walk every screen for hardcoded `left`/`right`
3. Replace with `start`/`end` directional equivalents
4. Check icons for unwanted mirroring
5. Verify Prayer module direction-sensitive content
6. Document fixes
7. Tests

### 10 Focus-Order and Keyboard Navigation Pass
1. Attach external keyboard to test device
2. Tab through every form in Water, Medicine, Prayer
3. Fix illogical focus traversal order
4. Verify custom controls are keyboard-operable
5. Check dialog/bottom-sheet focus trapping
6. Verify form validation error focus
7. Document fixes
8. Tests

### 11 Captioned Onboarding
1. **BLOCKED:** Wait for onboarding animation feature
2. When built: provide WebVTT captions in en/bn
3. Add text-only alternative screen
4. Add pause/stop/hide controls for auto-play
5. Tests

### 12 Screen-Reader-Friendly Onboarding Order
1. **BLOCKED:** Wait for onboarding module-toggle screen
2. When built: verify TalkBack announces each toggle
3. Verify skip path is reachable and labeled
4. Verify toggle state announcements
5. Check other first-run screens (permissions)
6. Tests
