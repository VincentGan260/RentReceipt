// SPDX-License-Identifier: GPL-3.0-only
// Source: AritxOnly/HyperModifier, revision 84fab7c2c06b19468fea469a09223667b9f85404
// Vendored 2026-10-12 for RentReceipt; see THIRD_PARTY_NOTICES.md.
package com.aritxonly.deadliner.ui.navigation

import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Shape
import com.aritxonly.deadliner.ui.material.glass.SoftGlassShadowTokens
import com.aritxonly.deadliner.ui.material.glass.softGlassShadow
import com.aritxonly.deadliner.ui.material.glass.softGlassShadowTokens

internal fun floatingNavigationShadowTokens(isDark: Boolean): SoftGlassShadowTokens =
    softGlassShadowTokens(isDark)

fun Modifier.floatingNavigationShadow(
    shape: Shape,
    isDark: Boolean,
): Modifier {
    return softGlassShadow(
        shape = shape,
        isDark = isDark,
    )
}
