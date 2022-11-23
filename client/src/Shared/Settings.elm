module Shared.Settings exposing (Theme (..), Settings, Setting (..))


type Theme
    = ThemeAuto
    | ThemeLight
    | ThemeDark


type alias Settings =
    { theme : Theme }

type Setting = Theme Theme