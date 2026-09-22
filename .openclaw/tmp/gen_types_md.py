import json, re
from collections import defaultdict, OrderedDict

with open('/Users/computer/Desktop/state-kit/.openclaw/tmp/api-inventory.json') as f:
    data = json.load(f)

symbols = data['symbols']

TYPE_KINDS = {'class', 'struct', 'enum', 'protocol', 'actor', 'typealias', 'extension', 'macro', 'associatedtype'}

# Module-level ordering & display names
MODULE_ORDER = [
    ('StateKitCore', 'StateKitCore', 'Runtime primitives: StateContext, StateRuntime, StateSignal, StateRef — nền cho mọi module khác.'),
    ('StateKit', 'StateKit', 'Hooks-style local state API (useState, useReducer, useEffect, useAsync...) dùng trong StateView.'),
    ('StateKitUI', 'StateKitUI', 'Tích hợp SwiftUI: StateScope, StateView, SKAtomRoot, phase views.'),
    ('StateKitAtoms', 'StateKitAtoms', 'Atom global state graph: atom protocols, store, selectors, atom hooks.'),
    ('Riverpods', 'Riverpods', 'Provider container kiểu Riverpod: Notifier/Provider, families, overrides, SwiftUI wrappers.'),
    ('StateConcurrency', 'StateConcurrency', 'Task helpers (retry/timeout/gather/race/debounce/throttle) + async streams.'),
    ('StateKitSupport', 'StateKitSupport', 'Property wrappers @SAtom/@Hook + helper hooks (useCount, useNow, useLoadMore...).'),
    ('StateKitCombine', 'StateKitCombine', 'Bridge Combine cho atoms và phases.'),
    ('StateKitPersistence', 'StateKitPersistence', 'Persistence: UserDefaults, Keychain, SwiftData.'),
    ('StateKitCache', 'StateKitCache', 'Cache policies + LRU/TTL cache cho provider.'),
    ('StateKitAnalytics', 'StateKitAnalytics', 'Analytics event tracking + user journey.'),
    ('StateKitFeatureFlags', 'StateKitFeatureFlags', 'Feature flags, rollout, A/B testing.'),
    ('StateKitTesting', 'StateKitTesting', 'Testing utilities deterministic + integration.'),
    ('StateKitDevTools', 'StateKitDevTools', 'State history, profiling, debug observer, DevTools UI.'),
    ('StateKitMacros', 'StateKitMacros', '48 public macro declarations (@StateAtom, @HookState, @Provider...).'),
]

def clean_sig(sig, maxlen=160):
    s = re.sub(r'\s+', ' ', sig).strip()
    s = re.sub(r'^public\s+', '', s)
    s = re.sub(r'\s*:\s*$', '', s)
    # remove stored default like "= nil" keep; keep it, useful
    if len(s) > maxlen:
        s = s[:maxlen - 1] + '…'
    return s

def short_name(sig):
    # name after kind (strip leading access level + modifiers first)
    sig2 = re.sub(r'^(?:public\s+|open\s+|final\s+|static\s+|indirect\s+|nonisolated\s+|mutating\s+|override\s+|required\s+|convenience\s+|lazy\s+|weak\s+)+', '', sig)
    m = re.match(r'^(?:@\w+(?:\([^)]*\))?\s+)*(class|struct|enum|protocol|actor|extension|typealias|func|var|let|macro|subscript)\s+([A-Za-z_][A-Za-z0-9_]*)', sig2)
    if m:
        kind, name = m.group(1), m.group(2)
        name = name.rstrip(':')
        if kind in ('class', 'struct', 'enum', 'protocol', 'actor', 'typealias'):
            # attach generic params if present, e.g. StateRef<T>
            g = re.search(re.escape(kind) + r'\s+' + re.escape(name) + r'\s*(<[^{}]*?>)?', sig2)
            if g and g.group(1):
                name += g.group(1).strip()
        if kind == 'func' and name == 'init':
            return 'init(...)'
        if kind in ('class', 'struct', 'enum', 'protocol', 'actor', 'extension', 'typealias'):
            return name
        if kind in ('func', 'var', 'let', 'macro'):
            # for funcs keep params
            return name
    if 'init' in sig.split(' ')[1:2] or sig.startswith('public init'):
        return 'init'
    return sig.split(' ')[1] if len(sig.split(' ')) > 1 else sig

# Build per-module sections; skip StateKitMacrosPlugin (internal compiler plugin)
by_mod = defaultdict(list)
for s in symbols:
    by_mod[s['module']].append(s)

MODULE_DISPLAY = {m: d for m, d, _ in MODULE_ORDER}
MODULE_DESC = {m: desc for m, _, desc in MODULE_ORDER}

lines = []
lines.append('# StateKit — Public API Inventory (cho AI agent code theo flow)')
lines.append('')
lines.append('> Sinh tự động từ nguồn `Sources/` ngày 2026-09-22. Trừ `StateKitMacrosPlugin` (compiler plugin nội bộ, không import trực tiếp), mọi module khác đều là library product trong `Package.swift`.')
lines.append('> Mục đích: bản đồ API để AI agent điều hướng nhanh — "muốn X thì vào module Y, dùng symbol Z".')
lines.append('')
lines.append('## Cách đọc tài liệu này')
lines.append('')
lines.append('- **Type declaration** (class/struct/enum/protocol/actor/typealias): khối xây dựng chính, agent nên ưu tiên đọc file nguồn khi dùng.')

lines.append('- **Member declaration** (func/var/let/init): liệt kê tên + chữ ký rút gọn để tra nhanh.')
lines.append('- Chữ ký đã rút gọn (cắt generics/params dài), đường dẫn file relative tới `Sources/` giúp nhảy tới nguồn ngay.')
lines.append('')
lines.append('## Module map (flow code thực tế)')
lines.append('')
lines.append('| Module | Vai trò trong flow | Loại chính |')
lines.append('|---|---|---|')
flow_roles = {
    'StateKitCore': 'Nền runtime: mọi state chảy qua đây',
    'StateKit': 'Hooks API — viết UI state như React',
    'StateKitUI': 'Gắn hooks vào SwiftUI View',
    'StateKitAtoms': 'Global state dạng atom graph',
    'Riverpods': 'Global logic + DI dạng provider',
    'StateConcurrency': 'Side effects: async, retry, timeout, stream',
    'StateKitSupport': 'Property wrappers & tiện ích hook',
    'StateKitCombine': 'Bridge sang hệ Combine cũ',
    'StateKitPersistence': 'Lưu/đọc state ra storage',
    'StateKitCache': 'Memoize/bộ nhớ đệm cho provider',
    'StateKitAnalytics': 'Theo dõi event & hành trình người dùng',
    'StateKitFeatureFlags': 'Bật/tắt tính năng, A/B test',
    'StateKitTesting': 'Test state deterministic',
    'StateKitDevTools': 'Debug, history, profiling',
    'StateKitMacros': 'Macro rút gọn boilerplate',
}
main_type = {}
for mod in by_mod:
    kinds = defaultdict(int)
    for s in by_mod[mod]:
        if s['kind'] in TYPE_KINDS:
            kinds[s['kind']] += 1
    top = sorted(kinds.items(), key=lambda x: -x[1])
    main_type[mod] = ', '.join(f'{k}×{v}' for k, v in top[:3]) if top else '—'

for mod, disp, desc in MODULE_ORDER:
    if mod not in by_mod:
        continue
    lines.append(f"| `{disp}` | {flow_roles.get(mod, desc)} | {main_type.get(mod, '—')} |")
lines.append('')
lines.append(f"**Tổng: {sum(len(v) for k, v in by_mod.items() if k != 'StateKitMacrosPlugin')} public symbol (không tính macro plugin nội bộ).**")
lines.append('')
lines.append('---')
lines.append('')

for mod, disp, desc in MODULE_ORDER:
    if mod not in by_mod:
        continue
    syms = by_mod[mod]
    # group by file
    by_file = OrderedDict()
    for s in sorted(syms, key=lambda x: (x['file'], x['line'])):
        by_file.setdefault(s['file'], []).append(s)

    lines.append(f'## `{disp}`')
    lines.append('')
    lines.append(f'{desc}')
    lines.append('')
    types_by_file = OrderedDict()
    members_by_file = OrderedDict()
    for fpath, ss in by_file.items():
        ts = [s for s in ss if s['kind'] in TYPE_KINDS]
        ms = [s for s in ss if s['kind'] not in TYPE_KINDS]
        if ts:
            types_by_file[fpath] = ts
        if ms:
            members_by_file[fpath] = ms

    if types_by_file:
        lines.append('### Types')
        lines.append('')
        for fpath, ts in types_by_file.items():
            seen = {}
            ordered = []
            for s in ts:
                anchor = short_name(s['sig'])
                kind = s['kind']
                key = (kind, anchor)
                if key in seen:
                    continue
                seen[key] = True
                ordered.append((kind, anchor))
            for kind, anchor in ordered:
                lines.append(f'- **{kind} `{anchor}`** — `{fpath}`')
    if members_by_file:
        lines.append('')
        lines.append('### Members (func/var/init)')
        lines.append('')
        for fpath, ms in members_by_file.items():
            for s in ms:
                kind = s['kind']
                sig = clean_sig(s['sig'], 150)
                lines.append(f'- `{sig}` — `{fpath}:{s["line"]}`')
    lines.append('')
    lines.append('---')
    lines.append('')

lines.append('## Ghi chú cho AI agent')
lines.append('')
lines.append('- **Không import `StateKitMacrosPlugin`** — đó là compiler plugin; chỉ dùng `@macro` từ module `StateKitMacros`.')
lines.append('- **Extension** được liệt kê ở phần Types vì chúng thêm API public cho type có sẵn (ví dụ `Task`, `AsyncSequence`, `MainActor`).')
lines.append('- Flow khuyến nghị khi viết tính năng mới: `StateKitCore` (đã re-export qua `StateKit`) → chọn state model (hooks / atom / provider) → UI ở `StateKitUI` → side effects ở `StateConcurrency` → test ở `StateKitTesting` → debug ở `StateKitDevTools`.')
lines.append('- Tài liệu chi tiết hơn: `docs/core/GUIDE.md`, `docs/macros/STATEKIT_V1_REFERENCE.md`, `docs/release/API_STABILITY.md`.')

with open('/Users/computer/Desktop/state-kit/docs/core/PUBLIC_API_INVENTORY.md', 'w') as f:
    f.write('\n'.join(lines))

print('written', len(lines), 'lines')
