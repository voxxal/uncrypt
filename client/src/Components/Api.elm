module Components.Api exposing (..)

import Api.Http
import Html exposing (..)
import Html.Attributes as Attr


failure : Api.Http.Error -> List (Html msg)
failure err =
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
    [ h2 [] [ text "Something went wrong..." ], text errMsg ]
