import simple_parseopt

simple_parseopt.config: can_name_bare
let options = get_options:
    docs = false  {. aka("d"), info("Make documentation") .}
    make = false  {. aka("m"), info("Make this exe") .}
    readme = "README.md"
    src = "src/"
    bin = "bin/"
