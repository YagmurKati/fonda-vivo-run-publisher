<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-18: "where the run's resources went" on workflow run pages (class rm:RunMetadata).
  One bar per workflow stage of the run (rm:hasWorkflowProcess), longest CPU time first, with its share of the
  stages' CPU time, its task count and its energy as published for the stage execution.
  Data:     runStageRows, from display:fondaRunStagesDataGetter
            (/opt/vivo/vivo/rdf/display/everytime/fonda-run-stages.n3). The query runs on every page view.
  Included: by individual--fonda-run.ftl, the custom display view of rm:RunMetadata.
  The script places the section below the "workflow stages of the run" list. Shown only when at least two
  stages have a CPU time.
-->
<#if runStageRows?? && runStageRows?size gt 1>
<section id="run-stage-breakdown" class="run-stage-breakdown" aria-labelledby="rsb-heading" hidden>
    <h3 id="rsb-heading">where the run's resources went</h3>
    <p class="rsb-note">One bar per workflow stage, longest CPU time first. Hover a row for its values; click a stage to open its page.</p>
    <div class="rsb-list" role="table" aria-labelledby="rsb-heading"></div>
</section>

<style>
#run-stage-breakdown { --rsb-bar: #2a78d6; --rsb-text: #595b5b; --rsb-strong: #2b2d2d; --rsb-muted: #6f7272;
    --rsb-head: #064d68; --rsb-line: #e3e7ec; --rsb-hl: #eef4fb;
    color: var(--rsb-text); clear: both; margin: 1.2em 0 1.5em; }
html.dark-mode #run-stage-breakdown { --rsb-bar: #3987e5; --rsb-text: #d5dde7; --rsb-strong: #f1f5f9; --rsb-muted: #9aa7b8;
    --rsb-head: #7fc0dd; --rsb-line: #273349; --rsb-hl: #16233a; }
#run-stage-breakdown :not(a) { color: inherit; }
#run-stage-breakdown h3 { font-size: 15px; font-weight: 600; color: var(--rsb-head); margin: 0 0 .35em; }
#run-stage-breakdown .rsb-note { color: var(--rsb-muted); font-size: 13px; margin: 0 0 .8em; }
#run-stage-breakdown .rsb-list { display: grid; grid-template-columns: minmax(0, 16em) minmax(0, 1fr) 7.6em 3.8em 5.2em;
    column-gap: 12px; row-gap: 2px; align-items: center; font-size: 13px; line-height: 1.35; max-width: 900px; }
#run-stage-breakdown .rsb-list.no-energy { grid-template-columns: minmax(0, 16em) minmax(0, 1fr) 7.6em 3.8em; }
#run-stage-breakdown .rsb-row { display: contents; }
#run-stage-breakdown .rsb-row > div { padding: 3px 0; }
#run-stage-breakdown .rsb-row:hover > div { background: var(--rsb-hl); }
#run-stage-breakdown .rsb-h > div { font-size: 12px; color: var(--rsb-muted); padding-bottom: 4px; border-bottom: 1px solid var(--rsb-line); }
#run-stage-breakdown .rsb-sum > div { color: var(--rsb-strong); font-weight: 600; border-top: 1px solid var(--rsb-line); padding-top: 5px; }
#run-stage-breakdown .rsb-n { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
#run-stage-breakdown .rsb-name { overflow-wrap: anywhere; }
#run-stage-breakdown .rsb-track { height: 14px; }
#run-stage-breakdown .rsb-bar { height: 100%; min-width: 2px; background: var(--rsb-bar); border-radius: 0 4px 4px 0; }
@media (max-width: 600px) {
    #run-stage-breakdown .rsb-list { grid-template-columns: minmax(0, 1fr) 6.6em 3em 4.6em; }
    #run-stage-breakdown .rsb-list.no-energy { grid-template-columns: minmax(0, 1fr) 6.6em 3em; }
    #run-stage-breakdown .rsb-trackcell { display: none; }
}
</style>

<script>
(function () {
    var rows = [
<#list runStageRows as row>
        {u: "${row.proc?js_string}", t: "${(row.title!"")?js_string}", l: "${(row.label!"")?js_string}", c: "${(row.cpu!"")?js_string}", n: "${(row.tasks!"")?js_string}", e: "${(row.energy!"")?js_string}"}<#sep>,</#sep>
</#list>
    ];
    var base = "${urls.base?js_string}";

    function num(s) { var v = parseFloat(s); return isFinite(v) ? v : null; }
    function el(tag, cls, text) {
        var e = document.createElement(tag);
        if (cls) { e.className = cls; }
        if (text !== undefined && text !== null) { e.textContent = text; }
        return e;
    }
    function fmtInt(v) { return Math.round(v).toLocaleString('en'); }
    function fmtSeconds(s) {
        if (s === null) { return '–'; }
        if (s < 100) { return (Math.round(s * 10) / 10).toLocaleString('en') + ' s'; }
        if (s < 36000) { return fmtInt(s) + ' s'; }
        var h = Math.floor(s / 3600), m = Math.round((s - h * 3600) / 60);
        return h + ' h ' + m + ' min';
    }

    var stages = rows.map(function (r) {
        var name = (r.t || r.l || '').replace(/^\s+|\s+$/g, '');
        name = name.replace(/ · run .*$/, '');   // labels of stage executions end in " · run <date>"
        return { uri: r.u, name: name || r.u.replace(/^.*[\/#]/, ''), cpu: num(r.c), tasks: num(r.n), kwh: num(r.e) };
    });
    var withCpu = stages.filter(function (s) { return s.cpu !== null && s.cpu > 0; });
    var root = document.getElementById('run-stage-breakdown');
    if (!root) { return; }
    if (withCpu.length < 2) { if (root.parentNode) { root.parentNode.removeChild(root); } return; }

    stages.sort(function (a, b) { return (b.cpu || 0) - (a.cpu || 0) || (a.name < b.name ? -1 : 1); });
    var cpuSum = withCpu.reduce(function (t, s) { return t + s.cpu; }, 0);
    var maxCpu = withCpu.reduce(function (m, s) { return Math.max(m, s.cpu); }, 0);
    var hasEnergy = stages.some(function (s) { return s.kwh !== null; });
    var kwhSum = stages.reduce(function (t, s) { return t + (s.kwh || 0); }, 0);
    var wh = kwhSum < 1;   // show Wh for small runs, kWh otherwise
    var energyUnit = wh ? 'Wh' : 'kWh';
    function fmtEnergy(kwh) {
        if (kwh === null) { return '–'; }
        var v = wh ? kwh * 1000 : kwh;
        return v >= 100 ? fmtInt(v) : v.toFixed(2);
    }
    var tasksSum = stages.reduce(function (t, s) { return t + (s.tasks || 0); }, 0);

    var list = root.querySelector('.rsb-list');
    if (!hasEnergy) { list.classList.add('no-energy'); }
    function row(cls, cells, title) {
        var r = el('div', 'rsb-row' + (cls ? ' ' + cls : ''));
        r.setAttribute('role', 'row');
        if (title) { r.title = title; }
        cells.forEach(function (c) { c.setAttribute('role', cls === 'rsb-h' ? 'columnheader' : 'cell'); r.appendChild(c); });
        list.appendChild(r);
    }
    var head = [el('div', null, 'stage'), el('div', 'rsb-trackcell', ''), el('div', 'rsb-n', 'CPU time'), el('div', 'rsb-n', 'tasks')];
    if (hasEnergy) { head.push(el('div', 'rsb-n', 'energy (' + energyUnit + ')')); }
    row('rsb-h', head);

    stages.forEach(function (s) {
        var share = s.cpu !== null && cpuSum > 0 ? 100 * s.cpu / cpuSum : null;
        var nameCell = el('div', 'rsb-name'), a = el('a', null, s.name);
        a.href = base + '/individual?uri=' + encodeURIComponent(s.uri);
        nameCell.appendChild(a);
        var trackCell = el('div', 'rsb-trackcell'), track = el('div', 'rsb-track'), bar = el('div', 'rsb-bar');
        bar.style.width = (s.cpu !== null && maxCpu > 0 ? 100 * s.cpu / maxCpu : 0) + '%';
        track.appendChild(bar); trackCell.appendChild(track);
        var cpuText = fmtSeconds(s.cpu) + (share !== null ? ' · ' + Math.round(share) + '%' : '');
        var cells = [nameCell, trackCell, el('div', 'rsb-n', cpuText), el('div', 'rsb-n', s.tasks === null ? '–' : fmtInt(s.tasks))];
        if (hasEnergy) { cells.push(el('div', 'rsb-n', fmtEnergy(s.kwh))); }
        var title = s.name + '\nCPU time ' + fmtSeconds(s.cpu) + (share !== null ? ' (' + share.toFixed(1) + '% of the stages)' : '')
            + (s.tasks !== null ? '\n' + fmtInt(s.tasks) + (s.tasks === 1 ? ' task' : ' tasks') : '')
            + (s.kwh !== null ? '\nenergy ' + fmtEnergy(s.kwh) + ' ' + energyUnit : '');
        row(null, cells, title);
    });

    var sum = [el('div', null, 'all ' + stages.length + ' stages'), el('div', 'rsb-trackcell', ''), el('div', 'rsb-n', fmtSeconds(cpuSum)), el('div', 'rsb-n', fmtInt(tasksSum))];
    if (hasEnergy) { sum.push(el('div', 'rsb-n', fmtEnergy(kwhSum))); }
    row('rsb-sum', sum);

    // place below the "workflow stages of the run" list (property rm:hasWorkflowProcess)
    var heading = document.getElementById('hasWorkflowProcess');
    var article = heading && heading.closest ? heading.closest('article') : null;
    if (article && article.parentNode) { article.parentNode.insertBefore(root, article.nextSibling); }
    root.hidden = false;
})();
</script>
</#if>
