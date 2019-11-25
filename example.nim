import simple_parseopt

#let (xmas, _) = get_options_and_presence:
#    foo = "Holiday"
#    bar = "Season"
#
#echo xmas.foo, " ", xmas.bar

let (options, is_set) = get_options_and_supplied:
    name = "John Random"
    age = 30

echo options.name, " is ", options.age
