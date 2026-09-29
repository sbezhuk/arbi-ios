# Spred iOS Engineering & UI Guidelines

This document provides architectural rules, styling standards, and implementation guidelines for AI agents and engineers working on the Spred iOS application codebase.

---

## UI & Navigation Guidelines

### Navigation Architecture
- Use standard SwiftUI `NavigationStack` with native navigation patterns whenever possible.
- Main landing screens (e.g., Home/Dashboard) use `.navigationTitle(...)` with `.navigationBarTitleDisplayMode(.large)` to support the familiar iOS large-title collapsing behavior.
- Modal input sheets (e.g., `AddOrderView`, `CapitalSettingsView`, `BankAccountsView`) typically use `.navigationBarTitleDisplayMode(.inline)` with standard `.cancellationAction` (Cancel/Done) and `.confirmationAction` (Save) toolbar placements.
- Primary screen-level creation actions (e.g., New Order/Trade) belong in the trailing navigation bar (`ToolbarItem(placement: .topBarTrailing)` or `.primaryAction`), ensuring single-source-of-truth access across both expanded and collapsed navigation bar states without floating buttons or duplicate triggers.

### Native Scrolling & Materials
- All screens and modal sheets rely strictly on native UIKit/SwiftUI navigation bar materials and scrolling behaviors.
- Do not apply custom edge fade masks, gradient overlays, or shader masks to scroll containers.
- Pinned header controls (such as segmented pickers) and native navigation bars remain 100% visible, fully opaque, and interactive with native layout margins and safe area behavior.
