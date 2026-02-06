pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool showPreview
    property string scheme
    property string flavour
    readonly property bool light: showPreview ? previewLight : currentLight
    property bool currentLight
    property bool previewLight
    readonly property M3Palette palette: showPreview ? preview : current
    readonly property M3TPalette tPalette: M3TPalette {}
    readonly property M3Palette current: M3Palette {}
    readonly property M3Palette preview: M3Palette {}
    readonly property Transparency transparency: Transparency {}
    property real wallLuminance: 0

    // Cached pywal data for mode switching without re-reading
    property var _pywalCache: null

    function getLuminance(c: color): real {
        if (c.r == 0 && c.g == 0 && c.b == 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    function alterColour(c: color, a: real, layer: int): color {
        const luminance = getLuminance(c);

        const offset = (!light || layer == 1 ? 1 : -layer / 2) * (light ? 0.2 : 0.3) * (1 - transparency.base) * (1 + wallLuminance * (light ? (layer == 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        const r = Math.max(0, Math.min(1, c.r * scale));
        const g = Math.max(0, Math.min(1, c.g * scale));
        const b = Math.max(0, Math.min(1, c.b * scale));

        return Qt.rgba(r, g, b, a);
    }

    function layer(c: color, layer: var): color {
        if (!transparency.enabled)
            return c;

        return layer === 0 ? Qt.alpha(c, transparency.base) : alterColour(c, transparency.layers, layer ?? 1);
    }

    function on(c: color): color {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    // Tonal math: preserve hue + saturation, set lightness to t/100
    function tone(c, t) {
        return Qt.hsla(c.hslHue, c.hslSaturation, t / 100.0, 1.0);
    }

    // Desaturate by factor (0 = no change, 1 = full grey)
    function desat(c, factor) {
        return Qt.hsla(c.hslHue, c.hslSaturation * (1 - factor), c.hslLightness, 1.0);
    }

    function _computeAccent(target, prefix, color, isLight) {
        const cap = prefix[0].toUpperCase() + prefix.slice(1);
        target[`m3${prefix}_paletteKeyColor`] = color;

        if (isLight) {
            target[`m3${prefix}`] = tone(color, 40);
            target[`m3on${cap}`] = tone(color, 100);
            target[`m3${prefix}Container`] = desat(tone(color, 90), 0.3);
            target[`m3on${cap}Container`] = tone(color, 10);
        } else {
            target[`m3${prefix}`] = tone(color, 80);
            target[`m3on${cap}`] = tone(color, 20);
            target[`m3${prefix}Container`] = desat(tone(color, 30), 0.3);
            target[`m3on${cap}Container`] = tone(color, 90);
        }

        // Only primary has an inverse property
        if (prefix === "primary")
            target.m3inversePrimary = isLight ? tone(color, 80) : tone(color, 40);

        target[`m3${prefix}Fixed`] = tone(color, 90);
        target[`m3${prefix}FixedDim`] = tone(color, 80);
        target[`m3on${cap}Fixed`] = tone(color, 10);
        target[`m3on${cap}FixedVariant`] = tone(color, 30);
    }

    function _applyPalette(target, pywal, isLight) {
        const bg = Qt.color(pywal.special.background);
        const fg = Qt.color(pywal.special.foreground);

        const colors = {};
        for (const [key, val] of Object.entries(pywal.colors))
            colors[key] = Qt.color(val);

        const bgL = bg.hslLightness * 100;

        // Accent families
        _computeAccent(target, "primary", colors.color1, isLight);
        _computeAccent(target, "secondary", colors.color4, isLight);
        _computeAccent(target, "tertiary", colors.color5, isLight);

        // Neutral palette keys
        target.m3neutral_paletteKeyColor = desat(bg, 0.5);
        target.m3neutral_variant_paletteKeyColor = desat(colors.color8 || bg, 0.3);

        // Error family (hardcoded red)
        const errColor = Qt.color("#B3261E");
        if (isLight) {
            target.m3error = tone(errColor, 40);
            target.m3onError = tone(errColor, 100);
            target.m3errorContainer = tone(errColor, 90);
            target.m3onErrorContainer = tone(errColor, 10);
        } else {
            target.m3error = tone(errColor, 80);
            target.m3onError = tone(errColor, 20);
            target.m3errorContainer = tone(errColor, 30);
            target.m3onErrorContainer = tone(errColor, 90);
        }

        // Success family (hardcoded green)
        const succColor = Qt.color("#2E7D32");
        if (isLight) {
            target.m3success = tone(succColor, 40);
            target.m3onSuccess = tone(succColor, 100);
            target.m3successContainer = tone(succColor, 90);
            target.m3onSuccessContainer = tone(succColor, 10);
        } else {
            target.m3success = tone(succColor, 80);
            target.m3onSuccess = tone(succColor, 20);
            target.m3successContainer = tone(succColor, 30);
            target.m3onSuccessContainer = tone(succColor, 90);
        }

        // Surface hierarchy
        if (isLight) {
            target.m3surfaceContainerLowest = tone(bg, Math.min(bgL + 2, 100));
            target.m3surface = bg;
            target.m3surfaceDim = bg;
            target.m3surfaceContainerLow = tone(bg, Math.max(bgL - 3, 0));
            target.m3surfaceContainer = tone(bg, Math.max(bgL - 5, 0));
            target.m3surfaceContainerHigh = tone(bg, Math.max(bgL - 7, 0));
            target.m3surfaceContainerHighest = tone(bg, Math.max(bgL - 10, 0));
            target.m3surfaceBright = tone(bg, Math.min(bgL + 5, 100));
        } else {
            target.m3surfaceContainerLowest = tone(bg, Math.max(bgL - 2, 0));
            target.m3surface = bg;
            target.m3surfaceDim = bg;
            target.m3surfaceContainerLow = tone(bg, Math.min(bgL + 3, 100));
            target.m3surfaceContainer = tone(bg, Math.min(bgL + 5, 100));
            target.m3surfaceContainerHigh = tone(bg, Math.min(bgL + 7, 100));
            target.m3surfaceContainerHighest = tone(bg, Math.min(bgL + 10, 100));
            target.m3surfaceBright = tone(bg, Math.min(bgL + 15, 100));
        }

        target.m3background = bg;

        // Text and surface roles
        target.m3onSurface = fg;
        target.m3onBackground = fg;
        target.m3surfaceVariant = tone(bg, Math.min(bgL + 20, 100));
        target.m3onSurfaceVariant = desat(tone(fg, 70), 0.2);
        target.m3inverseSurface = fg;
        target.m3inverseOnSurface = tone(bg, Math.min(bgL + 5, 100));
        target.m3outline = colors.color8 || tone(bg, 50);
        target.m3outlineVariant = tone(bg, Math.min(bgL + 20, 100));
        target.m3shadow = Qt.color("#000000");
        target.m3scrim = Qt.color("#000000");
        target.m3surfaceTint = target.m3primary;

        // Terminal colors (direct pywal mapping)
        for (let i = 0; i < 16; i++)
            target[`term${i}`] = colors[`color${i}`];
    }

    function load(data: string, isPreview: bool): void {
        const pywal = JSON.parse(data);
        root._pywalCache = pywal;

        const bg = Qt.color(pywal.special.background);
        const isLight = getLuminance(bg) >= 0.5;

        const target = isPreview ? preview : current;

        if (!isPreview) {
            root.scheme = "pywal";
            root.flavour = isLight ? "light" : "dark";
            root.currentLight = isLight;
            root.wallLuminance = getLuminance(bg);
        } else {
            root.previewLight = isLight;
        }

        _applyPalette(target, pywal, isLight);
    }

    function setMode(mode: string): void {
        root.currentLight = (mode === "light");
        _recomputePalette();
    }

    function _recomputePalette(): void {
        if (!_pywalCache)
            return;

        const isLight = root.currentLight;
        root.flavour = isLight ? "light" : "dark";
        _applyPalette(current, _pywalCache, isLight);

        if (showPreview)
            _applyPalette(preview, _pywalCache, root.previewLight);
    }

    FileView {
        id: walFile
        path: `${Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`}/wal/colors.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load(text(), false)
    }

    component Transparency: QtObject {
        readonly property bool enabled: Appearance.transparency.enabled
        readonly property real base: Appearance.transparency.base - (root.light ? 0.1 : 0)
        readonly property real layers: Appearance.transparency.layers
    }

    component M3TPalette: QtObject {
        readonly property color m3primary_paletteKeyColor: root.layer(root.palette.m3primary_paletteKeyColor)
        readonly property color m3secondary_paletteKeyColor: root.layer(root.palette.m3secondary_paletteKeyColor)
        readonly property color m3tertiary_paletteKeyColor: root.layer(root.palette.m3tertiary_paletteKeyColor)
        readonly property color m3neutral_paletteKeyColor: root.layer(root.palette.m3neutral_paletteKeyColor)
        readonly property color m3neutral_variant_paletteKeyColor: root.layer(root.palette.m3neutral_variant_paletteKeyColor)
        readonly property color m3background: root.layer(root.palette.m3background, 0)
        readonly property color m3onBackground: root.layer(root.palette.m3onBackground)
        readonly property color m3surface: root.layer(root.palette.m3surface, 0)
        readonly property color m3surfaceDim: root.layer(root.palette.m3surfaceDim, 0)
        readonly property color m3surfaceBright: root.layer(root.palette.m3surfaceBright, 0)
        readonly property color m3surfaceContainerLowest: root.layer(root.palette.m3surfaceContainerLowest)
        readonly property color m3surfaceContainerLow: root.layer(root.palette.m3surfaceContainerLow)
        readonly property color m3surfaceContainer: root.layer(root.palette.m3surfaceContainer)
        readonly property color m3surfaceContainerHigh: root.layer(root.palette.m3surfaceContainerHigh)
        readonly property color m3surfaceContainerHighest: root.layer(root.palette.m3surfaceContainerHighest)
        readonly property color m3onSurface: root.layer(root.palette.m3onSurface)
        readonly property color m3surfaceVariant: root.layer(root.palette.m3surfaceVariant, 0)
        readonly property color m3onSurfaceVariant: root.layer(root.palette.m3onSurfaceVariant)
        readonly property color m3inverseSurface: root.layer(root.palette.m3inverseSurface, 0)
        readonly property color m3inverseOnSurface: root.layer(root.palette.m3inverseOnSurface)
        readonly property color m3outline: root.layer(root.palette.m3outline)
        readonly property color m3outlineVariant: root.layer(root.palette.m3outlineVariant)
        readonly property color m3shadow: root.layer(root.palette.m3shadow)
        readonly property color m3scrim: root.layer(root.palette.m3scrim)
        readonly property color m3surfaceTint: root.layer(root.palette.m3surfaceTint)
        readonly property color m3primary: root.layer(root.palette.m3primary)
        readonly property color m3onPrimary: root.layer(root.palette.m3onPrimary)
        readonly property color m3primaryContainer: root.layer(root.palette.m3primaryContainer)
        readonly property color m3onPrimaryContainer: root.layer(root.palette.m3onPrimaryContainer)
        readonly property color m3inversePrimary: root.layer(root.palette.m3inversePrimary)
        readonly property color m3secondary: root.layer(root.palette.m3secondary)
        readonly property color m3onSecondary: root.layer(root.palette.m3onSecondary)
        readonly property color m3secondaryContainer: root.layer(root.palette.m3secondaryContainer)
        readonly property color m3onSecondaryContainer: root.layer(root.palette.m3onSecondaryContainer)
        readonly property color m3tertiary: root.layer(root.palette.m3tertiary)
        readonly property color m3onTertiary: root.layer(root.palette.m3onTertiary)
        readonly property color m3tertiaryContainer: root.layer(root.palette.m3tertiaryContainer)
        readonly property color m3onTertiaryContainer: root.layer(root.palette.m3onTertiaryContainer)
        readonly property color m3error: root.layer(root.palette.m3error)
        readonly property color m3onError: root.layer(root.palette.m3onError)
        readonly property color m3errorContainer: root.layer(root.palette.m3errorContainer)
        readonly property color m3onErrorContainer: root.layer(root.palette.m3onErrorContainer)
        readonly property color m3success: root.layer(root.palette.m3success)
        readonly property color m3onSuccess: root.layer(root.palette.m3onSuccess)
        readonly property color m3successContainer: root.layer(root.palette.m3successContainer)
        readonly property color m3onSuccessContainer: root.layer(root.palette.m3onSuccessContainer)
        readonly property color m3primaryFixed: root.layer(root.palette.m3primaryFixed)
        readonly property color m3primaryFixedDim: root.layer(root.palette.m3primaryFixedDim)
        readonly property color m3onPrimaryFixed: root.layer(root.palette.m3onPrimaryFixed)
        readonly property color m3onPrimaryFixedVariant: root.layer(root.palette.m3onPrimaryFixedVariant)
        readonly property color m3secondaryFixed: root.layer(root.palette.m3secondaryFixed)
        readonly property color m3secondaryFixedDim: root.layer(root.palette.m3secondaryFixedDim)
        readonly property color m3onSecondaryFixed: root.layer(root.palette.m3onSecondaryFixed)
        readonly property color m3onSecondaryFixedVariant: root.layer(root.palette.m3onSecondaryFixedVariant)
        readonly property color m3tertiaryFixed: root.layer(root.palette.m3tertiaryFixed)
        readonly property color m3tertiaryFixedDim: root.layer(root.palette.m3tertiaryFixedDim)
        readonly property color m3onTertiaryFixed: root.layer(root.palette.m3onTertiaryFixed)
        readonly property color m3onTertiaryFixedVariant: root.layer(root.palette.m3onTertiaryFixedVariant)
    }

    component M3Palette: QtObject {
        property color m3primary_paletteKeyColor: "#a8627b"
        property color m3secondary_paletteKeyColor: "#8e6f78"
        property color m3tertiary_paletteKeyColor: "#986e4c"
        property color m3neutral_paletteKeyColor: "#807477"
        property color m3neutral_variant_paletteKeyColor: "#837377"
        property color m3background: "#191114"
        property color m3onBackground: "#efdfe2"
        property color m3surface: "#191114"
        property color m3surfaceDim: "#191114"
        property color m3surfaceBright: "#403739"
        property color m3surfaceContainerLowest: "#130c0e"
        property color m3surfaceContainerLow: "#22191c"
        property color m3surfaceContainer: "#261d20"
        property color m3surfaceContainerHigh: "#31282a"
        property color m3surfaceContainerHighest: "#3c3235"
        property color m3onSurface: "#efdfe2"
        property color m3surfaceVariant: "#514347"
        property color m3onSurfaceVariant: "#d5c2c6"
        property color m3inverseSurface: "#efdfe2"
        property color m3inverseOnSurface: "#372e30"
        property color m3outline: "#9e8c91"
        property color m3outlineVariant: "#514347"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: "#ffb0ca"
        property color m3primary: "#ffb0ca"
        property color m3onPrimary: "#541d34"
        property color m3primaryContainer: "#6f334a"
        property color m3onPrimaryContainer: "#ffd9e3"
        property color m3inversePrimary: "#8b4a62"
        property color m3secondary: "#e2bdc7"
        property color m3onSecondary: "#422932"
        property color m3secondaryContainer: "#5a3f48"
        property color m3onSecondaryContainer: "#ffd9e3"
        property color m3tertiary: "#f0bc95"
        property color m3onTertiary: "#48290c"
        property color m3tertiaryContainer: "#b58763"
        property color m3onTertiaryContainer: "#000000"
        property color m3error: "#ffb4ab"
        property color m3onError: "#690005"
        property color m3errorContainer: "#93000a"
        property color m3onErrorContainer: "#ffdad6"
        property color m3success: "#B5CCBA"
        property color m3onSuccess: "#213528"
        property color m3successContainer: "#374B3E"
        property color m3onSuccessContainer: "#D1E9D6"
        property color m3primaryFixed: "#ffd9e3"
        property color m3primaryFixedDim: "#ffb0ca"
        property color m3onPrimaryFixed: "#39071f"
        property color m3onPrimaryFixedVariant: "#6f334a"
        property color m3secondaryFixed: "#ffd9e3"
        property color m3secondaryFixedDim: "#e2bdc7"
        property color m3onSecondaryFixed: "#2b151d"
        property color m3onSecondaryFixedVariant: "#5a3f48"
        property color m3tertiaryFixed: "#ffdcc3"
        property color m3tertiaryFixedDim: "#f0bc95"
        property color m3onTertiaryFixed: "#2f1500"
        property color m3onTertiaryFixedVariant: "#623f21"
        property color term0: "#353434"
        property color term1: "#ff4c8a"
        property color term2: "#ffbbb7"
        property color term3: "#ffdedf"
        property color term4: "#b3a2d5"
        property color term5: "#e98fb0"
        property color term6: "#ffba93"
        property color term7: "#eed1d2"
        property color term8: "#b39e9e"
        property color term9: "#ff80a3"
        property color term10: "#ffd3d0"
        property color term11: "#fff1f0"
        property color term12: "#dcbc93"
        property color term13: "#f9a8c2"
        property color term14: "#ffd1c0"
        property color term15: "#ffffff"
    }
}
