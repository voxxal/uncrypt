module Pages.Login exposing (Model, Msg, page)

import Components.Input exposing (passwordInput, textInput)
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Http
import Json.Decode as D
import Json.Encode as E
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Shared
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }
        |> Page.withLayout (\_ -> Layouts.Navbar { navbar = {} })



-- INIT


type alias Model =
    { username : String
    , password : String
    , isSubmitting : Bool
    , badLogin : Bool
    }


init : () -> ( Model, Effect Msg )
init () =
    ( { username = ""
      , password = ""
      , isSubmitting = False
      , badLogin = False
      }
    , Effect.none
    )



-- UPDATE


type alias AuthorizedResponse =
    { token : String }


type Msg
    = ExampleMsgReplaceMe
    | UpdateUsername String
    | UpdatePassword String
    | Submit
    | GotResponse (Result Http.Error AuthorizedResponse)


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        ExampleMsgReplaceMe ->
            ( model
            , Effect.none
            )

        UpdateUsername username ->
            ( { model | username = username }, Effect.none )

        UpdatePassword password ->
            ( { model | password = password }, Effect.none )

        Submit ->
            ( { model | isSubmitting = True }
            , Http.post
                { url = "/api/auth/login"
                , body =
                    Http.jsonBody
                        (E.object
                            [ ( "username", E.string model.username )
                            , ( "password", E.string model.password )
                            ]
                        )
                , expect = Http.expectJson GotResponse (D.map AuthorizedResponse (D.field "token" D.string))
                }
                |> Effect.sendCmd
            )

        GotResponse (Ok { token }) ->
            ( { model | isSubmitting = False }
            , Effect.login token
            )

        GotResponse (Err (Http.BadStatus 401)) ->
            ( { model | isSubmitting = False, badLogin = True }, Effect.none )

        GotResponse _ ->
            ( { model | isSubmitting = False }, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Login"
    , body =
        [ div [ Attr.class "auth-content" ]
            [ textInput
                { id = "login-username"
                , name = "Username"
                , placeholder = Nothing
                , value = model.username
                , onInput = UpdateUsername
                }
            , br [] []
            , passwordInput
                { id = "login-password"
                , name = "Password"
                , placeholder = Nothing
                , value = model.password
                , onInput = UpdatePassword
                }
            , br [] []

            -- this works but i should probably not reuse `login` styles
            , button [ Attr.class "button login", Events.onClick Submit ]
                [ if model.isSubmitting then
                    text "Loading..."

                  else
                    text "Login"
                ]
            ]
        ]
    }
