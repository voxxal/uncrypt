module Api.Baconian exposing (..)

import Api.Http
import Api.Puzzle
import Array exposing (Array)
import Effect exposing (Effect)
import Http
import Json.Decode as D
import Json.Encode as E
import Jwt.Http


type alias Puzzle =
    { id : Int
    , ciphertext : Array String
    , sig : String
    , timestamp : Int
    , attribution : String
    }


puzzleDecoder : D.Decoder Puzzle
puzzleDecoder =
    D.map5 Puzzle
        (D.field "id" D.int)
        (D.field "ciphertext" (D.array D.string))
        (D.field "sig" D.string)
        (D.field "timestamp" D.int)
        (D.field "attribution" D.string)


new : Maybe String -> (Result Api.Http.Error Puzzle -> msg) -> Effect msg
new maybeToken toMsg =
    case maybeToken of
        Just token ->
            Jwt.Http.get token
                { url = "/api/baconian/new"
                , expect = Api.Http.expectJson toMsg puzzleDecoder
                }
                |> Effect.sendCmd

        Nothing ->
            Http.get
                { url = "/api/baconian/new"
                , expect = Api.Http.expectJson toMsg puzzleDecoder
                }
                |> Effect.sendCmd


submit :
    Maybe String
    ->
        { id : Int
        , message : String
        , sig : String
        , timestamp : Int
        }
    -> (Result Api.Http.Error Api.Puzzle.SubmitResponse -> msg)
    -> Effect msg
submit maybeToken { id, message, sig, timestamp } toMsg =
    case maybeToken of
        Just token ->
            Jwt.Http.post token
                { url = "/api/baconian/submit"
                , body =
                    Http.jsonBody
                        (E.object
                            [ ( "id", E.int id )
                            , ( "message", E.string message )
                            , ( "sig", E.string sig )
                            , ( "timestamp", E.int timestamp )
                            ]
                        )
                , expect = Api.Http.expectJson toMsg Api.Puzzle.submitResponseDecoder
                }
                |> Effect.sendCmd

        Nothing ->
            Http.post
                { url = "/api/baconian/submit"
                , body =
                    Http.jsonBody
                        (E.object
                            [ ( "id", E.int id )
                            , ( "message", E.string message )
                            , ( "sig", E.string sig )
                            , ( "timestamp", E.int timestamp )
                            ]
                        )
                , expect = Api.Http.expectJson toMsg Api.Puzzle.submitResponseDecoder
                }
                |> Effect.sendCmd
