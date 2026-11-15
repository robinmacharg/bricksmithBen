#!/usr/bin/env python3 -I
"""Mark every object/CF pointer in a header's method declarations as null_unspecified, wrapped in
NS_ASSUME_NONNULL_BEGIN/END.

Why (plan §5 P1, v3.1 rule): a header gets nullability annotations together with its first test, and
clang's -Wnullability-completeness then requires *every* pointer in the header to be annotated. Inside
NS_ASSUME_NONNULL an unmarked pointer silently becomes nonnull, which is a claim nobody verified. This
tool makes "unverified" explicit; verified pointers are then hand-edited to nonnull/nullable.

null_unspecified imports into Swift exactly like an unannotated pointer (implicitly unwrapped), so this
step changes no Swift spelling.

Usage:  scripts/dev/annotate-unspecified.py HEADER [HEADER...]
Fails (exit 1) listing any method-declaration pointer it could not annotate.
"""
import re
import sys

ANNOTATED = re.compile(r'\b(nullable|nonnull|null_unspecified|null_resettable|_Nullable|_Nonnull|_Null_unspecified)\b')
# A parenthesised type in a method declaration: "(...)" that follows -/+ or ':'
TYPE = re.compile(r'(?P<pre>(?:^\s*[-+]\s*|:\s*))\((?P<type>[^()]*?)\)')
# Typedef'd pointers (dispatch_*_t, CF/CG ...Ref) have no visible '*': under NS_ASSUME_NONNULL they would
# silently become nonnull (this bit us with dispatch_group_t - LEARNINGS L36).
POINTERISH = re.compile(r'(\*|\bid\b|\bClass\b|\b\w+Ref\b|\bdispatch_\w+_t\b|\bSEL\b(?!ector)|\^)')


def annotate_type(t):
    t = t.strip()
    if ANNOTATED.search(t) or not POINTERISH.search(t):
        return t
    levels = t.count('*') + (1 if re.match(r'^(id|Class)\b', t) else 0)
    if levels >= 2:  # multi-level pointer (incl. "id *"): annotate each level
        base = t.replace('*', '').strip()
        inner = f'{base} _Null_unspecified' if re.match(r'^(id|Class)\b', base) else f'{base} * _Null_unspecified'
        return inner + ' * _Null_unspecified' * (t.count('*') - (0 if re.match(r'^(id|Class)\b', base) else 1))
    if t.startswith('SEL'):
        return t  # SEL is not a pointer-to-object for nullability purposes
    return 'null_unspecified ' + t


def process(path):
    text = open(path).read()
    if 'NS_ASSUME_NONNULL_BEGIN' in text:
        print(f'{path}: already has NS_ASSUME_NONNULL - edit by hand', file=sys.stderr)
        return False
    out, problems, in_decl = [], [], False
    in_block = False
    for line in text.split('\n'):
        stripped = line.strip()
        if re.match(r'^@(interface|protocol)\b', stripped) and not stripped.endswith(';'):
            in_block = True
        if stripped == '@end':
            in_block = False
        if in_block and (re.match(r'^[-+]\s*\(', stripped) or in_decl):
            in_decl = not stripped.split('//')[0].rstrip().endswith(';')
            code, _, comment = line.partition('//')
            code = TYPE.sub(lambda m: f"{m.group('pre')}({annotate_type(m.group('type'))})", code)
            for m in TYPE.finditer(code):
                t = m.group('type')
                if POINTERISH.search(t) and not ANNOTATED.search(t) and not t.strip().startswith('SEL'):
                    problems.append(f'{path}: unannotated pointer in: {stripped}')
            line = code + ('//' + comment if comment else '')
        out.append(line)
    text = '\n'.join(out)
    first = re.search(r'^@(interface|protocol)\b(?!.*;\s*$)', text, re.M)
    # wrap from the first @interface/@protocol definition to the last @end
    start = first.start()
    end = text.rindex('@end') + len('@end')
    text = text[:start] + 'NS_ASSUME_NONNULL_BEGIN\n\n' + text[start:end] + '\n\nNS_ASSUME_NONNULL_END' + text[end:]
    open(path, 'w').write(text)
    for p in problems:
        print(p, file=sys.stderr)
    return not problems


if __name__ == '__main__':
    ok = all([process(p) for p in sys.argv[1:]])
    sys.exit(0 if ok else 1)
