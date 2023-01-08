module Components.Input exposing (..)

import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events


textInput :
    { id : String
    , name : String
    , placeholder : Maybe String
    , value : String
    , onInput : String -> msg
    }
    -> Html msg
textInput { id, name, placeholder, value, onInput } =
    div []
        [ label [ Attr.class "bigLabel", Attr.for id ] [ text name ]
        , input
            [ Attr.type_ "text"
            , Attr.id id
            , Events.onInput onInput
            , Attr.value value
            , Attr.placeholder (Maybe.withDefault "" placeholder)
            , Attr.class "textInput"
            ]
            []
        ]


passwordInput :
    { id : String
    , name : String
    , placeholder : Maybe String
    , value : String
    , onInput : String -> msg
    }
    -> Html msg
passwordInput { id, name, placeholder, value, onInput } =
    div []
        [ label [ Attr.class "bigLabel", Attr.for id ] [ text name ]
        , input
            [ Attr.type_ "password"
            , Attr.id id
            , Events.onInput onInput
            , Attr.value value
            , Attr.placeholder (Maybe.withDefault "" placeholder)
            , Attr.class "textInput"
            ]
            []
        ]
