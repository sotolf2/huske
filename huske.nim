import os, strutils
import illwill as iw

proc exitProc() {.noconv.} =
  iw.illwillDeinit()
  iw.showCursor()
  quit(0)

iw.illwillInit()
setControlCHook(exitProc)
hideCursor()

var tb = iw.newTerminalBuffer(iw.terminalWidth(), iw.terminalHeight())
tb.setForegroundColor(fgBlack, true)

type 
  MenuItem = object
    name: string
    id: int

proc write(self: MenuItem, tb: var TerminalBuffer, x: int, y: int, selected=false) =
  if selected:
    tb.write(x, y, fgWhite, bgBlue, $self.id, ": ", self.name, resetStyle)
  else:
    tb.write(x, y, resetStyle, $self.id, ": ", self.name)

proc learn() =
  tb.clear()
  var selected = 0

  while true:
    let menuitems = [
      MenuItem(name: "Back", id: 1)
    ]

    tb.drawRect(0, 0, 80, 3 + menuitems.len)
    tb.write(2, 1, fgYellow, "Learn")
    tb.setForegroundColor(fgWhite, true)
    tb.drawHorizLine(2, 78, 2, doubleStyle=true)

    for i, item in menuitems:
      item.write(tb, 2, 3 + i, i == selected)
    
    var key = iw.getKey()
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
    of Key.Escape, Key.Q: exitProc()
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

    tb.drawRect(0, 0, 80, 3 + menuitems.len)
    tb.write(2, 1, fgYellow, "Choose collection")
    tb.setForegroundColor(fgWhite, true)
    tb.drawHorizLine(2, 78, 2, doubleStyle=true)

    for i, item in menuitems:
      item.write(tb, 2, 3 + i, i == selected)
    
    var key = iw.getKey()
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
    of Key.Escape, Key.Q: exitProc()
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

    tb.drawRect(0, 0, 80, 3 + menuitems.len)
    tb.write(2, 1, fgYellow, "Create collection")
    tb.setForegroundColor(fgWhite, true)
    tb.drawHorizLine(2, 78, 2, doubleStyle=true)

    for i, item in menuitems:
      item.write(tb, 2, 3 + i, i == selected)
    
    var key = iw.getKey()
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
    of Key.Escape, Key.Q: exitProc()
    else:
      discard

    tb.display()
    sleep(20)


proc main() =
  var selected = 0
  tb.clear()
  
  while true:
    let menuitems = [
      MenuItem(name: "Learn", id: 1),
      MenuItem(name: "Create new cards", id: 2),
      MenuItem(name: "Create new collection", id: 3),
      MenuItem(name: "Quit", id: 4)
    ]

    # Draw main menu
    tb.drawRect(0, 0, 80, 3 + menuitems.len)
    tb.write(2, 1, fgYellow, "Main menu")
    tb.setForegroundColor(fgWhite, true)
    tb.drawHorizLine(2, 78, 2, doubleStyle=true)

    for i, item in menuitems:
      item.write(tb, 2, 3 + i, i == selected)
    
    var key = iw.getKey()
    case key
    of Key.Up: 
      if selected > 0:
        selected -= 1
    of Key.Down: 
      if selected < menuitems.len - 1:
        selected += 1
    of Key.Enter:
      case selected + 1
      of 1: learn()
      of 2: create_cards()
      of 3: create_collection()
      of 4: exitProc()
      else: discard
    of Key.Escape, Key.Q: exitProc()
    else:
      discard

    tb.display()
    sleep(20)


main()
