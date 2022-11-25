module Pages.Home_ exposing (Model, Msg, page)

import Dict
import Effect exposing (Effect)
import Html
import Layout exposing (Layout)
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import View exposing (View)


layout : Layout
layout =
    Layout.Navbar


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- INIT


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init () =
    ( {}
    -- Currently aristocrat is our only thing so we'll just redirect there.
    , Effect.pushRoute
        { path = Route.Path.Aristocrat
        , query = Dict.empty
        , hash = Nothing
        }
    )



-- UPDATE


type Msg
    = ExampleMsgReplaceMe


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        ExampleMsgReplaceMe ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Home"
    , body = [ Html.text "/" ]
    }
