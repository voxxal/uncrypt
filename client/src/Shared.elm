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
    { settings : Maybe Settings.Settings
    }


decoder : D.Decoder Flags
decoder =
    D.map Flags (D.maybe (D.field "settings" Settings.settingsDecoder))



-- INIT


type alias Model =
    { settings : Settings.Settings
    }


init : Result D.Error Flags -> Route () -> ( Model, Effect Msg )
init flagsResult route =
    let
        flags : Flags
        flags =
            flagsResult
                |> Result.withDefault { settings = Nothing }

        defaultSettings =
            { theme = Settings.ThemeAuto }

        settings =
            Maybe.withDefault defaultSettings flags.settings
    in
    ( { settings = settings }
    , Effect.fromCmd (Settings.updateTheme (Settings.themeEncoder settings.theme))
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
