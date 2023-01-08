module Auth.User exposing (User, decoder)

import Json.Decode as D


type alias User =
    { id : String
    , username : String
    , solved : Int
    , level : Int
    , experience : Int
    , expRequired : Int
    , expThrough : Int
    }


decoder : D.Decoder User
decoder =
    D.map7 User 
        (D.field "id" D.string)
        (D.field "username" D.string)
        (D.field "solved" D.int)
        (D.field "level" D.int)
        (D.field "experience" D.int)
        (D.field "expRequired" D.int)
        (D.field "expThrough" D.int)
