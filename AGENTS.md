# Spred iOS Engineering & UI Guidelines

This document provides architectural rules, styling standards, and implementation guidelines for AI agents and engineers working on the Spred iOS application codebase.

---

## UI & Navigation Guidelines

### Navigation Architecture
- Use standard SwiftUI `NavigationStack` with native navigation patterns whenever possible.
- Main landing screens (e.g., Home/Dashboard) use `.navigationTitle(...)` with `.navigationBarTitleDisplayMode(.large)` to support the familiar iOS large-title collapsing behavior.
- Modal input sheets (e.g., `AddOrderView`, `CapitalSettingsView`, `BankAccountsView`) typically use `.navigationBarTitleDisplayMode(.inline)` with standard `.cancellationAction` (Cancel/Done) and `.confirmationAction` (Save) toolbar placements.
- Primary screen-level creation actions (e.g., New Order/Trade) belong in the trailing navigation bar (`ToolbarItem(placement: .topBarTrailing)` or `.primaryAction`), ensuring single-source-of-truth access across both expanded and collapsed navigation bar states without floating buttons or duplicate triggers.

### Scroll Edge Fades

- Screens using the native iOS collapsing App Bar / Large Title navigation pattern must NOT use a custom top fade.
- Let the native navigation bar handle the top scroll-edge transition and content interaction.
- Do not add a top `ShaderMask`, gradient overlay, fade container, or custom scroll-edge fade to these screens.
- Bottom fades may still be used where appropriate and should extend naturally to the bottom edge of the screen without introducing additional layout space.
- Fade effects must never alter layout dimensions, Safe Area behavior, or native navigation-bar behavior.
- For screens with native collapsing navigation bars, use `.bottomScrollFade()` to apply the bottom fade while leaving the top edge transition entirely to native UIKit/SwiftUI navigation bar materials.
- For modal forms or sheets featuring custom pinned top controls (such as segmented pickers), edge fades must be strictly layered beneath header controls so that title, buttons, and pinned controls remain 100% visible, fully opaque, and interactive.
