module Api.Puzzle exposing (..)

import Auth.User
import Html exposing (..)
import Html.Attributes as Attr
import Json.Decode as D


type alias SubmitResponse =
    { plaintext : String
    , timeTaken : Int
    , profile : Maybe Auth.User.User
    , expSources : Maybe (List ExpSource)
    , totalExp : Maybe Int
    }


submitResponseDecoder : D.Decoder SubmitResponse
submitResponseDecoder =
    D.map5 SubmitResponse
        (D.field "plaintext" D.string)
        (D.field "timeTaken" D.int)
        (D.maybe (D.field "profile" Auth.User.decoder))
        (D.maybe (D.field "expSources" (D.list expSourceDecoder)))
        (D.maybe (D.field "totalExp" (D.int)))



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

