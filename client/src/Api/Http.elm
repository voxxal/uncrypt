module Api.Http exposing (..)

import Http
import Json.Decode as D


type alias ResponseStatusError =
    { status : Int, message : String }


responseStatusErrorDecoder : D.Decoder ResponseStatusError
responseStatusErrorDecoder =
    D.map2 ResponseStatusError (D.field "status" D.int) (D.field "message" D.string)


type Error
    = BadUrl String
    | Timeout
    | NetworkError
    | BadStatus ResponseStatusError
    | BadBody String


expectJson : (Result Error a -> msg) -> D.Decoder a -> Http.Expect msg
expectJson toMsg decoder =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.BadUrl_ url ->
                    Err (BadUrl url)

                Http.Timeout_ ->
                    Err Timeout

                Http.NetworkError_ ->
                    Err NetworkError

                Http.BadStatus_ _ body ->
                    case D.decodeString responseStatusErrorDecoder body of
                        Ok value ->
                            Err (BadStatus value)

                        Err err ->
                            Err (BadBody (D.errorToString err))

                Http.GoodStatus_ _ body ->
                    case D.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (BadBody (D.errorToString err))
