import simple_parseopt, os, strutils, osproc

help_text(
    "Increase version and publish to github + nimble.",
    "Will increase Patch version by default")

let options = get_options:
    major  = false
    minor  = false
    nimble = false

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


proc check_exec_cmd(command, message: string) =
    var error = os.exec_shell_cmd(command)
    if error != 0:
        quit "\n" & message & ": " & error.repr

proc publish_to_nimble() =
    echo "\nPublishing to Nimble..."
    check_exec_cmd "nimble publish", "Error publishing to nimble.  You may use \"publish -nimble\" to attempt this step again."

if options.nimble:
    if options.major or options.minor:
        quit "Cannot update version while only publishing to nimble."
    publish_to_nimble()
    quit(0)


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


publish_to_nimble()
