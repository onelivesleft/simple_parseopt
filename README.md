# simple_parseopt
Nim module which provides clean, zero-effort command line parsing

---

## Use

This module gives you two ways to parse the command line: `get_options` and `get_options_and_supplied`

At it's simplest, declare a block like this:

```nim
# foo.nim

let options = get_options:
    name = "Default Name"
    toggle = false
    letter = 'a'
    age = 1
    here = true
    there = false
    big:float64 = 1.1
    small:float = 2.2
    flat:uint = 2
    hello:string
```

Notice it follows the same syntax as a `var` block.  `options` will be set to an `object` with fields as described in the block.  Each field will also be a command-line parameter; bools will toggle, while other fields will take a value argument.

The resulting `object` will also contain an `arugments` field, a `seq[string]` which contains all the bare arguments which were not one of the designated parameters.

```bash
foo.exe -name "J. Random" -toggle -big 1011121.121498
```

---

`get_options_and_supplied` will return two objects: the first as above, but with a second which has identical field names, as bools.  For any field which the user has supplied the bool will be set to true:

```nim
# foo.nim

let (options, is_set) = get_options:
    name = "Default Name"
    toggle = false
    letter = 'a'
    age = 1
    here = true
    there = false
    big:float64 = 1.1
    small:float = 2.2
    flat:uint = 2
    hello:string

if is_set.age:
    recalculate_ages(options.age)
```

---

# Options

You may tailor the parser with the following calls:


* allow_dash(allow = true) [default: true]
Treat arguments starting with `-` as parameter names.

* allow_slash(allow = true) [default: true]
Treat arguments starting with `/` as parameter names.

* allow_repetition(allow = true) [default: false]
Allow the same parameter name to appear more than once.

* allow_errors(allow = true) [default: false]
Allow execution to continue despite an erroneous command line.

* strict_parameters(strict = true) [default: false]
Do not allow bare arguments: only arguments which match the specified parameters are allowed.

* manual_help(manual = true) [default:false]
If this is not turned on then `-?`, `-h`, and `-help` parameters, if not provided by you, will display a simple help message detailing the available parameters.

* help_info(text: string) [default: "Available parameters:"]
If `manual_help` is not enabled, then this text will be displayed at the start of the automatic help message.
