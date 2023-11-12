switch("backend", "cpp")
switch("warning", "HoleEnumConv:off")
switch("warning", "ImplicitDefaultValue:off")

when defined(Windows):
  switch("passC", "-static")
  switch("passL", "-static")
