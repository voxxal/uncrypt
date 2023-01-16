module Pages.Profile.Username_ exposing (Model, Msg, page)

import Api
import Effect exposing (Effect)
import Html
import Layouts
import Page exposing (Page)
import Pages.Profile exposing (Msg(..))
import Route exposing (Route)
import Shared
import View exposing (View)
import Api.Profile

page : Shared.Model -> Route { username : String } -> Page Model Msg
page shared route =
    Page.new
        { init = init route.params.username
        , update = update
        , subscriptions = subscriptions
        , view = view
        }
        |> Page.withLayout (\_ -> Layouts.Navbar { navbar = {} })



-- INIT


type alias Model =
    Pages.Profile.Model


init : String -> () -> ( Model, Effect Msg )
init username () =
    ( { profile = Api.Loading, solves = Api.Loading }
    , Effect.batch [ Api.Profile.profile username GotProfile, Api.Profile.solves username GotSolves] 
    )



-- UPDATE


type alias Msg = Pages.Profile.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update = Pages.Profile.update



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> View Msg
view = Pages.Profile.view