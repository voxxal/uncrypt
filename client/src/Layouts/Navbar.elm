module Layouts.Navbar exposing (Model, Msg, Settings, layout)

import Components.Icon exposing (icon)
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
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
        , view = view
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
    = ReplaceMe


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        ReplaceMe ->
            ( model
            , Effect.none
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : { fromMsg : Msg -> mainMsg, content : View mainMsg, model : Model } -> View mainMsg
view { fromMsg, model, content } =
    { title = "uncrypt | " ++ content.title
    , body =
        [ nav [ Attr.class "navbar" ]
            [ div [] [ a [ Attr.class "logo", Attr.href "/" ] [ text "uncrypt" ] ]
            , div [ Attr.class "location" ] [ text content.title ]
            , div [ Attr.class "right" ]
                [ div [ Attr.class "buttons" ]
                    [ a [ Attr.class "options", Attr.href "/settings" ] [ icon "fa-solid fa-gear" ]
                    , a [ Attr.class "button login" ] [ icon "fa-solid fa-user fa-sm", text "Login" ]
                    ]
                ]
            ]
        , div [ Attr.class "page" ] content.body
        ]
    }



{-
   module Layouts.Navbar exposing (layout)

   import Html exposing (..)
   import Html.Attributes as Attr
   import View exposing (View)


   layout : { page : View msg } -> View msg
   layout { page } =
       { title = page.title
       , body =
           [ nav [ Attr.class "navbar" ]
               [ a [ Attr.class "logo", Attr.href "/" ] [ text "uncrypt" ]
               , div [ Attr.class "location" ] [ text page.title ]
               , a [ Attr.class "options", Attr.href "/settings" ] [ text "Settings" ]
               ]
           , div [ Attr.class "page" ] page.body
           ]
       }
-}
