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
    }


submitResponseDecoder : D.Decoder SubmitResponse
submitResponseDecoder =
    D.map4 SubmitResponse
        (D.field "plaintext" D.string)
        (D.field "timeTaken" D.int)
        (D.maybe (D.field "profile" Auth.User.decoder))
        (D.maybe (D.field "expSources" (D.list expSourceDecoder)))


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


viewExpSource : ExpSource -> Html msg
viewExpSource source =
    div [ Attr.classList [ ( "expSource", True ), ( "special", source.special ) ] ]
        [ span [ Attr.class "expSourceName" ] [ text source.name ]
        , span [ Attr.class "expSourceAmount" ] [ text source.amount ]
        ]
