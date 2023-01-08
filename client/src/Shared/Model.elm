module Shared.Model exposing (Model)

import Settings
import Auth.User

type alias Model =
    { settings : Settings.Settings
    , token : Maybe String
    , user : Maybe Auth.User.User
    }
