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

import Api.Auth
import Dict
import Effect exposing (Effect)
import Json.Decode as D
import Json.Encode as E
import Route exposing (Route)
import Route.Path
import Settings
import Settings.Theme
import Shared.Model
import Shared.Msg exposing (Msg(..))



-- FLAGS


type alias Flags =
    { settings : Maybe Settings.Settings
    , token : Maybe String
    }


decoder : D.Decoder Flags
decoder =
    D.map2 Flags
        (D.maybe (D.field "settings" Settings.settingsDecoder))
        (D.maybe (D.field "token" D.string))



-- INIT


type alias Model =
    Shared.Model.Model


init : Result D.Error Flags -> Route () -> ( Model, Effect Msg )
init flagsResult route =
    let
        flags : Flags
        flags =
            flagsResult
                |> Result.withDefault { settings = Nothing, token = Nothing }

        defaultSettings =
            { theme = Settings.Theme.Auto }

        settings =
            Maybe.withDefault defaultSettings flags.settings
    in
    ( { settings = settings, token = flags.token, user = Nothing }
    , Effect.batch
        [ Effect.sendCmd (Settings.Theme.updateTheme (Settings.Theme.encoder settings.theme))
        , Maybe.withDefault Effect.none (Maybe.map2 Api.Auth.profile flags.token (Just GotProfile))
        ]
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

                sideEffect =
                    case setting of
                        Settings.Theme _ ->
                            Effect.sendCmd (Settings.Theme.updateTheme (Settings.Theme.encoder newSettings.theme))
            in
            ( { model | settings = newSettings }
            , Effect.batch
                [ sideEffect
                , Effect.save "settings" (Settings.settingsEncoder newSettings)
                ]
            )

        Login token ->
            ( { model | token = Just token }
            , Effect.batch
                [ Effect.pushRoute
                    { path = Route.Path.Home_
                    , query = Dict.empty
                    , hash = Nothing
                    }
                , Effect.save "token" (E.string token)
                , Api.Auth.profile token GotProfile
                ]
            )

        GotProfile (Ok profile) ->
            ( { model | user = Just profile }, Effect.none )

        GotProfile (Err _) ->
            ( { model | token = Nothing }, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Route () -> Model -> Sub Msg
subscriptions route model =
    Sub.none
