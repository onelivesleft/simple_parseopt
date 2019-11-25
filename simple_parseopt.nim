import macros, tables, os, strutils
export tables
#
# @TODO: rewrite without dependencies.  Use seq instead of tables.
#

const
    TYPE_NAME = "Options"
    TYPE_PRESENT_NAME = "Options_Present"
    VAR_NAME = "options"
    VAR_PRESENT_NAME = "options_present"
    OFFSET_NAMES_NAME = "param_names"
    OFFSET_NAME = "param_offset"
    OFFSET_PRESENT_NAME = "param_present_offset"
    VAR_TYPE_NAME = "param_type"
    VAR_DEFAULT_NAME = "param_defaults"
    PROC_NAME = "parse"
    ARGUMENTS_NAME = "arguments"

when isMainModule:
    const DEBUG = true
else:
    const DEBUG = false

var
    dash_denotes_param = true
    slash_denotes_param = true
    use_double_dash = false
    parameters_are_unique = true
    quit_on_error = true
    automatic_help = true
    parameters_only = false
    help_text_pre = "Available parameters:\n"
    help_text_post = ""

proc allow_dash*(allow = true) =
    ## Set whether parameters may be specified by prefixing with `-`
    ## Default: ON
    dash_denotes_param = allow

proc allow_slash*(allow = true) =
    ## Set whether parameters may be specified by prefixing with `/`
    ## Default: ON
    slash_denotes_param = allow

proc require_double_dash*(require = false) =
    ## Set whether parameters which have more than one character in their name
    ## must be prefixed by `--`  instead of `-`
    ## Default: OFF
    use_double_dash = require

proc allow_repetition*(allow = true) =
    ## Set whether the same parameter may by set by the user more than once.
    ## Default: OFF
    parameters_are_unique = not allow

proc allow_errors*(allow = true) =
    ## Set whether program execution continues after erroneous input.
    ## Default: OFF
    quit_on_error = not allow

proc strict_parameters*(strict = true) =
    ## Set whether only specified parameters are allowed.  Disallows the
    ## entry of bare arguments.
    ## Default: OFF
    parameters_only = strict

proc manual_help*(manual = true) =
    ## Set whether `-?`, `-h` and `-help` will (if you do not include them)
    ## display auto-generated help text.
    ## Default: OFF
    automatic_help = not manual

proc help_text*(text: string, footer = "") =
    ## Set the text which is included in the auto-generated help-message
    ## when the user enters `-?`, `-h`, or `-help`.
    ##   `text` is displayed at the top, before the parameters, and
    ##   `footer` is displayed at the bottom, after them.
    ## Default: "Available parameters:\n" and ""
    help_text_pre = text
    help_text_post = footer

when DEBUG:
    var DEBUG_ARGS = "-name \"name has changed!\" -toggle"
    proc prettify[T](title: string, data: T, new_section = false) =
        if new_section:
            echo "--------------"
        echo title
        let s = $data
        var indenting = false
        for output in s[1 ..< ^1].strip.replace("[", "").replace("]", "").split(','):
            var line = output.strip()
            if line.ends_with("\"") and " = 0" in line:
                let start = line.find(" = 0")
                let skip = line.find("\"")
                line = line[0 ..< start + 3] & line[skip ..< ^0]
            if line.starts_with(ARGUMENTS_NAME & ": @"):
                line = line[line.find("\"") ..< ^0]
                indenting = true
                echo "arguments:"
            if indenting:
                if line.starts_with("\""):
                    line = "  " & line
                else:
                    indenting = false
            if line != "":
                echo line
        echo ""


type Param_Kind = enum
    param_undefined,
    param_int,
    param_i8,
    param_i16,
    param_i32,
    param_i64,
    param_uint,
    param_u8,
    param_u16,
    param_u32,
    param_u64,
    param_float,
    param_f32,
    param_f64,
    param_char,
    param_string,
    param_bool,
    param_seq

const
    int_param_undefined = 0
    int_param_int       = 1
    int_param_i8        = 2
    int_param_i16       = 3
    int_param_i32       = 4
    int_param_i64       = 5
    int_param_uint      = 6
    int_param_u8        = 7
    int_param_u16       = 8
    int_param_u32       = 9
    int_param_u64       = 10
    int_param_float     = 11
    int_param_f32       = 12
    int_param_f64       = 13
    int_param_char      = 14
    int_param_string    = 15
    int_param_bool      = 16
    int_param_seq       = 17




type Param = object
    name: string
    present: bool
    description: string
    alias: seq[string]
    case kind: ParamKind
    of param_undefined:    discard
    of param_int:          int_value: int
    of param_i8:           i8_value: int8
    of param_i16:          i16_value: int16
    of param_i32:          i32_value: int32
    of param_i64:          i64_value: int64
    of param_uint:         uint_value: uint
    of param_u8:           u8_value: uint8
    of param_u16:          u16_value: uint16
    of param_u32:          u32_value: uint32
    of param_u64:          u64_value: uint64
    of param_float:        float_value: float
    of param_f32:          f32_value: float32
    of param_f64:          f64_value: float64
    of param_char:         char_value: char
    of param_string:       string_value: string
    of param_bool:         bool_value: bool
    of param_seq:          seq_value: seq[string]


proc int_param_from_param(kind: Param_Kind): int =
    case kind:
    of param_undefined: return int_param_undefined
    of param_int: return int_param_int
    of param_i8: return int_param_i8
    of param_i16: return int_param_i16
    of param_i32: return int_param_i32
    of param_i64: return int_param_i64
    of param_uint: return int_param_uint
    of param_u8: return int_param_u8
    of param_u16: return int_param_u16
    of param_u32: return int_param_u32
    of param_u64: return int_param_u64
    of param_float: return int_param_float
    of param_f32: return int_param_f32
    of param_f64: return int_param_f64
    of param_char: return int_param_char
    of param_string: return int_param_string
    of param_bool: return int_param_bool
    of param_seq: return int_param_seq

proc param_from_nodes(name_node: Nim_Node, kind: Param_Kind, value_node: Nim_Node, pragma_node: Nim_Node): (Param, string) =
    let name = name_node.str_val.to_lower
    var param: Param
    if value_node == nil:
        case kind:
            of param_undefined: param = Param(name: name, kind: param_undefined)
            of param_int:     param = Param(name: name, kind: param_int)
            of param_i8:      param = Param(name: name, kind: param_i8)
            of param_i16:     param = Param(name: name, kind: param_i16)
            of param_i32:     param = Param(name: name, kind: param_i32)
            of param_i64:     param = Param(name: name, kind: param_i64)
            of param_uint:    param = Param(name: name, kind: param_uint)
            of param_u8:      param = Param(name: name, kind: param_u8)
            of param_u16:     param = Param(name: name, kind: param_u16)
            of param_u32:     param = Param(name: name, kind: param_u32)
            of param_u64:     param = Param(name: name, kind: param_u64)
            of param_float:   param = Param(name: name, kind: param_float)
            of param_f32:     param = Param(name: name, kind: param_f32)
            of param_f64:     param = Param(name: name, kind: param_f64)
            of param_char:    param = Param(name: name, kind: param_char)
            of param_string:  param = Param(name: name, kind: param_string)
            of param_bool:    param = Param(name: name, kind: param_bool)
            of param_seq:     param = Param(name: name, kind: param_seq)
    else:
        case kind:
        of param_undefined: param = Param(name: name, kind: param_undefined)
        of param_int:     param = Param(name: name, kind: param_int,    int_value:    cast[int](value_node.int_val))
        of param_i8:      param = Param(name: name, kind: param_i8,     i8_value:     cast[int8](value_node.int_val))
        of param_i16:     param = Param(name: name, kind: param_i16,    i16_value:    cast[int16](value_node.int_val))
        of param_i32:     param = Param(name: name, kind: param_i32,    i32_value:    cast[int32](value_node.int_val))
        of param_i64:     param = Param(name: name, kind: param_i64,    i64_value:    value_node.int_val)
        of param_uint:    param = Param(name: name, kind: param_uint,   uint_value:   cast[uint](value_node.int_val))
        of param_u8:      param = Param(name: name, kind: param_u8,     u8_value:     cast[uint8](value_node.int_val))
        of param_u16:     param = Param(name: name, kind: param_u16,    u16_value:    cast[uint16](value_node.int_val))
        of param_u32:     param = Param(name: name, kind: param_u32,    u32_value:    cast[uint32](value_node.int_val))
        of param_u64:     param = Param(name: name, kind: param_u64,    u64_value:    cast[uint64](value_node.int_val))
        of param_float:   param = Param(name: name, kind: param_float,  float_value:  value_node.float_val)
        of param_f32:     param = Param(name: name, kind: param_f32,    f32_value:    value_node.float_val)
        of param_f64:     param = Param(name: name, kind: param_f64,    f64_value:    value_node.float_val)
        of param_char:    param = Param(name: name, kind: param_char,   char_value:   cast[char](value_node.int_val))
        of param_string:  param = Param(name: name, kind: param_string, string_value: value_node.str_val)
        of param_bool:    param = Param(name: name, kind: param_bool,   bool_value:   value_node.str_val == "true")
        of param_seq:     param = Param(name: name, kind: param_seq,    seq_value:    @[value_node.str_val])
    if pragma_node != nil:
        for child in pragma_node.children:
            if child.kind != nnk_call or len(child) < 2 or child[0].kind != nnk_ident:
                error("Invalid pragma node", child)
            elif child[0].str_val == "alias":
                for i, alias in child.children.pairs:
                    if i > 0:
                        if alias.kind != nnk_str_lit:
                            error("Invalid pragma node", alias)
                        else:
                            param.alias.add alias.str_val
            elif child[0].str_val == "info":
                if child[1].kind != nnk_str_lit:
                    error("Invalid pragma node", child[1])
                else:
                    param.description = child[1].str_val
            else:
                error("Invalid pragma node")
    return (param, name)


proc kind_from_lit(lit: Nim_Node): Param_Kind =
    case lit.kind
    of nnk_int_lit:
        return param_int
    of nnk_float_lit:
        return param_float
    of nnk_char_lit:
        return param_char
    of nnk_str_lit:
        return param_string
    of nnk_ident:
        if lit.str_val == "true" or lit.str_val == "false":
            return param_bool
        else:
            return param_undefined
    else:
        return param_undefined


proc ident_from_kind(kind: Param_Kind): Nim_Node =
    case kind
    of param_undefined:    return nil
    of param_seq:          return nil
    of param_int:          return ident("int")
    of param_i8:           return ident("int8")
    of param_i16:          return ident("int16")
    of param_i32:          return ident("int32")
    of param_i64:          return ident("int64")
    of param_uint:         return ident("uint")
    of param_u8:           return ident("uint8")
    of param_u16:          return ident("uint16")
    of param_u32:          return ident("uint32")
    of param_u64:          return ident("uint64")
    of param_float:        return ident("float")
    of param_f32:          return ident("float32")
    of param_f64:          return ident("float64")
    of param_char:         return ident("char")
    of param_string:       return ident("string")
    of param_bool:         return ident("bool")


proc kind_from_ident(ident: Nim_node): Param_Kind =
    case ident.str_val
    of "int":       return param_int
    of "int8":      return param_i8
    of "int16":     return param_i16
    of "int32":     return param_i32
    of "int64":     return param_i64
    of "uint":      return param_uint
    of "uint8":     return param_u8
    of "uint16":    return param_u16
    of "uint32":    return param_u32
    of "uint64":    return param_u64
    of "float":     return param_float
    of "float32":   return param_f32
    of "float64":   return param_f64
    of "char":      return param_char
    of "string":    return param_string
    of "true":      return param_bool
    of "false":     return param_bool
    else:           return param_undefined


proc value_node_from_param(param: Param): Nim_Node =
    case param.kind:
    of param_undefined: return nil
    of param_seq:       return nil
    of param_int:       return new_int_lit_node(param.int_value)
    of param_i8:        return new_int_lit_node(param.i8_value)
    of param_i16:       return new_int_lit_node(param.i16_value)
    of param_i32:       return new_int_lit_node(param.i32_value)
    of param_i64:       return new_int_lit_node(param.i64_value)
    of param_uint:      return new_int_lit_node(cast[Biggest_Int](param.uint_value))
    of param_u8:        return new_int_lit_node(cast[Biggest_Int](param.u8_value))
    of param_u16:       return new_int_lit_node(cast[Biggest_Int](param.u16_value))
    of param_u32:       return new_int_lit_node(cast[Biggest_Int](param.u32_value))
    of param_u64:       return new_int_lit_node(cast[Biggest_Int](param.u64_value))
    of param_float:     return new_float_lit_node(param.float_value)
    of param_f32:       return new_float_lit_node(param.f32_value)
    of param_f64:       return new_float_lit_node(param.f64_value)
    of param_char:      return new_lit(param.char_value)
    of param_string:    return new_str_lit_node(param.string_value)
    of param_bool:
        if param.bool_value:
            return ident("true")
        else:
            return ident("false")

proc string_from_param(param: Param): string =
    case param.kind:
    of param_undefined: return ""
    of param_seq:       return ""
    of param_int:       return repr(param.int_value)
    of param_i8:        return repr(param.i8_value)
    of param_i16:       return repr(param.i16_value)
    of param_i32:       return repr(param.i32_value)
    of param_i64:       return repr(param.i64_value)
    of param_uint:      return repr(param.uint_value)
    of param_u8:        return repr(param.u8_value)
    of param_u16:       return repr(param.u16_value)
    of param_u32:       return repr(param.u32_value)
    of param_u64:       return repr(param.u64_value)
    of param_float:     return repr(param.float_value)
    of param_f32:       return repr(param.f32_value)
    of param_f64:       return repr(param.f64_value)
    of param_char:      return repr(param.char_value)
    of param_string:    return param.string_value
    of param_bool:
        if param.bool_value:
            return "true"
        else:
            return "false"


type Assignment = tuple
    kind: Param_Kind
    name_node: Nim_Node
    value_node: Nim_Node
    pragma_node: Nim_Node
    error: int

proc assignment_from_node(node: Nim_Node): Assignment =
    if node.kind == nnk_asgn: # simple assignment
        if node.len != 2 or node[0].kind != nnk_ident:                                                  # error 1
            return (param_undefined, nil, nil, nil, 1)
        elif node[1].kind == nnk_pragma_expr and len(node[1]) == 2 and node[1][1].kind == nnk_pragma:   # x = n + pragma
            return (kind_from_lit(node[1][0]), node[0], node[1][0], node[1][1], 0)
        else:                                                                                           # x = n
            return (kind_from_lit(node[1]), node[0], node[1], nil, 0)
    elif node.kind == nnk_call: # typed assignment
        if node.len != 2 or node[0].kind != nnk_ident or node[1].kind != nnk_stmt_list:                 # error 2
            return (param_undefined, nil, nil, nil, 2)
        elif node[1].len == 1 and node[1][0].kind == nnk_ident:                                         # x:t
            return (kind_from_ident(node[1][0]), node[0], nil, nil, 0)
        elif node[1].len == 1 and node[1][0].kind == nnk_pragma_expr:                                   # x:t + pragma
            return (kind_from_ident(node[1][0][0]), node[0], nil, node[1][0][1], 0)
        elif node[1].len != 1 or node[1][0].kind != nnk_asgn:                                           # error 3
            return (param_undefined, nil, nil, nil, 3)
        elif node[1][0].len != 2 or node[1][0][0].kind != nnk_ident:                                    # error 4
            return (param_undefined, nil, nil, nil, 4)
        elif node[1][0].len == 2 and node[1][0][1].kind == nnk_pragma_expr:                             # x:t = n + pragma
            return (kind_from_ident(node[1][0][0]), node[0], node[1][0][1][0], node[1][0][1][1], 0)
        else:                                                                                           # x:t = n
            return (kind_from_ident(node[1][0][0]), node[0], node[1][0][1], nil, 0)


macro get_options_and_supplied*(body: untyped): untyped =
    ## Parses the command-line arguments provided by the user,
    ## using it and the code block to fill out an object's fields.
    ##
    ## Returns a tuple of two objects: the first as detailed by
    ## the code block, the second a mirror of it, but all of `bool`.
    ## For any parameters which the user has supplied on the command line,
    ## the field on the second object will be set to `true`.
    ##
    ## The block is filled out as if it were a `var` block.
    ## All basic intrinsic types are supported.
    ## i.e. all of these are valid:
    ##
    ##   x = 0
    ##   x:int32
    ##   x:int = 20
    ##
    ## You may also add pragmas to the end of any line:
    ##
    ##   (. info("Description") .}  = description of the parameter
    ##   {. alias("a", "b", ...) .} = aliases for the parameter
    ##
    ## Example:
    ##
    ## let options, supplied = get_options_and_supplied:
    ##     teenager = "Joe Random" {. alias("name", "n") .}
    ##     age[int8] = 13
    ##     nin:string              {. info("National Insurance Number") .}
    ##
    ## if not supplied.nin:
    ##     echo "Must supply NIN"
    ##     quit(1)
    ##
    ## if options.age < 13 or options.age > 19:
    ##     echo "Not a teenager!"
    ##     quit(1)


    if body.kind != nnk_stmt_list:
        error("Block expected, e.g. var opts = parse_params: ...", body)

    var params = init_table[string, Param]()
    var params_in_order: seq[string] = @[]

    for node in body.children:
        var (kind, name_node, value_node, pragma_node, error) = assignment_from_node(node)
        if  kind == param_undefined:
            error("Expected declaration, e.g. x = 1 or x:int = 1 or x:int [ERR:" & error.repr & "]", node)
        let (param, name) = param_from_nodes(name_node, kind, value_node, pragma_node)
        if name in params:
            error("Duplicate param.", node)
        params[name] = param
        params_in_order.add(name)

    var param_names_node = new_nim_node(nnk_var_section)
    param_names_node.add(
        nnk_ident_defs.new_tree(
            ident(OFFSET_NAMES_NAME),
            new_empty_node(),
            nnk_call.new_tree(
                nnk_bracket_expr.new_tree(
                    ident("new_seq"),
                    ident("string")))))

    var param_node = new_nim_node(nnk_var_section)
    param_node.add(
        nnk_ident_defs.new_tree(
            ident(OFFSET_NAME),
            new_empty_node(),
            nnk_call.new_tree(
                nnk_bracket_expr.new_tree(
                    ident("new_seq"),
                    ident("uint")))))

    var param_present_node = new_nim_node(nnk_var_section)
    param_present_node.add(
        nnk_ident_defs.new_tree(
            ident(OFFSET_PRESENT_NAME),
            new_empty_node(),
            nnk_call.new_tree(
                nnk_bracket_expr.new_tree(
                    ident("new_seq"),
                    ident("uint")))))

    var param_type_node = new_nim_node(nnk_var_section)
    param_type_node.add(
        nnk_ident_defs.new_tree(
            ident(VAR_TYPE_NAME),
            new_empty_node(),
            nnk_call.new_tree(
                nnk_bracket_expr.new_tree(
                    ident("new_seq"),
                    ident("int")))))

    var param_default_node = new_nim_node(nnk_var_section)
    param_default_node.add(
        nnk_ident_defs.new_tree(
            ident(VAR_DEFAULT_NAME),
            new_empty_node(),
            nnk_call.new_tree(
                nnk_bracket_expr.new_tree(
                    ident("new_seq"),
                    ident("string")))))

    var offset_node = new_nim_node(nnk_block_stmt)
    offset_node.add new_empty_node()
    offset_node.add new_nim_node(nnk_stmt_list)

    let proc_name = ident(PROC_NAME)
    let type_name = ident(TYPE_NAME)
    let present_type_name = ident(TYPE_PRESENT_NAME)
    let outer_param_names = ident(OFFSET_NAMES_NAME)
    let outer_param_offset = ident(OFFSET_NAME)
    let outer_param_present_offset = ident(OFFSET_PRESENT_NAME)
    let outer_param_type = ident(VAR_TYPE_NAME)
    let outer_param_default = ident(VAR_DEFAULT_NAME)

    var proc_node = quote do:
        proc `proc_name`(options: var `type_name`, present: var `present_type_name`): (`type_name`, `present_type_name`) =

            when DEBUG:
                prettify("Options", options.repr, true)
                prettify("Present", present.repr)

            template parse_error(err: string) =
                echo err
                if quit_on_error:
                    quit(1)

            proc index_from_name(name: string): int =
                for (i, n) in `outer_param_names`.pairs:
                    if n == name:
                        return i
                parse_error("Cannot find option: " & name)

            proc get_param_offset(name: string): uint =
                return `outer_param_offset`[index_from_name(name)]

            proc get_param_present_offset(name: string): uint =
                return `outer_param_present_offset`[index_from_name(name)]

            proc get_param_type(name: string): int =
                return `outer_param_type`[index_from_name(name)]

            proc do_help() =
                echo help_text
                var prefix = ""
                if dash_denotes_param:
                    prefix = "-"
                elif slash_denotes_param:
                    prefix = "/"
                var letters = 0
                for i, name in `outer_param_names`[0 ..< ^1]:
                    if name.len > letters: letters = name.len
                for i, name in `outer_param_names`[0 ..< ^1]:
                    var default = `outer_param_default`[i]
                    if default == "" or `outer_param_type`[i] == `int_param_bool`:
                        echo " ", prefix, name
                    else:
                        var spacer = ""
                        while name.len + spacer.len < letters:
                            spacer = spacer & " "
                        echo " ", prefix, name, spacer, "     [", default, "]"
                echo ""

            proc is_present(address: ptr `present_type_name`, name: string): bool =
                let field = cast[ptr bool](cast[uint](address) + get_param_present_offset(name))
                return field[]

            proc set_present(address: ptr `present_type_name`, name: string) =
                let field = cast[ptr bool](cast[uint](address) + get_param_present_offset(name))
                field[] = true

            proc int_from_string[T](s: string): (T, bool) =
                try:
                    result = (cast[T](parse_biggest_int(s)), true)
                except:
                    return (cast[T](0), false)

            proc uint_from_string[T](s: string): (T, bool) =
                try:
                    result = (cast[T](parse_biggest_uint(s)), true)
                except:
                    return (cast[T](0), false)

            proc float_from_string[T](s: string): (T, bool) =
                try:
                    result = (cast[T](parse_float(s)), true)
                except:
                    return (cast[T](0), false)

            proc set_value(address: ptr `type_name`, name: string, value: string = ""): bool =
                let kind = get_param_type(name)
                case kind
                of `int_param_string`:
                    let field = cast[ptr string](cast[uint](address) + get_param_offset(name))
                    field[] = value
                    return true
                of `int_param_bool`:
                    let field = cast[ptr bool](cast[uint](address) + get_param_offset(name))
                    field[] = not field[]
                    return true
                of `int_param_int`:
                    let (parsed_value, success) = int_from_string[int](value)
                    if success:
                        let field = cast[ptr int](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_i8`:
                    let (parsed_value, success) = int_from_string[int8](value)
                    if success:
                        let field = cast[ptr int8](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_i16`:
                    let (parsed_value, success) = int_from_string[int16](value)
                    if success:
                        let field = cast[ptr int16](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_i32`:
                    let (parsed_value, success) = int_from_string[int32](value)
                    if success:
                        let field = cast[ptr int32](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_i64`:
                    let (parsed_value, success) = int_from_string[int64](value)
                    if success:
                        let field = cast[ptr int64](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_uint`:
                    let (parsed_value, success) = uint_from_string[uint](value)
                    if success:
                        let field = cast[ptr uint](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_u8`:
                    let (parsed_value, success) = uint_from_string[uint8](value)
                    if success:
                        let field = cast[ptr uint8](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_u16`:
                    let (parsed_value, success) = uint_from_string[uint16](value)
                    if success:
                        let field = cast[ptr uint16](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_u32`:
                    let (parsed_value, success) = uint_from_string[uint32](value)
                    if success:
                        let field = cast[ptr uint32](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_u64`:
                    let (parsed_value, success) = uint_from_string[uint64](value)
                    if success:
                        let field = cast[ptr uint64](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_float`:
                    let (parsed_value, success) = float_from_string[float](value)
                    if success:
                        let field = cast[ptr float](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_f32`:
                    let (parsed_value, success) = float_from_string[float32](value)
                    if success:
                        let field = cast[ptr float32](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_f64`:
                    let (parsed_value, success) = float_from_string[float64](value)
                    if success:
                        let field = cast[ptr float64](cast[uint](address) + get_param_offset(name))
                        field[] = parsed_value
                    return success
                of `int_param_char`:
                    if value.len != 1: return false
                    let field = cast[ptr char](cast[uint](address) + get_param_offset(name))
                    field[] = value[0]
                    return true
                of `int_param_undefined`:
                    return false
                of `int_param_seq`:
                    return false
                else:
                    return false

            var
                awaiting_value = false
                awaiting_value_for = ""

            when DEBUG:
                let words:seq[string] = parse_cmd_line(DEBUG_ARGS)
            else:
                let words:seq[string] = command_line_params()
            for word in words:
                if (dash_denotes_param and word.starts_with("-")) or (slash_denotes_param and word.starts_with("/")):
                    if awaiting_value:
                        parse_error("Expected value for: " & awaiting_value_for)
                    var name = word[1 ..< ^0].to_lower
                    if not `outer_param_names`.contains(name):
                        if automatic_help and (name == "help" or name == "h" or name == "?"):
                            do_help()
                            quit(0)
                        else:
                            parse_error("No such parameter: " & word)
                    if parameters_are_unique and is_present(addr present, name):
                        parse_error("Parameter already set: " & word)

                    if get_param_type(name) == `int_param_bool`:
                        if set_value(addr options, name):
                            set_present(addr present, name)
                        else:
                            parse_error("Failed to set " & word & ": this should not happen!")
                    else:
                        awaiting_value = true
                        awaiting_value_for = name
                else:
                    if awaiting_value:
                        if set_value(addr options, awaiting_value_for, word):
                            set_present(addr present, awaiting_value_for)
                            awaiting_value = false
                        else:
                            parse_error("Could not parse value for: " & word)
                    elif parameters_only:
                        parse_error("No such parameter: " & word)
                    else:
                        let field = cast[ptr seq[string]](cast[uint](addr options) + get_param_offset(`ARGUMENTS_NAME`))
                        field[].add word
                        set_present(addr present, `ARGUMENTS_NAME`)


            if awaiting_value:
                parse_error("Expected value for: " & awaiting_value_for)

            return (options, present)


    var type_node = new_nim_node(nnk_type_section)
    var present_type_node = new_nim_node(nnk_type_section)
    var var_node = new_nim_node(nnk_var_section)
    var present_var_node = new_nim_node(nnk_var_section)
    var call_node = new_nim_node(nnk_call)

    result = new_nim_node(nnk_block_stmt)
    result.add new_empty_node()
    result.add new_nim_node(nnk_stmt_list)

    result[1].add type_node
    result[1].add present_type_node
    result[1].add var_node
    result[1].add present_var_node
    result[1].add param_names_node
    result[1].add param_node
    result[1].add param_present_node
    result[1].add param_type_node
    result[1].add param_default_node
    result[1].add offset_node
    result[1].add proc_node
    result[1].add call_node

    type_node.add new_nim_node(nnk_type_def)
    type_node[0].add ident(TYPE_NAME)
    type_node[0].add new_empty_node()
    type_node[0].add new_nim_node(nnk_object_ty)
    type_node[0][2].add new_empty_node()
    type_node[0][2].add new_empty_node()
    type_node[0][2].add new_nim_node(nnk_rec_list)
    type_node = type_node[0][2][2]

    present_type_node.add new_nim_node(nnk_type_def)
    present_type_node[0].add ident(TYPE_PRESENT_NAME)
    present_type_node[0].add new_empty_node()
    present_type_node[0].add new_nim_node(nnk_object_ty)
    present_type_node[0][2].add new_empty_node()
    present_type_node[0][2].add new_empty_node()
    present_type_node[0][2].add new_nim_node(nnk_rec_list)
    present_type_node = present_type_node[0][2][2]

    var_node.add new_nim_node(nnk_ident_defs)
    var_node[0].add ident(VAR_NAME)
    var_node[0].add new_empty_node()
    var_node[0].add new_nim_node(nnk_obj_constr)
    var_node = var_node[0][2]

    present_var_node.add new_nim_node(nnk_ident_defs)
    present_var_node[0].add ident(VAR_PRESENT_NAME)
    present_var_node[0].add new_empty_node()
    present_var_node[0].add new_nim_node(nnk_call)
    present_var_node = present_var_node[0][2]

    var_node.add ident(TYPE_NAME)
    present_var_node.add ident(TYPE_PRESENT_NAME)

    offset_node = offset_node[1]

    call_node.add ident(PROC_NAME)
    call_node.add ident(VAR_NAME)
    call_node.add ident(VAR_PRESENT_NAME)


    template add_type(name: string, kind: ParamKind) =
        type_node.add(
            nnk_ident_defs.new_tree(
                ident(name),
                ident_from_kind(kind),
                new_empty_node()))
        present_type_node.add(
            nnk_ident_defs.new_tree(
                ident(name),
                ident("bool"),
                new_empty_node()))

    template add_var(name: string, value_node: Nim_Node) =
        var_node.add(
            nnk_expr_colon_expr.new_tree(
                ident(name),
                value_node.copy_nim_node))

    template add_offset(name: string) =
        offset_node.add(
            nnk_call.new_tree(
                nnk_dot_expr.new_tree(
                    ident(OFFSET_NAME),
                    ident("add")),
                nnk_infix.new_tree(
                    ident("-"),
                    nnk_cast.new_tree(
                        ident("uint"),
                        nnk_command.new_tree(
                            ident("addr"),
                            nnk_dot_expr.new_tree(
                                ident(VAR_NAME),
                                ident(name)))),
                    nnk_cast.new_tree(
                        ident("uint"),
                        nnk_command.new_tree(
                            ident("addr"),
                            ident(VAR_NAME))))))

    template add_present_offset(name: string) =
        offset_node.add(
            nnk_call.new_tree(
                nnk_dot_expr.new_tree(
                    ident(OFFSET_PRESENT_NAME),
                    ident("add")),
                nnk_infix.new_tree(
                    ident("-"),
                    nnk_cast.new_tree(
                        ident("uint"),
                        nnk_command.new_tree(
                            ident("addr"),
                            nnk_dot_expr.new_tree(
                                ident(VAR_PRESENT_NAME),
                                ident(name)))),
                    nnk_cast.new_tree(
                        ident("uint"),
                        nnk_command.new_tree(
                            ident("addr"),
                            ident(VAR_PRESENT_NAME))))))

    template add_name(name: string) =
        offset_node.add(
            nnk_call.new_tree(
                nnk_dot_expr.new_tree(
                    ident(OFFSET_NAMES_NAME),
                    ident("add")),
                new_str_lit_node(name)))

    template add_type_lookup(name: string, kind: Param_Kind) =
        offset_node.add(
            nnk_call.new_tree(
                nnk_dot_expr.new_tree(
                    ident(VAR_TYPE_NAME),
                    ident("add")),
                new_int_lit_node(int_param_from_param(kind))))

    template add_default_value(name: string, default: string) =
        offset_node.add(
            nnk_call.new_tree(
                nnk_dot_expr.new_tree(
                    ident(VAR_DEFAULT_NAME),
                    ident("add")),
                new_str_lit_node(default)))

    for name in params_in_order:
        let param = params[name]
        add_type name, param.kind
        add_var name, value_node_from_param(param)
        add_offset name
        add_present_offset name
        add_name name
        add_type_lookup name, param.kind
        add_default_value name, string_from_param(param)

    # arguments list for loose args
    type_node.add nnk_ident_defs.new_tree(
        ident(ARGUMENTS_NAME),
        nnk_bracket_expr.new_tree(
            ident("seq"),
            ident("string")),
        new_empty_node())
    present_type_node.add nnk_ident_defs.new_tree(
        ident(ARGUMENTS_NAME),
        ident("bool"),
        new_empty_node())
    add_offset ARGUMENTS_NAME
    add_present_offset ARGUMENTS_NAME
    add_name ARGUMENTS_NAME
    add_type_lookup ARGUMENTS_NAME, param_seq
    add_default_value ARGUMENTS_NAME, ""


macro get_options*(body: untyped): untyped =
    ## Parses the command-line arguments provided by the user,
    ## using it and the code block to fill out an object's fields.
    ##
    ## Returns an object whose fields are detailed by the code block.
    ##
    ## The block is filled out as if it were a `var` block.
    ## All basic intrinsic types are supported.
    ## i.e. all of these are valid:
    ##
    ##   x = 0
    ##   x:int32
    ##   x:int = 20
    ##
    ## You may also add pragmas to the end of any line:
    ##
    ##   (. info("Description") .}  = description of the parameter
    ##   {. alias("a", "b", ...) .} = aliases for the parameter
    ##
    ## Example:
    ##
    ## let options = get_options:
    ##     teenager = "Joe Random" {. alias("name", "n") .}
    ##     age[int8] = 13
    ##     nin:string              {. info("National Insurance Number") .}
    ##
    ## if options.nin.len != 9:
    ##     echo "Must supply valid NIN"
    ##     quit(1)
    ##
    ## if options.age < 13 or options.age > 19:
    ##     echo "Not a teenager!"
    ##     quit(1)
    var options, _ = quote do:
        get_options_and_supplied(`body`)[0]
    return options


when DEBUG:
    DEBUG_ARGS = "-age 2 -here albert -there -big 10 -name \"Iain King\" -flat 5 -letter z bob"

#    var options = get_options:
#        name = "Default Name"
#        toggle = false
#        letter = 'a'
#        age = 1 {. min(0) .}
#        here = true
#        there = false
#        big:float64 = 1.1
#        small:float = 2.2 {. blobby .}
#        flat:uint = 2
#        hello:string {. ok .}
#
#    echo options.repr
#    prettify("Options", parsed_params, true)
    #prettify("Present", is_set.repr)

#template ok {. pragma .}
#template min(bound: int) {. pragma .}
#
dump_tree:
    x = 1 {.alias("x", "y", "z").}
    y:int {. info("A Y and only a Y") .}
