module Components.Puzzle exposing (..)

import Api.Puzzle
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events


viewExpSource : Api.Puzzle.ExpSource -> Html msg
viewExpSource source =
    div [ Attr.classList [ ( "expSource", True ), ( "special", source.special ) ] ]
        [ span [ Attr.class "expSourceName" ] [ text source.name ]
        , span [ Attr.class "expSourceAmount" ] [ text source.amount ]
        ]


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
        , if frequency /= -1 then
            span [ Attr.class "frequency" ] [ text (String.fromInt frequency) ]

          else
            text ""
        ]


unimportant : String -> Html msg
unimportant char =
    span [ Attr.class "unimportant" ] [ text char ]


modalBox : Api.Puzzle.SubmitResponse -> String -> msg -> Html msg
modalBox info attribution tryAnother =
    div [ Attr.class "modal" ]
        [ div [ Attr.class "modalContent" ]
            [ h1 [] [ text "Congratulations!" ]
            , div []
                [ text "You completed the Baconian in "
                , strong [] [ text (String.fromFloat (toFloat info.timeTaken / 1000)) ]
                , text " seconds!"
                ]
            , div [ Attr.class "messageContainer" ]
                [ div [ Attr.class "message" ] [ text ("\"" ++ info.plaintext ++ "\"") ]
                , div [ Attr.class "attribution" ] [ text ("- " ++ attribution) ]
                ]
            , case info.expSources of
                Just expSources ->
                    div [ Attr.class "expSources" ] (List.map viewExpSource expSources)

                Nothing ->
                    text ""
            , case info.totalExp of
                Just exp ->
                    div [ Attr.class "totalExp" ]
                        [ div [ Attr.classList [ ( "expSource", True ), ( "special", False ) ] ]
                            [ span [ Attr.class "expSourceName" ] [ text "Total" ]
                            , span [ Attr.class "expSourceAmount" ] [ text (String.fromInt exp) ]
                            ]
                        ]

                Nothing ->
                    div [ Attr.class "totalExp" ] []
            , case info.profile of
                Just profile ->
                    div [ Attr.class "levelInfo" ]
                        [ span [ Attr.class "level" ] [ text (String.fromInt profile.level) ]
                        , div [ Attr.class "levelContainer" ]
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

                Nothing ->
                    text ""
            , button [ Attr.class "button submitButton", Events.onClick tryAnother ] [ text "Try another" ]
            ]
        ]


type SolveStatus
    = NotChecked
    | Failure
    | Solved Api.Puzzle.SubmitResponse
