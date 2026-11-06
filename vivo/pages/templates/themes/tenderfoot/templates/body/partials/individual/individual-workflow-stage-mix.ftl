<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-18: "stage mix per run" on workflow pages (class rm:Workflow).
  One column per run, in chronological order, split by each stage's share of the CPU time of all stages of that
  run (the same shares as on the run page, "where the run's resources went"). The four stages with the largest
  average share get their own colour, the others are grouped as "other". Colours follow the stage, not the run.
  Hover a column for its values; a column opens the run page. A table with the same values is below the chart.
  Shown only when at least two runs have a CPU time for their stages and some run has more than one stage.
  Data:     workflowStageMixRows, from display:fondaWorkflowStageMixDataGetter
            (/opt/vivo/vivo/rdf/display/everytime/fonda-workflow-stage-mix.n3). The query runs on every page view.
  Included: by individual--fonda-workflow.ftl (the view of workflows and workflow stages); on stage pages there
            is no data, so nothing is shown. Placed below "energy, carbon and time per run".
  Colours:  blue, aqua, violet, yellow (light and dark steps checked for colour-blind separation), grey = other.
  2026-10-18: the y axis is labelled "share of run's CPU time (%)" (written along the axis).
-->
<#if workflowStageMixRows?? && workflowStageMixRows?size gt 1>
<section id="workflow-stage-mix" class="workflow-stage-mix" aria-labelledby="wsm-heading" hidden>
    <h3 id="wsm-heading">stage mix per run</h3>
    <p class="wsm-note">One column per run, in chronological order, split by each stage's share of the CPU time of all its stages.
       The four largest stages have their own colour; the rest are grouped. Hover a column for values; click to open the run.</p>
    <div class="wsm-legend"></div>
    <div class="wsm-plot"></div>
    <div class="wsm-table-wrap"></div>
    <div class="wsm-tip" role="tooltip" hidden></div>
</section>

<style>
#workflow-stage-mix { --wsm-1: #2a78d6; --wsm-2: #1baf7a; --wsm-3: #6250d6; --wsm-4: #eda100; --wsm-other: #b4bcc6;
    --wsm-surface: #ffffff; --wsm-text: #595b5b; --wsm-strong: #2b2d2d; --wsm-muted: #6f7272; --wsm-head: #064d68;
    --wsm-grid: #e6e8eb; --wsm-base: #b9bec4; --wsm-line: #e3e7ec; --wsm-hl: #eef4fb;
    color: var(--wsm-text); clear: both; margin: 1.6em 0 1.5em; }
html.dark-mode #workflow-stage-mix { --wsm-1: #3987e5; --wsm-2: #199e70; --wsm-3: #9085e9; --wsm-4: #c98500; --wsm-other: #56627a;
    --wsm-surface: #0f151f; --wsm-text: #d5dde7; --wsm-strong: #f1f5f9; --wsm-muted: #9aa7b8; --wsm-head: #7fc0dd;
    --wsm-grid: #232e42; --wsm-base: #3b4a63; --wsm-line: #273349; --wsm-hl: #16233a; }
#workflow-stage-mix :not(a) { color: inherit; }
#workflow-stage-mix h3 { font-size: 15px; font-weight: 600; color: var(--wsm-head); margin: 0 0 .35em; }
#workflow-stage-mix .wsm-note { color: var(--wsm-muted); font-size: 13px; margin: 0 0 .7em; max-width: 62em; }
#workflow-stage-mix .wsm-legend { display: flex; flex-wrap: wrap; gap: 4px 1.3em; font-size: 12.5px; margin: 0 0 .5em; max-width: 980px; }
#workflow-stage-mix .wsm-legend span { white-space: nowrap; }
#workflow-stage-mix .wsm-legend i { display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin-right: 6px; vertical-align: -1px; }
#workflow-stage-mix .wsm-legend b { font-weight: 600; color: var(--wsm-strong); }
#workflow-stage-mix .wsm-legend small { color: var(--wsm-muted); font-size: 12px; margin-left: .3em; }
#workflow-stage-mix .wsm-plot { max-width: 980px; }
#workflow-stage-mix svg { display: block; overflow: visible; font-family: inherit; }
#workflow-stage-mix svg text { fill: var(--wsm-muted); font-size: 11px; font-variant-numeric: tabular-nums; }
#workflow-stage-mix .wsm-gridline { stroke: var(--wsm-grid); stroke-width: 1; shape-rendering: crispEdges; }
#workflow-stage-mix .wsm-axis { stroke: var(--wsm-base); stroke-width: 1; shape-rendering: crispEdges; }
#workflow-stage-mix .wsm-col { transition: opacity .12s; }
#workflow-stage-mix svg.focus .wsm-col { opacity: .4; }
#workflow-stage-mix svg.focus .wsm-col.hot { opacity: 1; }
#workflow-stage-mix .wsm-seg { stroke: var(--wsm-surface); stroke-width: 1; }
#workflow-stage-mix .wsm-hit { fill: transparent; cursor: pointer; }
#workflow-stage-mix .wsm-tip { position: fixed; z-index: 1000; pointer-events: none; padding: 7px 10px; border-radius: 4px;
    font-size: 12px; line-height: 1.5; background: #ffffff; color: #3a3c3c; border: 1px solid #cfd6de; box-shadow: 0 2px 8px rgba(0,0,0,.15); }
html.dark-mode #workflow-stage-mix .wsm-tip { background: #151d2b; color: #d5dde7; border-color: #273349; }
#workflow-stage-mix .wsm-tip table { border-collapse: collapse; margin: 3px 0 0; }
#workflow-stage-mix .wsm-tip td { padding: 0 12px 0 0; border: 0; white-space: nowrap; }
#workflow-stage-mix .wsm-tip td.n { text-align: right; font-variant-numeric: tabular-nums; }
#workflow-stage-mix .wsm-tip i { display: inline-block; width: 9px; height: 9px; border-radius: 2px; margin-right: 6px; vertical-align: -1px; }
#workflow-stage-mix .wsm-tip .foot { margin-top: 3px; opacity: .75; }
#workflow-stage-mix .wsm-table-wrap { overflow-x: auto; max-width: 980px; }
#workflow-stage-mix details { margin-top: 1.2em; }
#workflow-stage-mix details > summary { display: inline-flex; align-items: center; gap: .6em; list-style: none; cursor: pointer; user-select: none;
    margin: 0; padding: 5px 12px 5px 11px; border-radius: 4px; background: #eceff3; color: #23395d; font-size: 13px; font-weight: 600; line-height: 1.4; }
#workflow-stage-mix details > summary::-webkit-details-marker { display: none; }
#workflow-stage-mix details > summary::marker { content: ''; }
#workflow-stage-mix details > summary::before { content: ''; flex: 0 0 auto; width: 6px; height: 6px; border-right: 2px solid currentColor;
    border-bottom: 2px solid currentColor; transform: rotate(-45deg); transition: transform .15s; }
#workflow-stage-mix details[open] > summary::before { transform: translateY(-2px) rotate(45deg); }
#workflow-stage-mix details > summary:hover { background: #dfe4ea; }
html.dark-mode #workflow-stage-mix details > summary { background: #1f2a3d; color: #7fc0dd; }
html.dark-mode #workflow-stage-mix details > summary:hover { background: #273349; }
#workflow-stage-mix table.wsm-values { border-collapse: collapse; margin-top: .6em; font-size: 13px; line-height: 1.35; }
#workflow-stage-mix table.wsm-values th, #workflow-stage-mix table.wsm-values td { text-align: left; padding: 4px 12px 4px 0;
    border-bottom: 1px solid var(--wsm-line); white-space: nowrap; }
#workflow-stage-mix table.wsm-values th { font-weight: 600; color: var(--wsm-strong); vertical-align: bottom; }
#workflow-stage-mix table.wsm-values .n { text-align: right; font-variant-numeric: tabular-nums; }
#workflow-stage-mix table.wsm-values tr.hl td { background: var(--wsm-hl); }
</style>

<script>
(function () {
    var rows = [
<#list workflowStageMixRows as row>
        {r: "${row.run?js_string}", s: "${(row.start!"")?js_string}", p: "${row.proc?js_string}", c: "${(row.cpu!"")?js_string}", st: "${(row.stage!"")?js_string}", sn: "${(row.stageName!"")?js_string}", pn: "${(row.procName!"")?js_string}", pl: "${(row.procLabelText!"")?js_string}"}<#sep>,</#sep>
</#list>
    ];
    var base = "${urls.base?js_string}";
    var SVGNS = 'http://www.w3.org/2000/svg';
    var COLORS = ['var(--wsm-1)', 'var(--wsm-2)', 'var(--wsm-3)', 'var(--wsm-4)'], OTHER = 'var(--wsm-other)';

    function num(s) { var v = parseFloat(s); return isFinite(v) ? v : null; }
    function el(tag, cls, text) {
        var e = document.createElement(tag);
        if (cls) { e.className = cls; }
        if (text !== undefined && text !== null) { e.textContent = text; }
        return e;
    }
    function svgEl(tag, attrs) {
        var e = document.createElementNS(SVGNS, tag);
        for (var k in attrs) { if (attrs.hasOwnProperty(k)) { e.setAttribute(k, attrs[k]); } }
        return e;
    }
    function niceStep(max, count) {
        var raw = max / count, p = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10)), f = raw / p;
        return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * p;
    }
    function pct(v) { return v >= 9.95 ? Math.round(v) + '%' : v >= 0.05 ? (Math.round(v * 10) / 10) + '%' : (v > 0 ? '<0.1%' : '0%'); }
    function fmtSeconds(s) {
        if (s < 100) { return (Math.round(s * 10) / 10).toLocaleString('en') + ' s'; }
        if (s < 36000) { return Math.round(s).toLocaleString('en') + ' s'; }
        var h = Math.floor(s / 3600); return h + ' h ' + Math.round((s - h * 3600) / 60) + ' min';
    }
    function trim(s) { return (s || '').replace(/^\s+|\s+$/g, ''); }
    // start time in Berlin time, as on the other plots
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

    function start() {
        var root = document.getElementById('workflow-stage-mix');
        if (!root) { return; }
        var remove = function () { if (root.parentNode) { root.parentNode.removeChild(root); } };

        // ---- runs: CPU time per stage of the workflow (each stage execution counted once)
        var runOf = {}, runs = [], stageOf = {}, stages = [], keyOfName = {};
        var norm = function (s) { return trim(s).replace(/_/g, ' ').replace(/\s+/g, ' ').toLowerCase(); };
        // an execution without a link to its stage is put with the stage of the same name
        rows.forEach(function (r) { if (r.st && trim(r.sn)) { keyOfName[norm(r.sn)] = r.st; } });
        rows.forEach(function (r) {
            var run = runOf[r.r];
            if (!run) { run = runOf[r.r] = { uri: r.r, start: r.s, procs: {}, cpu: {}, total: 0 }; runs.push(run); }
            if (!run.start && r.s) { run.start = r.s; }
            var name = trim(r.sn) || trim(r.pn) || trim(r.pl).replace(/ · run .*$/, '').replace(/ · job \d+$/, '') || r.p.replace(/^.*[\/#]/, '');
            var key = r.st || keyOfName[norm(name)] || 'name:' + norm(name);
            var st = stageOf[key];
            if (!st) { st = stageOf[key] = { key: key, uri: r.st, name: name, sum: 0 }; stages.push(st); }
            if (r.sn && st.name !== trim(r.sn)) { st.name = trim(r.sn); }
            var c = num(r.c);
            if (c === null || c < 0 || run.procs[r.p]) { return; }
            run.procs[r.p] = true;
            run.cpu[key] = (run.cpu[key] || 0) + c;
            run.total += c;
        });
        runs = runs.filter(function (r) { return r.total > 0; });
        if (runs.length < 2 || !runs.some(function (r) { return Object.keys(r.cpu).length > 1; })) { remove(); return; }
        runs.sort(function (a, b) { var x = a.start || '9', y = b.start || '9'; return x < y ? -1 : x > y ? 1 : (a.uri < b.uri ? -1 : 1); });
        runs.forEach(function (r, i) { r.n = i + 1; r.date = when(r.start); });
        var n = runs.length;

        // ---- the four stages with the largest average share get a colour; the rest are "other"
        stages.forEach(function (st) {
            st.sum = runs.reduce(function (t, r) { return t + (r.cpu[st.key] || 0) / r.total; }, 0);
            st.mean = 100 * st.sum / n;
        });
        stages = stages.filter(function (st) { return st.sum > 0; });
        stages.sort(function (a, b) { return b.sum - a.sum || (a.name < b.name ? -1 : 1); });
        var named = stages.slice(0, 4);
        var rest = stages.slice(named.length);
        var groups = named.map(function (st, i) { return { name: st.name, color: COLORS[i], keys: [st.key], uri: st.uri, mean: st.mean }; });
        if (rest.length) {
            groups.push({ name: rest.length === 1 ? rest[0].name : 'other ' + rest.length + ' stages', color: OTHER,
                          keys: rest.map(function (st) { return st.key; }), other: true, mean: rest.reduce(function (t, st) { return t + st.mean; }, 0),
                          title: rest.map(function (st) { return st.name; }).join(', ') });
        }
        runs.forEach(function (r) {
            r.parts = groups.map(function (g) {
                var c = g.keys.reduce(function (t, k) { return t + (r.cpu[k] || 0); }, 0);
                return { g: g, cpu: c, share: 100 * c / r.total };
            });
        });

        // ---- legend (always shown: colour is never the only key; the table below has the values)
        var legend = root.querySelector('.wsm-legend');
        groups.forEach(function (g) {
            var s = el('span'), i = el('i');
            i.style.background = g.color; s.appendChild(i);
            s.appendChild(el('b', null, g.name));
            s.appendChild(el('small', null, 'avg ' + pct(g.mean)));
            if (g.title) { s.title = g.title; }
            legend.appendChild(s);
        });

        // ---- chart
        var box = root.querySelector('.wsm-plot'), tip = root.querySelector('.wsm-tip'), tableRows = [], svg = null, cols = [];
        function showTip(i, x, y) {
            var r = runs[i];
            tip.innerHTML = '';
            tip.appendChild(el('b', null, 'Run ' + r.n + ' of ' + n + (r.date ? ' · ' + r.date : '')));
            var t = el('table');
            r.parts.slice().reverse().forEach(function (p) {
                if (p.cpu <= 0) { return; }
                var tr = el('tr'), td = el('td'), k = el('i');
                k.style.background = p.g.color; td.appendChild(k); td.appendChild(document.createTextNode(p.g.name));
                tr.appendChild(td); tr.appendChild(el('td', 'n', pct(p.share))); tr.appendChild(el('td', 'n', fmtSeconds(p.cpu)));
                t.appendChild(tr);
            });
            tip.appendChild(t);
            tip.appendChild(el('div', 'foot', 'CPU time of all stages: ' + fmtSeconds(r.total)));
            tip.hidden = false;
            var w = tip.offsetWidth, h = tip.offsetHeight, px = x + 16, py = y + 16;
            if (px + w > window.innerWidth - 8) { px = x - w - 16; }
            if (py + h > window.innerHeight - 8) { py = y - h - 16; }
            tip.style.left = Math.max(8, px) + 'px'; tip.style.top = Math.max(8, py) + 'px';
        }
        function mark(i) {
            if (svg) { svg.classList.toggle('focus', i !== null); }
            cols.forEach(function (c, j) { c.classList.toggle('hot', j === i); });
            tableRows.forEach(function (tr, j) { tr.classList.toggle('hl', j === i); });
        }
        function draw() {
            box.innerHTML = ''; svg = null; cols = [];
            var W = Math.floor(box.clientWidth);
            if (W < 10) { return; }
            var padL = 54, padR = 8, padT = 8, plotH = 180, H = padT + plotH + 36, plotW = Math.max(40, W - padL - padR), slot = plotW / n;
            var bw = Math.max(2, Math.min(32, slot * 0.72)), rad = Math.min(4, bw / 2);
            var y = function (v) { return padT + plotH - plotH * v / 100; };
            svg = svgEl('svg', { width: W, height: H, viewBox: '0 0 ' + W + ' ' + H, role: 'img',
                'aria-label': 'Share of each stage in the CPU time of ' + n + ' runs; the table below has the values' });
            [0, 25, 50, 75, 100].forEach(function (t) {
                var ty = Math.round(y(t)) + 0.5;
                svg.appendChild(svgEl('line', { 'class': t ? 'wsm-gridline' : 'wsm-axis', x1: padL, x2: padL + plotW, y1: ty, y2: ty }));
                var lab = svgEl('text', { x: padL - 8, y: ty, dy: '.32em', 'text-anchor': 'end' }); lab.textContent = t + '%'; svg.appendChild(lab);
            });
            var ym = padT + plotH / 2, yt = svgEl('text', { x: 10, y: ym, 'text-anchor': 'middle', transform: 'rotate(-90 10 ' + ym + ')' });
            yt.textContent = 'share of run\'s CPU time (%)'; svg.appendChild(yt);
            var defs = svgEl('defs', {}); svg.appendChild(defs);
            var uid = 'wsm' + Math.random().toString(36).slice(2, 8);
            runs.forEach(function (r, i) {
                var cx = padL + slot * (i + 0.5), x0 = cx - bw / 2, top = y(100), bot = y(0);
                // rounded top end only; the bottom sits on the axis
                var clip = svgEl('clipPath', { id: uid + i });
                clip.appendChild(svgEl('path', { d: 'M' + x0 + ',' + bot + 'V' + (top + rad) + 'Q' + x0 + ',' + top + ' ' + (x0 + rad) + ',' + top
                    + 'H' + (x0 + bw - rad) + 'Q' + (x0 + bw) + ',' + top + ' ' + (x0 + bw) + ',' + (top + rad) + 'V' + bot + 'Z' }));
                defs.appendChild(clip);
                var g = svgEl('g', { 'class': 'wsm-col', 'clip-path': 'url(#' + uid + i + ')' });
                var acc = 0;
                r.parts.forEach(function (p) {
                    if (p.share <= 0) { return; }
                    var y1 = y(acc + p.share), y2 = y(acc);
                    g.appendChild(svgEl('rect', { 'class': 'wsm-seg', x: x0, y: y1, width: bw, height: Math.max(0, y2 - y1), fill: p.g.color }));
                    acc += p.share;
                });
                svg.appendChild(g); cols.push(g);
            });
            var xs = n <= 12 ? 1 : Math.max(1, Math.round(niceStep(n, 5))), xt = [1];
            for (var k = xs; k <= n; k += xs) { if (k > 1) { xt.push(k); } }
            xt.forEach(function (k) {
                var t = svgEl('text', { x: padL + slot * (k - 0.5), y: padT + plotH + 16, 'text-anchor': 'middle' }); t.textContent = String(k); svg.appendChild(t);
            });
            var xl = svgEl('text', { x: padL + plotW / 2, y: padT + plotH + 31, 'text-anchor': 'middle' }); xl.textContent = 'run index (chronological)'; svg.appendChild(xl);
            var hit = svgEl('rect', { 'class': 'wsm-hit', x: padL, y: padT, width: plotW, height: plotH + 20 });
            var at = function (clientX) { var b = svg.getBoundingClientRect(); return Math.max(0, Math.min(n - 1, Math.floor((clientX - b.left - padL) / slot))); };
            hit.addEventListener('mousemove', function (ev) { var i = at(ev.clientX); mark(i); showTip(i, ev.clientX, ev.clientY); });
            hit.addEventListener('mouseleave', function () { mark(null); tip.hidden = true; });
            hit.addEventListener('click', function (ev) { window.location.href = base + '/individual?uri=' + encodeURIComponent(runs[at(ev.clientX)].uri); });
            svg.appendChild(hit);
            box.appendChild(svg);
        }

        // ---- table with the same values (collapsed)
        var details = el('details');
        details.appendChild(el('summary', null, 'stage shares per run (' + n + ')'));
        var table = el('table', 'wsm-values'), hr = el('tr');
        [['#', 'n'], ['run', '']].concat(groups.map(function (g) { return [g.name, 'n', g.title]; })).concat([['CPU time, all stages', 'n']]).forEach(function (h) {
            var th = el('th', h[1] || null, h[0]); th.scope = 'col';
            if (h[2]) { th.title = h[2]; th.style.cursor = 'help'; }
            hr.appendChild(th);
        });
        var thead = el('thead'); thead.appendChild(hr); table.appendChild(thead);
        var tbody = el('tbody');
        runs.forEach(function (r, i) {
            var tr = el('tr'), td = el('td'), a = el('a', null, r.date || r.uri.replace(/^.*[\/#]/, ''));
            tr.appendChild(el('td', 'n', String(r.n)));
            a.href = base + '/individual?uri=' + encodeURIComponent(r.uri); td.appendChild(a); tr.appendChild(td);
            r.parts.forEach(function (p) { tr.appendChild(el('td', 'n', pct(p.share))); });
            tr.appendChild(el('td', 'n', fmtSeconds(r.total)));
            tr.addEventListener('mouseenter', function () { mark(i); });
            tr.addEventListener('mouseleave', function () { mark(null); });
            tbody.appendChild(tr); tableRows.push(tr);
        });
        table.appendChild(tbody); details.appendChild(table);
        root.querySelector('.wsm-table-wrap').appendChild(details);

        // ---- below "energy, carbon and time per run", else below the "workflow runs" list
        var plots = document.getElementById('workflow-run-metrics');
        var title = document.getElementById('hasRun') || document.getElementById('hasWorkflowRun');
        var after = plots && plots.parentNode ? plots : (title && title.closest ? title.closest('article') : null);
        if (after && after.parentNode) { after.parentNode.insertBefore(root, after.nextSibling); }
        root.hidden = false;
        var lastW = -1, pending = false;
        var schedule = function () {
            if (pending) { return; }
            pending = true;
            window.requestAnimationFrame(function () { pending = false; var w = box.clientWidth; if (w !== lastW) { lastW = w; tip.hidden = true; draw(); } });
        };
        if (window.ResizeObserver) { new ResizeObserver(schedule).observe(box); }
        window.addEventListener('resize', schedule);
        schedule();
    }
    // after the page is parsed, so that the plots above are already in place
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', start); } else { start(); }
})();
</script>
</#if>
