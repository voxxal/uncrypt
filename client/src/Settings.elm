module Settings exposing
    ( Setting(..)
    , Settings
    , settingsDecoder
    , settingsEncoder
    )

import Json.Decode as D
import Json.Encode as E
import Settings.Theme


type alias Settings =
    { theme : Settings.Theme.Theme }


settingsDecoder : D.Decoder Settings
settingsDecoder =
    D.map Settings (D.field "theme" Settings.Theme.decoder)


settingsEncoder : Settings -> E.Value
settingsEncoder settings =
    E.object [ ( "theme", Settings.Theme.encoder settings.theme ) ]


type Setting
    = Theme Settings.Theme.Theme
