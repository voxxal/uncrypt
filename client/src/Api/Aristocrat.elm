module Api.Aristocrat exposing (Puzzle, SubmitResponse, new, submit)

import Api.Http
import Effect exposing (Effect)
import Http
import Json.Decode as D
import Json.Encode as E


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


new : (Result Api.Http.Error Puzzle -> msg) -> Effect msg
new toMsg =
    Http.get
        { url = "/api/aristocrat/new"
        , expect = Api.Http.expectJson toMsg puzzleDecoder
        }
        |> Effect.sendCmd


type alias SubmitResponse =
    { plaintext : String
    , timeTaken : Int
    }


submitResponseDecoder : D.Decoder SubmitResponse
submitResponseDecoder =
    D.map2 SubmitResponse
        (D.field "plaintext" D.string)
        (D.field "timeTaken" D.int)


submit :
    { id : Int
    , message : String
    , sig : String
    , timestamp : Int
    }
    -> (Result Api.Http.Error SubmitResponse -> msg)
    -> Effect msg
submit { id, message, sig, timestamp } toMsg =
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
