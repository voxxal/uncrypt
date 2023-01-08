module Auth.User exposing (User)

type alias User =
    { id : String
    , username : String
    , solved : Int
    , experience : Int
    }