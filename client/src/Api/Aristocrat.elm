module Api.Aristocrat exposing (Puzzle, SubmitResponse, ExpSource, new, submit)

import Api.Http
import Auth.User
import Effect exposing (Effect)
import Http
import Json.Decode as D
import Json.Encode as E
import Jwt.Http


type alias Puzzle =
    { id : Int
    , ciphertext : String
    , sig : String
    , timestamp : Int
    , attribution : String
    }


puzzleDecoder : D.Decoder Puzzle
puzzleDecoder =
    D.map5 Puzzle
        (D.field "id" D.int)
        (D.field "ciphertext" D.string)
        (D.field "sig" D.string)
        (D.field "timestamp" D.int)
        (D.field "attribution" D.string)


new : Maybe String -> (Result Api.Http.Error Puzzle -> msg) -> Effect msg
new maybeToken toMsg =
    case maybeToken of
        Just token ->
            Jwt.Http.get token
                { url = "/api/aristocrat/new"
                , expect = Api.Http.expectJson toMsg puzzleDecoder
                }
                |> Effect.sendCmd

        Nothing ->
            Http.get
                { url = "/api/aristocrat/new"
                , expect = Api.Http.expectJson toMsg puzzleDecoder
                }
                |> Effect.sendCmd


type alias ExpSource =
    { name : String
    , amount : String
    , special : Bool
    }


expSourceDecoder : D.Decoder ExpSource
expSourceDecoder =
    D.map3 ExpSource
        (D.field "name" D.string)
        (D.field "amount" D.string)
        (D.field "special" D.bool)


type alias SubmitResponse =
    { plaintext : String
    , timeTaken : Int
    , profile : Maybe Auth.User.User
    , expSources : Maybe (List ExpSource)
    }


submitResponseDecoder : D.Decoder SubmitResponse
submitResponseDecoder =
    D.map4 SubmitResponse
        (D.field "plaintext" D.string)
        (D.field "timeTaken" D.int)
        (D.maybe (D.field "profile" Auth.User.decoder))
        (D.maybe (D.field "expSources" (D.list expSourceDecoder)))


submit :
    Maybe String
    ->
        { id : Int
        , message : String
        , sig : String
        , timestamp : Int
        }
    -> (Result Api.Http.Error SubmitResponse -> msg)
    -> Effect msg
submit maybeToken { id, message, sig, timestamp } toMsg =
    case maybeToken of
        Just token ->
            Jwt.Http.post token
                { url = "/api/aristocrat/submit"
                , body =
                    Http.jsonBody
                        (E.object
                            [ ( "id", E.int id )
                            , ( "message", E.string message )
                            , ( "sig", E.string sig )
                            , ( "timestamp", E.int timestamp )
                            ]
                        )
                , expect = Api.Http.expectJson toMsg submitResponseDecoder
                }
                |> Effect.sendCmd

        Nothing ->
            Http.post
                { url = "/api/aristocrat/submit"
                , body =
                    Http.jsonBody
                        (E.object
                            [ ( "id", E.int id )
                            , ( "message", E.string message )
                            , ( "sig", E.string sig )
                            , ( "timestamp", E.int timestamp )
                            ]
                        )
                , expect = Api.Http.expectJson toMsg submitResponseDecoder
                }
                |> Effect.sendCmd
