module Layouts.Navbar exposing (layout)

import Html exposing (..)
import Html.Attributes as Attr
import View exposing (View)


layout : { page : View msg } -> View msg
layout { page } =
    { title = page.title
    , body =
        [ nav [ Attr.class "navbar" ]
            [ a [ Attr.class "logo", Attr.href "/" ] [ text "cryptow/eve" ]
            , div [ Attr.class "location" ] [ text page.title ]
            , a [ Attr.class "options", Attr.href "/settings" ] [ text "Settings" ]
            ]
        , div [ Attr.class "page" ] page.body
        ]
    }
