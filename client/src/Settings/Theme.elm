port module Settings.Theme exposing
    ( Theme(..)
    , decoder
    , encoder
    , fromString
    , toString
    , updateTheme
    )

import Json.Decode as D
import Json.Encode as E


port updateTheme : E.Value -> Cmd msg


type Theme
    = Auto
    | Light
    | Dark


fromString : String -> Theme
fromString str =
    case str of
        "auto" ->
            Auto

        "light" ->
            Light

        "dark" ->
            Dark

        _ ->
            Auto


toString : Theme -> String
toString theme =
    case theme of
        Auto ->
            "auto"

        Light ->
            "light"

        Dark ->
            "dark"


decoder : D.Decoder Theme
decoder =
    D.map fromString D.string


encoder : Theme -> E.Value
encoder theme =
    E.string (toString theme)
