switch("backend", "cpp")
switch("warning", "HoleEnumConv:off")
switch("warning", "ImplicitDefaultValue:off")
switch("threads", "on")

when defined(Windows):
  switch("passC", "-static")
  switch("passL", "-static")
