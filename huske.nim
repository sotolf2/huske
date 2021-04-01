import os, options
import illwill as iw
import db_sqlite as sq
import schedule as se
import backend 

proc exit_proc() {.noconv.} =
  iw.illwill_deinit()
  iw.show_cursor()
  quit(0)

iw.illwill_init(fullscreen=true)
set_control_c_hook(exit_proc)
hide_cursor()

var tb = iw.new_terminal_buffer(iw.terminal_width(), iw.terminal_height())
tb.set_foreground_color(fg_black, true)

type 
  MenuItem = object
    name: string
    id: int

proc write(self: MenuItem, tb: var TerminalBuffer, x: int, y: int, selected=false) =
  if selected:
    tb.write(x, y, fg_white, bg_blue, $self.id, ": ", self.name, reset_style)
  else:
    tb.write(x, y, reset_style, $self.id, ": ", self.name)

proc learn(db: DBConn) =
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

proc create_cards() =
  tb.clear()
  var selected = 0

  while true:
    let menuitems = [
      MenuItem(name: "Back", id: 1)
    ]

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
    of Key.Enter:
      case selected + 1
      of 1: 
        tb.clear()
        return
      else: discard
    of Key.Escape, Key.Q: return
    else:
      discard

    tb.display()
    sleep(20)

proc create_collection() =
  tb.clear()
  var selected = 0

  while true:
    let menuitems = [
      MenuItem(name: "Back", id: 1)
    ]

    tb.draw_rect(0, 0, iw.terminal_width() - 1, 3 + menuitems.len)
    tb.write(2, 1, fgYellow, "Create collection")
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
      of 1: 
        tb.clear()
        return
      else: discard
    of Key.Escape, Key.Q: return
    else:
      discard

    tb.display()
    sleep(20)


proc main() =
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
      of 2: create_cards()
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
