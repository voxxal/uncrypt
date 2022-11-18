module Main exposing (main)

import Array exposing (Array)
import Browser
import Browser.Events exposing (onKeyDown)
import Dict exposing (Dict)
import Dict.Extra
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Http
import Json.Decode as D
import Maybe.Extra
import Random
import Random.List
import Set



-- MAIN


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Model =
    { message : String
    , translation : Dict Char Char
    , index : Int
    , scrambledCharacters : Dict Char Char
    , scrambledMessage : Array Char
    , letterFrequencies : Dict Char Int
    , attribution : String
    }


letters : List Char
letters =
    String.toList "abcdefghijklmnopqrstuvwxyz"


scrambleCharacters : Random.Generator (List Char)
scrambleCharacters =
    Random.List.shuffle letters


init : () -> ( Model, Cmd Msg )
init _ =
    let
        model =
            { message = ""
            , translation = Dict.empty
            , index = 0
            , scrambledCharacters = Dict.empty
            , scrambledMessage = Array.empty
            , letterFrequencies = Dict.empty
            , attribution = ""
            }
    in
    ( model
    , Http.get { url = "/api", expect = Http.expectJson GotMessage messageDecoder }
    )



-- UPDATE


type alias Message =
    { message : String, attribution : String }


messageDecoder : D.Decoder Message
messageDecoder =
    D.map2 Message (D.field "message" D.string) (D.field "attribution" D.string)


type Msg
    = GotMessage (Result Http.Error Message)
    | GotScrambledCharacters (List Char)
    | KeyPress String
    | Clicked Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotMessage (Ok message) ->
            ( { model | message = message.message, attribution = message.attribution }
            , Random.generate GotScrambledCharacters scrambleCharacters
            )

        GotMessage (Err _) ->
            ( { model | message = "Something went wrong when fetching the message. But you can solve this instead" }
            , Random.generate GotScrambledCharacters scrambleCharacters
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
                    Dict.Extra.frequencies scrambledMessage
            in
            ( { model
                | scrambledCharacters = scrambledCharacters
                , scrambledMessage = scrambledMessage |> Array.fromList
                , letterFrequencies = letterFrequencies
              }
            , Cmd.none
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
                                Maybe.Extra.unwrap num
                                    (\_ -> shiftOverAnswered newTranslation (num + sign num))
                                    (Dict.get char newTranslation)

                            else
                                shiftOverAnswered newTranslation (num + sign num)

                        Nothing ->
                            0
            in
            case key of
                "Backspace" ->
                    case Array.get model.index model.scrambledMessage of
                        Just char ->
                            ( { model | translation = Dict.remove char model.translation, index = model.index + shift -1 }, Cmd.none )

                        Nothing ->
                            ( model, Cmd.none )

                "ArrowLeft" ->
                    ( { model | index = model.index + shift -1 }, Cmd.none )

                "ArrowRight" ->
                    ( { model | index = model.index + shift 1 }, Cmd.none )

                any ->
                    case String.uncons any of
                        Just ( pressedKey, "" ) ->
                            if Char.isAlpha pressedKey then
                                case Array.get model.index model.scrambledMessage of
                                    Just char ->
                                        let
                                            newTranslation =
                                                Dict.insert char pressedKey model.translation
                                        in
                                        ( { model
                                            | index = model.index + shiftOverAnswered newTranslation 1
                                            , translation = newTranslation
                                          }
                                        , Cmd.none
                                        )

                                    _ ->
                                        ( model, Cmd.none )

                            else
                                ( model, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

        Clicked index ->
            ( { model | index = index }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    onKeyDown (D.field "key" D.string) |> Sub.map KeyPress



-- VIEW
-- TODO group by words


view : Model -> Browser.Document Msg
view model =
    { title = "Crypto Puzzles"
    , body =
        (model.scrambledMessage
            |> Array.indexedMap (viewCharacter model)
            |> Array.toList
        )
            ++ [ text ("- " ++ model.attribution) ]
    }


viewCharacter : Model -> Int -> Char -> Html Msg
viewCharacter model index char =
    let
        bigChar =
            Maybe.Extra.unwrap
                char
                Char.toUpper
                (Dict.get char model.translation)

        smallChar =
            if bigChar /= char then
                String.fromChar char

            else
                ""

        frequency =
            Maybe.Extra.unwrap ""
                String.fromInt
                (Dict.get char model.letterFrequencies)

        selected =
            model.index == index

        softSelected =
            not selected && Just char == Array.get model.index model.scrambledMessage
    in
    if Char.isAlpha char then
        div [ Attr.class "char" ]
            [ span
                [ Attr.classList
                    [ ( "selected", selected )
                    , ( "softSelected", softSelected )
                    ]
                , Events.onClick (Clicked index)
                ]
                [ text (String.fromChar bigChar) ]
            , div [ Attr.class "charExtraInfo" ]
                [ span [ Attr.class "untranslatedChar" ] [ text smallChar ]
                , span [ Attr.class "frequency" ] [ text frequency ]
                ]
            ]

    else
        span [ Attr.class "unimportant" ] [ text (String.fromChar bigChar) ]
