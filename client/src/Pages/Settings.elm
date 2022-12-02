module Pages.Settings exposing (Model, Msg, page)

import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Layout exposing (Layout)
import Page exposing (Page)
import Route exposing (Route)
import Shared
import Shared.Msg
import Shared.Settings
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
        , view = view shared
        }



-- INIT


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init () =
    ( {}
    , Effect.none
    )



-- UPDATE


type Msg
    = ChangeSetting Shared.Settings.Setting


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        ChangeSetting setting ->
            ( model
            , Effect.fromSharedMsg (Shared.Msg.ChangeSetting setting)
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    let
        currentThemeString =
            Shared.Settings.themeToString shared.settings.theme

        selected value =
            Attr.selected (currentThemeString == value)
    in
    { title = "Settings"
    , body =
        [ div [ Attr.class "settings-content text-content" ]
            [ label [ Attr.class "heading", Attr.for "theme" ] [ text "THEME: " ]
            , select
                [ Attr.name "theme"
                , Attr.id "theme"
                , Events.onInput
                    (Shared.Settings.themeFromString
                        >> Shared.Settings.Theme
                        >> ChangeSetting
                    )
                ]
                [ option [ Attr.value "auto", selected "auto" ] [ text "Auto" ]
                , option [ Attr.value "light", selected "light" ] [ text "Light" ]
                , option [ Attr.value "dark", selected "dark" ] [ text "Dark" ]
                ]
            ]
        ]
    }
