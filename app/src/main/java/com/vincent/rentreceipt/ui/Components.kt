package com.vincent.rentreceipt.ui

import androidx.compose.runtime.CompositionLocalProvider
import com.aritxonly.deadliner.ui.material.glass.ProgressiveTopBarMaterial
import com.aritxonly.deadliner.ui.material.glass.LocalTopBarScrollProgress
import com.aritxonly.deadliner.ui.material.glass.LocalImmersiveTopBarEnabled
import com.aritxonly.deadliner.ui.material.glass.LocalTopBarButtonMaterialProgress
import com.aritxonly.deadliner.ui.material.glass.SoftGlassIconButton
import com.aritxonly.deadliner.ui.theme.LocalAdvancedMaterialBackdrop
import com.aritxonly.deadliner.ui.theme.LocalAdvancedMaterialSpec
import com.aritxonly.deadliner.ui.theme.AdvancedMaterialSpec
import android.Manifest
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.widget.Toast
import androidx.activity.SystemBarStyle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.material3.Card
import androidx.compose.material3.Icon as MaterialIcon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Shapes
import androidx.compose.material3.Text as MaterialText
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import java.io.File
import kotlinx.coroutines.flow.distinctUntilChanged
import com.materialkolor.PaletteStyle
import com.materialkolor.dynamiccolor.ColorSpec
import com.materialkolor.rememberDynamicColorScheme
import top.yukonga.miuix.kmp.theme.MiuixTheme as XiaomiTheme
import top.yukonga.miuix.kmp.theme.LocalContentColor as XiaomiLocalContentColor
import top.yukonga.miuix.kmp.theme.ColorSchemeMode
import top.yukonga.miuix.kmp.theme.ThemeColorSpec
import top.yukonga.miuix.kmp.theme.ThemeController
import top.yukonga.miuix.kmp.theme.ThemePaletteStyle
import top.yukonga.miuix.kmp.basic.Card as XiaomiCard
import top.yukonga.miuix.kmp.basic.Button as XiaomiButton
import top.yukonga.miuix.kmp.basic.ButtonDefaults as XiaomiButtonDefaults
import top.yukonga.miuix.kmp.basic.TextButton as XiaomiTextButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold as XiaomiScaffold
import top.yukonga.miuix.kmp.basic.SearchBar as XiaomiSearchBar
import top.yukonga.miuix.kmp.basic.InputField as XiaomiInputField
import top.yukonga.miuix.kmp.basic.SmallTitle as XiaomiSmallTitle
import top.yukonga.miuix.kmp.basic.TopAppBar as XiaomiTopAppBar
import top.yukonga.miuix.kmp.basic.IconButton as XiaomiIconButton
import top.yukonga.miuix.kmp.basic.Icon as XiaomiIcon
import top.yukonga.miuix.kmp.basic.FloatingActionButton as XiaomiFloatingActionButton
import top.yukonga.miuix.kmp.basic.Slider as XiaomiSlider
import top.yukonga.miuix.kmp.basic.LinearProgressIndicator as XiaomiLinearProgressIndicator
import top.yukonga.miuix.kmp.basic.Switch as XiaomiSwitch
import top.yukonga.miuix.kmp.basic.TextField as XiaomiTextField
import top.yukonga.miuix.kmp.basic.TextFieldDefaults as XiaomiTextFieldDefaults
import top.yukonga.miuix.kmp.basic.Text as XiaomiText
import top.yukonga.miuix.kmp.window.WindowDialog as XiaomiWindowDialog
import top.yukonga.miuix.kmp.preference.SwitchPreference as XiaomiSwitchPreference
import top.yukonga.miuix.kmp.utils.PressFeedbackType
import top.yukonga.miuix.kmp.blur.BlendColorEntry
import top.yukonga.miuix.kmp.blur.BlurDefaults
import top.yukonga.miuix.kmp.blur.ProgressiveBlur
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.progressiveTextureBlur
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop

private class PageMaterialHost {
    var backdrop by mutableStateOf<top.yukonga.miuix.kmp.blur.LayerBackdrop?>(null)
}
private val LocalPageMaterialHost = staticCompositionLocalOf { PageMaterialHost() }

val LocalPageTransitionModifier = staticCompositionLocalOf<Modifier> { Modifier }

val LocalPageSearchAction = staticCompositionLocalOf<(@Composable () -> Unit)?> { null }

val LocalPageBottomBar = staticCompositionLocalOf<(@Composable () -> Unit)?> { null }

val LocalPageScrollStateChange = staticCompositionLocalOf<(Boolean) -> Unit> { {} }
val LocalUseMiuix = staticCompositionLocalOf { false }
val LocalBottomBarStyle = staticCompositionLocalOf { BottomBarStyle.LIQUID_GLASS }
val LocalAnimationsEnabled = staticCompositionLocalOf { true }
private val LocalDialogAction = staticCompositionLocalOf { false }
private val LocalPrimaryDialogAction = staticCompositionLocalOf { false }

private fun Modifier.dialogAction(): Modifier =
    fillMaxWidth().heightIn(min = 52.dp)

/** Semantic tokens shared by the intentional MIUIX and Material 3 presentation modes. */
object KitColors {
    val background: Color
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.colorScheme.background
        } else MaterialTheme.colorScheme.background
    val primary: Color
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.colorScheme.primary
        } else MaterialTheme.colorScheme.primary
    val primaryContainer: Color
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.colorScheme.primaryContainer
        } else MaterialTheme.colorScheme.primaryContainer
    val secondaryContainer: Color
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.colorScheme.secondaryContainer
        } else MaterialTheme.colorScheme.secondaryContainer
    val tertiaryContainer: Color
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.colorScheme.tertiaryContainer
        } else MaterialTheme.colorScheme.tertiaryContainer
    val error: Color
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.colorScheme.error
        } else MaterialTheme.colorScheme.error
    val onSurface: Color
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.colorScheme.onSurface
        } else MaterialTheme.colorScheme.onSurface
    val onSurfaceVariant: Color
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.colorScheme.onSurfaceVariantSummary
        } else MaterialTheme.colorScheme.onSurfaceVariant
    val surface: Color
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.colorScheme.surface
        } else MaterialTheme.colorScheme.surface
    val surfaceContainer: Color
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.colorScheme.surfaceContainer
        } else MaterialTheme.colorScheme.surfaceContainer
    val surfaceContainerHigh: Color
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.colorScheme.surfaceContainerHigh
        } else MaterialTheme.colorScheme.surfaceContainerHigh
}

object KitTypography {
    val displaySmall: TextStyle @Composable get() = XiaomiTheme.textStyles.title1
    val headlineMedium: TextStyle @Composable get() = XiaomiTheme.textStyles.title4
    val headlineSmall: TextStyle @Composable get() = XiaomiTheme.textStyles.title4
    val titleLarge: TextStyle @Composable get() = XiaomiTheme.textStyles.title4
    val titleMedium: TextStyle @Composable get() = XiaomiTheme.textStyles.headline1
    val titleSmall: TextStyle @Composable get() = XiaomiTheme.textStyles.subtitle
    val bodyLarge: TextStyle @Composable get() = XiaomiTheme.textStyles.body1
    val summary: TextStyle @Composable get() = XiaomiTheme.textStyles.footnote1
    val labelLarge: TextStyle @Composable get() = XiaomiTheme.textStyles.button
    val labelSmall: TextStyle @Composable get() = XiaomiTheme.textStyles.footnote2
}

private fun uiText(size: Int, height: Int, weight: FontWeight = FontWeight.Normal) = TextStyle(
    fontSize = size.sp, lineHeight = height.sp, fontWeight = weight,
    platformStyle = androidx.compose.ui.text.PlatformTextStyle(includeFontPadding = false)
)

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    if (LocalUseMiuix.current) {
        XiaomiText(text = text, color = XiaomiTheme.colorScheme.primary,
            style = XiaomiTheme.textStyles.footnote1,
            modifier = modifier.padding(horizontal = 24.dp, vertical = 8.dp))
    } else {
        Text(
            text = text,
            modifier = modifier.padding(horizontal = 4.dp, vertical = 8.dp),
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
fun Text(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = Color.Unspecified,
    style: TextStyle? = null,
    overflow: TextOverflow = TextOverflow.Clip,
    maxLines: Int = Int.MAX_VALUE
) {
    val resolvedStyle = style ?: if (color == KitColors.onSurfaceVariant) KitTypography.summary else KitTypography.bodyLarge
    if (LocalUseMiuix.current) {
        XiaomiText(
            text = text,
            modifier = modifier,
            color = color,
            style = resolvedStyle,
            overflow = overflow,
            maxLines = maxLines
        )
    } else {
        MaterialText(text = text, modifier = modifier, color = color, style = resolvedStyle,
            overflow = overflow, maxLines = maxLines)
    }
}

@Composable
fun Icon(
    imageVector: ImageVector,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    tint: Color = Color.Unspecified
) {
    if (LocalUseMiuix.current) {
        if (tint == Color.Unspecified) XiaomiIcon(imageVector, contentDescription, modifier)
        else XiaomiIcon(imageVector, contentDescription, modifier, tint)
    } else {
        if (tint == Color.Unspecified) MaterialIcon(imageVector, contentDescription, modifier)
        else MaterialIcon(imageVector, contentDescription, modifier, tint)
    }
}

@Composable
fun Icon(
    painter: Painter,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    tint: Color = Color.Unspecified
) {
    if (LocalUseMiuix.current) {
        if (tint == Color.Unspecified) XiaomiIcon(painter, contentDescription, modifier)
        else XiaomiIcon(painter, contentDescription, modifier, tint)
    } else {
        if (tint == Color.Unspecified) MaterialIcon(painter, contentDescription, modifier)
        else MaterialIcon(painter, contentDescription, modifier, tint)
    }
}

@Composable
fun Button(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit
) {
    val actionModifier = if (LocalDialogAction.current) modifier.dialogAction() else modifier
    if (LocalUseMiuix.current) {
        XiaomiButton(
            onClick = onClick,
            modifier = actionModifier,
            enabled = enabled,
            colors = XiaomiButtonDefaults.buttonColorsPrimary(),
            content = content
        )
    } else {
        androidx.compose.material3.Button(onClick, actionModifier, enabled, content = content)
    }
}

@Composable
fun FilledTonalButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit
) {
    val actionModifier = if (LocalDialogAction.current) modifier.dialogAction() else modifier
    if (LocalUseMiuix.current) {
        XiaomiButton(onClick, actionModifier, enabled, content = content)
    } else {
        androidx.compose.material3.FilledTonalButton(onClick, actionModifier, enabled, content = content)
    }
}

@Composable
fun OutlinedButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    destructive: Boolean = false,
    content: @Composable RowScope.() -> Unit
) {
    val actionModifier = if (LocalDialogAction.current) modifier.dialogAction() else modifier
    if (LocalUseMiuix.current) {
        val miuixColors = if (destructive) {
            XiaomiButtonDefaults.buttonColors(
                color = XiaomiTheme.colorScheme.errorContainer,
                contentColor = XiaomiTheme.colorScheme.error
            )
        } else XiaomiButtonDefaults.buttonColors()
        XiaomiButton(onClick, actionModifier, enabled, colors = miuixColors, content = content)
    } else {
        androidx.compose.material3.OutlinedButton(
            onClick = onClick,
            modifier = actionModifier,
            enabled = enabled,
            border = if (destructive) BorderStroke(1.dp, MaterialTheme.colorScheme.error) else null,
            colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(
                contentColor = if (destructive) MaterialTheme.colorScheme.error
                else MaterialTheme.colorScheme.primary
            ),
            content = content
        )
    }
}

@Composable
fun TextButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    if (LocalDialogAction.current) {
        if (LocalPrimaryDialogAction.current) {
            Button(onClick = onClick, modifier = modifier, enabled = enabled) { Text(text, maxLines = 1) }
        } else {
            OutlinedButton(onClick = onClick, modifier = modifier, enabled = enabled) { Text(text, maxLines = 1) }
        }
    } else if (LocalUseMiuix.current) {
        XiaomiTextButton(text = text, onClick = onClick, modifier = modifier, enabled = enabled)
    } else {
        androidx.compose.material3.TextButton(onClick, modifier, enabled) { MaterialText(text) }
    }
}

/** Icon + text action; Miuix 0.9.3 TextButton only accepts a String label. */
@Composable
fun IconTextButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit
) {
    if (LocalUseMiuix.current) {
        XiaomiButton(onClick, modifier, enabled, content = content)
    } else {
        androidx.compose.material3.TextButton(onClick, modifier, enabled, content = content)
    }
}

@Composable
fun KitIconButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable () -> Unit
) {
    if (LocalUseMiuix.current && LocalImmersiveTopBarEnabled.current) {
        SoftGlassIconButton(onClick = onClick, modifier = modifier, enabled = enabled,
            materialAlpha = LocalTopBarButtonMaterialProgress.current,
            shadowRadiusScale = 0.34f, content = content)
    } else if (LocalUseMiuix.current) {
        XiaomiIconButton(
            onClick = onClick,
            modifier = modifier,
            enabled = enabled,
            content = content
        )
    } else {
        androidx.compose.material3.IconButton(
            onClick = onClick,
            modifier = modifier,
            enabled = enabled,
            content = content
        )
    }
}

@Composable
fun KitExtendedFloatingActionButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: @Composable () -> Unit,
    text: @Composable () -> Unit
) {
    if (LocalUseMiuix.current) {
        XiaomiFloatingActionButton(
            onClick = onClick,
            modifier = modifier,
            containerColor = XiaomiTheme.colorScheme.primary
        ) {
            androidx.compose.runtime.CompositionLocalProvider(
                XiaomiLocalContentColor provides XiaomiTheme.colorScheme.onPrimary
            ) {
                Row(
                    Modifier.padding(horizontal = 18.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    icon()
                    androidx.compose.foundation.layout.Spacer(Modifier.width(8.dp))
                    text()
                }
            }
        }
    } else {
        androidx.compose.material3.ExtendedFloatingActionButton(
            onClick = onClick,
            modifier = modifier,
            icon = icon,
            text = text
        )
    }
}

@Composable
fun KitSwitch(
    checked: Boolean,
    onCheckedChange: ((Boolean) -> Unit)?,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    if (LocalUseMiuix.current) {
        com.aritxonly.myhypermodifier.DeadlinerSwitch(
            checked = checked,
            onCheckedChange = { onCheckedChange?.invoke(it) },
            modifier = modifier,
            enabled = enabled
        )
    } else {
        androidx.compose.material3.Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            modifier = modifier,
            enabled = enabled
        )
    }
}

@Composable
fun KitSwitchPreference(
    title: String,
    summary: String? = null,
    checked: Boolean,
    enabled: Boolean = true,
    icon: ImageVector? = null,
    onCheckedChange: (Boolean) -> Unit
) {
    if (LocalUseMiuix.current) {
        com.aritxonly.myhypermodifier.SettingsSwitchItem(
            label = title, supportingText = summary.orEmpty(), checked = checked,
            enabled = enabled, onCheckedChange = onCheckedChange
        )
        return
    }
    Row(
        Modifier.fillMaxWidth().padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        icon?.let {
            Icon(
                it,
                null,
                Modifier.size(24.dp),
                tint = if (LocalUseMiuix.current) XiaomiTheme.colorScheme.primary
                else MaterialTheme.colorScheme.primary
            )
            androidx.compose.foundation.layout.Spacer(Modifier.width(12.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            summary?.let { Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        KitSwitch(checked, onCheckedChange, enabled = enabled)
    }
}

@Composable
fun KitSlider(
    value: Float,
    onValueChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    valueRange: ClosedFloatingPointRange<Float> = 0f..1f,
    steps: Int = 0
) {
    if (LocalUseMiuix.current) {
        com.aritxonly.myhypermodifier.DeadlinerSlider(
            value = value,
            onValueChange = onValueChange,
            modifier = modifier,
            enabled = enabled,
            valueRange = valueRange,
            steps = steps
        )
    } else {
        androidx.compose.material3.Slider(
            value = value,
            onValueChange = onValueChange,
            modifier = modifier,
            enabled = enabled,
            valueRange = valueRange,
            steps = steps
        )
    }
}

@Composable
fun KitLinearProgressIndicator(
    modifier: Modifier = Modifier,
    progress: Float? = null
) {
    if (LocalUseMiuix.current) {
        XiaomiLinearProgressIndicator(modifier = modifier, progress = progress)
    } else if (progress == null) {
        androidx.compose.material3.LinearProgressIndicator(modifier = modifier)
    } else {
        androidx.compose.material3.LinearProgressIndicator(
            progress = { progress },
            modifier = modifier
        )
    }
}

@Composable
fun KitTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    singleLine: Boolean = true,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    leadingIcon: @Composable (() -> Unit)? = null,
    trailingIcon: @Composable (() -> Unit)? = null
) {
    if (LocalUseMiuix.current) {
        XiaomiTextField(
            value = value,
            onValueChange = onValueChange,
            label = label,
            useLabelAsPlaceholder = false,
            modifier = modifier,
            enabled = enabled,
            singleLine = singleLine,
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
            leadingIcon = leadingIcon,
            trailingIcon = trailingIcon,
            textStyle = KitTypography.bodyLarge,
            colors = XiaomiTextFieldDefaults.textFieldColors(
                backgroundColor = XiaomiTheme.colorScheme.surfaceContainerHigh,
                labelColor = XiaomiTheme.colorScheme.onSurfaceContainer,
                borderColor = XiaomiTheme.colorScheme.primary
            )
        )
    } else {
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            label = { Text(label) },
            modifier = modifier,
            enabled = enabled,
            singleLine = singleLine,
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
            leadingIcon = leadingIcon,
            trailingIcon = trailingIcon,
            shape = MaterialTheme.shapes.medium
        )
    }
}

@Composable
fun KitSearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier
) {
    if (LocalUseMiuix.current) {
        var expanded by remember { mutableStateOf(false) }
        XiaomiSearchBar(
            modifier = modifier,
            insideMargin = DpSize(0.dp, 0.dp),
            inputField = {
                XiaomiInputField(
                    query = query,
                    onQueryChange = onQueryChange,
                    onSearch = { expanded = false },
                    expanded = expanded,
                    onExpandedChange = { expanded = it },
                    label = label
                )
            },
            expanded = expanded,
            onExpandedChange = { expanded = it }
        ) {}
    } else {
        KitTextField(
            value = query,
            onValueChange = onQueryChange,
            label = label,
            modifier = modifier,
            leadingIcon = { Icon(KitIcons.Search, null) },
            trailingIcon = {
                if (query.isNotEmpty()) {
                    KitIconButton(onClick = { onQueryChange("") }) {
                        Icon(KitIcons.SearchCleanup, "清除搜索")
                    }
                }
            }
        )
    }
}

@Composable
private fun DialogActions(dismissButton: @Composable () -> Unit, confirmButton: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth(),
        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically) {
        androidx.compose.runtime.CompositionLocalProvider(LocalDialogAction provides true) {
            Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                androidx.compose.runtime.CompositionLocalProvider(LocalPrimaryDialogAction provides false) { dismissButton() }
            }
            Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                androidx.compose.runtime.CompositionLocalProvider(LocalPrimaryDialogAction provides true) { confirmButton() }
            }
        }
    }
}

@Composable
fun KitAlertDialog(
    onDismissRequest: () -> Unit,
    title: String,
    text: @Composable () -> Unit,
    confirmButton: @Composable () -> Unit,
    dismissButton: @Composable () -> Unit = {}
) {
    val host = LocalPageMaterialHost.current
    val dialogBodyHeight = (androidx.compose.ui.platform.LocalConfiguration.current.screenHeightDp * 0.45f).dp
    CompositionLocalProvider(
        LocalAdvancedMaterialBackdrop provides host.backdrop,
        LocalAdvancedMaterialSpec provides AdvancedMaterialSpec(enabled = true, blurRadius = 92f)
    ) {
        com.aritxonly.myhypermodifier.DeadlinerMiuixDialog(
            show = true, title = title, summary = null, onDismissRequest = onDismissRequest
        ) {
            Column(verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(24.dp)) {
                Column(Modifier.heightIn(max = dialogBodyHeight).verticalScroll(rememberScrollState())) {
                    text()
                }
                DialogActions(dismissButton, confirmButton)
            }
        }
    }
}

@Composable
fun RentTheme(settings: AppearanceSettingsState, content: @Composable () -> Unit) {
    val context = LocalContext.current
    val systemDark = androidx.compose.foundation.isSystemInDarkTheme()
    val dark = when (settings.colorMode) {
        AppColorMode.SYSTEM -> systemDark
        AppColorMode.LIGHT -> false
        AppColorMode.DARK -> true
    }
    val colors = remember(dark) { com.aritxonly.myhypermodifier.MhmPresetColors.material(dark) }
    val miuixColors = remember(colors, dark) { com.aritxonly.myhypermodifier.MhmPresetColors.miuix(colors, dark) }
    val materialHost = remember { PageMaterialHost() }
    val defaultTextStyles = XiaomiTheme.textStyles
    val textStyles = remember(defaultTextStyles) {
        defaultTextStyles.copy(
            main = uiText(16, 22), paragraph = uiText(16, 22),
            body1 = uiText(16, 22), body2 = uiText(14, 20),
            button = uiText(16, 22, FontWeight.Medium),
            footnote1 = uiText(14, 20), footnote2 = uiText(12, 16),
            headline1 = uiText(16, 22, FontWeight.Medium),
            headline2 = uiText(16, 22, FontWeight.Medium),
            subtitle = uiText(14, 20, FontWeight.Medium),
            title1 = uiText(32, 40, FontWeight.Bold),
            title2 = uiText(28, 36, FontWeight.Bold),
            title3 = uiText(24, 32, FontWeight.SemiBold),
            title4 = uiText(20, 26, FontWeight.Medium)
        )
    }
    SideEffect {
        context.findActivity()?.enableEdgeToEdge(
            statusBarStyle = if (dark) SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
            else SystemBarStyle.light(
                android.graphics.Color.TRANSPARENT,
                android.graphics.Color.TRANSPARENT
            ),
            navigationBarStyle = if (dark) SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
            else SystemBarStyle.light(
                android.graphics.Color.TRANSPARENT,
                android.graphics.Color.TRANSPARENT
            )
        )
    }
    CompositionLocalProvider(
        LocalUseMiuix provides true,
        LocalBottomBarStyle provides BottomBarStyle.LIQUID_GLASS,
        LocalAnimationsEnabled provides settings.animations,
        LocalPageMaterialHost provides materialHost,
        LocalAdvancedMaterialSpec provides AdvancedMaterialSpec(enabled = true, blurRadius = 92f),
        LocalAdvancedMaterialBackdrop provides materialHost.backdrop
    ) {
        MaterialTheme(colorScheme = colors, typography = Typography(
            bodyLarge = uiText(16, 22), bodyMedium = uiText(16, 22), bodySmall = uiText(14, 20),
            titleLarge = uiText(20, 26, FontWeight.Medium), titleMedium = uiText(16, 22, FontWeight.Medium),
            titleSmall = uiText(14, 20, FontWeight.Medium), labelLarge = uiText(16, 22, FontWeight.Medium),
            labelMedium = uiText(14, 20), labelSmall = uiText(12, 16)
        )) {
            XiaomiTheme(colors = miuixColors, textStyles = textStyles) {
                // Own the overlay lifecycle for dialogs declared beside a page.
                XiaomiScaffold(containerColor = Color.Transparent) { content() }
            }
        }
    }
}

@Composable
fun ExpressivePage(
    title: String,
    navigation: @Composable () -> Unit = {},
    actions: @Composable RowScope.() -> Unit = {},
    floatingAction: @Composable () -> Unit = {},
    listState: LazyListState = rememberLazyListState(),
    searchQuery: String? = null,
    onSearchQueryChange: ((String) -> Unit)? = null,
    content: LazyListScope.() -> Unit
) {
    var showSearch by remember { mutableStateOf(false) }
    var searchText by remember { mutableStateOf(searchQuery.orEmpty()) }
    val searchFocusManager = androidx.compose.ui.platform.LocalFocusManager.current
    val searchKeyboard = androidx.compose.ui.platform.LocalSoftwareKeyboardController.current
    val closeSearch = {
        searchFocusManager.clearFocus()
        searchKeyboard?.hide()
        showSearch = false
    }
    val searchAction: (@Composable () -> Unit)? = if (searchQuery != null && onSearchQueryChange != null) {
        {
            SoftGlassIconButton(onClick = { searchText = searchQuery.orEmpty(); showSearch = true }, size = 54.dp,
                tint = XiaomiTheme.colorScheme.surfaceContainer,
                shadowRadiusScale = 0.34f) {
                Icon(KitIcons.Search, if (searchQuery.isBlank()) "搜索房间号" else "搜索房间号·已筛选",
                    modifier = Modifier.size(26.dp))
            }
        }
    } else null
    if (showSearch && searchQuery != null && onSearchQueryChange != null) {
        KitAlertDialog(
            onDismissRequest = closeSearch, title = "搜索房间号",
            text = {
                KitTextField(value = searchText, onValueChange = { searchText = it },
                    label = "房间号", modifier = Modifier.fillMaxWidth(),
                    leadingIcon = {
                        Box(Modifier.padding(start = 16.dp, end = 12.dp).size(20.dp)) {
                            Icon(KitIcons.Search, null, Modifier.fillMaxSize(), tint = KitColors.onSurfaceVariant)
                        }
                    })
            },
            confirmButton = { TextButton("搜索", onClick = { onSearchQueryChange(searchText); closeSearch() }) },
            dismissButton = { TextButton("清除", onClick = { searchText = ""; onSearchQueryChange(""); closeSearch() }) }
        )
    }
    val contentEntry = remember(title) { androidx.compose.animation.core.Animatable(0.8f) }
    val playAnimation = LocalAnimationsEnabled.current
    LaunchedEffect(title, playAnimation) {
        if (playAnimation) {
            contentEntry.snapTo(0.8f)
            contentEntry.animateTo(1f, androidx.compose.animation.core.tween(180, easing = androidx.compose.animation.core.FastOutSlowInEasing))
        } else contentEntry.snapTo(1f)
    }
    val onScrollStateChange = LocalPageScrollStateChange.current
    val useMiuix = LocalUseMiuix.current
    val floatingBottomBar = LocalBottomBarStyle.current == BottomBarStyle.FLOATING
    LaunchedEffect(listState, onScrollStateChange) {
        snapshotFlow { listState.isScrollInProgress }
            .distinctUntilChanged()
            .collect(onScrollStateChange)
    }
    if (useMiuix) {
        val scrollBehavior = MiuixScrollBehavior()
        val density = androidx.compose.ui.platform.LocalDensity.current
        val progress = if (listState.firstVisibleItemIndex > 0) 1f else
            (listState.firstVisibleItemScrollOffset / with(density) { 48.dp.toPx() }).coerceIn(0f, 1f)
        val buttonProgress by androidx.compose.animation.core.animateFloatAsState(
            progress, animationSpec = androidx.compose.animation.core.tween(220), label = "top-button-material"
        )
        val bottomBar = LocalPageBottomBar.current
        Box(Modifier.fillMaxSize()) {
            CompositionLocalProvider(
                LocalTopBarButtonMaterialProgress provides buttonProgress,
                LocalPageSearchAction provides searchAction
            ) {
            com.aritxonly.myhypermodifier.DeadlinerMiuixScaffold(
                scrollProgress = progress,
                modifier = if (bottomBar != null) Modifier.nestedScroll(scrollBehavior.nestedScrollConnection) else Modifier,
                topBar = {
                    if (bottomBar != null) {
                        XiaomiTopAppBar(
                            title = title, largeTitle = title, color = Color.Transparent,
                            navigationIcon = navigation, actions = actions, scrollBehavior = scrollBehavior
                        )
                    } else {
                        top.yukonga.miuix.kmp.basic.SmallTopAppBar(
                            title = title, color = Color.Transparent,
                            navigationIcon = navigation, actions = actions
                        )
                    }
                },
                bottomBar = { bottomBar?.invoke() }
            ) { innerPadding ->
                    val pageBackdrop = LocalAdvancedMaterialBackdrop.current
                    val host = LocalPageMaterialHost.current
                    SideEffect { host.backdrop = pageBackdrop }
                    LazyColumn(
                        state = listState,
                        modifier = Modifier
                            .fillMaxSize()
                            .graphicsLayer {
                                alpha = contentEntry.value
                            }
                            .imePadding(),
                        contentPadding = PaddingValues(
                            start = 16.dp,
                            top = innerPadding.calculateTopPadding() + 8.dp,
                            end = 16.dp,
                            bottom = if (floatingBottomBar || LocalBottomBarStyle.current == BottomBarStyle.LIQUID_GLASS) 112.dp else 84.dp
                        ),
                        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(6.dp),
                        content = content
                    )
                }
            }
            AnimatedVisibility(
                visible = !listState.isScrollInProgress,
                modifier = Modifier.align(Alignment.BottomEnd),
                enter = fadeIn() + scaleIn(initialScale = 0.84f),
                exit = fadeOut() + scaleOut(targetScale = 0.84f)
            ) {
                Box { floatingAction() }
            }
        }
        return
    }
    Box(Modifier.fillMaxSize()) {
        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize().statusBarsPadding().imePadding(),
            contentPadding = PaddingValues(
                start = if (useMiuix) 16.dp else 14.dp,
                top = if (useMiuix) 48.dp else 8.dp,
                end = if (useMiuix) 16.dp else 14.dp,
                bottom = if (useMiuix && floatingBottomBar) 110.dp else 92.dp
            ),
            verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(
                if (useMiuix) 12.dp else 10.dp
            ),
        ) {
            item(key = "page-title") {
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 48.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    navigation()
                    Text(
                        title,
                        style = if (useMiuix) MaterialTheme.typography.displaySmall
                        else MaterialTheme.typography.headlineMedium,
                        modifier = Modifier.weight(1f)
                    )
                    actions()
                }
            }
            content()
        }
        AnimatedVisibility(
            visible = !listState.isScrollInProgress,
            modifier = Modifier.align(Alignment.BottomEnd),
            enter = fadeIn() + scaleIn(initialScale = 0.84f),
            exit = fadeOut() + scaleOut(targetScale = 0.84f)
        ) {
            Box { floatingAction() }
        }
    }
}

@Composable
fun ExpressiveCard(
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(16.dp),
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    com.aritxonly.myhypermodifier.SettingsSection(
        modifier = modifier.then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
    ) {
        Column(Modifier.fillMaxWidth().padding(contentPadding),
            verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp),
            content = content)
    }
}

@Composable
fun NumberField(label: String, value: String, modifier: Modifier = Modifier, onValue: (String) -> Unit) {
    KitTextField(
        value = value,
        onValueChange = onValue,
        label = label,
        modifier = modifier.fillMaxWidth(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
    )
}

@Composable
fun TextField(label: String, value: String, modifier: Modifier = Modifier, onValue: (String) -> Unit) {
    KitTextField(
        value = value,
        onValueChange = onValue,
        label = label,
        modifier = modifier.fillMaxWidth()
    )
}

fun toast(context: Context, message: String) = Toast.makeText(context, message, Toast.LENGTH_LONG).show()

private tailrec fun Context.findActivity(): ComponentActivity? = when (this) {
    is ComponentActivity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
