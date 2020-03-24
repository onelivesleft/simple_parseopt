import os, strutils, glob
import "../src/simple_parseopt"  # when installed you need only `import simple_parseopt`

const TEMP_FILE = os.join_path("src", "header.md")


simple_parseopt.config: can_name_bare

var (options, supplied) = get_options_and_supplied:
    make_docs     = false   {. alias("d"), info("Make docs file: `simple_parseopt.html`") .}
    make_make     = false   {. alias("m"), info("Make this binary") .}
    make_examples = false   {. alias("x"), info("Make other examples") .}
    make_all      = false   {. alias("a") .}
    open          = false   {. info("Open `simpleparseopt.html` after making it.") .}
    include_file: string    {. alias("include"), info("File to include at top of doc"), bare .}
    bin      = "bin/"       {. info("Folder to put compiled binaries") .}
    src      = "src/"       {. info("Folder where `simple_parseopt.nim` resides") .}
    examples = "examples/"  {. info("Folder where example .nim files reside") .}
    version: string


if options.make_all:
    options.make_docs = true
    options.make_make = true
    options.make_examples = true


if options.make_docs:
    if not supplied.include_file:
        quit "You must specify an include_file"
    if not os.exists_dir(options.src):
        os.set_current_dir("..")
    let path = os.join_path(options.src, "simple_parseopt.nim")
    if not os.exists_file(path):
        quit "Could not find simple_parseopt.nim"
    if not os.exists_file(options.include_file):
        quit "Could not find " & options.include_file

    if not os.exists_file("simple_parseopt.nimble"):
        quit "Could not find `simple_parseopt.nimble`"

    let version = block:
        var result = ""
        if supplied.version:
            result = "v" & options.version
        else:
            let nimble = open("simple_parseopt.nimble")
            defer: nimble.close()

            var line: string
            while nimble.read_line(line):
                if line.starts_with("version"):
                    result = "v" & line.split("\"")[1]
                    break
        result

    if version == "":
        quit "Could not find version"

    echo "\nPackage version: " & version

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


    echo "\nGenerating doc..."
    var error = os.exec_shell_cmd(
        "nim doc2 --hints:off --git.url:https://github.com/onelivesleft/simple_parseopt --git.commit:" & version & " " & path)

    if error != 0:
        quit "\nCould not generate `simple_parseopt.html`: " & error.repr

    if options.open:
        echo "\nOpening..."
        error = os.exec_shell_cmd("start simple_parseopt.html")


if options.make_make:
    if not os.exists_dir(options.examples):
        os.set_current_dir("..")
    let path = os.join_path(options.examples, "make.nim")
    if not os.exists_file(path):
        quit "Could not find make.nim"
    if not os.exists_dir(options.bin):
        quit "Could not find output folder"

    echo "\nCompiling make.nim..."
    var error = os.exec_shell_cmd("nim --hints:off -o:" & options.bin & " c  " & path)

    if error != 0:
        quit "\nError compiling `make.nim`: " & error.repr


if options.make_examples:
    if not os.exists_dir(options.examples):
        os.set_current_dir("..")
    if not os.exists_dir(options.bin):
        quit "Could not find output folder"

    for file in glob.walk_glob("*", options.examples):
        if file != "make.nim":
            echo "\nCompiling " & file & "..."
            var error = os.exec_shell_cmd("nim --hints:off -o:" & options.bin & " c  " & os.join_path(options.examples, file))

            if error != 0:
                quit "\nError compiling `" & file & "`: " & error.repr
