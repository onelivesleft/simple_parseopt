# simple_parseopt
Nim module which provides clean, zero-effort command line parsing

---

## Basic Use

This module gives you two ways to parse the command line: `get_options` and `get_options_and_supplied`


### Parsing with `get_options`

At its simplest, declare a block like this:

```nim
# foo.nim

let options = get_options:
    name          = "Default Name"
    active        = false
    letter        = 'a'
    age           = 1
    big:float64   = 1.1
    small:float   = 2.2
    flat:uint     = 2
    hello:string

echo options.name & " is " & options.age.repr & " years old!"
```

Notice it follows the same syntax as a `var` block.

In the example `foo.nim` above, the variable `options` will be set to an `object` with fields as described in the `get_options` block.  Each field will also be set up as a command-line parameter for the user running the program to use; bools will toggle, while other fields will take a value argument.

```bash
foo -name "J. Random" -toggle -big 1011121.121498
```

This will set the `name` `string` to `"J. Random"`, toggle the `active` `bool` to `true`, and set the `big` `float64` to `1011121.121498`

#### Details

The code above will translate into the following data structure:

```nim
type Options = object
    name:string
    active:bool
    letter:char
    age:int
    big:float64
    small:float
    flat:uint
    hello:string

options = Options(name: "Default Name", active: false, letter: 'a', age: 1, big: 1.1, small: 2.2, flat: 2)
```

This will then be modified at runtime, using whatever parameters the user has supplied on the command line.

---

### Parsing with `get_options_and_supplied`

Using a `get_options_and_supplied` block will behave just like `get_options`, except it will return a tuple of two objects.  The first is as detailed above.  The second object will have identical field names, but all its fields will be of type `bool`.

Any field which the user has supplied on the command line will have its `bool` in the second object set to `true`.

```nim
# foo.nim

let (options, supplied) = get_options_and_supplied:
    name          = "Default Name"
    active        = false
    letter        = 'a'
    age           = 1
    big:float64   = 1.1
    small:float   = 2.2
    flat:uint     = 2
    hello:string

if supplied.name and supplied.age:
    echo options.name & " is " & options.age.repr & " years old!"
```

---

# Default command-line syntax

By default, each named parameter may be set on the command line by the user prefixing it with a `-` or a `/`.  For `bool` fields, this will toggle the field.  For other fields, the next argument on the command line is used to set the field.

All of these will work:

```bash
foo -name "Joe Random" -active
foo /active /letter Z /flat 100
foo /hello Greetings! -big 100 /small 20
```s

---

# Settings

You may tailor the parser with the following calls:

## `no_dash()`

Disable parameter being identified by prefixing with `-`

## `no_slash()`

Disable parameter being identified by prefixing with `/`

## `require_double_dash()`

Require that parameters which have more than one character in their name be prefixed with `--` instead of `-`. Single-character parameters may then be entered grouped together under one `-`

## `allow_repetition()`

Allow the user to specify the same parameter more than once with reporting an error.

## `allow_errors()`

Allow program execution to continue after erroneous input.

## `no_implicit_bare()`

Do not automatically use the last `seq[string]` parameter to gather any bare parameters the user enters (they become erroneous instead)

## `manual_help()`
Disable automatic generation of help message when user enters `-?`, `-h` or `-help` (when you do not include them as parameters)

## `help_text(text: string, footer = "")`

Set the text which is included in the auto-generated help-message when the user enters `-?`, `-h`, or `-help`.
  * `text` is displayed at the top, before the parameters, and
  * `footer` is displayed at the bottom, after them.

Note: `help_text` may not be included in a `config:` chain

## `config:`

A helper macro which allows you to specify the above options (except `help_text`) as a call chain.  For example:

```nim
config: no_slash.require_double_dash.allow_repetition
```
