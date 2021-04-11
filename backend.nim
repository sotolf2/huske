## Backend for Huske, mainly dealing with database storage
##
## Backend
## -------
## 
## I'm using sqlite as a backing store for the cards and collections that 
## huske uses to store metadata and collections.

import db_sqlite as sq
import times as dt
import strutils
import options
import sugar


proc init_tables(db: DbConn) =
  ## Sets the tables in the database if they aren't already
  ## this is used to ensure that we have a schema to work with
  ## in case there is not yet an existing database file.
  
  # Collections
  db.exec(sql"""create table if not exists collection (
                collection_id integer primary key
                , name text not null);
          """)

  # Cards
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
  ## Opens the databasefile and initiates tables
  var db = sq.open("huske.db", "", "", "")
  db.init_tables()
  return db

type 
  Collection* = object
    ## a group of cards to separate out different learning sessions
    id*: int
    name*: string

proc collection_from_id*(db: DbConn, id: int): Option[Collection] = 
  ## Gets a collection from the database based on its id
  let row = db.getRow(sql"select * from collection where collection_id = ?", id)
  if row[0] != "":
    dump(row)
    result = some(Collection(id: row[0].parse_int(), name: row[1]))
    return
  result = none(Collection)

proc collections*(db: DbConn): Option[seq[Collection]] =
  ## Gets all the collections stored in the db
  let rows = db.get_all_rows(sql"select * from collection")
  # early return if no results
  if rows == @[]:
    return none(seq[Collection])

  var collections: seq[Collection]
  for row in rows:
    collections.add(Collection(id: row[0].parseInt, name: row[1]))
  return some(collections)

proc new_collection*(db: DbConn, name: string) =
  ## Stores a new collection in the database
  db.exec(sql"insert into collection(name) values(?)", name)

type
  CardType* = enum
    ## These stores the state of a card, the intention is to use these to
    ## decide how to better schedule them or to move cards into the learning
    ## queue
    New = 0
    Learning = 1
    Review = 2

type
  Card* = object
    ## Here we have a card and its metadata which will be used for scheduling them
    id*: int
    frontside*: string
    backside*: string
    difficulty*: float
    days_between_reviews*: float
    date_last_reviewed*: DateTime
    collection_id*: int
    card_type*: CardType

proc to_card(row: seq[string]): Card =
  ## Takes a database row and parses it into a Card
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
  ## Queries a card from the db based on its id
  let row = db.get_row(sql"select * from card where card_id = ?", id)
  if row[0] != "":
    result = some(row.toCard())
    return
  result = none(Card)

proc new_card*(db: DbConn, frontside: string, backside: string, collection_id: int) =
  ## Adds a new card to the database if it doesn't exist
  var existing_card = 
    db.get_row(sql"select 1 from card where frontside = ? and backside = ? and collection_id = ?",
                frontside, backside, collection_id)
  if existing_card == @[""] :
    db.exec(sql"insert into card(frontside, backside, collection_id, card_type) values(?, ?, ?, ?)",
          frontside, backside, collection_id,0)

proc cards*(db: DbConn): Option[seq[Card]] =
  ## Queries a list of all cards from the database
  let rows = db.get_all_rows(sql"select * from card")
  # early return if no results
  if rows == @[]:
    return none(seq[Card])

  var cards: seq[Card]
  for row in rows:
    cards.add(row.to_card())
  return some(cards)

proc cards_from_collection*(db: DbConn, collection_id: int): Option[seq[Card]] =
  ## Queries cards that belong to a collection by id
  let rows = db.get_all_rows(sql"select * from card where collection_id = ? order by frontside asc", collection_id)
  if rows == @[]:
    return none(seq[Card])

  var cards: seq[Card]
  for row in rows:
    cards.add(row.to_card())
  return some(cards)

proc due_cards*(db: DbConn, collection_id: int): Option[seq[Card]] =
  ## Get the due cards from the collection
  let rows = db.get_all_rows(sql"select * from card where collection_id = ? and card_type <> 0 and (julianday('now', 'localtime') - julianday(date_last_reviewed)) > days_between_reviews")

  if rows == @[]:
    return none(seq[Card])

  var cards: seq[Card]
  for row in rows:
    cards.add(row.to_card())
  return some(cards)

proc num_cards_in_collection*(db: DbConn, collection_id: int): int =
  ## Returns the number of cards in a collection
  let row = db.get_row(sql"select count(*) from card where collection_id = ?", collection_id)
  return row[0].parse_int

proc num_new_cards_in_collection*(db: DbConn, collection_id: int): int =
  ## Returns the number of cards not yet started in a collection
  let row = db.get_row(sql"select count(*) from card where collection_id = ? and card_type = 0", collection_id)
  return row[0].parse_int

proc num_due_cards_in_collection*(db: DbConn, collection_id: int): int =
  ## Returns the number of cards that are due
  let row = db.get_row(sql"select count(*) from card where collection_id = ? and card_type <> 0 and (julianday('now', 'localtime') - julianday(date_last_reviewed)) > days_between_reviews", collection_id)
  return row[0].parse_int

proc remove_card* (db: DbConn, id: int) =
  ## Removes a card by id
  db.exec(sql"delete from card where card_id = ?", id)

proc remove_collection*(db: DbConn, id: int) =
  ## Removes a collection and all its associated cards from the db
  # first delete the cards connected to the collection
  db.exec(sql"delete from card where collection_id = ?", id)
  # then delete the collection itself
  db.exec(sql"delete from collection where collection_id = ?", id)
