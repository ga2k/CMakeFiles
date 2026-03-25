import sys, re

key = sys.argv[1]
try:
    with open(".modules") as f:
        for line in f:
            m = re.match(r'^\s*' + re.escape(key) + r'\s*:=\s*(.*)', line)
            if m:
                val = m.group(1)
                val = re.sub(r'[ \t]*#.*', '', val)  # strip comments
                val = val.strip().strip('"').strip("'")
                print(val, end='')
                sys.exit(0)
except Exception:
    pass
<<<<<<< HEAD

=======
>>>>>>> 1128d811df0c97c7ac1cfa26d6edee0108ff99a7
