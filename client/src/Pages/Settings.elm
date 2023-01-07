module Pages.Settings exposing (Model, Msg, page)

import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Layout exposing (Layout)
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Settings
import Settings.Theme
import Shared
import Shared.Msg
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view shared
        }
        |> Page.withLayout (\_ -> Layouts.Navbar { navbar = {} })



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
    = ChangeSetting Settings.Setting


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        ChangeSetting setting ->
            ( model
            , Effect.sendSharedMsg (Shared.Msg.ChangeSetting setting)
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
            Settings.Theme.toString shared.settings.theme

        selected value =
            Attr.selected (currentThemeString == value)
    in
    { title = "Settings"
    , body =
        [ div [ Attr.class "settings-content text-content" ]
            [ label [ Attr.class "label", Attr.for "theme" ] [ text "THEME: " ]
            , select
                [ Attr.name "theme"
                , Attr.id "theme"
                , Events.onInput
                    (Settings.Theme.fromString
                        >> Settings.Theme
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
