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
import Layout exposing (Layout)
import Maybe.Extra as Maybe
import Page exposing (Page)
import Random
import Random.List
import Route exposing (Route)
import Set
import Shared
import Task
import Time
import View exposing (View)



-- TODO letter is a better word than character.


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


type SolveStatus
    = NotChecked
    | Failure
    | Solved


type Timing
    = NotStarted
    | Started Int
    | Finished Int Int


type alias Model =
    { message : String
    , translation : Dict Char Char
    , reverseTrans : Dict Char (List Char)
    , index : Int
    , scrambledCharacters : Dict Char Char
    , scrambledMessage : Array Char
    , letterFrequencies : Dict Char Int
    , attribution : String
    , solved : SolveStatus
    , timing : Timing
    }


letters : List Char
letters =
    String.toList "abcdefghijklmnopqrstuvwxyz"


scrambleCharacters : Random.Generator (List Char)
scrambleCharacters =
    Random.List.shuffle letters


init : () -> ( Model, Effect Msg )
init _ =
    let
        model =
            { message = ""
            , translation = Dict.empty
            , reverseTrans = Dict.empty
            , index = 0
            , scrambledCharacters = Dict.empty
            , scrambledMessage = Array.empty
            , letterFrequencies = Dict.empty
            , attribution = "Unknown"
            , solved = NotChecked
            , timing = NotStarted
            }
    in
    ( model
    , Http.get
        { url = "/api"
        , expect = Http.expectJson GotMessage messageDecoder
        }
        |> Effect.fromCmd
    )



-- UPDATE


type alias Message =
    { message : String, attribution : Maybe String }


messageDecoder : D.Decoder Message
messageDecoder =
    D.map2 Message (D.field "message" D.string) (D.field "attribution" (D.maybe D.string))


type Msg
    = GotMessage (Result Http.Error Message)
    | GotStartTime Time.Posix
    | GotEndTime Time.Posix
    | GotScrambledCharacters (List Char)
    | KeyPress String
    | Clicked Int
    | Check


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        GotStartTime time ->
            ( { model | timing = Started (Time.posixToMillis time) }, Effect.none )

        GotMessage (Ok message) ->
            ( { model | message = message.message, attribution = Maybe.withDefault "Unknown" message.attribution }
            , Random.generate GotScrambledCharacters scrambleCharacters |> Effect.fromCmd
            )

        GotMessage (Err _) ->
            ( { model | message = "Something went wrong when fetching the message. But you can solve this instead" }
            , Random.generate GotScrambledCharacters scrambleCharacters |> Effect.fromCmd
            )

        GotScrambledCharacters scrambled ->
            let
                characters =
                    model.message
                        |> String.toLower
                        |> String.filter Char.isAlpha
                        |> String.toList
                        |> Set.fromList
                        |> Set.toList

                scrambledCharacters =
                    List.map2 Tuple.pair characters scrambled |> Dict.fromList

                scrambledMessage =
                    String.map
                        (\c ->
                            if Char.isAlpha c then
                                Maybe.withDefault '�' (Dict.get (Char.toLower c) scrambledCharacters)

                            else
                                c
                        )
                        model.message
                        |> String.toList

                letterFrequencies =
                    Dict.frequencies scrambledMessage
            in
            ( { model
                | scrambledCharacters = scrambledCharacters
                , scrambledMessage = scrambledMessage |> Array.fromList
                , letterFrequencies = letterFrequencies
              }
            , Effect.none
            )

        KeyPress key ->
            let
                sign : Int -> Int
                sign num =
                    if num < 0 then
                        -1

                    else if num > 0 then
                        1

                    else
                        0

                shift : Int -> Int
                shift num =
                    case Array.get (model.index + num) model.scrambledMessage of
                        Just char ->
                            if Char.isAlpha char then
                                num

                            else
                                shift (num + sign num)

                        Nothing ->
                            0

                -- Dict and shift happens at the same time.
                shiftOverAnswered : Dict Char Char -> Int -> Int
                shiftOverAnswered newTranslation num =
                    case Array.get (model.index + num) model.scrambledMessage of
                        Just char ->
                            if Char.isAlpha char then
                                Maybe.unwrap num
                                    (\_ -> shiftOverAnswered newTranslation (num + sign num))
                                    (Dict.get char newTranslation)

                            else
                                shiftOverAnswered newTranslation (num + sign num)

                        Nothing ->
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
            in
            if model.solved /= Solved then
                case key of
                    "Backspace" ->
                        case Array.get model.index model.scrambledMessage of
                            Just char ->
                                ( { model
                                    | index = model.index + shift -1
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
                                    case Array.get model.index model.scrambledMessage of
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
                                            , case model.timing of
                                                NotStarted ->
                                                    Task.perform GotStartTime Time.now |> Effect.fromCmd

                                                _ ->
                                                    Effect.none
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

        Check ->
            let
                solved =
                    Dict.invert model.translation == model.scrambledCharacters
            in
            if model.solved /= Solved && solved then
                ( { model | solved = Solved }
                , Effect.batch
                    [ Effect.confetti
                    , Task.perform GotEndTime Time.now |> Effect.fromCmd
                    ]
                )

            else if model.solved == Solved then
                ( model, Effect.none )

            else
                ( { model | solved = Failure }, Effect.none )

        GotEndTime time ->
            case model.timing of
                Started startTime ->
                    ( { model | timing = Finished startTime (Time.posixToMillis time - startTime) }, Effect.none )

                _ ->
                    ( model, Effect.none )



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
            model.scrambledMessage
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
    { title = "Aristocrat"
    , body =
        [ div [ Attr.class "content" ]
            [ div [ Attr.classList [ ( "puzzle", True ), ( "solved", model.solved == Solved ) ] ]
                (if Array.isEmpty model.scrambledMessage then
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
                        [ ( "check", True )
                        , ( "shake", model.solved == Failure )
                        ]
                    , Events.onClick Check
                    ]
                    [ text "Check" ]
                ]
            ]
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
            not selected && Just char == Array.get model.index model.scrambledMessage

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
