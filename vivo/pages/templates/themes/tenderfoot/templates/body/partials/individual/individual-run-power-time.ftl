<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-19: "power over time" on workflow run pages (class rm:RunMetadata).
  Top: the node's power during the job (rm:nodePowerReadings, seconds since the job start and watts), split at the
  node's idle power (rm:nodeIdlePowerW): grey = what the node draws anyway, blue = power above idle. Below: when
  each stage of the run ran (prov:startedAtTime / prov:endedAtTime of the stage executions), on the same time axis.
  Hover shows the time, the power and the stages running then. Only runs published with the readings show it
  (collector change of 2026-10-19).
  Data:     runPowerRows and runStageTimeRows, from display:fondaRunPowerDataGetter and
            display:fondaRunStageTimesDataGetter (/opt/vivo/vivo/rdf/display/everytime/fonda-run-power-time.n3).
  Included: by individual--fonda-run.ftl, the custom display view of rm:RunMetadata.
-->
<#-- FONDA 2026-10-26: power over time only for logged-in users (visitors get nothing, not even the data). -->
<#assign fondaShowPowerTime = true>  <#-- FONDA 2026-10-30: public again -->
<#if fondaShowPowerTime && runPowerRows?? && runPowerRows?has_content>
<#assign rpt = runPowerRows[0]>
<section id="run-power-time" class="run-power-time" aria-labelledby="rpt-heading" hidden>
    <h3 id="rpt-heading">power over time</h3>
    <p class="rpt-note"></p>
    <div class="rpt-cap">Node power <span>(W)</span></div>
    <div class="rpt-plot"></div>
    <div class="rpt-tip" role="tooltip" hidden></div>
    <p class="rpt-source"></p>
</section>

<style>
#run-power-time { --rpt-work: #2a78d6; --rpt-line: #1c5cab; --rpt-idle: #b4bcc6; --rpt-stage: #6f8db3; --rpt-surface: #ffffff;
    --rpt-text: #595b5b; --rpt-strong: #2b2d2d; --rpt-muted: #6f7272; --rpt-head: #064d68; --rpt-grid: #e6e8eb; --rpt-base: #b9bec4;
    color: var(--rpt-text); clear: both; margin: 1.2em 0 1.5em; }
html.dark-mode #run-power-time { --rpt-work: #3987e5; --rpt-line: #86b6ef; --rpt-idle: #56627a; --rpt-stage: #6d86ab; --rpt-surface: #0f151f;
    --rpt-text: #d5dde7; --rpt-strong: #f1f5f9; --rpt-muted: #9aa7b8; --rpt-head: #7fc0dd; --rpt-grid: #232e42; --rpt-base: #3b4a63; }
#run-power-time :not(a) { color: inherit; }
#run-power-time h3 { font-size: 15px; font-weight: 600; color: var(--rpt-head); margin: 0 0 .35em; }
#run-power-time .rpt-note { color: var(--rpt-muted); font-size: 13px; margin: 0 0 .7em; max-width: 62em; }
#run-power-time .rpt-source { color: var(--rpt-muted); font-size: 12px; margin: .4em 0 0; max-width: 62em; }
#run-power-time .rpt-cap { font-size: 13px; font-weight: 600; color: var(--rpt-strong); margin: 0 0 2px; }
#run-power-time .rpt-cap span { font-weight: 400; color: var(--rpt-muted); }
#run-power-time .rpt-plot { max-width: 980px; }
#run-power-time svg { display: block; overflow: visible; font-family: inherit; }
#run-power-time svg text { fill: var(--rpt-muted); font-size: 11px; font-variant-numeric: tabular-nums; }
#run-power-time svg .rpt-name { fill: var(--rpt-text); font-size: 11.5px; }
#run-power-time svg .rpt-lab { fill: var(--rpt-strong); font-size: 11.5px; font-weight: 600;
    paint-order: stroke; stroke: var(--rpt-surface); stroke-width: 3px; stroke-linejoin: round; }
#run-power-time .rpt-gridline { stroke: var(--rpt-grid); stroke-width: 1; shape-rendering: crispEdges; }
#run-power-time .rpt-axis { stroke: var(--rpt-base); stroke-width: 1; shape-rendering: crispEdges; }
#run-power-time .rpt-idlearea { fill: var(--rpt-idle); }
#run-power-time .rpt-workarea { fill: var(--rpt-work); opacity: .85; }
#run-power-time .rpt-curve { fill: none; stroke: var(--rpt-line); stroke-width: 1.5; stroke-linejoin: round; }
#run-power-time .rpt-idleline { stroke: var(--rpt-strong); stroke-width: 1; stroke-dasharray: 4 3; shape-rendering: crispEdges; }
#run-power-time .rpt-bar { fill: var(--rpt-stage); }
#run-power-time .rpt-bar.hot { fill: var(--rpt-work); }
#run-power-time .rpt-cross { stroke: var(--rpt-strong); stroke-width: 1; shape-rendering: crispEdges; pointer-events: none; }
#run-power-time .rpt-hit { fill: transparent; cursor: crosshair; }
#run-power-time .rpt-tip { position: fixed; z-index: 1000; pointer-events: none; padding: 6px 9px; border-radius: 4px; max-width: 320px;
    font-size: 12px; line-height: 1.45; background: #ffffff; color: #3a3c3c; border: 1px solid #cfd6de; box-shadow: 0 2px 8px rgba(0,0,0,.15); }
html.dark-mode #run-power-time .rpt-tip { background: #151d2b; color: #d5dde7; border-color: #273349; }
</style>

<script>
(function () {
    var d = {r: "${(rpt.readings!"")?js_string}", m: "${(rpt.method!"")?js_string}", i: "${(rpt.idlePower!"")?js_string}", sl: "${(rpt.sleepPower!"")?js_string}", aw: "${(rpt.awakePower!"")?js_string}",
             dur: "${(rpt.duration!"")?js_string}", e: "${(rpt.energy!"")?js_string}", a: "${(rpt.aboveIdle!"")?js_string}",
             s: "${(rpt.start!"")?js_string}", use: "${(rpt.nodeUse!"")?js_string}", cv: "${(rpt.coverage!"")?js_string}"};
    var stageRows = [
<#if runStageTimeRows??><#list runStageTimeRows as row>
        {t: "${(row.title!"")?js_string}", l: "${(row.label!"")?js_string}", s: "${(row.started!"")?js_string}", e: "${(row.ended!"")?js_string}"}<#sep>,</#sep>
</#list></#if>
    ];
    var SVGNS = 'http://www.w3.org/2000/svg';
    var root = document.getElementById('run-power-time');
    if (!root) { return; }
    function num(s) { var v = parseFloat(s); return isFinite(v) ? v : null; }
    function svgEl(tag, attrs, text) {
        var e = document.createElementNS(SVGNS, tag);
        for (var k in attrs) { if (attrs.hasOwnProperty(k)) { e.setAttribute(k, attrs[k]); } }
        if (text !== undefined) { e.textContent = text; }
        return e;
    }
    function niceStep(max, count) {
        var raw = max / count, p = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10)), f = raw / p;
        return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * p;
    }
    // "0.0 412; 1.0 415; ..." -> [[seconds, watts]]
    var pts = [];
    d.r.split(';').forEach(function (part) {
        var m = /^\s*(-?[0-9.]+)\s+([0-9.]+)\s*$/.exec(part);
        if (m) { pts.push([parseFloat(m[1]), parseFloat(m[2])]); }
    });
    pts.sort(function (a, b) { return a[0] - b[0]; });
    if (pts.length < 3) { if (root.parentNode) { root.parentNode.removeChild(root); } return; }

    var idle = num(d.i), dur = num(d.dur);
    // FONDA 2026-10-30: nodes whose cores sleep when idle have a sleeping (and an awake) idle power instead
    var sleeping = idle === null && num(d.sl) !== null;
    if (sleeping) { idle = num(d.sl); }
    var awake = sleeping ? num(d.aw) : null;
    // FONDA 2026-10-31: neither idle power nor sleeping idle power: the awake idle power alone, as a dotted line
    var awakeOnly = idle === null && num(d.aw) !== null;
    if (awakeOnly) { awake = num(d.aw); }
    var idleName = sleeping ? 'idle, cores sleeping' : 'idle';
    var t0 = 0, t1 = Math.max(dur || 0, pts[pts.length - 1][0]);
    var shared = /^\s*non-exclusive/i.test(d.use) || (!/^\s*exclusive/i.test(d.use) && /of the node \(shared/i.test(d.cv));
    // stages: seconds since the run's start; both times are in the same (local) time, so their difference counts
    function secs(s) { var m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/.exec(s || ''); return m ? Date.UTC(+m[1], m[2] - 1, +m[3], +m[4], +m[5], +m[6]) / 1000 : null; }
    var runStart = secs(d.s);
    var stages = [];
    if (runStart !== null) {
        stageRows.forEach(function (r) {
            var a = secs(r.s), b = secs(r.e);
            if (a === null || b === null) { return; }
            var name = (r.t || r.l || '').replace(/^\s+|\s+$/g, '').replace(/ · run .*$/, '').replace(/ · job \d+$/, '');
            stages.push({ name: name || 'stage', a: a - runStart, b: Math.max(b, a) - runStart });
        });
    }
    stages.sort(function (x, y) { return x.a - y.a || x.b - y.b; });
    var unitT = t1 < 180 ? { u: 's', div: 1 } : t1 < 10800 ? { u: 'min', div: 60 } : { u: 'h', div: 3600 };
    var fmtT = function (s) { var v = s / unitT.div; return (unitT.div === 1 ? Math.round(v) : (Math.round(v * 10) / 10)) + ' ' + unitT.u; };

    var maxW = pts.reduce(function (m, p) { return Math.max(m, p[1]); }, 0);
    var avgW = (function () {   // time-weighted average of the readings
        var sum = 0, span = 0;
        for (var k = 1; k < pts.length; k++) { var dt = pts[k][0] - pts[k - 1][0]; sum += (pts[k][1] + pts[k - 1][1]) / 2 * dt; span += dt; }
        return span > 0 ? sum / span : null;
    })();
    root.querySelector('.rpt-note').textContent = 'Power of the whole node while the run ran'
        + (shared ? ' (the node was shared, so this includes the other jobs on it)' : '') + '. '
        + (idle !== null ? 'Grey: up to the node\'s idle power' + (sleeping ? ' while its cores sleep' : '') + ' (' + Math.round(idle) + ' W), which it draws anyway; blue: power above idle. ' : '')
        + (awake !== null ? 'Dotted: idle power with the node kept awake (' + Math.round(awake) + ' W). ' : '')
        + (awakeOnly ? 'The node\'s idle power itself is not known, so the power is not split. ' : '')
        + (stages.length ? 'Below: when each stage ran. ' : '') + 'Hover for values.';
    if (shared) { root.querySelector('.rpt-cap').firstChild.textContent = 'Node power, all jobs '; }
    var src = root.querySelector('.rpt-source');
    src.textContent = pts.length + ' power readings' + (avgW !== null ? ', average ' + Math.round(avgW) + ' W' : '') + ', highest ' + Math.round(maxW) + ' W.';
    if (d.m) { src.title = d.m; }

    var box = root.querySelector('.rpt-plot'), tip = root.querySelector('.rpt-tip');
    function powerAt(t) {
        var lo = 0, hi = pts.length - 1;
        if (t <= pts[0][0]) { return pts[0][1]; }
        if (t >= pts[hi][0]) { return pts[hi][1]; }
        while (hi - lo > 1) { var mid = (lo + hi) >> 1; if (pts[mid][0] <= t) { lo = mid; } else { hi = mid; } }
        var f = (t - pts[lo][0]) / (pts[hi][0] - pts[lo][0]);
        return pts[lo][1] + f * (pts[hi][1] - pts[lo][1]);
    }
    function draw() {
        box.innerHTML = '';
        var W = Math.floor(box.clientWidth);
        if (W < 10) { return; }
        var narrow = W < 560;
        // stage names: measured, so the label column fits them (long names are shortened with ...)
        var svg = svgEl('svg', { width: W, height: 10 });
        box.appendChild(svg);
        var probe = svgEl('text', { 'class': 'rpt-name', x: 0, y: -100 });
        svg.appendChild(probe);
        var width = function (text) { probe.textContent = text; return probe.getComputedTextLength ? probe.getComputedTextLength() : text.length * 6.5; };
        var longest = stages.reduce(function (m, st) { return Math.max(m, width(st.name)); }, 0);
        var nameW = stages.length ? Math.max(60, Math.min(narrow ? 118 : 240, Math.ceil(longest) + 14)) : 40;
        stages.forEach(function (st) {
            st.label = st.name;
            while (st.label.length > 4 && width(st.label) > nameW - 12) { st.label = st.label.slice(0, -2).replace(/\s+$/, '') + '…'; st.label = st.label.replace(/……$/, '…'); }
        });
        svg.removeChild(probe);
        var padL = nameW, padR = 10, padT = 10, plotH = narrow ? 130 : 160, axisH = 34;
        var rowH = 15, laneTop = padT + plotH + axisH, H = laneTop + stages.length * rowH + (stages.length ? 6 : 0);
        var plotW = Math.max(40, W - padL - padR);
        var x = function (t) { return padL + plotW * (t - t0) / (t1 - t0 || 1); };
        var top = Math.max(maxW, idle || 0, awake || 0) * 1.08, step = niceStep(top, 4); top = Math.ceil(top / step) * step;
        var y = function (v) { return padT + plotH - plotH * Math.max(0, v) / top; };
        svg.setAttribute('height', H); svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H); svg.setAttribute('role', 'img');
        svg.setAttribute('aria-label', 'Node power during the run' + (idle !== null ? ', split at the idle power of ' + Math.round(idle) + ' W' : ''));
        for (var v = 0; v <= top + step / 2; v += step) {
            var ty = Math.round(y(v)) + 0.5;
            svg.appendChild(svgEl('line', { 'class': v > 0 ? 'rpt-gridline' : 'rpt-axis', x1: padL, x2: padL + plotW, y1: ty, y2: ty }));
            svg.appendChild(svgEl('text', { x: padL - 6, y: ty, dy: '.32em', 'text-anchor': 'end' }, String(+v.toFixed(6))));
        }
        // areas: grey below min(power, idle), blue between idle and power
        var line = pts.map(function (p, k) { return (k ? 'L' : 'M') + x(p[0]).toFixed(1) + ',' + y(p[1]).toFixed(1); }).join('');
        var base = 'L' + x(pts[pts.length - 1][0]).toFixed(1) + ',' + y(0) + 'L' + x(pts[0][0]).toFixed(1) + ',' + y(0) + 'Z';
        if (idle !== null) {
            var low = pts.map(function (p, k) { return (k ? 'L' : 'M') + x(p[0]).toFixed(1) + ',' + y(Math.min(p[1], idle)).toFixed(1); }).join('');
            var high = pts.map(function (p, k) { return (k ? 'L' : 'M') + x(p[0]).toFixed(1) + ',' + y(Math.max(p[1], idle)).toFixed(1); }).join('');
            var back = 'L' + x(pts[pts.length - 1][0]).toFixed(1) + ',' + y(idle).toFixed(1) + 'L' + x(pts[0][0]).toFixed(1) + ',' + y(idle).toFixed(1) + 'Z';
            svg.appendChild(svgEl('path', { 'class': 'rpt-idlearea', d: low + base }));
            svg.appendChild(svgEl('path', { 'class': 'rpt-workarea', d: high + back }));
            var iy = Math.round(y(idle)) + 0.5;
            svg.appendChild(svgEl('line', { 'class': 'rpt-idleline', x1: padL, x2: padL + plotW, y1: iy, y2: iy }));
            svg.appendChild(svgEl('text', { 'class': 'rpt-lab', x: padL + plotW - 4, y: iy + 14, 'text-anchor': 'end' }, idleName + ' ' + Math.round(idle) + ' W'));
            if (awake !== null) {
                var ay = Math.round(y(awake)) + 0.5;
                svg.appendChild(svgEl('line', { 'class': 'rpt-idleline', x1: padL, x2: padL + plotW, y1: ay, y2: ay, style: 'stroke-dasharray: 1 3' }));
                svg.appendChild(svgEl('text', { 'class': 'rpt-lab', x: padL + 4, y: ay - 5 }, 'idle, awake ' + Math.round(awake) + ' W'));
            }
        } else {
            svg.appendChild(svgEl('path', { 'class': 'rpt-workarea', d: line + base }));
            if (awakeOnly) {
                var oy = Math.round(y(awake)) + 0.5;
                svg.appendChild(svgEl('line', { 'class': 'rpt-idleline', x1: padL, x2: padL + plotW, y1: oy, y2: oy, style: 'stroke-dasharray: 1 3' }));
                svg.appendChild(svgEl('text', { 'class': 'rpt-lab', x: padL + 4, y: oy - 5 }, 'idle, awake ' + Math.round(awake) + ' W'));
            }
        }
        svg.appendChild(svgEl('path', { 'class': 'rpt-curve', d: line }));
        var peak = pts.reduce(function (m, p) { return p[1] > m[1] ? p : m; }, pts[0]);
        var px = x(peak[0]), anchor = px > padL + plotW * 0.8 ? 'end' : px < padL + plotW * 0.2 ? 'start' : 'middle';
        svg.appendChild(svgEl('text', { 'class': 'rpt-lab', x: px, y: y(peak[1]) - 5, 'text-anchor': anchor }, 'highest ' + Math.round(peak[1]) + ' W'));
        // time axis
        var tstep = niceStep((t1 - t0) / unitT.div, narrow ? 4 : 7) * unitT.div;
        for (var t = 0; t <= t1 + 1e-9; t += tstep) {
            svg.appendChild(svgEl('text', { x: x(t), y: padT + plotH + 15, 'text-anchor': 'middle' }, String(+(t / unitT.div).toFixed(6))));
        }
        svg.appendChild(svgEl('text', { x: padL + plotW / 2, y: padT + plotH + 30, 'text-anchor': 'middle' }, unitT.u === 's' ? 'seconds since the job started' : (unitT.u === 'min' ? 'minutes' : 'hours') + ' since the job started'));
        // stage lanes
        var bars = [];
        stages.forEach(function (st, k) {
            var ry = laneTop + k * rowH;
            var label = svgEl('text', { 'class': 'rpt-name', x: padL - 6, y: ry + rowH / 2, dy: '.32em', 'text-anchor': 'end' }, st.label);
            label.appendChild(svgEl('title', {}, st.name));
            svg.appendChild(label);
            var bx = x(Math.max(t0, st.a)), bw = Math.max(2, x(Math.min(t1, st.b)) - bx);
            var bar = svgEl('rect', { 'class': 'rpt-bar', x: bx, y: ry + 3, width: bw, height: rowH - 6, rx: 2 });
            bar.appendChild(svgEl('title', {}, st.name + '\n' + fmtT(st.a) + ' – ' + fmtT(st.b) + ' (' + fmtT(st.b - st.a) + ')'));
            svg.appendChild(bar);
            bars.push(bar);
        });
        // hover: crosshair over the whole height, power and running stages in the tooltip
        var cross = svgEl('line', { 'class': 'rpt-cross', y1: padT, y2: H, visibility: 'hidden' });
        svg.appendChild(cross);
        var hit = svgEl('rect', { 'class': 'rpt-hit', x: padL, y: padT, width: plotW, height: plotH });
        svg.appendChild(hit);
        hit.addEventListener('mousemove', function (ev) {
            var b = svg.getBoundingClientRect(), cx = Math.max(padL, Math.min(padL + plotW, ev.clientX - b.left));
            var t = t0 + (cx - padL) / plotW * (t1 - t0), w = powerAt(t);
            cross.setAttribute('x1', cx); cross.setAttribute('x2', cx); cross.setAttribute('visibility', 'visible');
            var running = stages.filter(function (st, k) { var on = st.a <= t && t <= st.b; bars[k].classList.toggle('hot', on); return on; });
            tip.textContent = '';
            var head = document.createElement('b'); head.textContent = fmtT(t) + ' · ' + Math.round(w) + ' W'; tip.appendChild(head);
            if (idle !== null) { tip.appendChild(document.createTextNode(w > idle ? ' (' + Math.round(w - idle) + ' W above idle)' : ' (at or below idle)')); }
            if (stages.length) {
                var list = document.createElement('div');
                list.textContent = running.length ? 'Running: ' + running.map(function (st) { return st.name; }).join(', ') : 'No stage running';
                tip.appendChild(list);
            }
            tip.hidden = false;
            var tw = tip.offsetWidth, th = tip.offsetHeight, tx = ev.clientX + 14, tyy = ev.clientY + 14;
            if (tx + tw > window.innerWidth - 8) { tx = ev.clientX - tw - 14; }
            if (tyy + th > window.innerHeight - 8) { tyy = ev.clientY - th - 14; }
            tip.style.left = Math.max(8, tx) + 'px'; tip.style.top = Math.max(8, tyy) + 'px';
        });
        hit.addEventListener('mouseleave', function () {
            cross.setAttribute('visibility', 'hidden'); tip.hidden = true;
            bars.forEach(function (bar) { bar.classList.remove('hot'); });
        });
    }

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
})();
</script>
</#if>
