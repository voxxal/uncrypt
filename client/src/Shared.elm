module Shared exposing
    ( Flags, decoder
    , Model, Msg
    , init, update, subscriptions
    )

{-|

@docs Flags, decoder
@docs Model, Msg
@docs init, update, subscriptions

-}

import Effect exposing (Effect)
import Json.Decode as D
import Route exposing (Route)
import Route.Path
import Shared.Msg exposing (Msg(..))
import Shared.Settings as Settings



-- FLAGS


type alias Flags =
    {}


decoder : D.Decoder Flags
decoder =
    D.succeed {}



-- INIT


type alias Model =
    { settings : Settings.Settings
    }


init : Result D.Error Flags -> Route () -> ( Model, Effect Msg )
init flagsResult route =
    let
        defaultSettings =
            { theme = Settings.ThemeAuto }
    in
    ( { settings = defaultSettings }
    , Effect.none
    )



-- UPDATE


type alias Msg =
    Shared.Msg.Msg


update : Route () -> Msg -> Model -> ( Model, Effect Msg )
update route msg model =
    case msg of
        ChangeSetting setting ->
            let
                settings =
                    model.settings

                newSettings =
                    case setting of
                        Settings.Theme theme ->
                            { settings | theme = theme }
            in
            ( { model | settings = newSettings }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Route () -> Model -> Sub Msg
subscriptions route model =
    Sub.none
