import csv, re, sys, statistics as st
from collections import defaultdict
U = {'ms': 0.001, 's': 1, 'm': 60, 'h': 3600, 'd': 86400}
def secs(v):
    v = v.strip()
    if v in ('', '-'): return None
    if re.fullmatch(r'[\d.]+', v): return float(v) / 1000   # raw trace: ms
    return sum(float(n) * U[u] for n, u in re.findall(r'([\d.]+)\s*(ms|s|m|h|d)', v))
g = defaultdict(list)
for r in csv.DictReader(open(sys.argv[1]), delimiter='\t'):
    if r.get('status') != 'COMPLETED': continue
    d, rt = secs(r['duration']), secs(r['realtime'])
    if d is None or rt is None: continue
    g[r['name'].split(' (')[0].split(':')[-1]].append((rt, d, d - rt))
print(f"{'process':30}{'n':>5}{'realtime':>10}{'duration':>10}{'overhead':>10}   medians in s")
allo = []
for p, v in sorted(g.items()):
    allo += [x[2] for x in v]
    print(f"{p:30}{len(v):>5}" + "".join(f"{st.median(x[i] for x in v):>10.1f}" for i in range(3)))
print(f"{'ALL':30}{len(allo):>5}{'':>20}{st.median(allo):>10.1f}")
