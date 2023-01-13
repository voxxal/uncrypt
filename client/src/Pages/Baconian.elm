module Pages.Baconian exposing (Model, Msg, page)

import Api
import Api.Baconian
import Api.Http
import Api.Puzzle
import Array exposing (Array)
import Browser.Events exposing (onKeyDown)
import Components.Puzzle exposing (SolveStatus(..), character, unimportant)
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
import Shared.Msg
import View exposing (View)


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
    Api.Baconian.Puzzle


type alias SolveStatus =
    Components.Puzzle.SolveStatus


type alias Model =
    { ciphertext : Array String
    , puzzle : Api.Status Puzzle
    , translation : Array (Maybe Char)
    , categories : ( List Char, List Char )
    , index : Int
    , letterFrequencies : Dict String Int
    , solved : SolveStatus
    , focused : Bool
    }


init : Maybe String -> () -> ( Model, Effect Msg )
init token _ =
    let
        model =
            { ciphertext = Array.empty
            , puzzle = Api.Loading
            , translation = Array.empty
            , categories = ( [], [] )
            , index = 0
            , letterFrequencies = Dict.empty
            , solved = NotChecked
            , focused = False
            }
    in
    ( model
    , Api.Baconian.new token GotPuzzle
    )



-- UPDATE


type Msg
    = GotPuzzle (Result Api.Http.Error Puzzle)
    | KeyPress String
    | UpdateCategory Bool String
    | Focus
    | Blur
    | Clicked Int
    | SubmitSolution
    | GotSubmitResponse (Result Api.Http.Error Api.Puzzle.SubmitResponse)
    | TryAnother


updateLoading : Msg -> Model -> ( Model, Effect Msg )
updateLoading msg model =
    case msg of
        GotPuzzle (Ok puzzle) ->
            ( { model
                | ciphertext = puzzle.ciphertext
                , translation = Array.repeat (Array.length puzzle.ciphertext) Nothing
                , puzzle = Api.Success puzzle
                , letterFrequencies = Dict.frequencies (puzzle.ciphertext |> Array.toList)
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
                        Just _ ->
                            num

                        Nothing ->
                            0

                -- Dict and shift happens at the same time. This function takes in the dict to go over already answered letters
                shiftOverAnswered : Array (Maybe Char) -> Int -> Int
                shiftOverAnswered newTranslation num =
                    case Array.get (model.index + num) newTranslation of
                        Just c ->
                            Maybe.unwrap num
                                (\_ -> shiftOverAnswered newTranslation (num + sign num))
                                c

                        Nothing ->
                            0
            in
            case model.solved of
                Solved _ ->
                    ( model, Effect.none )

                _ ->
                    if not model.focused then
                        case key of
                            "Enter" ->
                                ( model, Effect.sendMsg SubmitSolution )

                            "Backspace" ->
                                case Array.get model.index model.ciphertext of
                                    Just _ ->
                                        ( { model
                                            | index = model.index + shift 1
                                            , translation = Array.set model.index Nothing model.translation
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

                                            newTranslation =
                                                Array.set model.index (Just letter) model.translation
                                        in
                                        if Char.isAlpha pressedKey then
                                            ( { model
                                                | index = model.index + shiftOverAnswered newTranslation 1
                                                , translation = newTranslation
                                                , solved = NotChecked
                                              }
                                            , Effect.none
                                            )

                                        else
                                            ( model, Effect.none )

                                    _ ->
                                        ( model, Effect.none )

                    else
                        ( model, Effect.none )

        Clicked index ->
            ( { model | index = index }, Effect.none )

        SubmitSolution ->
            case model.solved of
                Solved _ ->
                    ( model, Effect.none )

                _ ->
                    ( model
                    , Api.Baconian.submit shared.token
                        { id = puzzle.id
                        , message =
                            Array.map (\c -> Maybe.withDefault ' ' c) model.translation
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

        UpdateCategory which input ->
            let
                newCategories =
                    if which then
                        Tuple.mapSecond (\_ -> input |> String.toList) model.categories

                    else
                        Tuple.mapFirst (\_ -> input |> String.toList) model.categories

                frequencies =
                    Dict.frequencies
                        (model.ciphertext
                            |> Array.toList
                            |> List.map (replaceWithCategories newCategories)
                        )
            in
            ( { model | categories = newCategories, letterFrequencies = frequencies }, Effect.none )

        Focus ->
            ( { model | focused = True }, Effect.none )

        Blur ->
            ( { model | focused = False }, Effect.none )

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
    [ div [ Attr.class "baconian-content text-content" ] [ text "Loading..." ] ]


viewSuccess : Model -> Puzzle -> List (Html Msg)
viewSuccess model puzzle =
    [ div [ Attr.class "baconian-content" ]
        [ div [ Attr.classList [ ( "puzzle", True ), ( "solved", isSolved model.solved ) ] ]
            (if Array.isEmpty model.ciphertext then
                [ text "Loading..." ]

             else
                [ h2 [ Attr.class "label" ] [ text "PUZZLE" ]
                , div [] (List.indexedMap (\i word -> viewWord model i word) (model.ciphertext |> Array.toList))
                , span [ Attr.class "attribution" ] [ text ("- " ++ puzzle.attribution) ]
                ]
            )
        , div [ Attr.class "controls" ]
            [ h2 [ Attr.class "label" ] [ text "CATEGORIES" ]
            , div [ Attr.class "remainingLetters" ]
                [ textarea
                    [ Attr.class "input"
                    , Events.onInput (UpdateCategory False)
                    , Events.onFocus Focus
                    , Events.onBlur Blur
                    , Attr.value (Tuple.first model.categories |> String.fromList)
                    ]
                    []
                , textarea
                    [ Attr.class "input"
                    , Events.onInput (UpdateCategory True)
                    , Events.onFocus Focus
                    , Events.onBlur Blur
                    , Attr.value (Tuple.second model.categories |> String.fromList)
                    ]
                    []
                ]
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
    , viewModalBox model puzzle
    ]


viewFailure : Api.Http.Error -> List (Html Msg)
viewFailure err =
    let
        errMsg =
            case err of
                Api.Http.BadUrl url ->
                    "Url " ++ url ++ " is bad"

                Api.Http.Timeout ->
                    "Timed Out"

                Api.Http.NetworkError ->
                    "Disconnected from the internet"

                Api.Http.BadStatus { status, message } ->
                    String.fromInt status ++ " " ++ message

                Api.Http.BadBody message ->
                    "Bad Body: " ++ message
    in
    [ div [ Attr.class "baconian-content text-content" ] [ text "Something went wrong...", br [] [], text errMsg ] ]


view : Model -> View Msg
view model =
    { title = "Baconian"
    , body =
        case model.puzzle of
            Api.Loading ->
                viewLoading

            Api.Success puzzle ->
                viewSuccess model puzzle

            Api.Failure err ->
                viewFailure err
    }


viewModalBox : Model -> Puzzle -> Html Msg
viewModalBox model puzzle =
    case model.solved of
        Solved info ->
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
                        , div [ Attr.class "attribution" ] [ text ("- " ++ puzzle.attribution) ]
                        ]
                    , case info.expSources of
                        Just expSources ->
                            div [ Attr.class "expSources" ] (List.map Api.Puzzle.viewExpSource expSources)

                        Nothing ->
                            text ""

                    -- TODO we probably want a total exp gained
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
                    , button [ Attr.class "button submitButton", Events.onClick TryAnother ] [ text "Try another" ]
                    ]
                ]

        _ ->
            text ""


viewWord : Model -> Int -> String -> Html Msg
viewWord model index word =
    let replaceWithModelC = replaceWithCategories model.categories in
    div [ Attr.class "word" ]
        [ character
            { translatedChar = Maybe.unwrap ' ' Char.toUpper (Maybe.join (Array.get index model.translation))
            , untranslated = replaceWithModelC word
            , frequency = Maybe.withDefault 0 (Dict.get (replaceWithModelC word) model.letterFrequencies)
            , selected = model.index == index
            , softSelected = Just (replaceWithModelC word) == Maybe.map replaceWithModelC (Array.get model.index model.ciphertext)
            , collision = False
            , onClick = Clicked index
            }
        ]


replaceWithCategories : ( List Char, List Char ) -> String -> String
replaceWithCategories ( fst, snd ) =
    String.map
        (\c ->
            if List.member c fst then
                'A'

            else if List.member c snd then
                'B'

            else
                c
        )