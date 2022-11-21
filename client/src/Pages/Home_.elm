module Pages.Home_ exposing (Model, Msg, page)

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
import Maybe.Extra as Maybe
import Page exposing (Page)
import Random
import Random.List
import Route exposing (Route)
import Set
import Shared
import Time
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- INIT


type alias Model =
    { message : String
    , translation : Dict Char Char
    , reverseTrans : Dict Char (List Char)
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
            , attribution = ""
            }
    in
    ( model
    , Http.get { url = "/api", expect = Http.expectJson GotMessage messageDecoder } |> Effect.fromCmd
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


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        GotMessage (Ok message) ->
            ( { model | message = message.message, attribution = message.attribution }
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
                        (\k v ->
                            if List.member char v then
                                List.filter (\c -> c /= char) v

                            else
                                v
                        )
            in
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
                            if Char.isAlpha pressedKey then
                                case Array.get model.index model.scrambledMessage of
                                    Just char ->
                                        let
                                            maybeOldChar =
                                                Dict.get char model.translation

                                            newTranslation =
                                                Dict.insert char pressedKey model.translation
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
                                                        pressedKey
                                                        [ char ]
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
    in
    { title = "Crypto Puzzles"
    , body =
        List.map (\( i, word ) -> viewWord model i word) words
            ++ [ text ("- " ++ model.attribution) ]
    }


viewWord : Model -> Int -> String -> Html Msg
viewWord model index word =
    div [ Attr.class "word" ] (List.indexedMap (\i c -> viewCharacter model (index + i) c) (String.toList word))


viewCharacter : Model -> Int -> Char -> Html Msg
viewCharacter model index char =
    let
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
                    [ ( "selected", selected )
                    , ( "softSelected", softSelected )
                    , ( "translatedChar", True )
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
