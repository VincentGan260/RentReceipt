package com.vincent.rentreceipt.ui

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
import top.yukonga.miuix.kmp.blur.BlendColorEntry
import top.yukonga.miuix.kmp.blur.BlurDefaults
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.blur.textureBlur
import top.yukonga.miuix.kmp.utils.PressFeedbackType

val LocalPageScrollStateChange = staticCompositionLocalOf<(Boolean) -> Unit> { {} }
val LocalUseMiuix = staticCompositionLocalOf { false }
val LocalGlobalBlurEnabled = staticCompositionLocalOf { true }
val LocalFloatingBottomBarEnabled = staticCompositionLocalOf { true }
val LocalGlassEffectEnabled = staticCompositionLocalOf { true }
val LocalAnimationsEnabled = staticCompositionLocalOf { true }

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
    val displaySmall: TextStyle
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.textStyles.title1
        } else MaterialTheme.typography.displaySmall
    val headlineMedium: TextStyle
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.textStyles.title3
        } else MaterialTheme.typography.headlineMedium
    val headlineSmall: TextStyle
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.textStyles.title3
        } else MaterialTheme.typography.headlineSmall
    val titleLarge: TextStyle
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.textStyles.title4
        } else MaterialTheme.typography.titleLarge
    val titleMedium: TextStyle
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.textStyles.headline1
        } else MaterialTheme.typography.titleMedium
    val titleSmall: TextStyle
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.textStyles.subtitle
        } else MaterialTheme.typography.titleSmall
    val bodyLarge: TextStyle
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.textStyles.paragraph
        } else MaterialTheme.typography.bodyLarge
    val labelLarge: TextStyle
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.textStyles.button
        } else MaterialTheme.typography.labelLarge
    val labelSmall: TextStyle
        @Composable @ReadOnlyComposable get() = if (LocalUseMiuix.current) {
            XiaomiTheme.textStyles.footnote2
        } else MaterialTheme.typography.labelSmall
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    if (LocalUseMiuix.current) {
        XiaomiSmallTitle(
            text = text,
            modifier = modifier,
            insideMargin = PaddingValues(horizontal = 12.dp, vertical = 8.dp)
        )
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
    if (LocalUseMiuix.current) {
        XiaomiText(
            text = text,
            modifier = modifier,
            color = color,
            style = style ?: XiaomiTheme.textStyles.main,
            overflow = overflow,
            maxLines = maxLines
        )
    } else if (style == null) {
        MaterialText(text = text, modifier = modifier, color = color, overflow = overflow, maxLines = maxLines)
    } else {
        MaterialText(
            text = text,
            modifier = modifier,
            color = color,
            style = style,
            overflow = overflow,
            maxLines = maxLines
        )
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
    if (LocalUseMiuix.current) {
        XiaomiButton(
            onClick = onClick,
            modifier = modifier,
            enabled = enabled,
            colors = XiaomiButtonDefaults.buttonColorsPrimary(),
            content = content
        )
    } else {
        androidx.compose.material3.Button(onClick, modifier, enabled, content = content)
    }
}

@Composable
fun FilledTonalButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit
) {
    if (LocalUseMiuix.current) {
        XiaomiButton(onClick, modifier, enabled, content = content)
    } else {
        androidx.compose.material3.FilledTonalButton(onClick, modifier, enabled, content = content)
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
    if (LocalUseMiuix.current) {
        val miuixColors = if (destructive) {
            XiaomiButtonDefaults.buttonColors(
                color = XiaomiTheme.colorScheme.errorContainer,
                contentColor = XiaomiTheme.colorScheme.error
            )
        } else XiaomiButtonDefaults.buttonColors()
        XiaomiButton(onClick, modifier, enabled, colors = miuixColors, content = content)
    } else {
        androidx.compose.material3.OutlinedButton(
            onClick = onClick,
            modifier = modifier,
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
    if (LocalUseMiuix.current) {
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
    if (LocalUseMiuix.current) {
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
        XiaomiSwitch(
            checked = checked,
            onCheckedChange = onCheckedChange,
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
        XiaomiSwitchPreference(
            title = title,
            summary = summary,
            checked = checked,
            enabled = enabled,
            onCheckedChange = onCheckedChange,
            startAction = icon?.let { image ->
                @Composable {
                    Icon(
                        imageVector = image,
                        contentDescription = null,
                        modifier = Modifier.padding(end = 12.dp).size(24.dp),
                        tint = XiaomiTheme.colorScheme.onBackground
                    )
                }
            }
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
        XiaomiSlider(
            value = value,
            onValueChange = onValueChange,
            modifier = modifier,
            enabled = enabled,
            valueRange = valueRange,
            steps = steps,
            showKeyPoints = steps > 0
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
            colors = XiaomiTextFieldDefaults.textFieldColors(
                backgroundColor = XiaomiTheme.colorScheme.surfaceContainerHigh,
                labelColor = XiaomiTheme.colorScheme.onSurfaceContainer,
                borderColor = XiaomiTheme.colorScheme.onSurfaceVariantActions
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
fun KitAlertDialog(
    onDismissRequest: () -> Unit,
    title: String,
    text: @Composable () -> Unit,
    confirmButton: @Composable () -> Unit,
    dismissButton: @Composable () -> Unit = {}
) {
    if (LocalUseMiuix.current) {
        XiaomiWindowDialog(show = true, title = title, onDismissRequest = onDismissRequest) {
            Column(verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(14.dp)) {
                text()
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(10.dp)
                ) {
                    Box(Modifier.weight(1f)) { dismissButton() }
                    Box(Modifier.weight(1f)) { confirmButton() }
                }
            }
        }
    } else {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = onDismissRequest,
            title = { Text(title) },
            text = text,
            confirmButton = confirmButton,
            dismissButton = dismissButton
        )
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
    val supportsMiuix = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
    val useMiuix = supportsMiuix && settings.uiStyle != UiStyle.MATERIAL
    val paletteStyle = runCatching { PaletteStyle.valueOf(settings.paletteStyle) }
        .getOrDefault(PaletteStyle.TonalSpot)
    val colorSpec = runCatching { ColorSpec.SpecVersion.valueOf(settings.colorSpec) }
        .getOrDefault(ColorSpec.SpecVersion.Default)
    val colors = when {
        settings.monet && settings.keyColor == 0 && !LocalInspectionMode.current &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        settings.monet -> rememberDynamicColorScheme(
            seedColor = if (settings.keyColor == 0) Color(0xFF4C6FAE) else Color(settings.keyColor),
            isDark = dark,
            style = paletteStyle,
            specVersion = colorSpec
        )
        dark -> darkColorScheme(
            primary = Color(0xFF277AF7),
            onPrimary = Color.White,
            primaryContainer = Color(0xFF183A67),
            onPrimaryContainer = Color.White,
            secondary = Color(0xFF277AF7),
            onSecondary = Color.White,
            secondaryContainer = Color(0xFF263A55),
            onSecondaryContainer = Color(0xFFE8F1FF),
            tertiary = Color(0xFF277AF7),
            onTertiary = Color.White,
            tertiaryContainer = Color(0xFF263A55),
            onTertiaryContainer = Color(0xFFE8F1FF)
        )
        else -> lightColorScheme(
            primary = Color(0xFF3482FF),
            onPrimary = Color.White,
            primaryContainer = Color(0xFFEAF2FF),
            onPrimaryContainer = Color(0xFF17365F),
            secondary = Color(0xFF3482FF),
            onSecondary = Color.White,
            secondaryContainer = Color(0xFFEAF2FF),
            onSecondaryContainer = Color(0xFF17365F),
            tertiary = Color(0xFF3482FF),
            onTertiary = Color.White,
            tertiaryContainer = Color(0xFFEAF2FF),
            onTertiaryContainer = Color(0xFF17365F)
        )
    }
    val shapes = Shapes(
        extraSmall = RoundedCornerShape(8.dp),
        small = RoundedCornerShape(14.dp),
        medium = RoundedCornerShape(22.dp),
        large = RoundedCornerShape(30.dp),
        extraLarge = RoundedCornerShape(38.dp)
    )
    val typography = Typography(
        displaySmall = TextStyle(
            fontSize = 42.sp,
            lineHeight = 46.sp,
            fontWeight = FontWeight.Black
        ),
        headlineLarge = TextStyle(
            fontSize = 34.sp,
            lineHeight = 40.sp,
            fontWeight = FontWeight.SemiBold
        ),
        headlineMedium = TextStyle(
            fontSize = 26.sp,
            lineHeight = 32.sp,
            fontWeight = FontWeight.Bold
        ),
        headlineSmall = TextStyle(
            fontSize = 24.sp,
            lineHeight = 30.sp,
            fontWeight = FontWeight.Medium
        ),
        titleLarge = TextStyle(
            fontSize = 22.sp,
            lineHeight = 28.sp,
            fontWeight = FontWeight.Bold
        ),
        titleMedium = TextStyle(
            fontSize = 16.sp,
            lineHeight = 22.sp,
            fontWeight = FontWeight.SemiBold
        ),
        bodyLarge = TextStyle(
            fontSize = 17.sp,
            lineHeight = 24.sp
        ),
        labelLarge = TextStyle(
            fontSize = 15.sp,
            lineHeight = 20.sp,
            fontWeight = FontWeight.SemiBold
        )
    )
    val miuixMode = when {
        settings.monet && settings.colorMode == AppColorMode.LIGHT -> ColorSchemeMode.MonetLight
        settings.monet && settings.colorMode == AppColorMode.DARK -> ColorSchemeMode.MonetDark
        settings.monet -> ColorSchemeMode.MonetSystem
        settings.colorMode == AppColorMode.LIGHT -> ColorSchemeMode.Light
        settings.colorMode == AppColorMode.DARK -> ColorSchemeMode.Dark
        else -> ColorSchemeMode.System
    }
    val miuixPalette = runCatching { ThemePaletteStyle.valueOf(settings.paletteStyle) }
        .getOrDefault(ThemePaletteStyle.TonalSpot)
    val miuixSpec = when (settings.colorSpec) {
        "Spec2025", "SPEC_2025" -> ThemeColorSpec.Spec2025
        else -> ThemeColorSpec.Spec2021
    }
    val miuixController = remember(
        miuixMode, settings.keyColor, miuixPalette, miuixSpec
    ) {
        ThemeController(
            colorSchemeMode = miuixMode,
            keyColor = settings.keyColor.takeIf { it != 0 }?.let(::Color),
            paletteStyle = miuixPalette,
            colorSpec = miuixSpec
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
    androidx.compose.runtime.CompositionLocalProvider(
        LocalUseMiuix provides useMiuix,
        LocalGlobalBlurEnabled provides settings.globalBlur,
        LocalFloatingBottomBarEnabled provides settings.floatingBottomBar,
        LocalGlassEffectEnabled provides (
            settings.glassEffect && settings.globalBlur &&
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
            ),
        LocalAnimationsEnabled provides settings.animations
    ) {
        MaterialTheme(colorScheme = colors, shapes = shapes, typography = typography) {
            if (useMiuix) XiaomiTheme(controller = miuixController, content = content)
            else content()
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
    content: LazyListScope.() -> Unit
) {
    val onScrollStateChange = LocalPageScrollStateChange.current
    val useMiuix = LocalUseMiuix.current
    val floatingBottomBar = LocalFloatingBottomBarEnabled.current
    LaunchedEffect(listState, onScrollStateChange) {
        snapshotFlow { listState.isScrollInProgress }
            .distinctUntilChanged()
            .collect(onScrollStateChange)
    }
    if (useMiuix) {
        val scrollBehavior = MiuixScrollBehavior()
        val blurActive = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            LocalGlobalBlurEnabled.current && isRuntimeShaderSupported()
        val surfaceColor = XiaomiTheme.colorScheme.surface
        val backdrop = if (blurActive) {
            rememberLayerBackdrop {
                drawRect(surfaceColor)
                drawContent()
            }
        } else null
        Box(Modifier.fillMaxSize()) {
            XiaomiScaffold(
                topBar = {
                    Box(
                        modifier = if (backdrop != null) {
                            Modifier.textureBlur(
                                backdrop = backdrop,
                                shape = RectangleShape,
                                blurRadius = 25f,
                                colors = BlurDefaults.blurColors(
                                    blendColors = listOf(
                                        BlendColorEntry(surfaceColor.copy(alpha = 0.8f))
                                    )
                                )
                            )
                        } else Modifier
                    ) {
                        XiaomiTopAppBar(
                            title = title,
                            largeTitle = title,
                            color = if (backdrop != null) Color.Transparent else surfaceColor,
                            navigationIcon = navigation,
                            actions = actions,
                            scrollBehavior = scrollBehavior
                        )
                    }
                }
            ) { innerPadding ->
                Box(modifier = if (backdrop != null) Modifier.layerBackdrop(backdrop) else Modifier) {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier
                            .fillMaxSize()
                            .imePadding()
                            .nestedScroll(scrollBehavior.nestedScrollConnection),
                        contentPadding = PaddingValues(
                            start = 16.dp,
                            top = innerPadding.calculateTopPadding() + 8.dp,
                            end = 16.dp,
                            bottom = if (floatingBottomBar) 112.dp else 84.dp
                        ),
                        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(10.dp),
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
    val useMiuix = LocalUseMiuix.current
    val animationsEnabled = LocalAnimationsEnabled.current
    // Card-level decorative icons shift every child onto a different baseline. Miuix
    // places semantic icons in Preference.startAction or the concrete action itself.
    val alignedContent: @Composable ColumnScope.() -> Unit = {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(10.dp),
            content = content
        )
    }
    if (useMiuix) {
        if (onClick == null) {
            XiaomiCard(
                modifier = modifier.fillMaxWidth(),
                insideMargin = contentPadding,
                content = alignedContent
            )
        } else {
            XiaomiCard(
                modifier = modifier.fillMaxWidth(),
                insideMargin = contentPadding,
                pressFeedbackType = if (animationsEnabled) PressFeedbackType.Sink
                else PressFeedbackType.None,
                onClick = onClick,
                content = alignedContent
            )
        }
        return
    }
    if (onClick == null) {
        Card(
            modifier = modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.extraLarge
        ) { Column(Modifier.fillMaxWidth().padding(contentPadding), content = alignedContent) }
    } else {
        Card(
            onClick = onClick,
            modifier = modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.extraLarge
        ) { Column(Modifier.fillMaxWidth().padding(contentPadding), content = alignedContent) }
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
