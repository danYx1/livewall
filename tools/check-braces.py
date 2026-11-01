import sys, io, os, re

def check(path):
    src = open(path, encoding='utf-8').read()
    stack = []
    i = 0
    n = len(src)
    line = 1
    in_line_comment = False
    in_block_comment = 0
    in_string = False
    in_multiline = False
    errors = []
    while i < n:
        c = src[i]
        nxt = src[i+1] if i+1 < n else ''
        if c == '\n':
            line += 1
            in_line_comment = False
            i += 1
            continue
        if in_line_comment:
            i += 1
            continue
        if in_block_comment:
            if c == '/' and nxt == '*':
                in_block_comment += 1
                i += 2
                continue
            if c == '*' and nxt == '/':
                in_block_comment -= 1
                i += 2
                continue
            i += 1
            continue
        if in_multiline:
            if c == '"' and src[i:i+3] == '"""':
                in_multiline = False
                i += 3
                continue
            i += 1
            continue
        if in_string:
            if c == '\\':
                i += 2
                continue
            if c == '"':
                in_string = False
            i += 1
            continue
        if c == '/' and nxt == '/':
            in_line_comment = True
            i += 2
            continue
        if c == '/' and nxt == '*':
            in_block_comment = 1
            i += 2
            continue
        if src[i:i+3] == '"""':
            in_multiline = True
            i += 3
            continue
        if c == '"':
            in_string = True
            i += 1
            continue
        if c in '([{':
            stack.append((c, line))
            i += 1
            continue
        if c in ')]}':
            pairs = {')': '(', ']': '[', '}': '{'}
            if not stack:
                errors.append(f'{line}: лишняя {c}')
            else:
                op, oline = stack.pop()
                if op != pairs[c]:
                    errors.append(f'{line}: {c} закрывает {op} из строки {oline}')
            i += 1
            continue
        i += 1
    for op, oline in stack:
        errors.append(f'{oline}: не закрыта {op}')
    return errors

root = sys.argv[1]
bad = 0
for dirpath, _, files in os.walk(root):
    for f in files:
        if f.endswith('.swift'):
            p = os.path.join(dirpath, f)
            errs = check(p)
            if errs:
                bad += 1
                print('FAIL', p)
                for e in errs[:10]:
                    print('   ', e)
            else:
                print('ok  ', os.path.relpath(p, root))
print('files with issues:', bad)
