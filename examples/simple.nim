import "../src/simple_parseopt"  # when installed you need only `import simple_parseopt`

let options = get_options:
    name = "John Random"
    age = 30

echo options.name, " is ", options.age
