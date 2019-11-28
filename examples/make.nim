import simple_parseopt, os, strutils, glob

const TEMP_FILE = "include.tmp"


simple_parseopt.config: can_name_bare

var (options, supplied) = get_options_and_supplied:
    make_examples = false   {. alias("x"), info("Make other examples") .}
    make_docs     = false   {. alias("d"), info("Make docs file: `simple_parseopt.html`") .}
    make_make     = false   {. alias("m"), info("Make this binary") .}
    make_all      = false   {. alias("a") .}
    open          = false   {. info("Open `simpleparseopt.html` after making it.") .}
    include_file: string    {. alias("include"), info("File to include at top of doc"), bare .}
    bin      = "bin/"       {. info("Folder to put compiled binaries") .}
    src      = "src/"       {. info("Folder where `simple_parseopt.nim` resides") .}
    examples = "examples/"  {. info("Folder where example .nim files reside") .}


if options.make_all:
    options.make_docs = true
    options.make_make = true
    options.make_examples = true


if options.make_docs:
    if not supplied.include_file:
        echo "You must specify an include_file"
        quit(1)
    if not os.exists_dir(options.src):
        os.set_current_dir("..")
    let path = os.join_path(options.src, "simple_parseopt.nim")
    if not os.exists_file(path):
        echo "Could not find simple_parseopt.nim"
        quit(1)
    if not os.exists_file(options.include_file):
        echo "Could not find " & options.include_file
        quit(1)

    block: #make temp file
        echo "\nGenerating header from " & options.include_file.extract_filename & "..."
        let in_file = open(options.include_file)
        defer: in_file.close()

        let out_file = open(TEMP_FILE, fm_write)
        defer: out_file.close()

        var started = false
        var line = ""
        while in_file.read_line(line):
            if not started:
                if line.starts_with("# "):
                    started = true
            else:
                if not line.starts_with("---"):
                    out_file.write_line(line)

    defer: os.remove_file(TEMP_FILE)

    echo "\nGenerating doc..."
    var error = os.exec_shell_cmd(
        "nim doc2 --git.url:https://github.com/onelivesleft/simple_parseopt.git " & path)

    if error != 0:
        echo "\nCould not generate `simple_parseopt.html`: " & error.repr
        quit(1)

    if options.open:
        echo "\nOpening..."
        error = os.exec_shell_cmd("start simple_parseopt.html")


if options.make_make:
    if not os.exists_dir(options.examples):
        os.set_current_dir("..")
    let path = os.join_path(options.examples, "make.nim")
    if not os.exists_file(path):
        echo "Could not find make.nim"
        quit(1)
    if not os.exists_dir(options.bin):
        echo "Could not find output folder"
        quit(1)

    echo "\nCompiling make.nim..."
    var error = os.exec_shell_cmd("nim -o:" & options.bin & " c  " & path)

    if error != 0:
        echo "\nError compiling `make.nim`: " & error.repr
        quit(1)


if options.make_examples:
    if not os.exists_dir(options.examples):
        os.set_current_dir("..")
    if not os.exists_dir(options.bin):
        echo "Could not find output folder"
        quit(1)

    for file in glob.walk_glob("*", options.examples):
        if file != "make.nim":
            echo "\nCompiling " & file & "..."
            var error = os.exec_shell_cmd("nim -o:" & options.bin & " c  " & os.join_path(options.examples, file))

            if error != 0:
                echo "\nError compiling `" & file & "`: " & error.repr
                quit(1)
