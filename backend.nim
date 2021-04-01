import db_sqlite as sq
import times as dt
import strutils
import options
import sugar


proc init_tables(db: DbConn) =
  # Collections
  db.exec(sql"""create table if not exists collection (
                collection_id integer primary key
                , name text not null);
          """)

  db.exec(sql"""create table if not exists card (
                card_id integer primary key
                , frontside text not null
                , backside text not null
                , difficulty real
                , days_between_reviews real
                , date_last_reviewed text
                , collection_id integer not null
                , card_type integer not null)
          """)

proc open_db*(): DbConn =
  var db = sq.open("huske.db", "", "", "")
  db.init_tables()
  return db

type 
  Collection* = object
    id*: int
    name*: string

proc collection_from_id*(db: DbConn, id: int): Option[Collection] = 
  let row = db.getRow(sql"select * from collection where collection_id = ?", id)
  if row[0] != "":
    dump(row)
    result = some(Collection(id: row[0].parse_int(), name: row[1]))
    return
  result = none(Collection)

proc collections*(db: DbConn): Option[seq[Collection]] =
  let rows = db.get_all_rows(sql"select * from collection")
  # early return if no results
  if rows == @[]:
    return none(seq[Collection])

  var collections: seq[Collection]
  for row in rows:
    collections.add(Collection(id: row[0].parseInt, name: row[1]))
  return some(collections)

proc new_collection*(db: DbConn, name: string) =
  db.exec(sql"insert into collection(name) values(?)", name)

type
  CardType* = enum
    New = 0
    Learning = 1
    Review = 2

type
  Card* = object
    id*: int
    frontside*: string
    backside*: string
    difficulty*: float
    days_between_reviews*: float
    date_last_reviewed*: DateTime
    collection_id*: int
    card_type*: CardType

proc to_card(row: seq[string]): Card =
  var 
    id: int = row[0].parse_int
    frontside: string = row[1]
    backside: string = row[2]
    collection_id: int = row[6].parse_int
    cardType: CardType = CardType(row[7].parse_int)
    difficulty: float 
    daysBetweenReviews: float
    dateLastReviewed: DateTime 
  
  difficulty = if row[3] != "": row[3].parse_float else: 0.3

  days_between_reviews = if row[4] != "": row[4].parse_float else: 1.0

  date_last_reviewed = if row[5] != "": dt.parse(row[5], "yyyy-MM-dd HH:mm")
    else: dt.now()

  result = Card(id: id,
                frontside: frontside,
                backside: backside,
                difficulty: difficulty,
                days_between_reviews: days_between_reviews,
                date_last_reviewed: date_last_reviewed,
                collection_id: collection_id,
                card_type: card_type)

proc card_from_id*(db: DbConn, id: int): Option[Card] = 
  let row = db.get_row(sql"select * from card where card_id = ?", id)
  if row[0] != "":
    result = some(row.toCard())
    return
  result = none(Card)

proc new_card*(db: DbConn, frontside: string, backside: string, collection_id: int) =
  db.exec(sql"insert into card(frontside, backside, collection_id, card_type) values(?, ?, ?, ?)",
          frontside, backside, collection_id,0)

proc cards*(db: DbConn): Option[seq[Card]] =
  let rows = db.get_all_rows(sql"select * from card")
  # early return if no results
  if rows == @[]:
    return none(seq[Card])

  var cards: seq[Card]
  for row in rows:
    cards.add(row.toCard())
  return some(cards)

proc remove_collection*(db: DbConn, id: int) =
  # first delete the cards connected to the collection
  db.exec(sql"delete from card where collection_id = ?", id)
  # then delete the collection itself
  db.exec(sql"delete from collection where collection_id = ?", id)