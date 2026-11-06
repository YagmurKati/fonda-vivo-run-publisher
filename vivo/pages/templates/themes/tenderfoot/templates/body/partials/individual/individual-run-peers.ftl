<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-18: "this run among the workflow's runs" on workflow run pages (class rm:RunMetadata).
  Four strips (energy, carbon, CPU time, duration): one point per run of the same workflow AND of the same kind
  (same compute cluster, node use and number of nodes, read as on the workflow plots), this run highlighted with
  its rank, and the mean +/- 1 SD of those runs. Runs of other kinds are left out, because their energy is
  counted differently (whole node vs. share of a node).
  Data:     runPeerRows, from display:fondaRunPeersDataGetter
            (/opt/vivo/vivo/rdf/display/everytime/fonda-run-peers.n3). The query runs on every page view.
  Included: by individual--fonda-run.ftl, the custom display view of rm:RunMetadata.
  2026-10-18: placed at the end of the tab that holds "energy consumed" (rm:energyKWh, the "Energy And Carbon"
            tab), instead of below the stage list.
-->
<#if runPeerRows?? && runPeerRows?size gt 0>
<section id="run-peers" class="run-peers" aria-labelledby="rp-heading" hidden>
    <h3 id="rp-heading">this run among the workflow's runs</h3>
    <p class="rp-note"></p>
    <div class="rp-plots"></div>
</section>

<style>
#run-peers { --rp-dot: #2a78d6; --rp-peer: #9aa3ad; --rp-ref: #eb6834; --rp-surface: #ffffff; --rp-text: #595b5b;
    --rp-strong: #2b2d2d; --rp-muted: #6f7272; --rp-head: #064d68; --rp-base: #b9bec4;
    color: var(--rp-text); clear: both; margin: 1.2em 0 1.5em; }
html.dark-mode #run-peers { --rp-dot: #3987e5; --rp-peer: #6b7a93; --rp-ref: #d95926; --rp-surface: #0f151f; --rp-text: #d5dde7;
    --rp-strong: #f1f5f9; --rp-muted: #9aa7b8; --rp-head: #7fc0dd; --rp-base: #3b4a63; }
#run-peers :not(a) { color: inherit; }
#run-peers h3 { font-size: 15px; font-weight: 600; color: var(--rp-head); margin: 0 0 .35em; }
#run-peers .rp-note { color: var(--rp-muted); font-size: 13px; margin: 0 0 .6em; max-width: 62em; }
#run-peers .rp-plots { max-width: 900px; }
#run-peers svg { display: block; overflow: visible; font-family: inherit; }
#run-peers svg text { fill: var(--rp-muted); font-size: 11px; font-variant-numeric: tabular-nums; }
#run-peers svg .rp-name { fill: var(--rp-strong); font-size: 12.5px; }
#run-peers svg .rp-val { fill: var(--rp-strong); font-size: 12px; font-weight: 600; }
#run-peers .rp-axis { stroke: var(--rp-base); stroke-width: 1; shape-rendering: crispEdges; }
#run-peers .rp-peer { fill: var(--rp-peer); stroke: var(--rp-surface); stroke-width: 1; cursor: pointer; }
#run-peers .rp-peer:hover { fill: var(--rp-dot); }
#run-peers .rp-self { fill: var(--rp-dot); stroke: var(--rp-surface); stroke-width: 2; }
#run-peers .rp-band { fill: var(--rp-ref); opacity: .14; }
#run-peers .rp-mean { stroke: var(--rp-ref); stroke-width: 2; }
#run-peers .rp-lead { stroke: var(--rp-strong); stroke-width: 1; }
</style>

<script>
(function () {
    var rows = [
<#list runPeerRows as row>
        {u: "${row.run?js_string}", l: "${(row.label!"")?js_string}", s: "${(row.start!"")?js_string}", e: "${(row.energy!"")?js_string}", c: "${(row.carbon!"")?js_string}", cpu: "${(row.cpu!"")?js_string}", d: "${(row.duration!"")?js_string}", cv: "${(row.coverage!"")?js_string}", cl: "${(row.cluster!"")?js_string}", cn: "${(row.clusterName!"")?js_string}", use: "${(row.nodeUse!"")?js_string}", nc: "${(row.nodes!"")?js_string}", wf: "${(row.workflow!"")?js_string}", wn: "${(row.workflowName!"")?js_string}"}<#sep>,</#sep>
</#list>
    ];
    var me = "${individual.uri?js_string}";
    var base = "${urls.base?js_string}";
    var SVGNS = 'http://www.w3.org/2000/svg';
    var root = document.getElementById('run-peers');
    if (!root) { return; }

    function num(s) { var v = parseFloat(s); return isFinite(v) ? v : null; }
    function svgEl(tag, attrs, text) {
        var e = document.createElementNS(SVGNS, tag);
        for (var k in attrs) { if (attrs.hasOwnProperty(k)) { e.setAttribute(k, attrs[k]); } }
        if (text !== undefined) { e.textContent = text; }
        return e;
    }
    function fmt(v) {
        if (v === null) { return '–'; }
        var a = Math.abs(v);
        if (a === 0) { return '0'; }
        if (a >= 100) { return Math.round(v).toLocaleString('en'); }
        if (a < 0.001) { return v.toExponential(2); }
        return v.toPrecision(3);
    }
    function fmtTick(t) { return String(+t.toFixed(6)); }
    function niceStep(max, count) {
        var raw = max / count, p = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10)), f = raw / p;
        return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * p;
    }
    // start time shown in Berlin time, as on the workflow plots
    function when(s) {
        var m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(s || '');
        if (m && /(Z|[+-]\d{2}:?\d{2})$/.test(s) && window.Intl) {
            var d = new Date(s);
            if (!isNaN(d.getTime())) {
                var p = {};
                new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Berlin', year: 'numeric', month: '2-digit', day: '2-digit',
                    hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(d).forEach(function (x) { p[x.type] = x.value; });
                return p.year + '-' + p.month + '-' + p.day + ' ' + p.hour + ':' + p.minute;
            }
        }
        return m ? m[1] + '-' + m[2] + '-' + m[3] + ' ' + m[4] + ':' + m[5] : '';
    }
    // node use as on the workflow plots: rm:nodeUse, else the energy measurement coverage of a Slurm run
    function nodeUse(recorded, coverageText) {
        var value = (recorded || '').replace(/^\s+/, '').toLowerCase();
        if (value.indexOf('non-exclusive') === 0) { return 'shared'; }
        if (value.indexOf('exclusive') === 0) { return 'exclusive'; }
        if (/whole node/i.test(coverageText)) { return 'exclusive'; }
        return /of the node \(shared/i.test(coverageText) ? 'shared' : '';
    }
    function timeUnit(maxSeconds) {
        return maxSeconds < 180 ? { unit: 's', div: 1 } : maxSeconds < 10800 ? { unit: 'min', div: 60 } : { unit: 'h', div: 3600 };
    }
    function ordinal(n) { var m = n % 100; if (m >= 11 && m <= 13) { return n + 'th'; } return n + ({ 1: 'st', 2: 'nd', 3: 'rd' }[n % 10] || 'th'); }

    var runs = rows.map(function (r) {
        var nodes = parseInt(r.nc, 10);
        return { uri: r.u, label: r.l || r.u, date: when(r.s), e: num(r.e), c: num(r.c), cpu: num(r.cpu), dur: num(r.d),
                 cluster: r.cl || '', clusterName: r.cn || (r.cl ? decodeURIComponent(r.cl.replace(/^.*[\/#]/, '')) : ''),
                 use: nodeUse(r.use, r.cv), nodes: nodes > 0 ? nodes : 0, wf: r.wf, wfName: r.wn };
    });
    var self = runs.filter(function (r) { return r.uri === me; })[0];
    if (!self) { if (root.parentNode) { root.parentNode.removeChild(root); } return; }
    var key = function (r) { return r.cluster + '|' + r.use + '|' + r.nodes; };
    var peers = runs.filter(function (r) { return key(r) === key(self); });
    var others = runs.length - peers.length;

    var useText = self.use === 'exclusive' ? 'whole node' : self.use === 'shared' ? 'shared node' : 'node use not recorded';
    var nodesText = self.nodes ? (self.nodes === 1 ? '1 node' : self.nodes + ' nodes') : 'nodes not recorded';
    var kind = (self.clusterName || 'cluster not recorded') + ' · ' + useText + ' · ' + nodesText;
    var note = root.querySelector('.rp-note');
    note.appendChild(document.createTextNode('Compared with the ' + peers.length + (peers.length === 1 ? ' run' : ' runs') + ' of this workflow of the same kind (' + kind + '). Orange: mean ± 1 SD of these runs; click a point to open its run. '));
    if (others > 0) {
        note.appendChild(document.createTextNode(others + (others === 1 ? ' other run is' : ' other runs are') + ' left out because their energy is measured differently; '));
        var a = document.createElement('a'); a.textContent = 'all runs are on the workflow page';
        a.href = base + '/individual?uri=' + encodeURIComponent(self.wf); note.appendChild(a); note.appendChild(document.createTextNode('.'));
    }

    var maxOf = function (k) { return peers.reduce(function (m, r) { return Math.max(m, r[k] === null ? 0 : r[k]); }, 0); };
    var maxE = maxOf('e'), maxC = maxOf('c'), tCpu = timeUnit(maxOf('cpu')), tDur = timeUnit(maxOf('dur'));
    var metrics = [
        { k: 'e', t: 'Energy consumed', unit: maxE < 1 ? 'Wh' : 'kWh', mult: maxE < 1 ? 1000 : 1 },
        { k: 'c', t: 'Carbon emission', unit: maxC < 1 ? 'g CO₂e' : 'kg CO₂e', mult: maxC < 1 ? 1000 : 1 },
        { k: 'cpu', t: 'CPU time', unit: tCpu.unit, mult: 1 / tCpu.div },
        { k: 'dur', t: 'Duration', unit: tDur.unit, mult: 1 / tDur.div }
    ].filter(function (m) {
        return self[m.k] !== null && peers.filter(function (r) { return r[m.k] !== null; }).length >= 2;
    });

    var plots = root.querySelector('.rp-plots');
    if (!metrics.length) {
        note.textContent = 'This is the only run of this workflow of its kind (' + kind + ') so far, so there is nothing to compare it with yet.'
            + (others > 0 ? ' ' + others + (others === 1 ? ' other run has' : ' other runs have') + ' a different cluster, node use or number of nodes.' : '');
    }

    function draw() {
        plots.innerHTML = '';
        if (!metrics.length) { return; }
        var W = Math.max(300, Math.floor(plots.clientWidth)), padL = W < 520 ? 96 : 128, padR = 14, rowH = 58, H = metrics.length * rowH + 6;
        var svg = svgEl('svg', { width: W, height: H, viewBox: '0 0 ' + W + ' ' + H, role: 'img',
            'aria-label': 'This run compared with ' + peers.length + ' runs of the same kind' });
        metrics.forEach(function (m, i) {
            var vals = peers.filter(function (r) { return r[m.k] !== null; }), v = function (r) { return r[m.k] * m.mult; };
            var n = vals.length, mean = vals.reduce(function (t, r) { return t + v(r); }, 0) / n;
            var sd = Math.sqrt(vals.reduce(function (t, r) { return t + (v(r) - mean) * (v(r) - mean); }, 0) / (n - 1));
            var max = Math.max(mean + sd, vals.reduce(function (mx, r) { return Math.max(mx, v(r)); }, 0));
            var step = niceStep(max || 1, 4), top = Math.ceil(max / step) * step || step;
            var x = function (val) { return padL + (W - padL - padR) * val / top; };
            var y0 = 6 + i * rowH, cy = y0 + 28;
            svg.appendChild(svgEl('text', { x: 0, y: cy + 1, 'class': 'rp-name' }, m.t));
            svg.appendChild(svgEl('text', { x: 0, y: cy + 15 }, '(' + m.unit + ')'));
            svg.appendChild(svgEl('rect', { 'class': 'rp-band', x: x(Math.max(0, mean - sd)), y: cy - 8, width: Math.max(0, x(mean + sd) - x(Math.max(0, mean - sd))), height: 16 }));
            svg.appendChild(svgEl('line', { 'class': 'rp-mean', x1: x(mean), x2: x(mean), y1: cy - 9, y2: cy + 9 }));
            svg.appendChild(svgEl('line', { 'class': 'rp-axis', x1: padL, x2: W - padR, y1: cy + 12, y2: cy + 12 }));
            for (var t = 0; t <= top + step / 2; t += step) {
                svg.appendChild(svgEl('text', { x: x(t), y: cy + 25, 'text-anchor': 'middle' }, fmtTick(t)));
            }
            var jitter = 0;
            vals.forEach(function (r) {
                if (r === self) { return; }
                jitter = (jitter + 1) % 3;
                var dot = svgEl('circle', { 'class': 'rp-peer', cx: x(v(r)), cy: cy + (jitter - 1) * 3.5, r: 3.8 });
                dot.appendChild(svgEl('title', {}, (r.date || r.label) + '\n' + m.t + ': ' + fmt(v(r)) + ' ' + m.unit));
                dot.addEventListener('click', function () { window.location.href = base + '/individual?uri=' + encodeURIComponent(r.uri); });
                svg.appendChild(dot);
            });
            var sv = v(self), sx = x(sv);
            var rank = 1 + vals.filter(function (r) { return v(r) > sv; }).length, low = n + 1 - rank;
            var rankText = rank <= low ? (rank === 1 ? 'highest' : ordinal(rank) + ' highest') + ' of ' + n : (low === 1 ? 'lowest' : ordinal(low) + ' lowest') + ' of ' + n;
            var dev = sd > 0 ? (sv - mean) / sd : 0;
            var devText = sd > 0 ? (Math.abs(dev) < 0.05 ? ' · at the mean' : ' · ' + (dev >= 0 ? '+' : '−') + Math.abs(dev).toFixed(1) + ' SD') : '';
            var me1 = svgEl('circle', { 'class': 'rp-self', cx: sx, cy: cy, r: 6 });
            me1.appendChild(svgEl('title', {}, 'This run · ' + self.date + '\n' + m.t + ': ' + fmt(sv) + ' ' + m.unit + '\nmean ± SD of the ' + n + ' runs: ' + fmt(mean) + ' ± ' + fmt(sd) + ' ' + m.unit));
            svg.appendChild(me1);
            var label = (W < 520 ? '' : 'this run ') + fmt(sv) + ' ' + m.unit + ' · ' + rankText + (W < 520 ? '' : devText);
            var rightSide = sx > padL + (W - padL - padR) * 0.55;
            svg.appendChild(svgEl('line', { 'class': 'rp-lead', x1: sx, x2: sx, y1: cy - 7, y2: cy - 13 }));
            svg.appendChild(svgEl('text', { x: rightSide ? sx + 4 : sx - 4, y: cy - 16, 'class': 'rp-val', 'text-anchor': rightSide ? 'end' : 'start' }, label));
        });
        plots.appendChild(svg);
    }

    // place at the end of the tab that holds "energy consumed" (data property rm:energyKWh, heading id "energyKWh");
    // without it, after the last tab, at the end of the page
    var anchor = document.getElementById('energyKWh') || document.getElementById('carbonEmissionKgCO2e');
    var pane = anchor && anchor.closest ? anchor.closest('.tab-pane') : null;
    var panes = document.querySelectorAll('.tab-pane');
    if (pane) { pane.appendChild(root); }
    else if (panes.length && panes[panes.length - 1].parentNode) { panes[panes.length - 1].parentNode.appendChild(root); }
    root.hidden = false;
    var lastW = -1, pending = false;
    var schedule = function () {
        if (pending) { return; }
        pending = true;
        // a tab that is not shown has width 0: draw when it is shown (the ResizeObserver fires then)
        window.requestAnimationFrame(function () { pending = false; var w = plots.clientWidth; if (w > 0 && w !== lastW) { lastW = w; draw(); } });
    };
    if (window.ResizeObserver) { new ResizeObserver(schedule).observe(plots); }
    window.addEventListener('resize', schedule);
    schedule();
})();
</script>
</#if>
