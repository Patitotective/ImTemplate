switch("backend", "cpp")
switch("warning", "HoleEnumConv:off")
switch("warning", "CStringConv:off")
when defined(Windows):
  switch("passC", "-static")
  switch("passL", "-static")
