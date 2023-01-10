module Pages.Register exposing (Model, Msg, page)

import Api.Auth exposing (AuthorizedResponse)
import Api.Http
import Components.Input exposing (textInput, passwordInput)
import Effect exposing (Effect)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
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
    , email : String
    , isSubmitting : Bool
    , badRegister : String
    }


init : () -> ( Model, Effect Msg )
init () =
    ( { username = ""
      , password = ""
      , email = ""
      , isSubmitting = False
      , badRegister = ""
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = ExampleMsgReplaceMe
    | UpdateUsername String
    | UpdatePassword String
    | UpdateEmail String
    | Submit
    | GotResponse (Result Api.Http.Error AuthorizedResponse)


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

        UpdateEmail email ->
            ( { model | email = email }, Effect.none )

        Submit ->
            ( { model | isSubmitting = True }
            , Api.Auth.register
                { username = model.username
                , password = model.password
                , email = model.email
                }
                GotResponse
            )

        GotResponse (Ok { token }) ->
            ( { model | isSubmitting = False }
            , Effect.login token
            )

        GotResponse (Err (Api.Http.BadStatus { message })) ->
            ( { model | isSubmitting = False, badRegister = message }, Effect.none )

        GotResponse (Err _) ->
            ( { model | isSubmitting = False, badRegister = "Something went wrong..." }, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Register"
    , body =
        [ div [ Attr.class "register-content" ]
            [ h1 [] [ text "Register" ]
            , textInput
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
            , textInput
                { id = "login-email"
                , name = "Email"
                , placeholder = Nothing
                , value = model.email
                , onInput = UpdateEmail
                }
            , p [ Attr.class "registerInfoText" ] [ em [] [ text "Email is not required, but can be used to recover your account in the event you forget your password. We'll never send you emails about anything." ] ]

            -- again, word login probably doesn't fit here.
            , button [ Attr.class "button login", Events.onClick Submit ]
                [ if model.isSubmitting then
                    text "Loading..."

                  else
                    text "Register"
                ]
            , p [ Attr.class "errorText" ] [ text model.badRegister ]
            , p [] [ text "Already have an account? ", a [ Attr.class "link", Attr.href "/login" ] [ text "Login" ] ]
            ]
        ]
    }
