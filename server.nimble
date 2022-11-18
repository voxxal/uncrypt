# Package

version       = "0.1.0"
author        = "voxal"
description   = "cryptopuz server"
license       = "MIT"
srcDir        = "src"
bin           = @["server"]


# Dependencies

requires "nim >= 1.7.3"
requires "jester >= 0.5.0"
requires "dotenv >= 2.0.0"