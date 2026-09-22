import os, re, json
from collections import defaultdict

ROOT = "/Users/computer/Desktop/state-kit/Sources"
KW = r'(class|struct|enum|protocol|actor|extension|typealias|func|var|let|init\??|macro|associatedtype|operator|subscript|case)'

def decl_kind(m):
    return m.group(1)

results = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    for fn in sorted(filenames):
        if not fn.endswith('.swift'):
            continue
        path = os.path.join(dirpath, fn)
        module = os.path.relpath(path, ROOT).split(os.sep)[0]
        with open(path, encoding='utf-8') as f:
            lines = f.read().splitlines()
        i = 0
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            m = re.match(r'^(?:@\w+(?:\([^)]*\))?\s+)*public\s+(?:static\s+|final\s+|open\s+|indirect\s+|weak\s+|lazy\s+|mutating\s+|nonisolated\s+|convenience\s+|required\s+|override\s+)*' + KW + r'\b', stripped)
            if m:
                # build signature: accumulate lines until balanced or 5 lines
                sig = stripped
                j = i
                # strip leading attributes on the same line already included
                open_count = sig.count('(') - sig.count(')') + sig.count('<') - sig.count('>') + sig.count('[') - sig.count(']')
                while j < i + 5 and (open_count > 0 or sig.rstrip().endswith(('(', ',', '&', 'where', 'returns'))):
                    j += 1
                    if j >= len(lines):
                        break
                    sig += ' ' + lines[j].strip()
                    open_count = sig.count('(') - sig.count(')') + sig.count('<') - sig.count('>') + sig.count('[') - sig.count(']')
                # cut at first top-level '{' if present
                brace = sig.find('{')
                if brace != -1 and sig.count('(') == sig.count(')'):
                    sig = sig[:brace].strip()
                sig = re.sub(r'\s+', ' ', sig)
                # extract name
                nm = re.match(r'^(?:@\w+(?:\([^)]*\))?\s+)*public\s+(?:static\s+|final\s+|open\s+|indirect\s+|weak\s+|lazy\s+|mutating\s+|nonisolated\s+|convenience\s+|required\s+|override\s+)*' + KW + r'\s+([A-Za-z_][A-Za-z0-9_]*)', sig)
                name = nm.group(2) if nm else ''
                kind = m.group(1)
                results.append({
                    'module': module,
                    'file': os.path.relpath(path, ROOT),
                    'line': i + 1,
                    'kind': kind,
                    'name': name,
                    'sig': sig,
                })
            i += 1

out = {'symbols': results}
with open('/Users/computer/Desktop/state-kit/.openclaw/tmp/api-inventory.json', 'w') as f:
    json.dump(out, f, indent=1)

# summary
by_mod = defaultdict(lambda: defaultdict(int))
for s in results:
    by_mod[s['module']][s['kind']] += 1
print(f"{'MODULE':28} {'total':>6}  breakdown")
for mod in sorted(by_mod):
    total = sum(by_mod[mod].values())
    br = ', '.join(f"{k}:{v}" for k, v in sorted(by_mod[mod].items(), key=lambda x: -x[1]))
    print(f"{mod:28} {total:>6}  {br}")
grand = sum(sum(v.values()) for v in by_mod.values())
print(f"{'GRAND TOTAL':28} {grand:>6}")
