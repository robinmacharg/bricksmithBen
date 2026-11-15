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


def project_pointer_typedefs():
    """Names of block typedefs (`typedef void (^Name)(...)`) and pointer typedefs (`typedef T *Name;`) in the
    app's headers. They hide their pointer-ness, so a '*' scan misses them (L36, L45)."""
    import glob, os
    root = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                        'trunk', 'Bricksmith', 'Source')
    names = set()
    for h in glob.glob(os.path.join(root, '**', '*.h'), recursive=True):
        text = open(h, errors='replace').read()
        names.update(re.findall(r'typedef[^;{]*\(\s*\^\s*(\w+)\s*\)', text))
        names.update(re.findall(r'typedef\s+\w+\s*\*\s*(\w+)\s*;', text))
    return names


TYPEDEF_POINTERS = project_pointer_typedefs()


def annotate_type(t):
    t = t.strip()
    bare = re.sub(r'\b(const|__kindof|__unsafe_unretained|__weak|__strong)\b', '', t).strip()
    if ANNOTATED.search(t) or not (POINTERISH.search(t) or bare in TYPEDEF_POINTERS):
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
                if (POINTERISH.search(t) or t.strip() in TYPEDEF_POINTERS) and not ANNOTATED.search(t) \
                        and not t.strip().startswith('SEL'):
                    problems.append(f'{path}: unannotated pointer in: {stripped}')
            line = code + ('//' + comment if comment else '')
        out.append(line)
    text = '\n'.join(out)
    # C prototypes ("extern T f(...);") anywhere in the header: annotate bare pointer parameters/returns too,
    # otherwise -Wnullability-completeness fires for them (L51).
    def c_proto(m):
        params = re.sub(r'(\w+)\s*\*\s*(?!_N|\*)(\w+)', r'\1 * _Null_unspecified \2', m.group(2))
        return m.group(1) + params + m.group(3)
    text = re.sub(r'(^extern\s[^(;]*\()([^;]*)(\)\s*;)', c_proto, text, flags=re.M)
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
