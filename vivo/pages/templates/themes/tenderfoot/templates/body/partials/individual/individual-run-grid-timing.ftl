<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-19: "was the timing green?" on workflow run pages (class rm:RunMetadata).
  One bar per hour: the carbon intensity of the German grid in the hours around the run (rm:gridCarbonIntensityHours,
  saved by the collector from the same answer that gave the run's own intensity). The hours the run used are blue,
  the cleanest hour shown is green. The text compares the run's emission with the emission the same energy would
  have had in that cleanest hour. Only runs published with these hours show it (collector change of 2026-10-19).
  Data:     runGridTimingRows, from display:fondaRunGridTimingDataGetter
            (/opt/vivo/vivo/rdf/display/everytime/fonda-run-grid-timing.n3). The query runs on every page view.
  Included: by individual--fonda-run.ftl, the custom display view of rm:RunMetadata.
-->
<#if runGridTimingRows?? && runGridTimingRows?has_content>
<#assign rgt = runGridTimingRows[0]>
<section id="run-grid-timing" class="run-grid-timing" aria-labelledby="rgt-heading" hidden>
    <h3 id="rgt-heading">was the timing green?</h3>
    <p class="rgt-note"></p>
    <p class="rgt-sum"></p>
    <div class="rgt-cap">Grid carbon intensity <span></span></div>
    <div class="rgt-plot"></div>
    <p class="rgt-source"></p>
</section>

<style>
#run-grid-timing { --rgt-run: #2a78d6; --rgt-low: #1baf7a; --rgt-bar: #c3c9d1; --rgt-surface: #ffffff;
    --rgt-text: #595b5b; --rgt-strong: #2b2d2d; --rgt-muted: #6f7272; --rgt-head: #064d68; --rgt-grid: #e6e8eb; --rgt-base: #b9bec4;
    color: var(--rgt-text); clear: both; margin: 1.2em 0 1.5em; }
html.dark-mode #run-grid-timing { --rgt-run: #3987e5; --rgt-low: #199e70; --rgt-bar: #46526a; --rgt-surface: #0f151f;
    --rgt-text: #d5dde7; --rgt-strong: #f1f5f9; --rgt-muted: #9aa7b8; --rgt-head: #7fc0dd; --rgt-grid: #232e42; --rgt-base: #3b4a63; }
#run-grid-timing :not(a) { color: inherit; }
#run-grid-timing h3 { font-size: 15px; font-weight: 600; color: var(--rgt-head); margin: 0 0 .35em; }
#run-grid-timing .rgt-note, #run-grid-timing .rgt-source { color: var(--rgt-muted); font-size: 13px; margin: 0 0 .6em; max-width: 62em; }
#run-grid-timing .rgt-source { font-size: 12px; margin: .4em 0 0; }
#run-grid-timing .rgt-sum { font-size: 13px; margin: 0 0 .9em; max-width: 62em; line-height: 1.5; }
#run-grid-timing .rgt-sum b { color: var(--rgt-strong); }
#run-grid-timing .rgt-plot { max-width: 980px; }
#run-grid-timing .rgt-cap { font-size: 13px; font-weight: 600; color: var(--rgt-strong); margin: 0 0 2px; }
#run-grid-timing .rgt-cap span { font-weight: 400; color: var(--rgt-muted); }
#run-grid-timing svg { display: block; overflow: visible; font-family: inherit; }
#run-grid-timing svg text { fill: var(--rgt-muted); font-size: 11px; font-variant-numeric: tabular-nums; }
#run-grid-timing svg .rgt-lab { fill: var(--rgt-strong); font-size: 11.5px; font-weight: 600;
    paint-order: stroke; stroke: var(--rgt-surface); stroke-width: 3px; stroke-linejoin: round; }
#run-grid-timing .rgt-gridline { stroke: var(--rgt-grid); stroke-width: 1; shape-rendering: crispEdges; }
#run-grid-timing .rgt-axis { stroke: var(--rgt-base); stroke-width: 1; shape-rendering: crispEdges; }
#run-grid-timing .rgt-daymark { stroke: var(--rgt-base); stroke-width: 1; stroke-dasharray: 3 3; shape-rendering: crispEdges; }
#run-grid-timing .rgt-b { fill: var(--rgt-bar); }
#run-grid-timing .rgt-b.run { fill: var(--rgt-run); }
#run-grid-timing .rgt-b.low { fill: var(--rgt-low); }
#run-grid-timing .rgt-b.est { opacity: .55; }
#run-grid-timing .rgt-b:hover { opacity: .8; }
#run-grid-timing .rgt-key { display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin: 0 5px 0 0; vertical-align: -1px; }
</style>

<script>
(function () {
    var d = {h: "${(rgt.hours!"")?js_string}", m: "${(rgt.method!"")?js_string}", i: "${(rgt.intensity!"")?js_string}",
             c: "${(rgt.carbon!"")?js_string}", e: "${(rgt.energy!"")?js_string}", s: "${(rgt.start!"")?js_string}",
             ws: "${(rgt.windowStart!"")?js_string}", we: "${(rgt.windowEnd!"")?js_string}", b: "${(rgt.basis!"")?js_string}"};
    var SVGNS = 'http://www.w3.org/2000/svg';
    var root = document.getElementById('run-grid-timing');
    if (!root) { return; }
    function remove() { if (root.parentNode) { root.parentNode.removeChild(root); } }
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
    function utc(s) { var t = Date.parse(s); return isFinite(t) ? t : null; }

    // "2026-10-17T20:00Z 377.0; 2026-10-17T21:00Z 365.2*; ..." -> [{t, v, est}]
    var hours = [];
    d.h.split(';').forEach(function (part) {
        var m = /^\s*(\d{4}-\d{2}-\d{2}T\d{2}:\d{2})Z\s+([0-9.]+)(\*?)\s*$/.exec(part);
        if (!m) { return; }
        var t = utc(m[1] + ':00Z'), v = num(m[2]);
        if (t !== null && v !== null) { hours.push({ t: t, v: v, est: m[3] === '*' }); }
    });
    hours.sort(function (a, b) { return a.t - b.t; });
    if (hours.length < 2) { remove(); return; }

    // Berlin time labels
    var fmt = function (opts) {
        try { return new Intl.DateTimeFormat('en-GB', Object.assign({ timeZone: 'Europe/Berlin', hourCycle: 'h23' }, opts)); }
        catch (e) { return new Intl.DateTimeFormat('en-GB', opts); }
    };
    var fHour = fmt({ hour: '2-digit', minute: '2-digit' }), fDay = fmt({ day: 'numeric', month: 'short' });
    var hourText = function (t) { return fHour.format(new Date(t)); };
    var dayText = function (t) { return fDay.format(new Date(t)); };

    // the hours the run used: the window of its own intensity, else the hour of its start
    var ws = utc(d.ws), we = utc(d.we);
    hours.forEach(function (h) { h.run = ws !== null && we !== null && h.t >= ws && h.t < we; });
    var runHours = hours.filter(function (h) { return h.run; });
    var low = hours.reduce(function (m, h) { return h.v < m.v ? h : m; }, hours[0]);
    low.low = true;

    var basis = d.b || '';
    var unit = /co2e/i.test(basis) ? 'g CO₂e/kWh' : 'g CO₂/kWh';
    var energy = num(d.e), intensity = num(d.i), carbon = num(d.c);

    root.querySelector('.rgt-note').textContent = 'Carbon intensity of the German grid for each hour around the run (Berlin time). '
        + 'Blue: the hours the run used. Green: the cleanest hour shown. Hover a bar for its value.';

    var sum = root.querySelector('.rgt-sum');
    function add(text, bold) { var n = bold ? document.createElement('b') : document.createTextNode(text); if (bold) { n.textContent = text; } sum.appendChild(n); }
    if (runHours.length && intensity !== null) {
        var first = runHours[0].t, last = runHours[runHours.length - 1].t + 3600000;
        add('The run used ' + hourText(first) + '–' + hourText(last) + ' on ' + dayText(first) + ' at ');
        add(Math.round(intensity * 1000) + ' ' + unit, true);
        if (carbon !== null) { add(' and emitted '); add(fmtG(carbon * 1000) + ' ' + (unit.indexOf('CO₂e') >= 0 ? 'CO₂e' : 'CO₂'), true); }
        add('. ');
        if (low.run) {
            add('It ran in the cleanest hour shown.');
        } else if (energy !== null) {
            var lowG = energy * low.v, runG = carbon !== null ? carbon * 1000 : energy * intensity * 1000;
            add('In the cleanest hour shown, ' + hourText(low.t) + ' on ' + dayText(low.t) + ' (' + Math.round(low.v) + ' ' + unit + '), the same energy would have emitted ');
            add(fmtG(lowG), true);
            var change = runG > 0 ? Math.round(100 * (lowG - runG) / runG) : null;
            add(change !== null ? ' (' + (change < 0 ? '−' + (-change) : '+' + change) + ' %).' : '.');
        }
    } else {
        sum.parentNode.removeChild(sum);
    }
    function fmtG(g) { return (g >= 100 ? Math.round(g).toLocaleString('en') : g >= 10 ? g.toFixed(1) : g.toFixed(2)) + ' g'; }

    root.querySelector('.rgt-cap span').textContent = '(' + unit + ')';
    var src = root.querySelector('.rgt-source');
    var anyEst = hours.some(function (h) { return h.est; });
    src.textContent = hours.length + ' hours as returned by the carbon source together with the run\'s own hours'
        + (basis ? ' (' + basis + ')' : '') + '.' + (anyEst ? ' Lighter bars: estimated by the source.' : '');
    if (d.m) { src.title = d.m; }

    var box = root.querySelector('.rgt-plot');
    function draw() {
        box.innerHTML = '';
        var W = Math.floor(box.clientWidth);
        if (W < 10) { return; }
        var t0 = hours[0].t, t1 = hours[hours.length - 1].t + 3600000, span = (t1 - t0) / 3600000;
        var max = hours.reduce(function (m, h) { return Math.max(m, h.v); }, 0);
        var step = niceStep(max || 1, 4), top = Math.ceil(max * 1.12 / step) * step || step;
        var padL = 42, padR = 8, padT = 22, plotH = 150, H = padT + plotH + 34, plotW = Math.max(40, W - padL - padR);
        var slot = plotW / span, bw = Math.max(1, slot - Math.min(3, slot * 0.25));
        var x = function (t) { return padL + plotW * (t - t0) / (t1 - t0); };
        var y = function (v) { return padT + plotH - plotH * v / top; };
        var svg = svgEl('svg', { width: W, height: H, viewBox: '0 0 ' + W + ' ' + H, role: 'img',
            'aria-label': 'Carbon intensity of the German grid per hour around the run; the run used the blue hours' });
        for (var v = 0; v <= top + step / 2; v += step) {
            var ty = Math.round(y(v)) + 0.5;
            svg.appendChild(svgEl('line', { 'class': v > 0 ? 'rgt-gridline' : 'rgt-axis', x1: padL, x2: padL + plotW, y1: ty, y2: ty }));
            svg.appendChild(svgEl('text', { x: padL - 8, y: ty, dy: '.32em', 'text-anchor': 'end' }, String(+v.toFixed(6))));
        }
        // hour ticks every 3 hours (Berlin time); a dashed line and the date at midnight
        var every = span > 30 ? 6 : 3, lastX = -100;
        hours.forEach(function (h) {
            var hh = parseInt(hourText(h.t).slice(0, 2), 10), cx = x(h.t);
            if (h === hours[0] || hh === 0) {
                if (h !== hours[0]) { svg.appendChild(svgEl('line', { 'class': 'rgt-daymark', x1: Math.round(cx) + 0.5, x2: Math.round(cx) + 0.5, y1: padT - 6, y2: padT + plotH })); }
                svg.appendChild(svgEl('text', { x: cx + (h === hours[0] ? 0 : 4), y: padT - 9 }, dayText(h.t)));
            }
            if (hh % every === 0 && cx - lastX > 34) {
                svg.appendChild(svgEl('text', { x: cx, y: padT + plotH + 15, 'text-anchor': 'middle' }, hourText(h.t)));
                lastX = cx;
            }
        });
        svg.appendChild(svgEl('text', { x: padL + plotW / 2, y: padT + plotH + 30, 'text-anchor': 'middle' }, 'hour (Berlin time)'));
        hours.forEach(function (h) {
            var bx = x(h.t) + (slot - bw) / 2, by = y(h.v), bh = Math.max(0, y(0) - by), r = Math.min(3, bw / 2, bh);
            var path = 'M' + bx + ',' + y(0) + 'V' + (by + r) + 'Q' + bx + ',' + by + ' ' + (bx + r) + ',' + by
                + 'H' + (bx + bw - r) + 'Q' + (bx + bw) + ',' + by + ' ' + (bx + bw) + ',' + (by + r) + 'V' + y(0) + 'Z';
            var bar = svgEl('path', { d: path, 'class': 'rgt-b' + (h.run ? ' run' : h.low ? ' low' : '') + (h.est ? ' est' : '') });
            bar.appendChild(svgEl('title', {}, dayText(h.t) + ' ' + hourText(h.t) + '–' + hourText(h.t + 3600000) + ' · '
                + Math.round(h.v) + ' ' + unit + (h.est ? ' (estimated)' : '') + (h.run ? '\nthe run used this hour' : '') + (h.low ? '\ncleanest hour shown' : '')));
            svg.appendChild(bar);
        });
        // labels above the run's hours and above the cleanest hour
        function label(h, text) {
            var cx = x(h.t) + slot / 2, side = cx > padL + plotW * 0.8 ? 'end' : cx < padL + plotW * 0.2 ? 'start' : 'middle';
            svg.appendChild(svgEl('text', { 'class': 'rgt-lab', x: cx, y: y(h.v) - 6, 'text-anchor': side }, text));
        }
        if (runHours.length) {
            var peak = runHours.reduce(function (m, h) { return h.v > m.v ? h : m; }, runHours[0]);
            label(peak, low.run ? 'this run · cleanest' : 'this run');
        }
        if (!low.run) { label(low, 'cleanest ' + Math.round(low.v)); }
        box.appendChild(svg);
    }

    // after "idle vs. work" if it is there (both are above the property tabs)
    root.hidden = false;
    var lastW = -1, pending = false;
    var schedule = function () {
        if (pending) { return; }
        pending = true;
        window.requestAnimationFrame(function () { pending = false; var w = box.clientWidth; if (w !== lastW) { lastW = w; draw(); } });
    };
    if (window.ResizeObserver) { new ResizeObserver(schedule).observe(box); }
    window.addEventListener('resize', schedule);
    schedule();
})();
</script>
</#if>
