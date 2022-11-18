import times, jester, db_postgres, dotenv, os, strformat, strutils, sequtils, random, json

load()
var count = 0
var lastCountUpdate = now() 

type GetMessageError* = object of IOError
type
  Message = object
    message: string
    attribution: string
var db = open("localhost", "voxal", os.getEnv("DB_PASSWORD"), "cryptopuz")

db.exec(sql"""CREATE TABLE IF NOT EXISTS messages(id SERIAL PRIMARY KEY, message VARCHAR(255) NOT NULL, attribution VARCHAR(127) NOT NULL)""")

settings:
  port = Port 5000

proc updateCountCache() =
  if now() >= lastCountUpdate + 1.hours or count == 0:
    echo "updating cache"
    let query = db.getRow(sql"SELECT count(id) FROM messages")
    try: count = parseInt(query[0])
    except: discard
    lastCountUpdate = now()
  else: discard

proc getMessage(id: int): Message =
    let row = db.getRow(sql"SELECT message, attribution FROM messages WHERE id=?", id)
    if row.all(proc(x: string): bool = x.isNil or x == ""):
      raise GetMessageError.newException(fmt"id {id} not found")
    else:
      Message(message: row[0], attribution: row[1])

routes:
  get "/":
    updateCountCache()

    try: 
      let message = getMessage(rand(1..count));
      resp(Http200, $(%* message), contentType = "application/json")
    except GetMessageError as e: resp(Http404, e.msg)
  get "/@id":
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

