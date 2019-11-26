import macros, tables, os, strutils

#
# @TODO:
#
#  {. alias .}
#  {. len .}
#  {. required .}
#  seq = @[] initializer
#  bare after --
#
# automatic_help upgrade
# param:value / param=value

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
    VAR_DESCRIPTION_NAME = "param_descriptions"
    VAR_BARE_NAME = "param_bare_indexes"
    PROC_NAME = "parse"

when isMainModule:
    const DEBUG = true
else:
    const DEBUG = false

var
    dash_denotes_param = true
    slash_denotes_param = true
    use_double_dash = false
    double_dash_separator = false
    implicit_bare = true
    quit_on_error = true
    automatic_help = true
    parameters_are_unique = true
    help_text_pre = "Available parameters:\n"
    help_text_post = ""


macro config*(body: untyped): untyped =
    ## Helper macro to let you easily specify several config options.
    ##
    ## Example:
    ##
    ##     config: no_slash.require_double_dash.allow_repetition
    ##

    proc check_for_help_text(node: Nim_Node): Nim_Node =
        if node.kind == nnk_ident and node.str_val == "help_text":
            return node
        elif node.len > 0:
            for child in node.children:
                var help_node = check_for_help_text(child)
                if help_node != nil:
                    return help_node
        return nil

    let help_node = check_for_help_text(body)
    if help_node != nil:
        error("Cannot include `help_text` proc in config chain", help_node)

    body.expect_kind(nnk_stmt_list)
    if body.len != 1: error("Expected dot expression", body)

    result = new_nim_node(nnk_stmt_list)
    if body[0].kind == nnk_ident:
        result.add nnk_call.new_tree(body[0].copy_nim_node)
    else:
        body[0].expect_kind(nnk_dot_expr)
        proc walk(node: Nim_Node, write: Nim_Node) =
            if node.len == 2:
                if node[0].kind == nnk_ident and node[1].kind == nnk_ident:
                    write.add nnk_call.new_tree(node[0].copy_nim_node)
                    write.add nnk_call.new_tree(node[1].copy_nim_node)
                elif node[0].kind == nnk_dot_expr and node[1].kind == nnk_ident:
                    walk(node[0], write)
            else:
                error("Expected dot expression", node)
        walk body[0], result


proc no_dash*() =
    ## Disable parameter being identified by prefixing with `-`
    dash_denotes_param = false

proc no_slash*() =
    ## Disable parameter being identified by prefixing with `/`
    slash_denotes_param = false

proc dash_dash_parameters*() =
    ## Require that parameters which have more than one character in their name
    ## be prefixed with `--` instead of `-`.
    ## Single-character parameters may then be entered grouped together under
    ## one `-`
    use_double_dash = true

proc dash_dash_separator*() =
    ## A `--` on its own will disable parameter names on every argument
    ## after it; they will all be treate as bare.
    double_dash_separator = true

proc allow_repetition*() =
    ## Allow the user to specify the same parameter more than once with reporting
    ## an error.
    parameters_are_unique = false

proc allow_errors*() =
    ## Allow program execution to continue after erroneous input.
    quit_on_error = true

proc no_implicit_bare*() =
    ## Do not automatically use the last seq[string] parameter to gather any
    ## bare parameters the user enters (instead they become erroneous)
    implicit_bare = false

proc manual_help*() =
    ## Disable automatic generation of help message when user enters
    ## `-?`, `-h` or `-help` (when you do not include them as parameters)
    automatic_help = false

proc help_text*(text: string, footer = "") =
    ## Set the text which is included in the auto-generated help-message
    ## when the user enters `-?`, `-h`, or `-help`.
    ##   `text` is displayed at the top, before the parameters, and
    ##   `footer` is displayed at the bottom, after them.
    ##
    ##   Note: help_text may not be included in a `config:` chain
    ##
    ## Default: "Available parameters:\n" and ""
    help_text_pre = text
    if footer != "":
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
            if line.contains(": @"):
                let c = line.find("@")
                echo line[0 ..< c]
                line = line[c + 1 ..< ^0]
                indenting = true
            if indenting:
                if line.contains(":"):
                    indenting = false
                else:
                    line = "  " & line
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
    param_seq_string,
    param_seq_int,
    param_seq_float,


const
    int_param_undefined  = 0
    int_param_int        = 1
    int_param_i8         = 2
    int_param_i16        = 3
    int_param_i32        = 4
    int_param_i64        = 5
    int_param_uint       = 6
    int_param_u8         = 7
    int_param_u16        = 8
    int_param_u32        = 9
    int_param_u64        = 10
    int_param_float      = 11
    int_param_f32        = 12
    int_param_f64        = 13
    int_param_char       = 14
    int_param_string     = 15
    int_param_bool       = 16
    int_param_seq_string = 17
    int_param_seq_int    = 18
    int_param_seq_float  = 19


type Param = object
    name: string
    accepts_bare: bool
    description: string
    alias: seq[string]
    seq_len: int
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
    of param_seq_string:   seq_string_value: seq[string]
    of param_seq_int:      seq_int_value: seq[int]
    of param_seq_float:    seq_float_value: seq[float]


proc int_param_from_param(kind: Param_Kind): int =
    case kind:
    of param_undefined:  return int_param_undefined
    of param_int:        return int_param_int
    of param_i8:         return int_param_i8
    of param_i16:        return int_param_i16
    of param_i32:        return int_param_i32
    of param_i64:        return int_param_i64
    of param_uint:       return int_param_uint
    of param_u8:         return int_param_u8
    of param_u16:        return int_param_u16
    of param_u32:        return int_param_u32
    of param_u64:        return int_param_u64
    of param_float:      return int_param_float
    of param_f32:        return int_param_f32
    of param_f64:        return int_param_f64
    of param_char:       return int_param_char
    of param_string:     return int_param_string
    of param_bool:       return int_param_bool
    of param_seq_string: return int_param_seq_string
    of param_seq_int:    return int_param_seq_int
    of param_seq_float:  return int_param_seq_float


proc param_from_nodes(name_node: Nim_Node, kind: Param_Kind, value_node: Nim_Node, pragma_node: Nim_Node): (Param, string) =
    let name = name_node.str_val.to_lower
    var param: Param
    if value_node == nil:
        case kind:
            of param_undefined:  param = Param(name: name, kind: param_undefined)
            of param_int:        param = Param(name: name, kind: param_int)
            of param_i8:         param = Param(name: name, kind: param_i8)
            of param_i16:        param = Param(name: name, kind: param_i16)
            of param_i32:        param = Param(name: name, kind: param_i32)
            of param_i64:        param = Param(name: name, kind: param_i64)
            of param_uint:       param = Param(name: name, kind: param_uint)
            of param_u8:         param = Param(name: name, kind: param_u8)
            of param_u16:        param = Param(name: name, kind: param_u16)
            of param_u32:        param = Param(name: name, kind: param_u32)
            of param_u64:        param = Param(name: name, kind: param_u64)
            of param_float:      param = Param(name: name, kind: param_float)
            of param_f32:        param = Param(name: name, kind: param_f32)
            of param_f64:        param = Param(name: name, kind: param_f64)
            of param_char:       param = Param(name: name, kind: param_char)
            of param_string:     param = Param(name: name, kind: param_string)
            of param_bool:       param = Param(name: name, kind: param_bool)
            of param_seq_string: param = Param(name: name, kind: param_seq_string)
            of param_seq_int:    param = Param(name: name, kind: param_seq_int)
            of param_seqfloat:   param = Param(name: name, kind: param_seq_float)
    else:
        case kind:
        of param_undefined:  param = Param(name: name, kind: param_undefined)
        of param_int:        param = Param(name: name, kind: param_int,        int_value:        cast[int](value_node.int_val))
        of param_i8:         param = Param(name: name, kind: param_i8,         i8_value:         cast[int8](value_node.int_val))
        of param_i16:        param = Param(name: name, kind: param_i16,        i16_value:        cast[int16](value_node.int_val))
        of param_i32:        param = Param(name: name, kind: param_i32,        i32_value:        cast[int32](value_node.int_val))
        of param_i64:        param = Param(name: name, kind: param_i64,        i64_value:        value_node.int_val)
        of param_uint:       param = Param(name: name, kind: param_uint,       uint_value:       cast[uint](value_node.int_val))
        of param_u8:         param = Param(name: name, kind: param_u8,         u8_value:         cast[uint8](value_node.int_val))
        of param_u16:        param = Param(name: name, kind: param_u16,        u16_value:        cast[uint16](value_node.int_val))
        of param_u32:        param = Param(name: name, kind: param_u32,        u32_value:        cast[uint32](value_node.int_val))
        of param_u64:        param = Param(name: name, kind: param_u64,        u64_value:        cast[uint64](value_node.int_val))
        of param_float:      param = Param(name: name, kind: param_float,      float_value:      value_node.float_val)
        of param_f32:        param = Param(name: name, kind: param_f32,        f32_value:        value_node.float_val)
        of param_f64:        param = Param(name: name, kind: param_f64,        f64_value:        value_node.float_val)
        of param_char:       param = Param(name: name, kind: param_char,       char_value:       cast[char](value_node.int_val))
        of param_string:     param = Param(name: name, kind: param_string,     string_value:     value_node.str_val)
        of param_bool:       param = Param(name: name, kind: param_bool,       bool_value:       value_node.str_val == "true")
        of param_seq_string: param = Param(name: name, kind: param_seq_string, seq_string_value: @[])
        of param_seq_int:    param = Param(name: name, kind: param_seq_int,    seq_int_value:    @[])
        of param_seq_float:  param = Param(name: name, kind: param_seq_float,  seq_float_value:  @[])

    if pragma_node != nil:
        if pragma_node.kind == nnk_ident and pragma_node.str_val == "bare":
            param.accepts_bare = true
        else:
            for child in pragma_node.children:
                if child.kind == nnk_ident and child.str_val == "bare":
                    param.accepts_bare = true
                elif child.kind != nnk_call or len(child) < 2 or child[0].kind != nnk_ident:
                    error("invalid pragma", child)
                elif child[0].str_val == "alias":
                    for i, alias in child.children.pairs:
                        if i > 0:
                            if alias.kind != nnk_str_lit:
                                error("invalid pragma", alias)
                            else:
                                param.alias.add alias.str_val
                elif child[0].str_val == "info":
                    if child[1].kind != nnk_str_lit:
                        error("invalid pragma", child[1])
                    else:
                        param.description = child[1].str_val
                elif child[0].str_val == "len":
                    if child[1].kind != nnk_int_lit:
                        error("invalid pragma", child[1])
                    else:
                        param.seq_len = cast[int](child[1].int_val)
                else:
                    error("invalid pragma", pragma_node)

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
    of param_seq_string:   return nnk_bracket_expr.new_tree(ident("seq"), ident("string"))
    of param_seq_int:      return nnk_bracket_expr.new_tree(ident("seq"), ident("int"))
    of param_seq_float:    return nnk_bracket_expr.new_tree(ident("seq"), ident("float"))
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
    if ident.kind == nnk_dot_expr and ident.len == 2 and
            ident[0].kind == nnk_ident and ident[0].str_val == "seq" and
            ident[1].kind == nnk_ident:
        case ident[1].str_val:
        of "string":    return param_seq_string
        of "int":       return param_seq_int
        of "float":     return param_seq_float
        else:           return param_undefined
    else:
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

proc seq_kind_from_ident(ident: Nim_node): Param_Kind =
    case ident.str_val
    of "string":    return param_seq_string
    of "int":       return param_seq_int
    of "float":     return param_seq_float
    else:           return param_undefined

proc value_node_from_param(param: Param): Nim_Node =
    case param.kind:
    of param_undefined:  return nil
    of param_seq_string: return nil
    of param_seq_int:    return nil
    of param_seq_float:  return nil
    of param_int:        return new_int_lit_node(param.int_value)
    of param_i8:         return new_int_lit_node(param.i8_value)
    of param_i16:        return new_int_lit_node(param.i16_value)
    of param_i32:        return new_int_lit_node(param.i32_value)
    of param_i64:        return new_int_lit_node(param.i64_value)
    of param_uint:       return new_int_lit_node(cast[Biggest_Int](param.uint_value))
    of param_u8:         return new_int_lit_node(cast[Biggest_Int](param.u8_value))
    of param_u16:        return new_int_lit_node(cast[Biggest_Int](param.u16_value))
    of param_u32:        return new_int_lit_node(cast[Biggest_Int](param.u32_value))
    of param_u64:        return new_int_lit_node(cast[Biggest_Int](param.u64_value))
    of param_float:      return new_float_lit_node(param.float_value)
    of param_f32:        return new_float_lit_node(param.f32_value)
    of param_f64:        return new_float_lit_node(param.f64_value)
    of param_char:       return new_lit(param.char_value)
    of param_string:     return new_str_lit_node(param.string_value)
    of param_bool:
        if param.bool_value:
            return ident("true")
        else:
            return ident("false")


proc string_from_param(param: Param): string =
    case param.kind:
    of param_undefined:  return ""
    of param_seq_string: return ""
    of param_seq_int:    return ""
    of param_seq_float:  return ""
    of param_int:        return repr(param.int_value)
    of param_i8:         return repr(param.i8_value)
    of param_i16:        return repr(param.i16_value)
    of param_i32:        return repr(param.i32_value)
    of param_i64:        return repr(param.i64_value)
    of param_uint:       return repr(param.uint_value)
    of param_u8:         return repr(param.u8_value)
    of param_u16:        return repr(param.u16_value)
    of param_u32:        return repr(param.u32_value)
    of param_u64:        return repr(param.u64_value)
    of param_float:      return repr(param.float_value)
    of param_f32:        return repr(param.f32_value)
    of param_f64:        return repr(param.f64_value)
    of param_char:       return repr(param.char_value)
    of param_string:     return param.string_value
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

        elif node[1].len == 1 and node[1][0].kind == nnk_bracket_expr and node[1][0].len == 2 and       # x:seq[t]
                node[1][0][0].kind == nnk_ident and node[1][0][0].str_val == "seq" and
                node[1][0][1].kind == nnk_ident:
            return (seq_kind_from_ident(node[1][0][1]), node[0], nil, nil, 0)
        elif node[1].len == 1 and node[1][0].kind == nnk_pragma_expr and                                # x:seq[t] + pragma
                node[1][0][0].kind == nnk_bracket_expr and node[1][0][0].len == 2 and
                node[1][0][0][0].kind == nnk_ident and node[1][0][0][0].str_val == "seq" and
                node[1][0][0][1].kind == nnk_ident:
            return (seq_kind_from_ident(node[1][0][0][1]), node[0], nil, node[1][0][1], 0)

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
    ## Parses the command-line arguments provided by the user,   @TODO update this
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
    ##   {. bare .}                 = accepts bare parameters instead of named
    ##   {. len(i) .}               = on a seq field, sets desired length
    ##
    ## If you specify any `seq[string]` fields then the last such field will
    ## be used to store all bare arguments.  (i.e. the last `seq[string]` is
    ## treated as if it had an implicit {. bare .} pragma.)
    ## This may be disabled with the `no_implicit_bare` setting.
    ##
    ## Example:
    ##
    ## let options, supplied = get_options_and_supplied:
    ##     teenager = "Joe Random" {. alias("name", "n") .}
    ##     age[int8] = 13
    ##     nin:string              {. info("National Insurance Number") .}
    ##     arguments:seq[string]
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

    var param_description_node = new_nim_node(nnk_var_section)
    param_description_node.add(
        nnk_ident_defs.new_tree(
            ident(VAR_DESCRIPTION_NAME),
            new_empty_node(),
            nnk_call.new_tree(
                nnk_bracket_expr.new_tree(
                    ident("new_seq"),
                    ident("string")))))

    var bare_index_node = new_nim_node(nnk_var_section)
    bare_index_node.add(
        nnk_ident_defs.new_tree(
            ident(VAR_BARE_NAME),
            new_empty_node(),
            nnk_call.new_tree(
                nnk_bracket_expr.new_tree(
                    ident("new_seq"),
                    ident("int")))))

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
    let outer_bare_indexes = ident(VAR_BARE_NAME)
    let outer_param_descriptions = ident(VAR_DESCRIPTION_NAME)


    var proc_node = quote do:
        proc `proc_name`(options: var `type_name`, present: var `present_type_name`): (`type_name`, `present_type_name`) =

            when DEBUG:
                prettify("Options", options.repr, true)
                prettify("Supplied", present.repr)

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

            proc is_bare(name: string): bool =
                `outer_bare_indexes`.contains(index_from_name(name))

            proc is_seq(name: string): bool =
                let kind = get_param_type(name)
                return kind == int_param_seq_string or kind == int_param_seq_int or kind == int_param_seq_float

            proc do_help() =
                echo help_text_pre
                var prefix = ""
                var extra_prefix = ""
                if dash_denotes_param:
                    prefix = "-"
                elif slash_denotes_param:
                    prefix = "/"
                var letters = 0
                proc full_name(index: int): string =
                    if `outer_bare_indexes`.contains(index):
                        return ""
                    var name = `outer_param_names`[index]
                    # if aliases contains... blahblahblah
                    return name
                for i, _ in `outer_param_names`:
                    let name = full_name(i)
                    if name.len > letters: letters = name.len
                for i, name in `outer_param_names`:
                    let display_name = full_name(i)
                    if display_name == "": continue
                    let postfix = `outer_param_descriptions`[i]
                    if name.len > 1 and use_double_dash:
                        extra_prefix = "-"
                    else:
                        extra_prefix = ""
                    if postfix == "":
                        echo " ", prefix, display_name
                    else:
                        var spacer = ""
                        while display_name.len + spacer.len < letters:
                            spacer = spacer & " "
                        echo " ", prefix, display_name, spacer, "  ", postfix
                echo ""
                if help_text_post != "":
                    echo help_text_post
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

            proc can_parse_as(value: string, kind: int): bool =
                case kind
                of `int_param_string`:
                    return true
                of `int_param_bool`:
                    return false
                of `int_param_int`:
                    return int_from_string[int](value)[1]
                of `int_param_i8`:
                    return int_from_string[int](value)[1]
                of `int_param_i16`:
                    return int_from_string[int](value)[1]
                of `int_param_i32`:
                    return int_from_string[int](value)[1]
                of `int_param_i64`:
                    return int_from_string[int](value)[1]
                of `int_param_uint`:
                    return uint_from_string[int](value)[1]
                of `int_param_u8`:
                    return uint_from_string[int](value)[1]
                of `int_param_u16`:
                    return uint_from_string[int](value)[1]
                of `int_param_u32`:
                    return uint_from_string[int](value)[1]
                of `int_param_u64`:
                    return uint_from_string[int](value)[1]
                of `int_param_float`:
                    return float_from_string[int](value)[1]
                of `int_param_f32`:
                    return float_from_string[int](value)[1]
                of `int_param_f64`:
                    return float_from_string[int](value)[1]
                of `int_param_char`:
                    return value.len == 1
                of `int_param_undefined`:
                    return false
                of `int_param_seq_string`:
                    return true
                of `int_param_seq_float`:
                    return float_from_string[int](value)[1]
                of `int_param_seq_int`:
                    return int_from_string[int](value)[1]
                else:
                    return false


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
                of `int_param_seq_string`:
                    let field = cast[ptr seq[string]](cast[uint](address) + get_param_offset(name))
                    field[].add value
                    return true
                of `int_param_seq_int`:
                    let (parsed_value, success) = int_from_string[int](value)
                    if success:
                        let field = cast[ptr seq[int]](cast[uint](address) + get_param_offset(name))
                        field[].add parsed_value
                    return success
                of `int_param_seq_float`:
                    let (parsed_value, success) = float_from_string[float](value)
                    if success:
                        let field = cast[ptr seq[float]](cast[uint](address) + get_param_offset(name))
                        field[].add parsed_value
                    return success
                else:
                    return false

            var
                awaiting_value = false
                awaiting_value_for = ""
                writing_to_seq = false
                current_bare_index = 0
                no_await_value_check_until = 0
                force_bare = false

            if implicit_bare:
                var last_seq_string = -1
                var add_implicit_bare = true
                for i, kind in `outer_param_type`:
                    if kind == int_param_seq_string:
                        if i in `outer_bare_indexes`:
                            add_implicit_bare = false
                            break
                        else:
                            last_seq_string = i
                if add_implicit_bare and last_seq_string >= 0:
                    `outer_bare_indexes`.add(last_seq_string)

            when DEBUG:
                var words:seq[string] = parse_cmd_line(DEBUG_ARGS)
            else:
                var words:seq[string] = command_line_params()
            var next_word_index = 0
            while next_word_index < words.len:
                let word = words[next_word_index]
                next_word_index += 1
                if ((dash_denotes_param and word.starts_with("-")) or (slash_denotes_param and word.starts_with("/"))) and not force_bare:
                    if writing_to_seq:
                        writing_to_seq = false
                    elif awaiting_value and next_word_index > no_await_value_check_until:
                        parse_error("Expected value for: " & awaiting_value_for)

                    echo double_dash_separator
                    echo word
                    if double_dash_separator and word == "--":
                        force_bare = true
                        echo "BARE"
                        continue

                    var name = word[1 ..< ^0].to_lower

                    if use_double_dash:
                        if name.starts_with("-"):
                            name = name[1 ..< ^0]
                        elif name.len > 1:
                            for i, letter in name.pairs:
                                no_await_value_check_until = next_word_index + i
                                words.insert "-" & letter, no_await_value_check_until
                            continue

                    let found = `outer_param_names`.contains(name) and not is_bare(name)
                    if not found:
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
                            if not writing_to_seq:
                                if is_seq(awaiting_value_for):
                                    writing_to_seq = true
                                else:
                                    awaiting_value = false
                        else:
                            parse_error("Could not parse value for: " & word)
                    else:
                        var ok = false
                        while current_bare_index < `outer_bare_indexes`.len:
                            if can_parse_as(word, `outer_param_type`[`outer_bare_indexes`[current_bare_index]]):
                                ok = true
                                break
                            current_bare_index += 1
                        if not ok:
                            parse_error("Could not accept argument: " & word)
                        let bare_name = `outer_param_names`[`outer_bare_indexes`[current_bare_index]]
                        if set_value(addr options, bare_name, word):
                            set_present(addr present, bare_name)
                        else:
                            parse_error("Could not parse value for: " & word)
                        let kind = `outer_param_type`[`outer_bare_indexes`[current_bare_index]]
                        if kind != int_param_seq_string and kind != int_param_seq_int and kind != int_param_seq_float:
                            current_bare_index += 1

            if awaiting_value and not writing_to_seq:
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
    result[1].add param_description_node
    result[1].add bare_index_node
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
        if value_node != nil:
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

    template add_description(name: string, description: string) =
        offset_node.add(
            nnk_call.new_tree(
                nnk_dot_expr.new_tree(
                    ident(VAR_DESCRIPTION_NAME),
                    ident("add")),
                new_str_lit_node(description)))

    template add_bare_index(index: int) =
        offset_node.add(
            nnk_call.new_tree(
                nnk_dot_expr.new_tree(
                    ident(VAR_BARE_NAME),
                    ident("add")),
                new_int_lit_node(index)))


    for i, name in params_in_order.pairs:
        let param = params[name]
        add_type name, param.kind
        add_var name, value_node_from_param(param)
        add_offset name
        add_present_offset name
        add_name name
        add_type_lookup name, param.kind
        add_default_value name, string_from_param(param)
        add_description name, param.description
        if param.accepts_bare:
            add_bare_index(i)


macro get_options*(body: untyped): untyped =
    ## Parses the command-line arguments provided by the user,   @TODO update this
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
    DEBUG_ARGS = "--age 2 --here --there --big 10 --name \"Joe Random\" 5 --letter z 10 20 -- -xy foo"

    simple_parseopt.config: no_slash.dash_dash_parameters.dash_dash_separator

    var (options, is_set) = get_options_and_supplied:
        name = "Default Name"
        toggle = false
        letter = 'a'
        age = 1 {. info("How old they are") .}
        here = true
        there = false
        big:float64 = 1.1
        small:float = 2.2
        flat:uint = 2
        hello:string
        x = ""
        y = ""
        args:seq[string]


    prettify("Options", options, true)
    prettify("Supplied", is_set)
