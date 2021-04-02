##
## Huske
## -----
##
## This is a small Spaced Repetition program that I'm writing to try and learn
## some nim, and hopefully it will also be helpful for memorizing stuff.
##
## It uses Sqlite as a backing store and has a little TUI user interface

import os, options
import illwill as iw
import illwillWidgets as iww
import db_sqlite as sq
import schedule as se
import backend 

proc exit_proc() {.noconv.} =
  ## Make sure to clean up illwill stuff when we leave and 
  ## restore the terminal to its previous state.
  iw.illwill_deinit()
  iw.show_cursor()
  quit(0)

# Set up stuff we need to get the TUI going
iw.illwill_init(fullscreen=true)
set_control_c_hook(exit_proc)
hide_cursor()

var tb = iw.new_terminal_buffer(iw.terminal_width(), iw.terminal_height())
tb.set_foreground_color(fg_black, true)

type 
  MenuItem = object
    ## This is used to build up menus and they will show up in the form:
    ## "id: string"
    name: string
    id: int

proc write(self: MenuItem, tb: var TerminalBuffer, x: int, y: int, selected=false) =
  ## Will show a MenuItem in the interface, and set the bacground blue
  ## to show that it's the selected one if it is.
  if selected:
    tb.write(x, y, fg_white, bg_blue, $self.id, ": ", self.name, reset_style)
  else:
    tb.write(x, y, reset_style, $self.id, ": ", self.name)

proc learn(db: DBConn) =
  ## The menu for The learning subset of the program
  tb.clear()
  var selected = 0
  
  var menuitems:seq[MenuItem] = @[]
  let colls = db.collections()

  var last_id = 0

  if colls.is_some():
    for coll in colls.get():
      menuitems.add(MenuItem(name: coll.name, id: coll.id))
      last_id = coll.id
      
  menuitems.add(MenuItem(name: "Back", id: (last_id + 1)))  
  
  while true:
    tb.draw_rect(0, 0, iw.terminal_width() - 1, 3 + menuitems.len)
    tb.write(2, 1, fgYellow, "Learn")
    tb.set_foreground_color(fgWhite, true)
    tb.draw_horiz_line(2, iw.terminal_width() - 3, 2, doubleStyle=true)

    for i, item in menuitems:
      item.write(tb, 2, 3 + i, i == selected)
    
    var key = iw.get_key()
    case key
    of Key.Up: 
      if selected > 0:
        selected -= 1
    of Key.Down: 
      if selected < menuitems.len - 1:
        selected += 1
    of Key.Enter:
      # The last menuitem is back
      if selected == len(menuitems) - 1:
        tb.clear()
        return
    of Key.Escape, Key.Q: 
      tb.clear()
      return
    else:
      discard

    tb.display()
    sleep(20)

proc manage_cards(db: DBConn) =
  ## The submenu for card creation
  tb.clear()
  var selected = 0
  var front_active = false
  var back_active = false

  # The y coordinate for the boxes is 0 since y-placement
  # is not yet known
  var front_text_box = new_text_box("", 2, 0, iw.terminal_width() - 3,
                              bg_color=bg_green)
  var back_text_box = new_text_box("", 2, 0, iw.terminal_width() - 3,
                              bg_color=bg_green)
  while true:
    var menuitems:seq[MenuItem] = @[]
    var colls = db.collections()

    var last_id = 0

    if colls.is_some():
      for coll in colls.get():
        let n_cards = db.num_cards_in_collection(coll.id)
        let desc = coll.name & " [" & $n_cards & "]"
        menuitems.add(MenuItem(name: desc, id: coll.id))
        last_id = coll.id

    menuitems.add(MenuItem(name: "Back", id: (last_id + 1)))  

    tb.draw_rect(0, 0, iw.terminal_width() - 1, 3 + menuitems.len)
    tb.write(2, 1, fgYellow, "Choose collection")
    tb.set_foreground_color(fgWhite, true)
    tb.draw_horiz_line(2, terminal_width() - 3, 2, doubleStyle=true)

    for i, item in menuitems:
      item.write(tb, 2, 3 + i, i == selected)
    
    var key = iw.get_key()
    case key
    of Key.Up: 
      if selected > 0:
        selected -= 1
    of Key.Down: 
      if selected < menuitems.len - 1:
        selected += 1
    of Key.Enter, Key.Right:
      if selected == menuitems.len - 1:
        tb.clear()
        return
    of Key.Escape, Key.Q:
      tb.clear()
      return
    else:
      discard

    tb.display()
    sleep(20)

proc manage_collections(db: DBConn) =
  ## Submenu for managing collections
  var selected = 0
  var warning_active = false
  var text_box_is_active = false

  # The y coordinate is set as 0 here since it's not yet sure where
  # we have to print it, it will be set later to the right spot
  var text_box = new_text_box("", 2, 0, iw.terminal_width() - 3,
                              bg_color=bg_green)
                              

  while true:
    # make sure we don't get artifacts from a previous state
    tb.clear()
    # had to put the generating list here to reflect changes
    # in the menu when a collection is deleted
    var menuitems:seq[MenuItem] = @[]
    var colls = db.collections()

    var last_id = 0

    if colls.is_some():
      for coll in colls.get():
        menuitems.add(MenuItem(name: coll.name, id: coll.id))
        last_id = coll.id
      
    menuitems.add(MenuItem(name: "Back", id: (last_id + 1)))  
    
    tb.draw_rect(0, 0, iw.terminal_width() - 1, 3 + menuitems.len)
    tb.write(2, 1, fg_yellow, "Manage collections")
    tb.set_foreground_color(fg_white, true)
    tb.draw_horiz_line(2, iw.terminal_width() - 3, 2, doubleStyle=true)
    for i, item in menuitems:
      item.write(tb, 2, 3 + i, i == selected)

    tb.write(2, 4 + menuitems.len, 
            fg_green, "d: ", fg_white, "delete selected collection")
    tb.write(2, 5 + menuitems.len, 
            fg_green, "c: ", fg_white, "create new collection")

    # setting the y coordinate for the text_box here since we
    # finally know where to place it
    text_box.y = 7 + menuitems.len

    # grab the key the user pushed
    var key = iw.get_key()
   
    # this is to be sure that the text_box will deal with its
    # stuff if it has focus
    if text_box.focus:
      # handle_key will return true when input is ended by Key.Enter
      if tb.handle_key(text_box, key):
        new_collection(db, text_box.text)
        # Hide the textbox when input is finished
        text_box_is_active = false
        text_box.focus = false
        # We have to replace the textbox when we're finished since
        # if I just set the text as empty the program will crash
        text_box = new_text_box("", 2, 0, iw.terminal_width() - 3,
                                 bg_color=bg_green)
      key.set_key_as_handled()

    
    case key
    of Key.None: discard
    of Key.Up: 
      if selected > 0:
        selected -= 1
    of Key.Down: 
      if selected < menuitems.len - 1:
        selected += 1
    of Key.C:
      text_box.focus = true
      text_box_is_active = true
    of Key.D:
      # last menuitem is not a collection
      if selected < menuitems.len - 1:
        warning_active = true
    of Key.Y:
      if warning_active:
        remove_collection(db, menuitems[selected].id)
        warning_active = false
    of Key.N:
      warning_active = false
    of Key.Enter, Key.Right:
      if selected == menuitems.len - 1:
        tb.clear()
        return
      else: discard
    of Key.Escape, Key.Q: 
      tb.clear()
      return
    else:
      discard

    # only show the text_box if it's needed
    if text_box_is_active:
      tb.render(text_box)

    if warning_active:
      tb.write(2, menuitems.len + 7, fg_red,
                "This will delete all cards in this collection (y/n)", reset_style)

    tb.display()
    sleep(20)


proc main() =
  ## Main menu of the Program
  var db = open_db()
  var selected = 0
  tb.clear()
  
  while true:
    let menuitems = [
      MenuItem(name: "Learn", id: 1),
      MenuItem(name: "Create new cards", id: 2),
      MenuItem(name: "Manage collections", id: 3),
      MenuItem(name: "Quit", id: 4)
    ]

    # Draw main menu
    tb.draw_rect(0, 0, iw.terminal_width() - 1, 3 + menuitems.len)
    tb.write(2, 1, fgYellow, "Main menu")
    tb.set_foreground_color(fgWhite, true)
    tb.draw_horiz_line(2, iw.terminal_width() - 3, 2, doubleStyle=true)

    for i, item in menuitems:
      item.write(tb, 2, 3 + i, i == selected)
    
    var key = iw.get_key()
    case key
    of Key.Up: 
      if selected > 0:
        selected -= 1
    of Key.Down: 
      if selected < menuitems.len - 1:
        selected += 1
    of Key.Enter:
      case selected + 1
      of 1: learn(db)
      of 2: manage_cards(db)
      of 3: manage_collections(db)
      of 4:
        db.close()
        exit_proc()
      else: discard
    of Key.Escape, Key.Q: 
      db.close()
      exit_proc()
    else:
      discard

    tb.display()
    sleep(20)


main()
