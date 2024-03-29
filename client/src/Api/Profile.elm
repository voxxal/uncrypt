module Api.Profile exposing (Solve, Solves, myProfile, mySolves, profile, solves)

import Api.Http
import Auth.User
import Effect exposing (Effect)
import Http
import Json.Decode as D
import Jwt.Http


type alias Solve =
    { puzzleType : String
    , plaintext : String
    , attribution : String
    , solvedAt : String
    , solver : String
    , timeTaken : Int
    , expGained : Int
    }


type alias Solves =
    List Solve


solveDecoder : D.Decoder Solve
solveDecoder =
    D.map7 Solve
        (D.field "puzzleType" D.string)
        (D.field "plaintext" D.string)
        (D.field "attribution" D.string)
        (D.field "solvedAt" D.string)
        (D.field "solver" D.string)
        (D.field "timeTaken" D.int)
        (D.field "expGained" D.int)


myProfile : String -> (Result Api.Http.Error Auth.User.User -> msg) -> Effect msg
myProfile token toMsg =
    Jwt.Http.get token
        { url = "/api/profile"
        , expect = Api.Http.expectJson toMsg Auth.User.decoder
        }
        |> Effect.sendCmd


profile : String -> (Result Api.Http.Error Auth.User.User -> msg) -> Effect msg
profile username toMsg =
    Http.get
        { url = "/api/profile/" ++ username
        , expect = Api.Http.expectJson toMsg Auth.User.decoder
        }
        |> Effect.sendCmd


mySolves : String -> (Result Api.Http.Error Solves -> msg) -> Effect msg
mySolves token toMsg =
    Jwt.Http.get token
        { url = "/api/solves"
        , expect = Api.Http.expectJson toMsg (D.list solveDecoder)
        }
        |> Effect.sendCmd


solves : String -> (Result Api.Http.Error Solves -> msg) -> Effect msg
solves username toMsg =
    Http.get
        { url = "/api/solves/" ++ username
        , expect = Api.Http.expectJson toMsg (D.list solveDecoder)
        }
        |> Effect.sendCmd
