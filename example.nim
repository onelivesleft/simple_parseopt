import simple_parseopt

let (options, is_set) = parse_options:
    name = "Iain King"
    age = 41

echo options.name, " is ", options.age
