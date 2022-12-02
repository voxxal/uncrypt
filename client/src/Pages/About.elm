module Pages.About exposing (page)

import Html exposing (..)
import Html.Attributes as Attr
import Layout exposing (Layout)
import View exposing (View)


layout : Layout
layout =
    Layout.Navbar


page : View msg
page =
    { title = "About"
    , body =
        [ div [ Attr.class "text-content" ]
            [ p []
                [ text "snuish was made by "
                , strong [] [ a [ Attr.href "https://voxal.dev" ] [ text "voxal" ] ]
                , text ". Special thanks to "
                , strong [] [ text "ryuusaka" ]
                , text " for getting me addicted to Cryptograms and providing valuable feedback."
                ]
            , p []
                [ text "This project is available on "
                , strong [] [ a [ Attr.href "https://github.com/voxxal/snuish" ] [ text "Github" ] ]
                , text ". Contributions are welcome."
                ]
            ]
        ]
    }
