module Components.Icon exposing (icon)

import Html exposing (Html)
import Html.Attributes exposing (class)


icon : String -> Html msg
icon id =
    Html.i [ class id ] []
