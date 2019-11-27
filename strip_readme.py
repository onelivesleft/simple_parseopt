out = open("include.tmp", 'w')
started = False
for line in open("README.md"):
    if not started:
        if line.startswith("# "):
            started = True
    else:
        if not line.startswith("---"):
            out.write(line)
out.close()
