pragma Singleton

import QtQuick
import QtCore

QtObject {
    id: rootStyle
    property QtObject color: QtObject {
        readonly property color transparent: 'transparent'
        readonly property color paleGray: '#F5F4EF'
        readonly property color lightGray: '#C1C2C5'
        readonly property color mutedGray: '#878B91'
        readonly property color charcoalGray: '#494B50'
        readonly property color slateGray: '#2C2D30'
        readonly property color onyxBlack: '#1C1D21'
        readonly property color midnightBlack: '#0E0E11'
        readonly property color goldenApricot: goldenApricotString
        readonly property color goldenApricotStrong: '#C8F050'
        readonly property color goldenApricotPressed: '#9FC72E'
        readonly property color benefitsPanelBackground: '#1C1C1E'
        readonly property color softViolet: '#A87BE2'
        readonly property color burntOrange: '#9FC72E'
        readonly property color mutedBrown: '#6E7A50'
        readonly property color richBrown: '#9FC72E'
        readonly property color deepBrown: '#3E4A22'
        readonly property color vibrantRed: '#EB5757'
        readonly property color vibrantGreen: '#3FBF6B'
        readonly property color deepMagenta: '#950051'
        readonly property color darkCharcoal: '#1A1C18'
        readonly property color pearlGray: '#EAEAEC'

        readonly property color sheerWhite: Qt.rgba(1, 1, 1, 0.12)
        readonly property color translucentWhite: Qt.rgba(1, 1, 1, 0.08)
        readonly property color barelyTranslucentWhite: Qt.rgba(1, 1, 1, 0.05)
        readonly property color translucentMidnightBlack: Qt.rgba(14/255, 14/255, 17/255, 0.8)
        readonly property color softGoldenApricot: Qt.rgba(184/255, 230/255, 65/255, 0.3)
        readonly property color mistyGray: Qt.rgba(245/255, 244/255, 239/255, 0.8)
        readonly property color cloudyGray: Qt.rgba(245/255, 244/255, 239/255, 0.65)
        readonly property color translucentRichBrown: Qt.rgba(184/255, 230/255, 65/255, 0.12)
        readonly property color translucentSlateGray: Qt.rgba(85/255, 86/255, 92/255, 0.13)
        readonly property color translucentOnyxBlack: Qt.rgba(28/255, 29/255, 33/255, 0.13)

        readonly property string goldenApricotString: '#B8E641'

        readonly property color backgroundBase: '#101012'
        readonly property color surfaceBase: '#18181B'
        readonly property color surfaceHovered: '#232327'
        readonly property color surfacePressed: '#2C2D30'
        readonly property color surfaceInverse: '#E4E4E7'
        readonly property color surfaceInverseHovered: '#D4D4D8'
        readonly property color surfaceInversePressed: '#A1A1AA'
        readonly property color textPrimary: '#FAFAFA'
        readonly property color textTertiary: '#A1A1AA'
        readonly property color textInverted: '#09090B'
        readonly property color textStaticWhite: '#FFFFFF'
        readonly property color borderSoft: '#3F3F46'
        readonly property color accentSuccess: '#4ADE80'
        readonly property color accentWarning: '#EAB308'
    }
    property bool isDark: true
    readonly property QtObject fresh: QtObject {
        readonly property color bg:         rootStyle.isDark ? "#0E0E11" : "#F4F4F2"
        readonly property color card:       rootStyle.isDark ? "#16171A" : "#FFFFFF"
        readonly property color bg2:        rootStyle.isDark ? "#1C1D21" : "#ECECEE"
        readonly property color bg3:        rootStyle.isDark ? "#25262B" : "#E0E0E4"
        readonly property color line:       rootStyle.isDark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.10)
        readonly property color fg:         rootStyle.isDark ? "#F5F4EF" : "#17181B"
        readonly property color mute:       rootStyle.isDark ? "#878B91" : "#6B6F76"
        readonly property color dim:        rootStyle.isDark ? "#5A5D63" : "#9CA0A6"
        readonly property color lime:       "#B8E641"
        readonly property color limeStrong: "#C8F050"
        readonly property color limeSoft:   rootStyle.isDark ? Qt.rgba(184/255,230/255,65/255,0.10) : Qt.rgba(116/255,182/255,43/255,0.12)
        readonly property color limeLine:   rootStyle.isDark ? Qt.rgba(184/255,230/255,65/255,0.30) : Qt.rgba(116/255,182/255,43/255,0.40)
        readonly property color warn:       "#FBB26A"
        readonly property color bad:        "#E5484D"
        readonly property color ok:         "#5FD08A"
        readonly property color danger:     "#E5715A"
    }

    property Settings _themePersist: Settings {
        category: "FreshUI"
        property alias isDark: rootStyle.isDark
    }
}