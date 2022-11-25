port module Shared.Settings exposing (Setting(..), Settings, Theme(..), settingsDecoder, themeDecoder, themeEncoder, updateTheme)

import Json.Decode as D
import Json.Encode as E


type Theme
    = ThemeAuto
    | ThemeLight
    | ThemeDark


themeEncoder : Theme -> E.Value
themeEncoder theme =
    E.string
        (case theme of
            ThemeAuto ->
                "auto"

            ThemeLight ->
                "light"

            ThemeDark ->
                "dark"
        )


themeDecoder : D.Decoder Theme
themeDecoder =
    D.map
        (\str ->
            case str of
                "auto" ->
                    ThemeAuto

                "light" ->
                    ThemeLight

                "dark" ->
                    ThemeDark

                _ ->
                    ThemeAuto
        )
        D.string

port updateTheme : E.Value -> Cmd msg


type alias Settings =
    { theme : Theme }


settingsDecoder : D.Decoder Settings
settingsDecoder =
    D.map Settings (D.field "theme" themeDecoder)


type Setting
    = Theme Theme
