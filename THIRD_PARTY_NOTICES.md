# Third-party notices / 开源声明

Android soft-glass navigation and top-bar components are copied from
[AritxOnly/HyperModifier](https://github.com/AritxOnly/HyperModifier), revision 84fab7c2c06b19468fea469a09223667b9f85404.
Upstream retains authorship, original package names, and source comments, including
Deadliner provenance and Kyant0/AndroidLiquidGlass shader attribution.
License: GNU GPL version 3 (see LICENSE and app/src/main/assets/licenses/HyperModifier-GPL-3.0.txt).
Imported files: app/src/main/java/com/aritxonly/deadliner/{model,ui/material/glass,ui/theme,ui/navigation}.
Changes on 2026-10-12: source attribution headers, Android 12 progressive-blur and glass-material capability guards;
RentReceipt adapters connect existing tabs, icons, page scrolling and top-bar actions.
Shared page-only backdrop recording and background-color capture match the upstream scaffold;
glass chrome is excluded from the recorded source.
No upstream app icons or runtime hooks are included.

Kyant0/AndroidLiquidGlass: https://github.com/Kyant0/AndroidLiquidGlass (Apache-2.0).
Its attribution in GlassRefractionShader.kt is preserved. See bundled Apache-2.0 license.
Shapes 1.2.0: https://github.com/Kyant0/Shapes (Apache-2.0).

## Distribution

RentReceipt Android is licensed under GPL-3.0. It is provided without warranty.
Recipients may use, modify and redistribute it under that license.
Distribute the full corresponding source for the exact APK version, including modified
components and build scripts, alongside the APK with equally accessible download links.
An upstream project link alone does not provide the corresponding source of this modified App.
Never include signing passwords, private keys, tenant records or personal backups in source archives.
Project source: https://github.com/VincentGan260/RentReceipt

2026-10-12: also directly vendored DeadlinerMiuixScaffold.kt (original package and implementation),
used as the common top/body/bottom material host. Bottom glass stays visible during scrolling,
as in HyperModifier, and samples the same source as the top bar.

Full Android UI migration on 2026-10-12: directly imported MhmPresetColors.kt,
DeadlinerMiuixControls.kt and DeadlinerSettingsComponents.kt. Fixed original light/dark
palette replaces wallpaper colors; grouped sections, controls and glass dialogs are
adapted to existing rent workflows. Original business callbacks and calculations are retained.

2026-10-12 UI refinements: neutral TextField backgrounds; detached bottom-right
search action uses SoftGlassIconButton; app-wide typography scale, including a
caption-style adaptation in MiuixFloatingTabBar.kt. Rent filtering is unchanged.

2026-10-12: compact grouped row spacing in DeadlinerSettingsComponents.kt;
search drafts apply on submission; room-list search added; page tab transitions
no longer animate the entire navigation container. Detail pages omit the large-title
scroll connection. Existing rent calculations, saves and exports remain intact.

2026-10-12: grouped rows use a common 16dp horizontal inset and compact vertical spacing;
back actions use the glass icon-button wrapper; main tab content animates separately
from chrome. Existing business handlers are retained.
