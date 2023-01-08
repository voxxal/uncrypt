module Shared.Msg exposing (Msg(..))

import Api.Http
import Auth.User
import Settings


type Msg
    = ChangeSetting Settings.Setting
    | Login String
    | GotProfile (Result Api.Http.Error Auth.User.User)
