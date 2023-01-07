module Shared.Model exposing (Model)

import Settings

type alias Model =
    { settings : Settings.Settings
    , token : Maybe String
    }
