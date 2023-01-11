module Components.Puzzle exposing (..)

import Api.Puzzle
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events


character :
    { translatedChar : Char
    , untranslated : String
    , frequency : Int
    , selected : Bool
    , softSelected : Bool
    , collision : Bool
    , onClick : msg
    }
    -> Html msg
character { translatedChar, untranslated, frequency, selected, softSelected, collision, onClick } =
    div [ Attr.class "char" ]
        [ span
            [ Attr.classList
                [ ( "translatedChar", True )
                , ( "selected", selected )
                , ( "softSelected", softSelected )
                , ( "collision", collision )
                ]
            , Events.onClick onClick
            ]
            [ text (String.fromChar translatedChar) ]
        , span [ Attr.class "untranslatedChar" ] [ text untranslated ]
        , span [ Attr.class "frequency" ] [ text (String.fromInt frequency) ]
        ]


unimportant : String -> Html msg
unimportant char =
    span [ Attr.class "unimportant" ] [ text char ]


type SolveStatus
    = NotChecked
    | Failure
    | Solved Api.Puzzle.SubmitResponse
