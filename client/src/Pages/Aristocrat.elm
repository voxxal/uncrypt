module Pages.Aristocrat exposing (Model, Msg, page)

import Api
import Api.Aristocrat
import Api.Http
import Api.Puzzle
import Array exposing (Array)
import Browser.Events exposing (onKeyDown)
import Components.Puzzle exposing (SolveStatus(..), character, modalBox, unimportant)
import Dict exposing (Dict)
import Dict.Extra as Dict
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as D
import Layouts
import Maybe.Extra as Maybe
import Page exposing (Page)
import Route exposing (Route)
import Shared
import Shared.Msg
import View exposing (View)
import Components.Api


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init shared.token
        , update = update shared
        , subscriptions = subscriptions
        , view = view
        }
        |> Page.withLayout (\_ -> Layouts.Navbar { navbar = {} })



-- INIT


type alias Puzzle =
    Api.Aristocrat.Puzzle


type alias SolveStatus =
    Components.Puzzle.SolveStatus


type alias Model =
    { ciphertext : Array Char
    , puzzle : Api.Status Puzzle
    , translation : Dict Char Char
    , reverseTrans : Dict Char (List Char)
    , index : Int
    , letterFrequencies : Dict Char Int
    , solved : SolveStatus
    }


letters : List Char
letters =
    String.toList "abcdefghijklmnopqrstuvwxyz"


init : Maybe String -> () -> ( Model, Effect Msg )
init token _ =
    let
        model =
            { ciphertext = Array.empty
            , puzzle = Api.Loading
            , translation = Dict.empty
            , reverseTrans = Dict.empty
            , index = 0
            , letterFrequencies = Dict.empty
            , solved = NotChecked
            }
    in
    ( model
    , Api.Aristocrat.new token GotPuzzle
    )



-- UPDATE


type Msg
    = GotPuzzle (Result Api.Http.Error Puzzle)
    | KeyPress String
    | Clicked Int
    | SubmitSolution
    | GotSubmitResponse (Result Api.Http.Error Api.Puzzle.SubmitResponse)
    | TryAnother


updateLoading : Msg -> Model -> ( Model, Effect Msg )
updateLoading msg model =
    case msg of
        GotPuzzle (Ok puzzle) ->
            ( { model
                | ciphertext = puzzle.ciphertext |> String.toList |> Array.fromList
                , puzzle = Api.Success puzzle
                , letterFrequencies = Dict.frequencies (puzzle.ciphertext |> String.toList)
              }
            , Effect.none
            )

        GotPuzzle (Err err) ->
            ( { model | puzzle = Api.Failure err }
            , Effect.none
            )

        _ ->
            ( model, Effect.none )


updateSuccess : Shared.Model -> Msg -> Model -> Puzzle -> ( Model, Effect Msg )
updateSuccess shared msg model puzzle =
    case msg of
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
            case model.solved of
                Solved _ ->
                    ( model, Effect.none )

                _ ->
                    case key of
                        "Enter" ->
                            ( model, Effect.sendMsg SubmitSolution )

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

        Clicked index ->
            ( { model | index = index }, Effect.none )

        SubmitSolution ->
            case model.solved of
                Solved _ ->
                    ( model, Effect.none )

                _ ->
                    ( model
                    , Api.Aristocrat.submit shared.token
                        { id = puzzle.id
                        , message =
                            Array.map (\c -> Dict.get c model.translation |> Maybe.withDefault c) model.ciphertext
                                |> Array.toList
                                |> String.fromList
                        , sig = puzzle.sig
                        , timestamp = puzzle.timestamp
                        }
                        GotSubmitResponse
                    )

        GotSubmitResponse (Ok res) ->
            ( { model | solved = Solved res }
            , Effect.batch
                [ Effect.confetti
                , case res.profile of
                    Just profile ->
                        Effect.sendSharedMsg (Shared.Msg.GotProfile (Ok profile))

                    Nothing ->
                        Effect.none
                ]
            )

        GotSubmitResponse (Err (Api.Http.BadStatus _)) ->
            ( { model | solved = Failure }, Effect.none )

        -- TODO handle rest of responses
        GotSubmitResponse _ ->
            ( model, Effect.none )

        TryAnother ->
            init shared.token ()

        _ ->
            ( model, Effect.none )


update : Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update shared msg model =
    case model.puzzle of
        Api.Loading ->
            updateLoading msg model

        Api.Success puzzle ->
            updateSuccess shared msg model puzzle

        Api.Failure _ ->
            ( model, Effect.none )


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


isSolved : SolveStatus -> Bool
isSolved solveStatus =
    case solveStatus of
        Solved _ ->
            True

        _ ->
            False


viewLoading : List (Html Msg)
viewLoading =
    [ div [ Attr.class "aristocrat-content text-content" ] [ text "Loading..." ] ]


viewSuccess : Model -> Puzzle -> List (Html Msg)
viewSuccess model puzzle =
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
    in
    [ div [ Attr.class "aristocrat-content" ]
        [ div [ Attr.classList [ ( "puzzle", True ), ( "solved", isSolved model.solved ) ] ]
            (if Array.isEmpty model.ciphertext then
                [ text "Loading..." ]

             else
                [ h2 [ Attr.class "label" ] [ text "PUZZLE" ]
                , div [] (List.map (\( i, word ) -> viewWord model i word) words)
                , span [ Attr.class "attribution" ] [ text ("- " ++ puzzle.attribution) ]
                ]
            )
        , div [ Attr.class "controls" ]
            [ h2 [ Attr.class "label" ] [ text "REMAINING LETTERS" ]
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
    , case model.solved of
        Solved info ->
            modalBox info puzzle.attribution TryAnother

        _ ->
            text ""
    ]


view : Model -> View Msg
view model =
    { title = "Aristocrat"
    , body =
        case model.puzzle of
            Api.Loading ->
                viewLoading

            Api.Success puzzle ->
                viewSuccess model puzzle

            Api.Failure err ->
                [Components.Api.failure err]
    }


viewWord : Model -> Int -> String -> Html Msg
viewWord model index word =
    div [ Attr.class "word" ]
        (List.indexedMap
            (\i c ->
                let
                    relI =
                        i + index
                in
                if Char.isAlpha c then
                    character
                        { translatedChar = Maybe.unwrap ' ' Char.toUpper (Dict.get c model.translation)
                        , untranslated = String.fromChar c
                        , frequency = Maybe.withDefault 0 (Dict.get c model.letterFrequencies)
                        , selected = model.index == relI
                        , softSelected = Just c == Array.get model.index model.ciphertext
                        , collision =
                            case Dict.get c model.translation of
                                Just decoded ->
                                    Maybe.unwrap False
                                        (\l -> List.length l > 1)
                                        (Dict.get decoded model.reverseTrans)

                                Nothing ->
                                    False
                        , onClick = Clicked relI
                        }

                else
                    unimportant (String.fromChar c)
            )
            (String.toList word)
        )
