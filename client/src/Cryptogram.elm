module Cryptogram exposing (..)

import Dict exposing (Dict)


type alias Cryptogram =
    { message : String
    , substitution : Dict Char Char
    }


