import simple_parseopt, os, strutils, osproc

help_text(
    "Increase version and publish to github + nimble.",
    "Will increase Patch version by default")

let options = get_options:
    major = false
    minor = false

if options.major and options.minor:
    quit("You cannot increase both major and minor versions")


if not os.exists_dir("src"):
    os.set_current_dir("..")
let simple_parseopt_path = os.join_path("src/simple_parseopt.nim")
if not os.exists_file(simple_parseopt_path):
    quit "Could not find `simple_parseopt.nim`"


block:
    let (output, error) = osproc.exec_cmd_ex("git diff --stat")
    if error != 0:
        quit "Error attempting to check status of repo.  Is git working?"
    elif output != "":
        quit "Please clean local repo before attempting to publish: either commit any changes, or discard them."


var version = block:
    let nimble = open("simple_parseopt.nimble")
    defer: nimble.close()

    var found = ""
    var line: string
    while nimble.read_line(line):
        if line.starts_with("version"):
            found = line.split("\"")[1]
            break
    found

if version == "":
    quit "Could not find version"

echo "\nCurrent version: v" & version

var
    parts = version.split(".")
    major = parse_int(parts[0])
    minor = parse_int(parts[1])
    patch = parse_int(parts[2])

if options.major:
    major += 1
    minor = 0
    patch = 0
elif options.minor:
    minor += 1
    patch = 0
else:
    patch += 1

version = major.repr & "." & minor.repr & "." & patch.repr
echo "New version:     v" & version


proc alter_version(file_path, line_starts_with, replace_with: string) =
    if not os.file_exists(file_path):
        quit "Could not find `" & file_path.extract_filename & "`"


    echo "\nUpdating `" & file_path.extract_filename & "` version..."

    let tmp_path = file_path.change_file_ext(".tmp")

    let in_file = open(file_path)
    let out_file = open(tmp_path, fm_write)

    var line: string
    while in_file.read_line(line):
        if line.starts_with(line_starts_with):
            out_file.write_line(replace_with)
        else:
            out_file.write_line(line)

    in_file.close()
    out_file.close()
    os.remove_file(file_path)
    os.move_file(tmp_path, file_path)

alter_version "src/simple_parseopt.nim", "const version", "const version = \"" & version & "\""
alter_version "simple_parseopt.nimble",  "version ",      "version       = \"" & version & "\""


proc check_exec_cmd(command, message: string) =
    var error = os.exec_shell_cmd(command)
    if error != 0:
        quit "\n" & message & ": " & error.repr


block:
    echo "\nGenerating docs..."
    check_exec_cmd(
        os.join_path("bin", "make") & " -d README.md -version " & version,
        "Could not generate `simple_parseopt.html`")


block:
    echo "\nPublishing to Github..."
    check_exec_cmd "git add src/simple_parseopt.nim", "Could not add `src/simple_parseopt.nim`"
    check_exec_cmd "git add simple_parseopt.nimble", "Could not add `simple_parseopt.nimble`"
    check_exec_cmd "git add simple_parseopt.html", "Could not add `simple_parseopt.html`"
    check_exec_cmd "git commit -m v" & version, "Could not commit."
    check_exec_cmd "git push", "Could not push."
    check_exec_cmd "git tag v" & version & " -m v" & version, "Could not tag."
    check_exec_cmd "git push origin v" & version, "Could not push tag."

#[
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
        "nim doc2 --git.url:https://github.com/onelivesleft/simple_parseopt --git.commit:" & version & " " & path)

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
    var error = os.exec_shell_cmd("nim -o:" & options.bin & " c  " & path)

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
            var error = os.exec_shell_cmd("nim -o:" & options.bin & " c  " & os.join_path(options.examples, file))

            if error != 0:
                quit "\nError compiling `" & file & "`: " & error.repr
]#