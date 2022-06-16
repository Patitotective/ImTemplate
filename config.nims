switch("backend", "cpp")
switch("warning", "HoleEnumConv:off")
switch("define", "tomlOrderedTable")

when defined(Windows):
  switch("passC", "-static")
  switch("passL", "-static")
