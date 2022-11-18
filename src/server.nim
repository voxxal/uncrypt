import times, jester, db_postgres, dotenv, os, strformat, strutils, sequtils, random, json

load()
var count = 1
var lastCountUpdate = now() 


var db = open("localhost", "voxal", os.getEnv("DB_PASSWORD"), "cryptopuz")
type GetMessageError* = object of IOError
type
  Message = object
    id: int
    message: string
    attribution: string

db.exec(sql"""CREATE TABLE IF NOT EXISTS messages(id SERIAL PRIMARY KEY, message VARCHAR(255) NOT NULL, attribution VARCHAR(127) NOT NULL)""")

settings:
  port = Port 5000

proc updateCountCache() =
  if now() >= lastCountUpdate + 1.hours:
    echo "updating cache"
    let query = db.getRow(sql"SELECT count(id) FROM messages")
    try: count = parseInt(query[0])
    except: discard
    lastCountUpdate = now()
  else: discard

proc getMessage(id: int): Message =
    let row = db.getRow(sql"SELECT id, message, attribution FROM messages WHERE id=?", id)
    if row.all(proc(x: string): bool = x.isNil or x == ""):
      raise GetMessageError.newException(fmt"id {id} not found")
    else:
      Message(id: parseInt(row[0]), message: row[1], attribution: row[2])

routes:
  get "/":
    resp(Http200, readFile("client/index.html"))

  get "/elm.js":
    resp(Http200, readFile("client/elm.js"), contentType = "application/javascript")

  get "/style.css":
    resp(Http200, readFile("client/style.css"), contentType = "text/css")

  get "/api":
    updateCountCache()

    try: 
      let message = getMessage(rand(1..count));
      resp(Http200, $(%* message), contentType = "application/json")
    except GetMessageError as e: resp(Http404, e.msg)

  get "/api/@id":
    let
      id = try: parseInt(@"id")
          except ValueError: -1
    if id == -1:
      resp(Http400, "invalid id format")
    try: 
      let message = getMessage(id)
      resp(Http200, $(%* message), contentType = "application/json")
    except GetMessageError as e: resp(Http404, e.msg)


runforever()

