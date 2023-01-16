module Pages.Profile exposing (Model, Msg, page)

import Api
import Api.Http
import Api.Profile
import Auth
import Auth.User
import Components.Api
import Dict
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Layouts
import Maybe.Extra as Maybe
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init shared
        , update = update
        , subscriptions = subscriptions
        , view = view
        }
        |> Page.withLayout (\_ -> Layouts.Navbar { navbar = {} })



-- INIT


type alias Model =
    { profile : Api.Status Auth.User.User
    , solves : Api.Status Api.Profile.Solves
    }


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { profile =
            case shared.user of
                Just user ->
                    Api.Success user

                Nothing ->
                    Api.Loading
      , solves = Api.Loading
      }
    , Effect.batch
        [ Maybe.unwrap
            (Effect.pushRoute
                { path = Route.Path.Login
                , query = Dict.empty
                , hash = Nothing
                }
            )
            (\token -> Api.Profile.mySolves token GotSolves)
            shared.token
        , case shared.user of
            Just _ ->
                Effect.none

            Nothing ->
                Maybe.unwrap
                    (Effect.pushRoute
                        { path = Route.Path.Login
                        , query = Dict.empty
                        , hash = Nothing
                        }
                    )
                    (\token -> Api.Profile.myProfile token GotProfile)
                    shared.token
        ]
    )



-- UPDATE


type Msg
    = GotProfile (Result Api.Http.Error Auth.User.User)
    | GotSolves (Result Api.Http.Error Api.Profile.Solves)


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        GotProfile (Ok profile) ->
            ( { model | profile = Api.Success profile }, Effect.none )

        GotProfile (Err err) ->
            ( { model | solves = Api.Failure err }, Effect.none )

        GotSolves (Ok solves) ->
            ( { model | solves = Api.Success solves }, Effect.none )

        GotSolves (Err err) ->
            ( { model | solves = Api.Failure err }, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title =
        case model.profile of
            Api.Success profile ->
                profile.username ++ "'s profile"

            _ ->
                "Profile"
    , body =
        [ div [ Attr.class "profile-content text-content" ]
            [ viewProfileInfo model
            , hr [] []
            , viewSolves model
            ]
        ]
    }


viewProfileInfo : Model -> Html Msg
viewProfileInfo model =
    case model.profile of
        Api.Loading ->
            text "Loading..."

        Api.Success profile ->
            div [ Attr.class "profileInfo" ]
                [ div [ Attr.class "userSummary" ]
                    [ span [ Attr.class "level" ] [ text (String.fromInt profile.level) ]
                    , h1 [] [ text profile.username ]
                    ]
                , div [ Attr.class "levelInfo" ]
                    [ div [ Attr.class "levelContainer" ]
                        [ div [ Attr.class "levelBar" ]
                            [ div [ Attr.class "barBg" ] []
                            , div
                                [ Attr.class "barFg"
                                , Attr.style "width" (String.fromFloat (toFloat profile.expThrough / toFloat profile.expRequired * 100) ++ "%")
                                ]
                                []
                            ]
                        , div [ Attr.class "levelProgress" ]
                            [ text (String.fromInt profile.expThrough ++ "/" ++ String.fromInt profile.expRequired)
                            ]
                        ]
                    ]
                ]

        Api.Failure err ->
            Components.Api.failure err


viewSolves : Model -> Html Msg
viewSolves model =
    case model.solves of
        Api.Loading ->
            if model.profile == Api.Loading then
                text ""

            else
                text "Loading Recent Solves"

        Api.Success solves ->
            div [ Attr.class "solves" ] (List.map viewSolve solves)

        Api.Failure err ->
            Components.Api.failure err


viewSolve : Api.Profile.Solve -> Html Msg
viewSolve solve =
    div []
        [ div [ Attr.class "solve" ]
            [ div [ Attr.class "puzzleInfo" ]
                [ h2 [ Attr.class "puzzleType" ] [ text solve.puzzleType ]
                , div [ Attr.class "message" ] [ text ("\"" ++ solve.plaintext ++ "\"") ]
                , div [ Attr.class "attribution" ] [ text ("- " ++ solve.attribution) ]
                ]
            , div [ Attr.class "solveInfo" ]
                [ div [ Attr.class "expGained" ] [ text ("+" ++ String.fromInt solve.expGained) ]
                , div [ Attr.class "timeTaken" ] [ text ("Solve Time: " ++ String.fromFloat (toFloat solve.timeTaken / 1000) ++ "s") ]
                ]
            ]
        , hr [ Attr.class "thin"] []
        ]
