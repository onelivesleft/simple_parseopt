# simple_parseopt
Nim module which provides clean, zero-effort command line parsing.

---

## Basic Use

This module gives you two ways to parse the command line: `get_options` and `get_options_and_supplied`


**get_options**

At its simplest, declare a block like this:

```nim
# foo.nim

let options = get_options:
    name          = "Default Name"
    active        = false
    letter_one    = 'a'
    age           = 1
    hello:string
    big:float64   = 1.1
    small:float   = 2.2
    flat:uint     = 2
    arguments:seq[string]

echo options.name & " is " & options.age.repr & " years old!"
```

Notice it follows the same syntax as a `var` block.

In the example `foo.nim` above, the variable `options` will be set to an `object` with fields as described in the `get_options` block.  Each field will also be set up as a command-line parameter for the user running the program to use; bools will toggle, while other fields will take a value argument.

```bash
foo -name "J. Random" -active -big 1011121.121498 -letter-one z
```

This will set the `name` `string` to `"J. Random"`, toggle the `active` `bool` to `true`, set the `big` `float64` to `1011121.121498`, and set `letter_one` to `z` (notice the underscore in the field becomes a hyphen at the command line).

You may use any basic type: `bool`, `string`, `int`, `float`, `uint`, `char`, and the sized variants thereof, as well as `seq`s of those types: `seq[string]`, `seq[int]`, `seq[float]`, etc. (You may not use `seq[bool]`)

The last `seq[string]` will automatically be used to store any arguments set without a parameter name (you can disable this behaviour with `no_implicit_bare()`)


*Details*

The code above will translate into the equivalent of:

```nim
type Options = object
    name:string
    active:bool
    letter_one:char
    age:int
    hello:string
    big:float64
    small:float
    flat:uint
    arguments:seq[string]

options = Options(name: "Default Name", active: false, letter_one: 'a', age: 1, big: 1.1, small: 2.2, flat: 2)

parse_command_line_into(options)
```

Where `parse_command_line_into` is some hypothetical procedure which parses the user-supplied command line and sets fields in `options` appropriately.

---

**get_options_and_supplied**

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

## Default command-line syntax

By default, each named parameter may be set on the command line by the user prefixing it with a `-` or a `/`.  For `bool` fields, this will toggle the field.  For other fields, the next argument on the command line is used to set the field.

All of these will work:

```bash
foo -name "Joe Random" -active
foo /active /flat 100
foo /hello Greetings! -big 100 /small 20
```

---

## Extra Parameter Info: Pragmas

You may also add pragmas to the end of any line to modify parameter behaviour.  Each pragma has a more verbose alias, if you prefer that style of code.

* `{. info("text") .}` *or* `{. description("text") .}`

    Description of the parameter which will be shown in help text.


* `{. aka("a", "b", ...) .}` *or* `{. alias("a", "b", ...) .}`

    Aliases for the parameter - user may use these as parameters; they will write to the field.


* `{. bare .}` *or* `{. positional .}`

    Accepts a bare, positional argument (an argument which has not been prefixed with a parameter name).  User will not be able to refer to the argument with its parameter name.


* `{. need .}` *or* `.{ required .}`

    Parameter must be supplied by user or an error is shown.


* `{. len(i) .}` *or* `.{ count(i) .}`

    Place on a `seq` field to require that many values be supplied to it. For example:

    `position:seq[float] {. len(3) .} # x y z`

    Note that this does not set a limit on the total length of the `seq`, only on how many values the user must specify.  Using `len` in conjunction with the `allow_repetition` setting, you can accept multiple batches of values (see `normalize.nim` example)

---

## Settings

You may tailor the parser with the following calls:


* **no_dash()**

    Disable parameter being identified by prefixing with `-`


* **no_slash()**

    Disable parameter being identified by prefixing with `/`


* **dash_dash_parameters()**

    Require that parameters which have more than one character in their name be prefixed with `--` instead of `-`. Single-character parameters may then be entered grouped together under one `-`

* **dash_dash_separator()**

    `--` on its own in the command line will disable parameter names on every argument after it; they will all be treated as bare

* **value_after_colon()**

    Allow the user to specify parameter & value together, separated by a `:`

    e.g. `-param:value`

    Note this will not play nicely with quoted string values.

* **value_after_equals()**

    Allow the user to specify parameter & value together, separated by a `=`

    e.g. `-param=value`

    Note this will not play nicely with quoted string values.

* **allow_repetition()**

    Allow the user to specify the same parameter more than once without reporting an error.

* **allow_errors()**

    Allow program execution to continue after erroneous input.

* **no_implicit_bare()**

    Do not automatically use the last `seq[string]` parameter to gather any bare parameters the user enters (they become erroneous instead)

* **can_name_bare()**

    Allows user to set bare parameters by name.

* **manual_help()**

    Disable automatic generation of help message when user enters `-?`, `-h` or `-help` (when you do not include them as parameters)


* **command_name(name: string)**

    Set the name of the executable, for use in the auto-generated
    help-message when the user enters `-?`, `-h`, or `-help`.

    Note: `command_name` may not be included in a `config:` chain


* **help_text(text: string, footer = "")**

    Set the text which is included in the auto-generated help-message when the user enters `-?`, `-h`, or `-help`.

    * `text` is displayed at the top, before the parameters.
    * `footer` is displayed at the bottom, after them.

    Note: `help_text` may not be included in a `config:` chain

* **config:**

    A helper macro which allows you to specify the above options (except `help_text` and `command_name`) as a call chain.  For example:

    `simple_parseopt.config: no_slash.dash_dash_parameters.allow_repetition`
