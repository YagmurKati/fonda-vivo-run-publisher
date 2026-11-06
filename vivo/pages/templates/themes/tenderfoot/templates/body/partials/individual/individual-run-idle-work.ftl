<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-18: "idle vs. work" on workflow run pages (class rm:RunMetadata).
  Only for runs with rm:energyAboveIdleKWh (HPC@HU Slurm runs with an idle measurement of their node); not shown
  on any other run. Three bars, all from the published values:
    - energy of the run (rm:energyKWh) split into the idle part (energy - energy above idle) and the energy above
      idle (rm:energyAboveIdleKWh)
    - node power: idle power (rm:nodeIdlePowerW), average (rm:nodePowerAvgW) and highest (rm:nodePowerMaxW)
    - CPU efficiency (rm:cpuEfficiencyPercent)
  The node the idle power was measured on is read from rm:nodeConditionsMethod.
  Data:     runIdleRows, from display:fondaRunIdleWorkDataGetter
            (/opt/vivo/vivo/rdf/display/everytime/fonda-run-idle-work.n3). The query runs on every page view.
  Included: by individual--fonda-run.ftl, the custom display view of rm:RunMetadata.
-->
<#if runIdleRows?? && runIdleRows?has_content>
<#assign riw = runIdleRows[0]>
<section id="run-idle-work" class="run-idle-work" aria-labelledby="riw-heading" hidden>
    <h3 id="riw-heading">idle vs. work</h3>
    <p class="riw-note"></p>
    <div class="riw-grid"></div>
    <p class="riw-source"></p>
</section>

<style>
#run-idle-work { --riw-work: #2a78d6; --riw-idle: #b4bcc6; --riw-idle-ink: #2b2d2d; --riw-track: #eef1f4;
    --riw-text: #595b5b; --riw-strong: #2b2d2d; --riw-muted: #6f7272; --riw-head: #064d68;
    color: var(--riw-text); clear: both; margin: 1.2em 0 1.5em; }
html.dark-mode #run-idle-work { --riw-work: #3987e5; --riw-idle: #56627a; --riw-idle-ink: #f1f5f9; --riw-track: #1c2433;
    --riw-text: #d5dde7; --riw-strong: #f1f5f9; --riw-muted: #9aa7b8; --riw-head: #7fc0dd; }
#run-idle-work :not(a) { color: inherit; }
#run-idle-work h3 { font-size: 15px; font-weight: 600; color: var(--riw-head); margin: 0 0 .35em; }
#run-idle-work .riw-note, #run-idle-work .riw-source { color: var(--riw-muted); font-size: 13px; margin: 0 0 .8em; max-width: 62em; }
#run-idle-work .riw-source { margin: .9em 0 0; }
#run-idle-work .riw-grid { display: grid; grid-template-columns: minmax(0, 11em) minmax(0, 1fr) 6.8em;
    column-gap: 12px; row-gap: 2px; align-items: center; font-size: 13px; line-height: 1.35; max-width: 900px; }
#run-idle-work .riw-label { color: var(--riw-strong); }
#run-idle-work .riw-label small { display: block; color: var(--riw-muted); font-size: 11.5px; }
#run-idle-work .riw-val { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; color: var(--riw-strong); font-weight: 600; }
#run-idle-work .riw-legend { grid-column: 2 / 4; color: var(--riw-muted); font-size: 12px; margin: 3px 0 14px; }
#run-idle-work .riw-legend span { display: inline-block; margin-right: 1.1em; white-space: nowrap; }
#run-idle-work .riw-legend i { display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin-right: 5px; vertical-align: -1px; }
#run-idle-work .riw-legend b { color: var(--riw-strong); font-weight: 600; }
#run-idle-work .riw-track { position: relative; display: flex; height: 18px; border-radius: 4px; background: var(--riw-track); }
#run-idle-work .riw-track.thin { height: 12px; }
#run-idle-work .riw-seg { height: 100%; display: flex; align-items: center; justify-content: center; overflow: hidden;
    font-size: 11.5px; font-weight: 600; font-variant-numeric: tabular-nums; white-space: nowrap; }
#run-idle-work .riw-seg:first-child { border-radius: 4px 0 0 4px; }
#run-idle-work .riw-seg:last-of-type { border-radius: 0 4px 4px 0; }
#run-idle-work .riw-seg:only-of-type { border-radius: 4px; }
#run-idle-work .riw-idle { background: var(--riw-idle); color: var(--riw-idle-ink); }
#run-idle-work .riw-work { background: var(--riw-work); color: #fff; }
#run-idle-work .riw-tick { position: absolute; top: -4px; bottom: -4px; width: 2px; margin-left: -1px; background: var(--riw-strong); }
@media (max-width: 600px) {
    #run-idle-work .riw-grid { grid-template-columns: minmax(0, 1fr) 5.8em; }
    #run-idle-work .riw-label { grid-column: 1 / -1; margin-top: 6px; }
    #run-idle-work .riw-label small { display: inline; margin-left: .4em; }
    #run-idle-work .riw-legend { grid-column: 1 / -1; }
    #run-idle-work .riw-legend span { white-space: normal; }
}
</style>

<script>
(function () {
    var d = {e: "${(riw.energy!"")?js_string}", a: "${(riw.aboveIdle!"")?js_string}", i: "${(riw.idlePower!"")?js_string}", sl: "${(riw.sleepPower!"")?js_string}",
             s: "${(riw.duration!"")?js_string}", pa: "${(riw.powerAvg!"")?js_string}", pm: "${(riw.powerMax!"")?js_string}",
             ce: "${(riw.cpuEfficiency!"")?js_string}", use: "${(riw.nodeUse!"")?js_string}",
             cv: "${(riw.coverage!"")?js_string}", cond: "${(riw.conditions!"")?js_string}"};
    var root = document.getElementById('run-idle-work');
    if (!root) { return; }
    function num(s) { var v = parseFloat(s); return isFinite(v) ? v : null; }
    function el(tag, cls, text) {
        var e = document.createElement(tag);
        if (cls) { e.className = cls; }
        if (text !== undefined && text !== null) { e.textContent = text; }
        return e;
    }
    function fmtInt(v) { return Math.round(v).toLocaleString('en'); }
    // node use as on the workflow plots: rm:nodeUse, else the energy measurement coverage of a Slurm run
    function nodeUse(recorded, coverageText) {
        var value = (recorded || '').replace(/^\s+/, '').toLowerCase();
        if (value.indexOf('non-exclusive') === 0) { return 'shared'; }
        if (value.indexOf('exclusive') === 0) { return 'exclusive'; }
        if (/whole node/i.test(coverageText)) { return 'exclusive'; }
        return /of the node \(shared/i.test(coverageText) ? 'shared' : '';
    }

    var E = num(d.e), A = num(d.a), idleW = num(d.i), dur = num(d.s);
    // FONDA 2026-10-30: nodes whose cores sleep when idle have a sleeping idle power instead
    var sleeping = idleW === null && num(d.sl) !== null;
    if (sleeping) { idleW = num(d.sl); }
    var pAvg = num(d.pa), pMax = num(d.pm), eff = num(d.ce);
    if (E === null || A === null || E <= 0) { if (root.parentNode) { root.parentNode.removeChild(root); } return; }
    var shared = nodeUse(d.use, d.cv) === 'shared';
    var idlePart = E - A;
    var workShare = Math.max(0, Math.min(1, A / E)), idleShare = 1 - workShare;
    var wh = E < 1, unit = wh ? 'Wh' : 'kWh';
    function fmtE(kwh) {
        var v = wh ? kwh * 1000 : kwh, sign = v < 0 ? '−' : '';
        v = Math.abs(v);
        return sign + (v >= 100 ? fmtInt(v) : v.toFixed(2)) + ' ' + unit;
    }
    function pct(f) { return Math.round(100 * f) + '%'; }

    var note = root.querySelector('.riw-note');
    note.textContent = 'A node draws its idle power even when it does nothing. Grey: the part of this run\'s energy '
        + 'the node would have drawn anyway (idle power × duration). Blue: energy above idle, what the run\'s work added on top.'
        + (shared ? ' The node was shared with other jobs, so both parts are this run\'s CPU-time share of the node.' : '');

    var grid = root.querySelector('.riw-grid');
    function label(text, sub) {
        var c = el('div', 'riw-label', text);
        if (sub) { c.appendChild(el('small', null, sub)); }
        grid.appendChild(c);
    }
    function legend(items) {
        var c = el('div', 'riw-legend');
        items.forEach(function (it) {
            var s = el('span');
            if (it.color) { var i = el('i'); i.style.background = it.color; s.appendChild(i); }
            s.appendChild(document.createTextNode(it.text + ' '));
            if (it.value) { s.appendChild(el('b', null, it.value)); }
            c.appendChild(s);
        });
        grid.appendChild(c);
    }
    function seg(cls, fraction, text, title) {
        var s = el('div', 'riw-seg ' + cls, fraction >= 0.1 ? text : '');
        s.style.width = (100 * fraction) + '%';
        if (title) { s.title = title; }
        return s;
    }

    // 1. energy of the run: idle part + energy above idle
    var idleWhole = idleW !== null && dur !== null ? idleW * dur / 3600000 : null;
    var jobShare = idleWhole ? idlePart / idleWhole : null;
    var idleTitle = 'Idle part: ' + fmtE(idlePart) + (idleW !== null && dur !== null
        ? ' = idle power ' + fmtInt(idleW) + ' W × ' + fmtInt(dur) + ' s' + (shared && jobShare !== null ? ' × job share ' + jobShare.toFixed(3) : '')
        : '');
    var workTitle = 'Energy above idle: ' + fmtE(A) + ' = energy of the run ' + fmtE(E) + ' − idle part ' + fmtE(idlePart);
    label('energy of the run', shared ? 'this run\'s share' : 'whole node');
    var t1 = el('div', 'riw-track');
    if (idleShare > 0) { t1.appendChild(seg('riw-idle', idleShare, pct(idleShare), idleTitle)); }
    if (workShare > 0) { t1.appendChild(seg('riw-work', workShare, pct(workShare), workTitle)); }
    grid.appendChild(t1);
    grid.appendChild(el('div', 'riw-val', fmtE(E)));
    legend([{ color: 'var(--riw-idle)', text: 'idle part', value: fmtE(idlePart) + ' · ' + pct(idleShare) },
            { color: 'var(--riw-work)', text: A < 0 ? 'above idle (the node drew less than its idle power)' : 'above idle, the work',
              value: fmtE(A) + ' · ' + pct(workShare) }]);

    // 2. node power: idle, average while the run ran, highest
    if (idleW !== null && pAvg !== null) {
        var top = Math.max(idleW, pAvg, pMax || 0) * 1.08;
        label('node power', shared ? 'whole node, all jobs' : 'whole node');
        var t2 = el('div', 'riw-track thin');
        t2.appendChild(seg('riw-idle', Math.min(idleW, pAvg) / top, '', 'Idle power ' + fmtInt(idleW) + ' W'));
        if (pAvg > idleW) { t2.appendChild(seg('riw-work', (pAvg - idleW) / top, '', 'Average while the run ran ' + fmtInt(pAvg) + ' W: ' + fmtInt(pAvg - idleW) + ' W above idle')); }
        if (pMax !== null) {
            var tick = el('div', 'riw-tick');
            tick.style.left = (100 * pMax / top) + '%';
            tick.title = 'Highest ' + fmtInt(pMax) + ' W';
            t2.appendChild(tick);
        }
        grid.appendChild(t2);
        grid.appendChild(el('div', 'riw-val', fmtInt(pAvg) + ' W'));
        var items = [{ color: 'var(--riw-idle)', text: sleeping ? 'idle, cores sleeping' : 'idle', value: fmtInt(idleW) + ' W' },
                     { color: 'var(--riw-work)', text: 'average while the run ran', value: fmtInt(pAvg) + ' W' }];
        if (pMax !== null) { items.push({ color: 'var(--riw-strong)', text: 'highest', value: fmtInt(pMax) + ' W' }); }
        legend(items);
    }

    // 3. CPU efficiency
    if (eff !== null) {
        var f = Math.max(0, Math.min(1, eff / 100));
        label('CPU efficiency', 'reserved CPUs');
        var t3 = el('div', 'riw-track thin');
        if (f > 0) { t3.appendChild(seg('riw-work', f, '', 'CPU efficiency ' + eff.toFixed(1) + '%')); }
        grid.appendChild(t3);
        grid.appendChild(el('div', 'riw-val', Math.round(eff) + '%'));
        legend([{ text: 'share of the reserved CPU time (CPUs × duration) that the run used' }]);
    }

    // where the idle power comes from (text of rm:nodeConditionsMethod)
    var source = root.querySelector('.riw-source');
    var m = /Idle power: (\d+) W, the average IPMI power of node (\S+) with the whole node allocated and no workload \(Slurm job (\d+), (\d{4}-\d{2}-\d{2})/.exec(d.cond);
    if (m) {
        source.textContent = 'Idle power measured on node ' + m[2] + ' on ' + m[4] + ' (Slurm job ' + m[3] + ', whole node, no workload).';
        var other = /No measurement exists for (\S+); the value of (\S+) is used/.exec(d.cond);
        if (other) { source.textContent += ' The run\'s node ' + other[1] + ' has no measurement of its own; the value of ' + other[2] + ', a node of the same kind, is used.'; }
    } else if (source.parentNode) { source.parentNode.removeChild(source); }
    root.hidden = false;
})();
</script>
</#if>
