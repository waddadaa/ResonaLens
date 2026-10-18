pragma Singleton
import QtQuick
import ResonaLens.Controllers 1.0

QtObject {
    // ── Theme mode ──
    readonly property bool isDark: {
        var t = SettingsController.theme
        if (t === "dark") return true
        if (t === "light") return false
        return Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    }

    // ── Core Backgrounds ──
    readonly property color background:      isDark ? "#1A1918" : "#F5F4F1"
    readonly property color surface:         isDark ? "#252422" : "#FFFFFF"
    readonly property color surfaceElevated: isDark ? "#2D2B29" : "#FAFAF8"
    readonly property color surfaceMuted:    isDark ? "#333230" : "#EDECEA"

    // ── Text ──
    readonly property color textPrimary:   isDark ? "#F5F4F1" : "#1A1918"
    readonly property color textSecondary: isDark ? "#9C9B99" : "#6D6C6A"
    readonly property color textTertiary:  isDark ? "#6D6C6A" : "#9C9B99"
    readonly property color textDisabled:  isDark ? "#5A5957" : "#A8A7A5"

    // ── Borders ──
    readonly property color borderSubtle: isDark ? "#333230" : "#E5E4E1"
    readonly property color borderStrong: isDark ? "#45433F" : "#D1D0CD"

    // ── Primary (Green) ──
    readonly property color primary:        "#3D8A5A"
    readonly property color primaryDark:    "#2D6A44"
    readonly property color primaryLight:   isDark ? "#1A3D2A" : "#C8F0D8"
    readonly property color primarySurface: isDark ? "#1E2E24" : "#F0F7F2"

    // ── Secondary (Coral) ──
    readonly property color secondary:        "#D89575"
    readonly property color secondaryDark:    "#C07558"
    readonly property color secondarySurface: isDark ? "#3A2419" : "#FEE8D6"

    // ── Semantic ──
    readonly property color error:         "#D08068"
    readonly property color warning:       "#D4A64A"
    readonly property color info:          "#4A8DB5"
    readonly property color infoSurface:   isDark ? "#1A2E3D" : "#E1F0F8"
    readonly property color purple:        "#7C6DB5"
    readonly property color purpleSurface: isDark ? "#2A2440" : "#E8E4F9"

    // ── Chat Bubbles ──
    readonly property color userBubble:      "#3D8A5A"
    readonly property color userText:        "#FFFFFF"
    readonly property color userTime:        "#FFFFFFAA"
    readonly property color assistantBubble: isDark ? "#252422" : "#FFFFFF"
    readonly property color assistantText:   isDark ? "#F5F4F1" : "#1A1918"
    readonly property color assistantTime:   "#9C9B99"

    // ── Overlay ──
    readonly property color overlayDim: isDark ? "#00000088" : "#00000055"

    // ── Gated Badge ──
    readonly property color gatedBadgeBg:   isDark ? "#3A2A10" : "#FFF3E0"
    readonly property color gatedBadgeText: "#E6A23C"

    // ── Typography ──
    readonly property string fontFamily: "Outfit"
    readonly property int fontDisplay: 32
    readonly property int fontTitle1: 26
    readonly property int fontTitle2: 22
    readonly property int fontTitle3: 18
    readonly property int fontHeadline: 15
    readonly property int fontBody: 15
    readonly property int fontCallout: 14
    readonly property int fontSubhead: 13
    readonly property int fontFootnote: 12
    readonly property int fontCaption1: 11
    readonly property int fontCaption2: 11
    readonly property int fontTab: 10

    readonly property int weightBold: Font.Bold
    readonly property int weightSemiBold: Font.DemiBold
    readonly property int weightMedium: Font.Medium
    readonly property int weightRegular: Font.Normal

    // ── Spacing ──
    readonly property int gapXxl: 24
    readonly property int gapXl: 20
    readonly property int gapLg: 16
    readonly property int gapMd: 14
    readonly property int gapBase: 12
    readonly property int gapSm: 10
    readonly property int gapXs: 8
    readonly property int gapXxs: 6
    readonly property int gapMicro: 4
    readonly property int gapNano: 2

    readonly property int padPage: 24
    readonly property int padCard: 14
    readonly property int padCardSide: 16
    readonly property int padCardLg: 16

    // ── Radii ──
    readonly property int radiusCard: 16
    readonly property int radiusInput: 12
    readonly property int radiusDrawerNav: 10
    readonly property int radiusChip: 100
    readonly property int radiusSelector: 8
    readonly property int radiusTag: 4

    // ── Icon Sizes ──
    readonly property int iconXl: 26
    readonly property int iconLg: 24
    readonly property int iconMd: 22
    readonly property int iconBase: 20
    readonly property int iconSm: 18
    readonly property int iconXs: 16
    readonly property int iconXxs: 14
    readonly property int iconChip: 12

    // ── Component Sizes ──
    readonly property int screenWidth: 402
    readonly property int screenHeight: 874
    readonly property int statusBarHeight: 54
    readonly property int headerHeight: 56
    readonly property int inputBarHeight: 56
    readonly property int searchBarHeight: 44
    readonly property int sendButtonSize: 38
    readonly property int avatarSize: 32
    readonly property int modelIconSize: 44
    readonly property int toggleWidth: 44
    readonly property int toggleHeight: 26
    readonly property int toggleDotSize: 20
    readonly property int navItemHeight: 44
    readonly property int historyItemHeight: 40
    readonly property int drawerWidth: 320
    readonly property int sliderThumbSize: 20
    readonly property int sliderTrackHeight: 6

    // ── Icon paths ──
    readonly property string iconPath: "qrc:/ResonaLensContent/images/icons/"

    function icon(name) {
        return iconPath + name + ".svg"
    }

    // ── Document icon helpers ──
    function docIconBg(sourceType) {
        switch (sourceType) {
        case "note": return primaryLight
        case "document": return secondarySurface
        case "link": return surfaceMuted
        case "markdown": return infoSurface
        case "paper": return purpleSurface
        default: return primaryLight
        }
    }

    function docIconColor(sourceType) {
        switch (sourceType) {
        case "note": return primary
        case "document": return secondary
        case "link": return textTertiary
        case "markdown": return info
        case "paper": return purple
        default: return primary
        }
    }

    function docIconName(sourceType) {
        switch (sourceType) {
        case "note": return "pen-line"
        case "document": return "file"
        case "link": return "link"
        case "markdown": return "file-text"
        case "paper": return "file-text"
        default: return "file-text"
        }
    }
}
