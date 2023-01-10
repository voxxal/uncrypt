module Api.Auth exposing (..)

import Api.Http
import Auth.User
import Effect exposing (Effect)
import Http
import Json.Decode as D
import Json.Encode as E
import Jwt.Http


type alias AuthorizedResponse =
    { token : String }


authorizedResponseDecoder : D.Decoder AuthorizedResponse
authorizedResponseDecoder =
    D.map AuthorizedResponse (D.field "token" D.string)


login :
    { username : String, password : String }
    -> (Result Api.Http.Error AuthorizedResponse -> msg)
    -> Effect msg
login { username, password } toMsg =
    Http.post
        { url = "/api/auth/login"
        , body =
            Http.jsonBody
                (E.object
                    [ ( "username", E.string username )
                    , ( "password", E.string password )
                    ]
                )
        , expect = Api.Http.expectJson toMsg authorizedResponseDecoder
        }
        |> Effect.sendCmd


register :
    { username : String, password : String, email : String }
    -> (Result Api.Http.Error AuthorizedResponse -> msg)
    -> Effect msg
register { username, password, email } toMsg =
    Http.post
        { url = "/api/auth/register"
        , body =
            Http.jsonBody
                (E.object
                    [ ( "username", E.string username )
                    , ( "password", E.string password )
                    , ( "email"
                      , if String.isEmpty email then
                            E.null

                        else
                            E.string email
                      )
                    ]
                )
        , expect = Api.Http.expectJson toMsg authorizedResponseDecoder
        }
        |> Effect.sendCmd


profile : String -> (Result Api.Http.Error Auth.User.User -> msg) -> Effect msg
profile token toMsg =
    Jwt.Http.get token
        { url = "/api/profile"
        , expect = Api.Http.expectJson toMsg Auth.User.decoder
        }
        |> Effect.sendCmd
