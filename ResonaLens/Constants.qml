pragma Singleton
import QtQuick
import QtQuick.Studio.Application

QtObject {
    // ── Screen Dimensions ──
    readonly property int width: 402
    readonly property int height: 874
    readonly property int screenCornerRadius: 40
    readonly property int statusBarHeight: 54
    readonly property int headerHeight: 56

    // ── Font ──
    readonly property string fontFamily: "Outfit"

    property string relativeFontDirectory: "fonts"

    // ── 1.1 Core Backgrounds ──
    readonly property color background: "#F5F4F1"
    readonly property color surface: "#FFFFFF"
    readonly property color surfaceElevated: "#FAFAF8"
    readonly property color surfaceMuted: "#EDECEA"

    // ── 1.2 Text Colors ──
    readonly property color textPrimary: "#1A1918"
    readonly property color textSecondary: "#6D6C6A"
    readonly property color textTertiary: "#9C9B99"
    readonly property color textDisabled: "#A8A7A5"

    // ── 1.3 Border Colors ──
    readonly property color borderSubtle: "#E5E4E1"
    readonly property color borderStrong: "#D1D0CD"

    // ── 1.4 Primary (Green) ──
    readonly property color primary: "#3D8A5A"
    readonly property color primaryDark: "#2D6A44"
    readonly property color primaryLight: "#C8F0D8"
    readonly property color primarySurface: "#F0F7F2"

    // ── 1.5 Secondary (Coral) ──
    readonly property color secondary: "#D89575"
    readonly property color secondaryDark: "#C07558"
    readonly property color secondarySurface: "#FEE8D6"

    // ── 1.6 Semantic Colors ──
    readonly property color error: "#D08068"
    readonly property color warning: "#D4A64A"
    readonly property color info: "#4A8DB5"
    readonly property color infoSurface: "#E1F0F8"
    readonly property color purple: "#7C6DB5"
    readonly property color purpleSurface: "#E8E4F9"

    // ── 1.7 User Message ──
    readonly property color userBubble: "#3D8A5A"
    readonly property color userText: "#FFFFFF"
    readonly property color userTime: "#FFFFFFAA"

    // ── 1.8 Assistant Message ──
    readonly property color assistantBubble: "#FFFFFF"
    readonly property color assistantText: "#1A1918"
    readonly property color assistantTime: "#9C9B99"

    // ── 1.9 Overlay ──
    readonly property color overlayDim: "#00000055"

    // ── 2.1 Typography Sizes ──
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

    // ── 2.2 Font Weights ──
    readonly property int weightBold: Font.Bold
    readonly property int weightSemiBold: Font.DemiBold
    readonly property int weightMedium: Font.Medium
    readonly property int weightRegular: Font.Normal

    // ── 2.3 Letter Spacing ──
    readonly property real lsDisplay: -1.0
    readonly property real lsTitle1: -0.5
    readonly property real lsTitle2: -0.3
    readonly property real lsTitle3: -0.2
    readonly property real lsNormal: 0

    // ── 3.1 Gap Scale ──
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

    // ── 3.2 Padding ──
    readonly property int padPage: 24
    readonly property int padCard: 14
    readonly property int padCardSide: 16
    readonly property int padCardLg: 16
    readonly property int padInput: 14
    readonly property int padChipV: 6
    readonly property int padChipH: 14
    readonly property int padBadgeV: 4
    readonly property int padBadgeH: 10
    readonly property int padHeader: 24
    readonly property int padDrawerTop: 54
    readonly property int padDrawerNavV: 8
    readonly property int padDrawerNavH: 12

    // ── 4. Corner Radius ──
    readonly property int radiusScreen: 40
    readonly property int radiusCard: 16
    readonly property int radiusInput: 12
    readonly property int radiusDrawerNav: 10
    readonly property int radiusChip: 100
    readonly property int radiusSelector: 8
    readonly property int radiusTag: 4

    // ── 5. Shadow System ──
    // Applied via layer.effect in QML
    readonly property int shadowCardOffsetY: 2
    readonly property int shadowCardBlur: 8
    readonly property color shadowCardColor: "#1A191808"
    readonly property int shadowElevatedBlur: 12
    readonly property int shadowSubtleBlur: 6
    readonly property int shadowFabOffsetY: 4
    readonly property int shadowFabBlur: 16
    readonly property color shadowFabColor: "#3D8A5A44"

    // ── 6. Icon Sizes ──
    readonly property int iconXl: 26
    readonly property int iconLg: 24
    readonly property int iconMd: 22
    readonly property int iconBase: 20
    readonly property int iconSm: 18
    readonly property int iconXs: 16
    readonly property int iconXxs: 14
    readonly property int iconChip: 12

    // ── Component Sizes ──
    readonly property int sendButtonSize: 38
    readonly property int avatarSize: 32
    readonly property int modelIconSize: 44
    readonly property int toggleWidth: 44
    readonly property int toggleHeight: 26
    readonly property int toggleDotSize: 20
    readonly property int inputBarHeight: 56
    readonly property int searchBarHeight: 44
    readonly property int navItemHeight: 44
    readonly property int historyItemHeight: 40
    readonly property int drawerWidth: 320
    readonly property int sliderThumbSize: 20
    readonly property int sliderTrackHeight: 6
    readonly property int chipHeight: 28

    // ── Chat Bubble Radii ──
    readonly property var userBubbleRadius: [16, 16, 4, 16]
    readonly property var assistantBubbleRadius: [16, 16, 16, 4]

    // ── Gated Model Badge ──
    readonly property color gatedBadgeBg: "#FFF3E0"
    readonly property color gatedBadgeText: "#E6A23C"

    // ── Document Icon Colors by Type ──
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

    // ── Storage Icon Colors ──
    readonly property color storageModels: "#3D8A5A"
    readonly property color storageChatHistory: "#D89575"
    readonly property color storageKnowledge: "#7C6DB5"

    property StudioApplication application: StudioApplication {
        fontPath: Qt.resolvedUrl("../ResonaLensContent/" + relativeFontDirectory)
    }
}
