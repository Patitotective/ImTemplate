import std/[strformat, strutils, sequtils, strscans, tables, re]

import nimgl/imgui
import mathexpr

type
  Cell* = tuple[row, col: int]
  Spreadsheet* = object
    label*: cstring # ImGui label ID
    rowMax*: int
    colMax*: range[1..26]
    cells: Table[Cell, tuple[text, buffer, formula: string, children, parents: seq[Cell]]]
    flags*: ImGuiTableFlags
    selectedCell*: Cell
    editing*: bool # Editing selected cell

import utils

const upperLetters = {'A'..'Z'}.toSeq()

proc evalFormula*(input: string): (bool, float) = 
  let e = newEvaluator()
  try:
    result = (true, e.eval(input))
  except ValueError:
    result = (false, 0d)

# https://github.com/ocornut/imgui/issues/589#issuecomment-238358689
proc igIsItemActivePreviousFrame(): bool = 
  let context = igGetCurrentContext()
  result = context.activeIdPreviousFrame == context.lastItemData.id

proc initSpreadsheet*(label: cstring, rowMax, colMax: int, flags: ImGuiTableFlags): Spreadsheet = 
  Spreadsheet(label: label, rowMax: rowMax, colMax: colMax, flags: flags, selectedCell: (-1, -1))  

proc parseCell(input: string): Cell = 
  let (ok, col, row) = input.scanTuple("$c$i")
  if ok:
    result = (row, upperLetters.find(col.toUpperAscii()))
  else:
    result = (-1, -1)

proc replaceCellsId(self: var Spreadsheet, input: string, calledFrom: Cell): tuple[cells: seq[Cell], output: string] = 
  result.output = input
  for id in input.findAll(re"[A-Za-z]\d+"): # Find IDs
    let cell = id.parseCell()
    result.cells.add cell

    # If the row or cell is out of the range or the cell is referencing the cell it was calledFrom
    # Don't replace anything, return the input
    if cell.row notin 0..self.rowMax or cell.col notin 0..self.colMax or cell == calledFrom:
      result.output = input
      return

    if self.cells[cell].text.len == 0:
      result.output = result.output.replace(id, "0")
    else:
      result.output = result.output.replace(id, self.cells[cell].text)

proc updateCell(self: var Spreadsheet, cell: Cell) = 
  let formula = self.cells[cell].formula

  # Remove cell from all its parents
  # And reset (clean) the parents seq
  for parent in self.cells[cell].parents:
    self.cells[parent].children.remove(cell)

  self.cells[cell].parents.reset()

  if formula.len > 1 and formula[0] == '=': 
    let (cellsInFormula, replacedFormula) = self.replaceCellsId(formula, cell)
    let (success, result) = evalFormula(replacedFormula[1..^1])

    if success:
      self.cells[cell].text = $result
      
      # Make this cell children of all the cellsInFormula
      # And add all the cellsInFormula as parents to this cell
      for parent in cellsInFormula:
        # To not add the cell to itself
        if parent != cell:
          self.cells[parent].children.add cell
          self.cells[cell].parents.add parent

    else: # Invalid formula
      self.cells[cell].text = formula
  else: # Not a formula
    self.cells[cell].text = formula

  # Update children
  for child in self.cells[cell].children:
    self.updateCell(child)

proc draw*(self: var Spreadsheet) = 
  # One more column because of the row numbers column
  if igBeginTable(self.label, int32 self.colMax+1, self.flags):
    igTableSetupScrollFreeze(1, 1)
    # Top left corner is an empty header
    igTableSetupColumn(cstring "")
    for col in 0..<self.colMax:
      igTableSetupColumn(cstring $upperLetters[col])
    igTableHeadersRow()

    igPushStyleVar(FrameRounding, 0)
    igPushStyleColor(FrameBg, 0)
    for row in 0..self.rowMax:
      igTableNextRow()
      
      # Row number
      igTableNextColumn()
      igTableHeader(cstring $row)

      # Set background white and the text black
      igTableSetBgColor(RowBg0, igGetColorU32(TableRowBgAlt))
      igPushStyleColor(Text, igGetColorU32(TableRowBg))

      for col in 0..<self.colMax:
        let cell = (row, col)
        if cell notin self.cells:
          self.cells[cell] = ("", newString(100), "", @[], @[])

        igTableNextColumn()

        # If there are no cells being edited
        # Or the selected cell is not this
        # Disable input text (the cell)
        var inputTextDisabled = false
        if not self.editing or self.selectedCell != cell:
          inputTextDisabled = true
          # When a cell is disabled, displaye the cell's text
          self.cells[cell].buffer.pushString(self.cells[cell].text)
          igPushItemFlag(ImGuiItemFlags.Disabled, true)
        else: # When a cell is being edited (enabled) display the formula
          self.cells[cell].buffer.pushString(self.cells[cell].formula)

        # If the selected cell is the current
        # Push border
        if self.selectedCell == cell:
          igPushStyleVar(FrameBorderSize, 1)
          igPushStyleColor(Border, igGetColorU32(BorderShadow))

        igSetNextItemWidth(70)
        if igInputText(cstring &"##{row}{col}", self.cells[cell].buffer.cstring, 100):
          if not inputTextDisabled: # Update the formula
            self.cells[cell].formula = self.cells[cell].buffer.cleanString()

        # If pressed enter
        # See https://github.com/ocornut/imgui/issues/589#issuecomment-238358689
        if igIsItemActivePreviousFrame() and not igIsItemActive() and igIsKeyPressedMap(ImGuiKey.Enter):
          self.updateCell(self.selectedCell)
          self.editing = false

        # Pop border
        if self.selectedCell == cell:
          igPopStyleColor()
          igPopStyleVar()

        # Pop input text disabled
        if inputTextDisabled:
          igPopItemFlag()

        if igIsItemHovered(AllowWhenDisabled):
          # When double clicking a cell
          # Set editing to true and focus the input text
          if igIsMouseDoubleClicked(ImGuiMouseButton.Left):
            self.editing = true
            igSetKeyboardFocusHere(-1)
          # If the selected cell is not the selected one but it is being clicked
          elif self.selectedCell != cell and igIsMouseClicked(ImGuiMouseButton.Left):
            if self.editing and self.selectedCell.row > -1 and self.selectedCell.col > -1:
              self.updateCell(self.selectedCell)

            self.editing = false
            self.selectedCell = cell


      igPopStyleColor()

    igPopStyleColor()
    igPopStyleVar()
    igEndTable()
