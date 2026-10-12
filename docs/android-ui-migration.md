# Android UI migration

Uses HyperModifier revision 84fab7c2c06b19468fea469a09223667b9f85404.
All rent screens share the upstream preset light/dark palette, grouped SettingsSection
surfaces, MIUIX typography and text fields, Deadliner switch/slider wrappers,
DeadlinerMiuixScaffold page material, floating tab bar and glass OverlayDialog.
Main pages use collapsing TopAppBar; details use SmallTopAppBar.
The original rent workflows, validation callbacks, ViewModel, model, repository,
backup and exporters remain intact. iOS is outside this migration.

Existing wallpaper-color and alternate-navigation preferences remain stored for
backward compatibility, but do not affect this preset UI and are no longer exposed.
Page scaling, animation and light/dark accessibility preferences remain available.

See THIRD_PARTY_NOTICES.md and hypermodifier-source-manifest.json for provenance.

## Validation (2026-10-12)

Android debug build passed; all 16 unit tests passed. Hash comparison confirmed
44 business, test and iOS files were unchanged during this migration.
Installed on RMX3562 via adb. Main tab navigation, appearance preset page, opening
and closing the glass license dialog, and back navigation passed.
No RentReceipt AndroidRuntime exceptions were reported during these checks.
These checks do not replace full visual acceptance or every business-flow test.

## Typography and search refinement

Body and field text: 16sp/22sp. Secondary text: 14sp/20sp. Captions: 12sp/16sp.
Section titles: 20sp/26sp. Page titles: 32sp/40sp. Numeric values retain their
adaptive width handling with a matching line height. MIUIX and Material theme
typography share these scales, with Android extra font padding disabled.
TextField uses the neutral surfaceContainerHigh background; focus stays primary.
Overview and entry search move from a permanent top bar to a detached soft-glass
action beside the floating bottom navigation. The dialog edits the same query
state, and active filters can be cleared from either dialog or list.

Follow-up: room search uses a draft and applies on submit; the same detached
search action is present on all main tabs. Detail lists omit the unused collapsing
header scroll connection. Tab switching no longer slides the entire page and chrome.
Grouped sections and settings rows use reduced padding. This revision was compiled
and installed only, per user request; visual/interaction acceptance is user-led.
