module Api exposing (..)

import Api.Http

type Status value
    = Loading
    | Success value
    | Failure Api.Http.Error