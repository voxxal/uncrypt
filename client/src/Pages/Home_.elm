module Pages.Home_ exposing (Model, Msg, page)

import Components.Icon exposing (icon)
import Dict
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }
        |> Page.withLayout (\_ -> Layouts.Navbar { navbar = {} })



-- INIT


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init () =
    ( {}, Effect.none )



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
    , body =
        [ div [ Attr.class "text-content" ]
            [ h1 [] [ text "uncrypt" ]
            , p []
                [ text "Welcome to uncrypt! A website dedicated to solving different cryptographic puzzles. Select one of our puzzles to get started, or create an account to start gaining experience."
                , p []
                    [ text "This website is "
                    , a [ Attr.href "https://github.com/voxxal/uncrypt" ] [ text "open source" ]
                    , text ". Consider contributing if you have experience in Elm or Rust. All pull requests are welcomed."
                    ]
                ]
            , hr [] []
            , div [ Attr.class "puzzleTypeInfo" ]
                [ a [ Attr.href "/aristocrat" ]
                    [ h2 [] [ text "Aristocrat" ]
                    , p [] [ text "Also known as Cryptograms, these puzzles are one of the most popular cryptographic puzzles." ]
                    , div [ Attr.class "play" ] [ div [ Attr.class "iconContainer" ] [ icon "fa-solid fa-chevron-right" ], text "Play" ]
                    ]
                ]
            , hr [] []
            , div [ Attr.class "puzzleTypeInfo" ]
                [ a [ Attr.href "/baconian" ]
                    [ h2 [] [ text "Baconian" ]
                    , p [] [ text (String.repeat 5 "SIR BACON ") ]
                    , div [ Attr.class "play" ] [ div [ Attr.class "iconContainer" ] [ icon "fa-solid fa-chevron-right" ], text "Play" ]
                    ]
                ]
            , hr [] []
            , p [] [ text "[about and socials]" ]
            ]
        ]
    }
