module Pages.Aristocrat exposing (Model, Msg, page)

import Array exposing (Array)
import Browser.Events exposing (onKeyDown)
import Dict exposing (Dict)
import Dict.Extra as Dict
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Http
import Json.Decode as D
import Json.Encode as E
import Layouts
import Maybe.Extra as Maybe
import Page exposing (Page)
import Route exposing (Route)
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


type SolveStatus
    = NotChecked
    | Failure
    | Solved


type Timing
    = NotStarted
    | Started Int
    | Finished Int


type alias Model =
    { ciphertext : Array Char
    , translation : Dict Char Char
    , reverseTrans : Dict Char (List Char)
    , index : Int
    , letterFrequencies : Dict Char Int
    , attribution : String
    , solved : SolveStatus
    , timing : Timing
    , sig : String
    }


letters : List Char
letters =
    String.toList "abcdefghijklmnopqrstuvwxyz"


init : () -> ( Model, Effect Msg )
init _ =
    let
        model =
            { translation = Dict.empty
            , reverseTrans = Dict.empty
            , index = 0
            , ciphertext = Array.empty
            , letterFrequencies = Dict.empty
            , attribution = "Unknown"
            , solved = NotChecked
            , timing = NotStarted
            , sig = ""
            }
    in
    ( model
    , Http.get
        { url = "/api/aristocrat/new"
        , expect = Http.expectJson GotPuzzleInfo puzzleInfoDecoder
        }
        |> Effect.sendCmd
    )



-- UPDATE


type alias PuzzleInfo =
    { message : String
    , sig : String
    , timestamp : Int
    , attribution : String
    }


puzzleInfoDecoder : D.Decoder PuzzleInfo
puzzleInfoDecoder =
    D.map4 PuzzleInfo
        (D.field "message" D.string)
        (D.field "sig" D.string)
        (D.field "timestamp" D.int)
        (D.field "attribution" D.string)


type Msg
    = GotPuzzleInfo (Result Http.Error PuzzleInfo)
    | KeyPress String
    | Clicked Int
    | SubmitSolution
    | GotSubmitResponse (Result Http.Error Int)
    | TryAnother


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        GotPuzzleInfo (Ok puzzleInfo) ->
            ( { model
                | ciphertext = puzzleInfo.message |> String.toList |> Array.fromList
                , attribution = puzzleInfo.attribution
                , sig = puzzleInfo.sig
                , timing = Started puzzleInfo.timestamp
                , letterFrequencies = Dict.frequencies (puzzleInfo.message |> String.toList)
              }
            , Effect.none
            )

        GotPuzzleInfo (Err _) ->
            ( { model | ciphertext = "Something went wrong! Try connecting to wifi." |> String.toList |> Array.fromList }
            , Effect.none
            )

        KeyPress key ->
            let
                shift : Int -> Int
                shift num =
                    case Array.get (model.index + num) model.ciphertext of
                        Just char ->
                            if Char.isAlpha char then
                                num

                            else
                                shift (num + sign num)

                        Nothing ->
                            0

                -- Dict and shift happens at the same time. This function takes in the dict to go over already answered letters
                shiftOverAnswered : Dict Char Char -> Int -> Int
                shiftOverAnswered newTranslation num =
                    case Array.get (model.index + num) model.ciphertext of
                        Just char ->
                            if Char.isAlpha char then
                                Maybe.unwrap num
                                    (\_ -> shiftOverAnswered newTranslation (num + sign num))
                                    (Dict.get char newTranslation)

                            else
                                shiftOverAnswered newTranslation (num + sign num)

                        Nothing ->
                            0
            in
            if model.solved /= Solved then
                case key of
                    "Enter" ->
                        update SubmitSolution model

                    "Backspace" ->
                        case Array.get model.index model.ciphertext of
                            Just char ->
                                ( { model
                                    | index = model.index + shift 1
                                    , translation = Dict.remove char model.translation
                                    , reverseTrans = removeFromDictLists char model.reverseTrans
                                  }
                                , Effect.none
                                )

                            Nothing ->
                                ( model, Effect.none )

                    "ArrowLeft" ->
                        ( { model | index = model.index + shift -1 }, Effect.none )

                    "ArrowRight" ->
                        ( { model | index = model.index + shift 1 }, Effect.none )

                    any ->
                        case String.uncons any of
                            Just ( pressedKey, "" ) ->
                                let
                                    letter =
                                        Char.toLower pressedKey
                                in
                                if Char.isAlpha pressedKey then
                                    case Array.get model.index model.ciphertext of
                                        Just char ->
                                            let
                                                maybeOldChar =
                                                    Dict.get char model.translation

                                                newTranslation =
                                                    Dict.insert char letter model.translation
                                            in
                                            ( { model
                                                | index = model.index + shiftOverAnswered newTranslation 1
                                                , translation = newTranslation
                                                , reverseTrans =
                                                    model.reverseTrans
                                                        |> (case maybeOldChar of
                                                                Just _ ->
                                                                    removeFromDictLists char

                                                                Nothing ->
                                                                    identity
                                                           )
                                                        |> Dict.insertDedupe
                                                            (++)
                                                            letter
                                                            [ char ]
                                                , solved = NotChecked
                                              }
                                            , Effect.none
                                            )

                                        _ ->
                                            ( model, Effect.none )

                                else
                                    ( model, Effect.none )

                            _ ->
                                ( model, Effect.none )

            else
                ( model, Effect.none )

        Clicked index ->
            ( { model | index = index }, Effect.none )

        SubmitSolution ->
            case model.timing of
                Started timestamp ->
                    ( model
                    , Http.post
                        { url = "/api/aristocrat/submit"
                        , body =
                            Http.jsonBody
                                (E.object
                                    [ ( "message"
                                      , E.string
                                            (Array.map (\c -> Dict.get c model.translation |> Maybe.withDefault c) model.ciphertext
                                                |> Array.toList
                                                |> String.fromList
                                            )
                                      )
                                    , ( "sig", E.string model.sig )
                                    , ( "timestamp", E.int timestamp )
                                    ]
                                )
                        , expect = Http.expectJson GotSubmitResponse D.int
                        }
                        |> Effect.sendCmd
                    )

                _ ->
                    ( model, Effect.none )

        GotSubmitResponse (Ok timeTaken) ->
            ( { model | solved = Solved, timing = Finished timeTaken }, Effect.confetti )

        GotSubmitResponse (Err (Http.BadStatus 417)) ->
            ( { model | solved = Failure }, Effect.none )

        -- TODO handle rest of responses
        GotSubmitResponse _ ->
            ( model, Effect.none )

        TryAnother ->
            init ()


sign : Int -> Int
sign num =
    if num < 0 then
        -1

    else if num > 0 then
        1

    else
        0


removeFromDictLists : Char -> Dict Char (List Char) -> Dict Char (List Char)
removeFromDictLists char =
    Dict.map
        (\_ v ->
            if List.member char v then
                List.filter (\c -> c /= char) v

            else
                v
        )
        >> Dict.filter (\_ v -> not (List.isEmpty v))



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ onKeyDown (D.field "key" D.string) |> Sub.map KeyPress
        ]



-- VIEW


view : Model -> View Msg
view model =
    let
        words =
            model.ciphertext
                |> Array.toIndexedList
                |> List.foldr
                    (\( i, c ) acc ->
                        case acc of
                            ( _, xa ) :: xs ->
                                if c /= ' ' then
                                    ( i, String.fromChar c ++ xa ) :: xs

                                else
                                    ( i, "" ) :: acc

                            [] ->
                                [ ( i, String.fromChar c ) ]
                    )
                    []

        remainingCharacters =
            List.filterMap
                (\c ->
                    if Dict.member c model.reverseTrans then
                        Nothing

                    else
                        Just (c |> Char.toUpper |> String.fromChar)
                )
                letters

        modalBox =
            case model.timing of
                Finished timeTaken ->
                    div [ Attr.class "modal" ]
                        [ div [ Attr.class "modalContent" ]
                            [ h1 [] [ text "Congratulations!" ]
                            , div []
                                [ text "You completed the Aristocrat in "
                                , strong [] [ text (String.fromFloat (toFloat timeTaken / 1000)) ]
                                , text " seconds!"
                                ]
                            , div [ Attr.class "messageContainer" ]
                                [ div [ Attr.class "message" ] [ text ("\"" ++ "you did it! this is placeholder until i figure out how to show the solved message here :)" ++ "\"") ]
                                , div [ Attr.class "attribution" ] [ text ("- " ++ model.attribution) ]
                                ]
                            , button [ Attr.class "button", Events.onClick TryAnother ] [ text "Try another" ]
                            ]
                        ]

                _ ->
                    text ""
    in
    { title = "Aristocrat"
    , body =
        [ div [ Attr.class "aristocrat-content" ]
            [ div [ Attr.classList [ ( "puzzle", True ), ( "solved", model.solved == Solved ) ] ]
                (if Array.isEmpty model.ciphertext then
                    [ text "Loading..." ]

                 else
                    [ h2 [ Attr.class "heading" ] [ text "PUZZLE" ]
                    , div [] (List.map (\( i, word ) -> viewWord model i word) words)
                    , span [ Attr.class "attribution" ] [ text ("- " ++ model.attribution) ]
                    ]
                )
            , div [ Attr.class "controls" ]
                [ h2 [ Attr.class "heading" ] [ text "REMAINING LETTERS" ]
                , div [ Attr.class "remainingLetters" ]
                    (List.map
                        (\c ->
                            span [ Attr.class "remainingLetter" ] [ text c ]
                        )
                        remainingCharacters
                    )
                , button
                    [ Attr.classList
                        [ ( "button", True )
                        , ( "submitButton", True )
                        , ( "shake", model.solved == Failure )
                        ]
                    , Events.onClick SubmitSolution
                    ]
                    [ text "Check" ]
                ]
            ]
        , modalBox
        ]
    }


viewWord : Model -> Int -> String -> Html Msg
viewWord model index word =
    div [ Attr.class "word" ] (List.indexedMap (\i c -> viewCharacter model (index + i) c) (String.toList word))


viewCharacter : Model -> Int -> Char -> Html Msg
viewCharacter model index char =
    let
        notSolved =
            not (model.solved == Solved)

        bigChar =
            Maybe.unwrap
                ' '
                Char.toUpper
                (Dict.get char model.translation)

        frequency =
            Maybe.unwrap ""
                String.fromInt
                (Dict.get char model.letterFrequencies)

        selected =
            model.index == index

        softSelected =
            not selected && Just char == Array.get model.index model.ciphertext

        collision =
            case Dict.get char model.translation of
                Just decoded ->
                    Maybe.unwrap False (\l -> List.length l > 1) (Dict.get decoded model.reverseTrans)

                Nothing ->
                    False
    in
    if Char.isAlpha char then
        div [ Attr.class "char" ]
            [ span
                [ Attr.classList
                    [ ( "translatedChar", True )
                    , ( "selected", selected && notSolved )
                    , ( "softSelected", softSelected && notSolved )
                    , ( "collision", collision )
                    ]
                , Events.onClick (Clicked index)
                ]
                [ text (String.fromChar bigChar) ]
            , span [ Attr.class "untranslatedChar" ] [ text (String.fromChar char) ]
            , span [ Attr.class "frequency" ] [ text frequency ]
            ]

    else
        span [ Attr.class "unimportant" ] [ text (String.fromChar char) ]
