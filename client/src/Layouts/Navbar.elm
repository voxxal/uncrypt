module Layouts.Navbar exposing (Model, Msg, Settings, layout)

import Components.Icon exposing (icon)
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Layout exposing (Layout)
import Route exposing (Route)
import Shared
import View exposing (View)


type alias Settings =
    {}


layout : Settings -> Shared.Model -> Route () -> Layout Model Msg mainMsg
layout settings shared route =
    Layout.new
        { init = init
        , update = update
        , view = view shared
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init _ =
    ( {}
    , Effect.none
    )



-- UPDATE


type Msg
    = Placeholder


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        _ ->
            ( model, Effect.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> { fromMsg : Msg -> mainMsg, content : View mainMsg, model : Model } -> View mainMsg
view shared { fromMsg, model, content } =
    { title = "uncrypt | " ++ content.title
    , body =
        [ nav [ Attr.class "navbar" ]
            [ div [] [ a [ Attr.class "logo", Attr.href "/" ] [ text "uncrypt" ] ]
            , div [ Attr.class "location" ] [ text content.title ]
            , div [ Attr.class "right" ]
                [ div [ Attr.class "buttons" ]
                    [ a [ Attr.class "options", Attr.href "/settings" ] [ icon "fa-solid fa-gear" ]
                    , viewProfileSummary shared
                    ]
                ]
            ]
        , div [ Attr.class "page" ] content.body
        ]
    }


viewProfileSummary : Shared.Model -> Html msg
viewProfileSummary shared =
    case shared.user of
        Nothing ->
            a
                [ Attr.class "button login", Attr.href "/login" ]
                [ text "Login" ]

        Just user ->
            a [ Attr.class "profile", Attr.href "/profile" ]
                [ span [ Attr.class "level" ] [ text (String.fromInt user.level) ]
                , span [] [ text user.username ]
                ]
