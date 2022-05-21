import std/[strformat, strutils, sequtils, strscans, tables, math, re]

import nimgl/imgui
import honeycomb

type
  Cell* = tuple[row, col: int]
  Spreadsheet* = object
    label*: cstring # ImGui label ID
    rowMax*: int
    colMax*: range[1..25]
    cells: Table[Cell, tuple[text, formula: string, children: seq[Cell]]] # Cells buffer strings
    flags*: ImGuiTableFlags
    selectedCell*: Cell
    editing*: bool # Editing selected cell

import utils

const upperLetters = {'A'..'Z'}.toSeq()

# Arithmetic expressions parser
func processOp(input: seq[string]): float =
  if input.len < 3: return input[0].parseFloat()
  case input[1]:
  of "+": return input[0].parseFloat() + processOp(input[2..^1])
  of "-": return input[0].parseFloat() - processOp(input[2..^1])
  of "*": return input[0].parseFloat() * processOp(input[2..^1])
  of "/": return input[0].parseFloat() / processOp(input[2..^1])
  of "%": return input[0].parseFloat().mod(processOp(input[2..^1]))
  of "^": return input[0].parseFloat().pow(processOp(input[2..^1]))

template defineBinOp(parseOp: Parser[string]) =
  let right = ((padding >> parseOp << padding) & prevt.asString).many().flatten
  prevt = (prevt.asString & right).map(processOp)

proc evalArithm*(input: string): ParseResult[float] = 
  var expression = fwdcl[float]()
  let
    padding = regex(r"\s*")
    number  = (digit.atLeast(1) & (c('.') & digit.atLeast(1)).optional).join.map(parseFloat)
    parens  = c('(') >> padding >> expression << padding << c(')')
    operand = number | parens
  var prevt = operand

  defineBinOp c("^")
  defineBinOp c("*/%")
  defineBinOp c("+-")

  expression.become(padding >> prevt << padding)

  let parser = expression << eof.desc("valid expression")
  result = parser.parse(input)

# https://github.com/ocornut/imgui/issues/589#issuecomment-238358689
proc igIsItemActivePreviousFrame(): bool = 
  let context = igGetCurrentContext()
  result = context.activeIdPreviousFrame == context.lastItemData.id

proc initSpreadsheet*(label: cstring, rowMax, colMax: int, flags: ImGuiTableFlags): Spreadsheet = 
  Spreadsheet(label: label, rowMax: rowMax, colMax: colMax, flags: flags, selectedCell: (-1, -1))

proc findCellsId(input: string): seq[string] =  
  input.findAll(re"[A-Za-z]\d{1,2}")

proc parseCell(input: string): Cell = 
  let (ok, col, row) = input.scanTuple("$c$i")
  result = (row, upperLetters.find(col.toUpperAscii()))

proc replaceCellsId(self: var Spreadsheet, input: string): tuple[cells: seq[Cell], output: string] = 
  result.output = input
  for id in input.findCellsId():
    let cell = id.parseCell()
    result.cells.add cell

    if cell == self.selectedCell:
      return

    if self.cells[cell].text.cleanString().len == 0:
      result.output = result.output.replace(id, "0")
    else:
      result.output = result.output.replace(id, self.cells[cell].text.cleanString())

proc updateCell(self: var Spreadsheet, cell: Cell) = 
  let formula = self.cells[cell].formula.cleanString()

  if formula.len > 1 and formula[0] == '=': 
    let (cellsInFormula, replacedFormula) = self.replaceCellsId(formula)
    let exprResult = evalArithm(replacedFormula[1..^1])

    if exprResult.kind == ParseResultKind.success:
      self.cells[cell].text = $exprResult.value
    else:
      self.cells[cell].text = self.cells[cell].formula

    for parent in cellsInFormula:
      if cell notin self.cells[parent].children:
        self.cells[parent].children.add cell

  else:
    self.cells[cell].text = self.cells[cell].formula

  for child in self.cells[cell].children:
    echo "Updating ", child
    self.updateCell(child)

proc draw*(self: var Spreadsheet) = 
  if igButton("Echo"):
    echo "Editing: ", self.editing
    echo "Selected: ", self.selectedCell
    echo "\t", self.cells[self.selectedCell], "\n"

  # Two more column because of the row numbers column
  if igBeginTable(self.label, int32 self.colMax+2, self.flags):
    igTableSetupScrollFreeze(1, 1)
    # Top left corner is an empty header
    igTableSetupColumn(cstring "")
    for col in 0..self.colMax:
      igTableSetupColumn(cstring $upperLetters[col])
    igTableHeadersRow()

    igPushStyleVar(FrameRounding, 0)
    igPushStyleColor(FrameBg, 0)
    for row in 0..self.rowMax:
      igTableNextRow()
      # Row number
      igTableNextColumn()
      
      igTableSetBgColor(CellBg, igGetColorU32(TableHeaderBg))
      igSelectable(cstring $row, size = ImVec2(x: 50, y: igTableGetHeaderRowHeight()))
      
      # Set background white and text black
      igTableSetBgColor(RowBg0, igGetColorU32(TableRowBgAlt))
      igPushStyleColor(Text, igGetColorU32(TableRowBg))

      for col in 0..self.colMax:
        if (row, col) notin self.cells:
          self.cells[(row, col)] = ("", newString(32), @[])

        igTableNextColumn()

        # If there are no cells being edited
        # Or the selected cell is not this
        # Disable input text
        var inputTextDisabled = false
        if not self.editing or self.selectedCell != (row, col):
          inputTextDisabled = true
          igPushItemFlag(ImGuiItemFlags.Disabled, true)

        # If the selected cell is this
        # Push border
        if self.selectedCell == (row, col):
          igPushStyleVar(FrameBorderSize, 1)
          igPushStyleColor(Border, igGetColorU32(BorderShadow))

        igSetNextItemWidth(70)
        igInputText(cstring &"##{row}{col}", if inputTextDisabled: self.cells[(row, col)].text.cstring else: self.cells[(row, col)].formula.cstring, 32)

        # If pressed enter
        # See https://github.com/ocornut/imgui/issues/589#issuecomment-238358689
        if igIsItemActivePreviousFrame() and not igIsItemActive() and igIsKeyPressedMap(ImGuiKey.Enter):
          self.updateCell((row, col))
          self.editing = false

        # Pop border
        if self.selectedCell == (row, col):
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
          # If the selected cell is not this but it is being clicked
          elif self.selectedCell != (row, col) and igIsMouseClicked(ImGuiMouseButton.Left):
            if self.editing and self.selectedCell.row > -1 and self.selectedCell.col > -1:
              self.updateCell(self.selectedCell)
            
            self.editing = false
            self.selectedCell = (row, col)

      igPopStyleColor()

    igPopStyleColor()
    igPopStyleVar()
    igEndTable()
