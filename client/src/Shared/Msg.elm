module Shared.Msg exposing (Msg(..))

import Settings


type Msg
    = ChangeSetting Settings.Setting
    | Login String
