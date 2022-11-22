import times, jester, db_postgres, dotenv, os, strformat, strutils, sequtils, random, json, options

load()
var count = 1
var lastCountUpdate = now() 


var db = open("localhost", os.getEnv("DB_USERNAME"), os.getEnv("DB_PASSWORD"), os.getEnv("DB_DATABASE"))
type GetMessageError* = object of IOError
type
  Message = object
    id: int
    message: string
    attribution: string

  MessageInput = object
    message: string
    attribution: Option[string]

db.exec(sql"""CREATE TABLE IF NOT EXISTS messages(id SERIAL PRIMARY KEY, message VARCHAR(255) NOT NULL UNIQUE, attribution VARCHAR(127))""")
db.exec(sql"""CREATE TABLE IF NOT EXISTS submissions(id SERIAL PRIMARY KEY, message VARCHAR(255) NOT NULL UNIQUE, attribution VARCHAR(127), accepted BOOLEAN NOT NULL)""")

settings:
  port = Port 5000
  staticDir = "./client/dist"

proc updateCountCache() =
  echo "updating cache"
  let query = db.getRow(sql"SELECT count(id) FROM messages")
  try: count = parseInt(query[0])
  except: discard
  lastCountUpdate = now()

updateCountCache()

proc getMessage(id: int): Message =
    let row = db.getRow(sql"SELECT id, message, attribution FROM messages WHERE id=?", id)
    if row.all(proc(x: string): bool = x.isNil or x == ""):
      raise GetMessageError.newException(fmt"id {id} not found")
    else:
      Message(id: parseInt(row[0]), message: row[1], attribution: row[2])

routes:
  get "/api":
    if now() >= lastCountUpdate + 1.hours: updateCountCache()

    try: 
      let message = getMessage(rand(1..count));
      resp(Http200, $(%* message), contentType = "application/json")
    except GetMessageError as e: resp(Http404, e.msg)

  get "/api/@id":
    let
      id = try: parseInt(@"id")
          except ValueError: -1
    if id == -1:
      resp Http400, "invalid id format"
    try: 
      let message = getMessage(id)
      resp Http200, $(%* message), contentType = "application/json"
    except GetMessageError as e: resp(Http404, e.msg)

  post "/api/submit":  
    try: 
      let payload = parseJson(request.body)
      let message = to(payload, MessageInput)
      db.exec(sql"INSERT INTO submissions (message, attribution, accepted) VALUES (?, ?, FALSE)", message.message, message.attribution)
      resp "success"
    except: resp Http401, "invalid"

  get "/@url":
    resp Http200, readFile("./client/dist/index.html")
    

runforever()