port module Shared.Settings exposing
    ( Setting(..)
    , Settings
    , Theme(..)
    , settingsDecoder
    , settingsEncoder
    , themeDecoder
    , themeEncoder
    , themeFromString
    , themeToString
    , updateTheme
    )

import Json.Decode as D
import Json.Encode as E


type Theme
    = ThemeAuto
    | ThemeLight
    | ThemeDark


themeFromString : String -> Theme
themeFromString str =
    case str of
        "auto" ->
            ThemeAuto

        "light" ->
            ThemeLight

        "dark" ->
            ThemeDark

        _ ->
            ThemeAuto


themeToString : Theme -> String
themeToString theme =
    case theme of
        ThemeAuto ->
            "auto"

        ThemeLight ->
            "light"

        ThemeDark ->
            "dark"


themeDecoder : D.Decoder Theme
themeDecoder =
    D.map themeFromString D.string


themeEncoder : Theme -> E.Value
themeEncoder theme =
    E.string (themeToString theme)


port updateTheme : E.Value -> Cmd msg


type alias Settings =
    { theme : Theme }


settingsDecoder : D.Decoder Settings
settingsDecoder =
    D.map Settings (D.field "theme" themeDecoder)


settingsEncoder : Settings -> E.Value
settingsEncoder settings =
    E.object [ ( "theme", themeEncoder settings.theme ) ]


type Setting
    = Theme Theme
