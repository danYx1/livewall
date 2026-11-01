import re, sys

path = sys.argv[1]
src = open(path, encoding='utf-8').read()

defs = set(re.findall(r'^\t\t([0-9A-F]{24}) ', src, re.M))
refs = set(re.findall(r'\b([0-9A-F]{24})\b', src))

missing = sorted(refs - defs)
print('definitions:', len(defs))
print('references :', len(refs))
if missing:
    print('MISSING DEFINITIONS:')
    for m in missing:
        print('  ', m)
else:
    print('all references resolved')

# brace balance
print('open braces :', src.count('{'), 'close braces:', src.count('}'))
print('open parens :', src.count('('), 'close parens:', src.count(')'))
