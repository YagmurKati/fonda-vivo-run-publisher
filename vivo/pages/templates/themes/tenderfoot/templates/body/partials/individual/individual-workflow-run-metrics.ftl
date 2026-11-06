<#-- FONDA 2026-10-26: energy above idle only for logged-in users (plot, hover, table and page data). -->
<#assign fondaShowAboveIdle = true>  <#-- FONDA 2026-10-30: public again -->
<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-09-29: "energy, carbon and time per run" plots on workflow pages (class rm:Workflow).
  Data:     workflowRunMetricRows, from display:fondaWorkflowRunMetricsDataGetter
            (/opt/vivo/vivo/rdf/display/everytime/fonda-workflow-run-metrics.n3). The query runs on
            every page view, so new runs appear automatically.
  Included: by individual--fonda-workflow.ftl, the custom display view of rm:Workflow.
            The script moves the section below the "workflow runs" list (Run Metadata tab).
  Four scatter plots (energy, carbon, CPU time, duration) with one data point per run, runs numbered
  in time order on the x axis. Hover shows a run in all four plots; click shows its details.
  Shown only when at least two runs have one of these values.
  Runs can be left out of the mean and standard deviation by run number, and the compute clusters whose
  runs are used can be selected.
  2026-10-03: the same plots on the pages of workflow stages (class rm:WorkflowStage, also shown with
            individual--fonda-workflow.ftl): one data point per execution of the stage, that is per run.
            Data: workflowStageMetricRows, from display:fondaWorkflowStageMetricsDataGetter
            (/opt/vivo/vivo/rdf/display/everytime/fonda-workflow-stage-metrics.n3). The section is placed
            below the "stage executions" list; a data point opens the page of the stage execution.
  2026-10-03: one "Runs used for mean and SD" block instead of separate lines: clusters, node use
            (exclusive = the job had a whole node, non-exclusive = it shared its node; read from the
            energy measurement coverage) and run numbers to exclude. A line of tick boxes is shown only
            when the runs differ in it, and only options that have runs are listed.
  2026-10-03: "Run by" tick boxes: the persons who ran the runs (rm:runOperator of each run, from the query),
            so that mean and SD can be limited to the runs of one or more persons.
  2026-10-03: a line whose runs all have the same value (one cluster, one node use, one person) is shown as
            plain text instead of being hidden, so that the reader still sees the value
            (SHOW_SINGLE_VALUE in the script below; false hides such a line).
  2026-10-03: node use is read from rm:nodeUse of the run ("exclusive (...)" / "non-exclusive (...)"), which the
            collectors write for Kubernetes runs from the CPU use of other workloads on the run's nodes. Slurm
            runs without it are still read from the energy measurement coverage. A run with neither counts as
            "not recorded"; Kubernetes runs are no longer assumed to be non-exclusive.
  2026-10-03: the y axis fits the runs that are used for mean and SD. An excluded run above the axis is drawn
            as a hollow triangle at the top edge; its value is still shown on hover and in the table.
  2026-10-04: "Nodes" tick boxes: the number of compute nodes a run used (its rm:executionHost values, counted
            by the query), so that mean and SD can be limited to runs with the same number of nodes.
  2026-10-04: mean and SD include the hovered run (it was left out before). They are now the same for every
            run: the mean and SD of all runs in use.
  2026-10-24: workflow pages get two more plots: average power (the run's energy / its duration) and energy
            above idle (rm:energyAboveIdleKWh, from the query). Stage pages keep their four plots.
  2026-10-04: shorter note above the plots. The hover box no longer names the "run by" person and no longer
            says "this run included".
  2026-11-06 (5): group bands are stronger (opacity .22 instead of .12) and the green is darker, so the green band is
            as visible as the orange one; group mean lines are 1.5 px.
  2026-11-06 (4): "Compare by" in the filter box: all runs together (default), or groups by cluster, number of nodes,
            node use or person, each group with its own mean, SD, band and colour (orange, green, purple, teal, brown,
            in the order of the tick boxes). Replaces the automatic grouping by cluster of version 3.
  2026-11-06 (3): runs of several clusters together: when the runs in use come from more than one cluster, mean and
            SD are computed per cluster. The runs are then grouped by cluster (each group oldest to newest), and each
            group has its own band and bar in its own colour (HPC@HU orange, Fonda green, others purple, teal, brown).
            Hover box, legend and table give the values of the run's own cluster. The bands are always shown.
  2026-11-06 (2): x axis labels: when two dates would overlap, the date with more runs is shown.
  2026-11-06: runs that are left out of mean and SD are no longer drawn (no hollow circles), and the runs in use
            sit evenly next to each other, oldest to newest. The x axis shows the start dates of the runs (as in the
            run names) instead of run numbers, which appear nowhere else. Runs are left out by unticking them in the
            table "values per run" instead of typing run numbers.
-->
<#assign wrmStage = (workflowStageMetricRows??)>
<#if wrmStage>
<#assign wrmRows = workflowStageMetricRows>
<#elseif workflowRunMetricRows??>
<#assign wrmRows = workflowRunMetricRows>
<#else>
<#assign wrmRows = []>
</#if>
<#if wrmRows?size gt 1>
<section id="workflow-run-metrics" class="workflow-run-metrics" aria-labelledby="wrm-heading" hidden>
<#if wrmStage>
    <h3 id="wrm-heading">energy, carbon and time of this stage per run</h3>
    <p class="wrm-note">One point per run of this stage that is used, oldest to newest. Hover for values; click to open the stage execution page.
       Band and bar: mean &plusmn; 1 SD of the runs used, or of each group chosen under &ldquo;Compare by&rdquo;.</p>
<#else>
    <h3 id="wrm-heading">energy, carbon and time per run</h3>
    <p class="wrm-note">One point per workflow run that is used, oldest to newest. Hover for values; click to open the run page.
       Band and bar: mean &plusmn; 1 SD of the runs used, or of each group chosen under &ldquo;Compare by&rdquo;.</p>
</#if>
    <div class="wrm-info" aria-live="polite"></div>
    <div class="wrm-filter" role="group" aria-labelledby="wrm-filter-title">
        <div id="wrm-filter-title" class="wrm-filter-title">Runs used for mean &plusmn; SD: <span class="wrm-used" aria-live="polite"></span></div>
        <div class="wrm-filter-row wrm-cluster-box" role="group" aria-labelledby="wrm-cluster-label" hidden>
            <span id="wrm-cluster-label" class="wrm-filter-name">Cluster</span>
            <span class="wrm-cluster-list"></span>
        </div>
        <div class="wrm-filter-row wrm-nodes-box" role="group" aria-labelledby="wrm-nodes-label" hidden>
            <span id="wrm-nodes-label" class="wrm-filter-name">Nodes</span>
            <span class="wrm-cluster-list wrm-nodes-list"></span>
        </div>
        <div class="wrm-filter-row wrm-node-box" role="group" aria-labelledby="wrm-node-label" hidden>
            <span id="wrm-node-label" class="wrm-filter-name">Node use</span>
            <span class="wrm-cluster-list wrm-node-list"></span>
        </div>
        <div class="wrm-filter-row wrm-by-box" role="group" aria-labelledby="wrm-by-label" hidden>
            <span id="wrm-by-label" class="wrm-filter-name">Run by</span>
            <span class="wrm-cluster-list wrm-by-list"></span>
        </div>
        <div class="wrm-filter-row wrm-cmp-box" role="radiogroup" aria-labelledby="wrm-cmp-label" hidden>
            <span id="wrm-cmp-label" class="wrm-filter-name">Compare by</span>
            <span class="wrm-cluster-list wrm-cmp-list"></span>
        </div>
        <div class="wrm-filter-row">
            <span class="wrm-filter-name">Exclude runs</span>
            <span class="wrm-excl-hint">untick a run in &ldquo;values per run&rdquo; below to leave it out</span>
            <span class="wrm-excl-msg" aria-live="polite"></span>
        </div>
    </div>
    <div class="wrm-legend" aria-live="polite" hidden></div>
    <div class="wrm-plots"></div>
    <div class="wrm-table-wrap"></div>
    <div class="wrm-tip" role="tooltip" hidden></div>
</section>

<style>
#workflow-run-metrics { --wrm-dot: #2a78d6; --wrm-surface: #ffffff; --wrm-text: #595b5b; --wrm-strong: #2b2d2d;
    --wrm-muted: #6f7272; --wrm-head: #064d68; --wrm-grid: #e6e8eb; --wrm-base: #b9bec4; --wrm-cross: #9aa3ad;
    --wrm-line: #e3e7ec; --wrm-panel: #f6f8fa; --wrm-hl: #eef4fb; --wrm-ref: #eb6834;
    --wrm-g2: #1f8a4c; --wrm-g3: #8a5cd1; --wrm-g4: #16929c; --wrm-g5: #9a7430;
    color: var(--wrm-text); clear: both; margin: 1.2em 0 1.5em; }
html.dark-mode #workflow-run-metrics { --wrm-dot: #3987e5; --wrm-surface: #0f151f; --wrm-text: #d5dde7; --wrm-strong: #f1f5f9;
    --wrm-muted: #9aa7b8; --wrm-head: #7fc0dd; --wrm-grid: #232e42; --wrm-base: #3b4a63; --wrm-cross: #5d6d86;
    --wrm-line: #273349; --wrm-panel: #151d2b; --wrm-hl: #16233a; --wrm-ref: #d95926;
    --wrm-g2: #3fb873; --wrm-g3: #a582e6; --wrm-g4: #2bb3bd; --wrm-g5: #c39a4e; }
#workflow-run-metrics :not(a) { color: inherit; }
#workflow-run-metrics h3 { font-size: 15px; font-weight: 600; color: var(--wrm-head); margin: 0 0 .35em; }
#workflow-run-metrics .wrm-note { color: var(--wrm-muted); font-size: 13px; margin: 0 0 .8em; }
#workflow-run-metrics .wrm-info { font-size: 13px; line-height: 1.45; min-height: 2.9em; margin: 0 0 1em; padding: 7px 11px;
    border: 1px solid var(--wrm-line); border-radius: 4px; background: var(--wrm-panel); max-width: 900px; }
#workflow-run-metrics .wrm-info .muted { color: var(--wrm-muted); }
#workflow-run-metrics .wrm-info b { color: var(--wrm-strong); }
#workflow-run-metrics .wrm-info .sep { color: var(--wrm-muted); padding: 0 .45em; }
#workflow-run-metrics .wrm-plots { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 22px 36px; max-width: 980px; }
@media (max-width: 640px) { #workflow-run-metrics .wrm-plots { grid-template-columns: minmax(0, 1fr); } }
#workflow-run-metrics figure { margin: 0; min-width: 0; }
#workflow-run-metrics figcaption { font-size: 13px; font-weight: 600; color: var(--wrm-strong); margin: 0 0 2px; }
#workflow-run-metrics figcaption span { font-weight: 400; color: var(--wrm-muted); }
#workflow-run-metrics svg { display: block; overflow: visible; font-family: inherit; outline: none; }
#workflow-run-metrics svg:focus-visible { outline: 2px solid var(--wrm-dot); outline-offset: 2px; }
#workflow-run-metrics .wrm-gridline { stroke: var(--wrm-grid); stroke-width: 1; shape-rendering: crispEdges; }
#workflow-run-metrics .wrm-axis { stroke: var(--wrm-base); stroke-width: 1; shape-rendering: crispEdges; }
#workflow-run-metrics .wrm-tick { fill: var(--wrm-muted); font-size: 11px; font-variant-numeric: tabular-nums; }
#workflow-run-metrics .wrm-xtitle { fill: var(--wrm-muted); font-size: 11px; }
#workflow-run-metrics .wrm-cross { stroke: var(--wrm-cross); stroke-width: 1; shape-rendering: crispEdges; }
#workflow-run-metrics .wrm-dot { fill: var(--wrm-dot); stroke: var(--wrm-surface); stroke-width: 1.5; transition: opacity .12s; }
#workflow-run-metrics svg.focus .wrm-dot { opacity: .45; }
#workflow-run-metrics svg.focus .wrm-dot.wrm-hot { opacity: 1; stroke: var(--wrm-strong); stroke-width: 2; }
#workflow-run-metrics .wrm-filter { font-size: 13px; line-height: 1.45; margin: 0 0 1.1em; padding: 8px 11px 9px; max-width: 900px;
    border: 1px solid var(--wrm-line); border-radius: 4px; }
#workflow-run-metrics .wrm-filter-title { font-weight: 600; color: var(--wrm-strong); margin: 0 0 5px; }
#workflow-run-metrics .wrm-used { font-weight: 400; color: var(--wrm-text); }
#workflow-run-metrics .wrm-filter-row { display: flex; align-items: baseline; margin: 4px 0 0; }
#workflow-run-metrics .wrm-filter-row[hidden] { display: none; }
#workflow-run-metrics .wrm-filter-name { flex: 0 0 7.2em; display: block; margin: 0; max-width: none; white-space: nowrap;
    font-weight: 400; color: var(--wrm-muted); }
#workflow-run-metrics .wrm-filter-row input[type=text] { display: block; flex: 0 0 13em; font: inherit; width: 13em; height: auto;
    margin: 0; padding: 2px 7px; border: 1px solid var(--wrm-base); border-radius: 4px; box-shadow: none;
    background: var(--wrm-surface); color: var(--wrm-text); }
#workflow-run-metrics .wrm-excl-msg { color: var(--wrm-muted); margin: 0 0 0 1em; }
#workflow-run-metrics .wrm-excl-msg:empty { display: none; }
#workflow-run-metrics .wrm-excl-hint { color: var(--wrm-text); }
#workflow-run-metrics .wrm-excl-msg button { font: inherit; padding: 0; margin: 0 0 0 .4em; border: 0; background: none;
    color: var(--wrm-dot); text-decoration: underline; cursor: pointer; }
#workflow-run-metrics td.use { text-align: center; padding-right: 8px; }
#workflow-run-metrics td.use input { margin: 0; width: auto; }
#workflow-run-metrics .wrm-cluster-list { display: flex; flex-wrap: wrap; gap: 2px 1.1em; }
#workflow-run-metrics .wrm-cluster-list label { display: inline-block; margin: 0; max-width: none; white-space: nowrap; font-weight: 400; cursor: pointer; }
#workflow-run-metrics .wrm-cluster-list input { width: auto; margin: 0 .35em 0 0; padding: 0; vertical-align: -1px; }
#workflow-run-metrics .wrm-cluster-list .count { color: var(--wrm-muted); }
#workflow-run-metrics .wrm-dot.wrm-excl { fill: var(--wrm-surface); stroke: var(--wrm-dot); stroke-width: 1.5; }
#workflow-run-metrics tr.excl td { opacity: .5; }
#workflow-run-metrics .wrm-focus { fill: var(--wrm-dot); stroke: var(--wrm-strong); stroke-width: 2; pointer-events: none; }
#workflow-run-metrics .wrm-hit { fill: transparent; cursor: pointer; }
#workflow-run-metrics .wrm-band { fill: var(--wrm-ref); opacity: .12; pointer-events: none; }
#workflow-run-metrics .wrm-meanline { stroke-width: 1; opacity: .7; pointer-events: none; shape-rendering: crispEdges; }
#workflow-run-metrics .wrm-sep { stroke: var(--wrm-base); stroke-width: 1; stroke-dasharray: 3 3; pointer-events: none; }
#workflow-run-metrics .wrm-legend { font-size: 13px; margin: -.4em 0 1em; display: flex; flex-wrap: wrap; gap: 4px 1.6em; max-width: 980px; }
#workflow-run-metrics .wrm-legend[hidden] { display: none; }
#workflow-run-metrics .wrm-legend .sw { display: inline-block; width: 18px; height: 10px; margin-right: 6px; vertical-align: -1px; border-radius: 2px; }
#workflow-run-metrics .wrm-bar { stroke: var(--wrm-ref); stroke-width: 2; stroke-linecap: round; fill: none; pointer-events: none; }
#workflow-run-metrics .wrm-tip th { font-weight: 400; color: inherit; opacity: .75; padding: 0 12px 2px 0; border: 0; text-align: right; }
#workflow-run-metrics .wrm-tip th:first-child { text-align: left; }
#workflow-run-metrics .wrm-tip .key { display: inline-block; width: 12px; height: 2px; background: var(--wrm-ref); vertical-align: middle; margin-right: 5px; }
#workflow-run-metrics .wrm-tip .foot { margin-top: 4px; opacity: .75; }
#workflow-run-metrics tfoot td { color: var(--wrm-muted); border-bottom: 0; }
#workflow-run-metrics details { margin-top: 1em; }
#workflow-run-metrics summary { cursor: pointer; font-size: 13px; font-weight: 600; color: var(--wrm-strong); }
#workflow-run-metrics .wrm-table-wrap { overflow-x: auto; }
#workflow-run-metrics table { border-collapse: collapse; margin-top: .5em; font-size: 13px; line-height: 1.35; }
#workflow-run-metrics th, #workflow-run-metrics td { text-align: left; padding: 4px 12px 4px 0; border-bottom: 1px solid var(--wrm-line); white-space: nowrap; }
#workflow-run-metrics th { font-weight: 600; color: var(--wrm-strong); vertical-align: bottom; }
#workflow-run-metrics .n { text-align: right; font-variant-numeric: tabular-nums; }
#workflow-run-metrics tr.hl td { background: var(--wrm-hl); }
#workflow-run-metrics .wrm-tip { position: fixed; z-index: 1000; pointer-events: none; padding: 7px 10px; border-radius: 4px;
    font-size: 12px; line-height: 1.5; background: #ffffff; color: #3a3c3c; border: 1px solid #cfd6de;
    box-shadow: 0 2px 8px rgba(0,0,0,.15); }
html.dark-mode #workflow-run-metrics .wrm-tip { background: #151d2b; color: #d5dde7; border-color: #273349; }
#workflow-run-metrics .wrm-tip table { margin: 3px 0 0; font-size: 12px; }
#workflow-run-metrics .wrm-tip td { border: 0; padding: 0 12px 0 0; background: transparent; }
#workflow-run-metrics .wrm-tip td.n { padding-right: 12px; text-align: right; }
#workflow-run-metrics .wrm-tip td.v { font-weight: 700; }
</style>

<script>
(function () {
    var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    var SVGNS = 'http://www.w3.org/2000/svg';

    function num(s) { var v = parseFloat(s); return isFinite(v) ? v : null; }
    function fmt(v) {
        if (v === null) { return '–'; }
        var a = Math.abs(v);
        if (a === 0) { return '0'; }
        if (a >= 100) { return Math.round(v).toLocaleString('en'); }
        if (a < 0.001) { return v.toExponential(2); }
        return v.toPrecision(3);
    }
    function fmtTick(t) { return String(+t.toFixed(6)); }
    function fmtSeconds(s) {
        if (s === null) { return '–'; }
        if (s < 60) { return fmt(s) + ' s'; }
        var r = Math.round(s), h = Math.floor(r / 3600), m = Math.floor((r % 3600) / 60), x = r % 60;
        return h ? h + ' h ' + m + ' min' : m + ' min ' + x + ' s';
    }
    function when(r) {
        var s = r.s || '', m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(s);
        if (m && /(Z|[+-]\d{2}:?\d{2})$/.test(s) && window.Intl) {
            var d = new Date(s);
            if (!isNaN(d.getTime())) {
                var p = {};
                new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Berlin', year: 'numeric', month: '2-digit',
                    day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
                    .formatToParts(d).forEach(function (x) { p[x.type] = x.value; });
                m = [null, p.year, p.month, p.day, p.hour, p.minute];
            }
        }
        if (!m) { m = /(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/.exec(r.l || ''); }
        if (!m) { return null; }
        return { key: m[1] + m[2] + m[3] + m[4] + m[5], text: m[1] + '-' + m[2] + '-' + m[3] + ' ' + m[4] + ':' + m[5] };
    }
    function el(tag, cls, text) {
        var e = document.createElement(tag);
        if (cls) { e.className = cls; }
        if (text !== undefined && text !== null) { e.textContent = text; }
        return e;
    }
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
    // sample statistics: mean, standard deviation (n - 1) and standard error of the mean
    function stats(arr) {
        var k = arr.length, i, sum = 0, sq = 0;
        if (!k) { return null; }
        for (i = 0; i < k; i++) { sum += arr[i]; }
        var mean = sum / k;
        for (i = 0; i < k; i++) { sq += (arr[i] - mean) * (arr[i] - mean); }
        var sd = k > 1 ? Math.sqrt(sq / (k - 1)) : null;
        return { k: k, mean: mean, sd: sd, se: sd === null ? null : sd / Math.sqrt(k) };
    }
    // energy measurement coverage: rm:energyMeasurementCoverage of the run (e.g. "14.3% (40 of 280 pods)" or
    // "2.4% of the node (shared, estimate)"). Runs published before that property existed have no value; for
    // those it is taken from the text of rm:energyCalculationMethod ("... for 40 of 280 pod(s) ...").
    function coverage(text) {
        var x = /for (\d+) of (\d+) pods?/.exec(text || '');
        if (!x || +x[2] === 0) { return null; }
        return (100 * x[1] / x[2]).toFixed(1).replace(/\.0$/, '') + '% (' + x[1] + ' of ' + x[2] + ' pods)';
    }
    // clusters always offered in "Select clusters"; other clusters found in the runs are added after them.
    // The name shown is the cluster's label in VIVO when a run has one, otherwise the name given here.
    var CLUSTERS = [
        ['http://example.org/vivo-import/run-metadata/cluster/hpc-hu-cluster', 'HPC@HU Cluster'],
        ['http://example.org/vivo-import/run-metadata/cluster/fonda-cluster', 'Fonda Cluster'],
        ['http://172.28.33.178:8080/vivo/individual/n7775', 'FU Berlin Allegro Cluster'],
        ['http://example.org/vivo-import/run-metadata/cluster/tu-berlin-cluster', 'TU Berlin Cluster']
    ];
    // node use of a run: 'exclusive' = nothing else used the run's nodes while it ran, 'shared' = other jobs or
    // workloads used them too, '' = not recorded. Read from rm:nodeUse ("exclusive (...)" or "non-exclusive (...)");
    // Slurm runs without it are read from their energy measurement coverage ("100% of the node (whole node,
    // measured)" or "2.4% of the node (shared, estimate)").
    var NODE_USE = [
        ['exclusive', 'exclusive', 'Nothing else used the run\u2019s nodes while it ran.'],
        ['shared', 'non-exclusive', 'Other jobs or workloads used the run\u2019s nodes at the same time.'],
        ['', 'not recorded', 'The run does not say whether it had its nodes to itself.']
    ];
    function nodeUse(recorded, coverageText) {
        var value = (recorded || '').replace(/^\s+/, '').toLowerCase();
        if (value.indexOf('non-exclusive') === 0) { return 'shared'; }
        if (value.indexOf('exclusive') === 0) { return 'exclusive'; }
        if (/whole node/i.test(coverageText)) { return 'exclusive'; }
        return /of the node \(shared/i.test(coverageText) ? 'shared' : '';
    }
    // persons who ran a run (rm:runOperator, "run by"): "<person URI> | <name>" entries separated by " ;; ";
    // a person without a name in VIVO is shown by the last part of the URI
    function persons(text) {
        var out = [], seen = {};
        (text || '').split(' ;; ').forEach(function (entry) {
            var cut = entry.indexOf(' | '), uri = (cut < 0 ? entry : entry.slice(0, cut)).replace(/^\s+|\s+$/g, '');
            var name = cut < 0 ? '' : entry.slice(cut + 3).replace(/^\s+|\s+$/g, '');
            if (!uri) { return; }
            if (seen[uri]) { if (name && !seen[uri].named) { seen[uri].name = name; seen[uri].named = true; } return; }
            var fallback = uri.replace(/[\/#]+$/, '').replace(/^.*[\/#]/, '');
            try { fallback = decodeURIComponent(fallback); } catch (e) { /* keep as it is */ }
            seen[uri] = { uri: uri, name: name || fallback, named: !!name };
            out.push(seen[uri]);
        });
        return out;
    }
    // 1, 2, 3, 5, 8, 9 -> "1\u20133, 5, 8, 9"
    function ranges(list) {
        var out = [], i = 0, j;
        while (i < list.length) {
            j = i;
            while (j + 1 < list.length && list[j + 1] === list[j] + 1) { j++; }
            out.push(j - i >= 2 ? list[i] + '\u2013' + list[j] : list.slice(i, j + 1).join(', '));
            i = j + 1;
        }
        return out.join(', ');
    }
    function timeUnit(maxSeconds) {
        return maxSeconds < 180 ? { unit: 's', div: 1 } : maxSeconds < 10800 ? { unit: 'min', div: 60 } : { unit: 'h', div: 3600 };
    }

    // stage = true on the page of a workflow stage: every row is one execution of that stage; r.rcv is the
    // energy measurement coverage of its run, used for a Slurm job ("... of the node ...": the stage's energy is a
    // share of the job's energy) when the execution has an energy value but no coverage of its own
    window.fondaWorkflowRunMetrics = function (root, base, rows, stage) {
        if (!root) { return; }
        var link = function (uri) { return base + '/individual?uri=' + encodeURIComponent(uri); };

        // ---- runs with at least one value, oldest first, numbered 1..n
        var runs = rows.map(function (r) {
            return { uri: r.r, label: r.l || r.r, when: when(r), e: num(r.e), c: num(r.c), cpu: num(r.cpu), dur: num(r.d), ai: num(r.ai), pw: (num(r.e) !== null && num(r.d) > 0) ? num(r.e) * 3600000 / num(r.d) : null, cov: (r.cv || '').replace(/^\s+|\s+$/g, '') || coverage(r.m) || (num(r.e) !== null && /of the node/.test(r.rcv || '') ? r.rcv.replace(/^\s+|\s+$/g, '') : ''), cl: r.cl || '', cn: r.cn || '', by: persons(r.by), use: (r.use || '').replace(/^\s+|\s+$/g, ''), nodes: parseInt(r.nc, 10) > 0 ? String(parseInt(r.nc, 10)) : '', nu: (r.cv || '') + ' ' + (r.rcv || '') };
        }).filter(function (r) { return r.e !== null || r.c !== null || r.cpu !== null || r.dur !== null; });
        if (runs.length < 2) { if (root.parentNode) { root.parentNode.removeChild(root); } return; }
        runs.sort(function (a, b) {
            var ka = a.when ? a.when.key : '9', kb = b.when ? b.when.key : '9';
            return ka < kb ? -1 : ka > kb ? 1 : (a.label < b.label ? -1 : 1);
        });
        // stage executions of Slurm jobs end in " \u00b7 job <ID>": jobs can start in the same minute
        runs.forEach(function (r, i) {
            var job = / \u00b7 (job \d+)$/.exec(r.label);
            r.n = i + 1; r.date = r.when ? r.when.text + (job ? ' \u00b7 ' + job[1] : '') : r.label;
        });
        var n = runs.length;

        // clusters: the known ones first, then any other cluster of these runs; '' = no cluster recorded
        var clusters = CLUSTERS.map(function (c) { return { uri: c[0], name: c[1], count: 0 }; }), clusterOf = {};
        clusters.forEach(function (c) { clusterOf[c.uri] = c; });
        runs.forEach(function (r) {
            var c = clusterOf[r.cl];
            if (!c) {
                c = { uri: r.cl, name: r.cl ? decodeURIComponent(r.cl.replace(/^.*[\/#]/, '')) : 'cluster not recorded', count: 0 };
                clusterOf[r.cl] = c; clusters.push(c);
            }
            if (r.cn) { c.name = r.cn; }
            c.count++;
        });
        runs.forEach(function (r) { r.cluster = r.cl ? clusterOf[r.cl].name : ''; });
        var clusterOff = {};   // cluster uri -> true when the cluster is not selected: its runs are left out of mean and SD
        var nodeUses = NODE_USE.map(function (u) { return { key: u[0], name: u[1], title: u[2], count: 0 }; }), nodeOff = {};
        runs.forEach(function (r) {
            r.node = nodeUse(r.use, r.nu);
            nodeUses.forEach(function (u) { if (u.key === r.node) { u.count++; } });
        });
        // persons ("run by"): one option per person, most runs first; '' = runs without a person
        // number of nodes a run used (execution hosts counted by the query): one option per number, smallest first;
        // '' = no execution host recorded
        var nodeCounts = [], nodeCountOf = {}, nodeCountOff = {};
        runs.forEach(function (r) {
            var c = nodeCountOf[r.nodes];
            if (!c) {
                c = { key: r.nodes, name: !r.nodes ? 'not recorded' : r.nodes === '1' ? '1 node' : r.nodes + ' nodes', count: 0,
                      title: r.nodes ? 'Runs that used ' + (r.nodes === '1' ? 'one compute node' : r.nodes + ' compute nodes') + '.'
                                     : 'The run does not name the nodes it ran on.' };
                nodeCountOf[r.nodes] = c; nodeCounts.push(c);
            }
            c.count++;
        });
        nodeCounts.sort(function (a, b) { return (a.key === '') - (b.key === '') || a.key - b.key; });
        var people = [], personOf = {}, personOff = {};
        var countPerson = function (uri, name, named) {
            var p = personOf[uri];
            if (!p) { p = { key: uri, name: name, named: named, count: 0 }; personOf[uri] = p; people.push(p); }
            if (named && !p.named) { p.name = name; p.named = true; }
            p.count++;
        };
        runs.forEach(function (r) {
            if (!r.by.length) { countPerson('', 'not recorded', true); }
            r.by.forEach(function (b) { countPerson(b.uri, b.name, b.named); });
        });
        runs.forEach(function (r) { r.runBy = r.by.map(function (b) { return personOf[b.uri].name; }).join('; '); });
        people.sort(function (a, b) { return (a.key === '') - (b.key === '') || b.count - a.count || (a.name < b.name ? -1 : 1); });
        // a run is left out when none of its persons is selected
        var byOff = function (r) {
            if (!r.by.length) { return !!personOff['']; }
            return r.by.every(function (b) { return personOff[b.uri]; });
        };

        var maxOf = function (k) { return Math.max.apply(null, runs.map(function (r) { return r[k] === null ? 0 : r[k]; })); };
        var maxE = maxOf('e'), maxC = maxOf('c'), tCpu = timeUnit(maxOf('cpu')), tDur = timeUnit(maxOf('dur'));
        var metrics = [
            { key: 'e', title: 'Energy consumed', unit: maxE < 1 ? 'Wh' : 'kWh', mult: maxE < 1 ? 1000 : 1 },
            { key: 'c', title: 'Carbon emission', unit: maxC < 1 ? 'g CO₂e' : 'kg CO₂e', mult: maxC < 1 ? 1000 : 1 },
            { key: 'cpu', title: 'CPU time, tasks', unit: tCpu.unit, mult: 1 / tCpu.div, time: true },
            { key: 'dur', title: 'Duration', unit: tDur.unit, mult: 1 / tDur.div, time: true }
        ];
        // FONDA 2026-10-24: workflow pages only (a stage's energy is a share of its run's energy)
        if (!stage) {
            metrics.push({ key: 'pw', title: 'Average power', unit: 'W', mult: 1 });
            <#if fondaShowAboveIdle>
            metrics.push({ key: 'ai', title: 'Energy above idle', unit: maxE < 1 ? 'Wh' : 'kWh', mult: maxE < 1 ? 1000 : 1 });
            </#if>
        }
        var value = function (r, m) { return r[m.key] === null ? null : r[m.key] * m.mult; };
        var shown = function (r, m) { return m.time ? fmtSeconds(r[m.key]) : fmt(value(r, m)) + ' ' + m.unit; };
        // runs left out of mean and SD by the reader (index -> true), set in the "Exclude runs" box
        var excluded = {};
        // statistics of the runs in use (not excluded); the hovered run is NOT left out, so they are the same for every run
        // FONDA 2026-11-06 (3): when the runs in use come from several clusters, mean and SD per cluster (groups)
        var groups = [], grouped = false;   // group keys of the runs in use, in the order of the tick boxes
        var compareBy = '';   // '' = all runs together, 'cluster', 'nodes', 'node' (node use), 'by' (run by)
        var gk = function (r) {
            return compareBy === 'cluster' ? r.cl : compareBy === 'nodes' ? r.nodes : compareBy === 'node' ? r.node
                 : compareBy === 'by' ? (r.by.length ? r.by[0].uri : '') : '';
        };
        var optionsFor = function () {   // the tick-box options of the chosen dimension (key, name), in their order
            var o = compareBy === 'cluster' ? clusters.map(function (c) { return { key: c.uri, name: c.name, count: c.count }; })
                  : compareBy === 'nodes' ? nodeCounts : compareBy === 'node' ? nodeUses : compareBy === 'by' ? people : [];
            return o.filter(function (x) { return x.count > 0; });
        };
        var GROUP_COLOURS = ['var(--wrm-ref)', 'var(--wrm-g2)', 'var(--wrm-g3)', 'var(--wrm-g4)', 'var(--wrm-g5)'];
        var colourOf = function (key) {
            var idx = -1;
            optionsFor().forEach(function (o, j) { if (o.key === key) { idx = j; } });
            return GROUP_COLOURS[Math.min(Math.max(idx, 0), GROUP_COLOURS.length - 1)];
        };
        var groupName = function (key) {
            var name = '';
            optionsFor().forEach(function (o) { if (o.key === key) { name = o.name; } });
            if (compareBy === 'node' && name) { return 'node use ' + name; }
            return name || 'not recorded';
        };
        function recomputeStats() {
            groups = [];
            var inUse = {};
            runs.forEach(function (r, j) { if (!excluded[j]) { inUse[gk(r)] = true; } });
            groups = compareBy ? optionsFor().map(function (o) { return o.key; }).filter(function (k) { return inUse[k]; }) : [];
            grouped = groups.length > 1;
            metrics.forEach(function (m) {
                var vals = runs.map(function (r) { return value(r, m); });
                m.all = stats(vals.filter(function (v, j) { return v !== null && !excluded[j]; }));
                m.by = {};
                groups.forEach(function (g) {
                    m.by[g] = stats(vals.filter(function (v, j) { return v !== null && !excluded[j] && gk(runs[j]) === g; }));
                });
            });
        }
        // statistics a run is compared with: its own cluster's when several clusters are used
        var statFor = function (i, m) { return grouped ? (m.by[gk(runs[i])] || null) : m.all; };
        recomputeStats();
        var excludedList = function () {
            return Object.keys(excluded).map(function (j) { return +j + 1; }).sort(function (a, b) { return a - b; });
        };
        var meanSd = function (st, m) {
            if (!st) { return '\u2013'; }
            return fmt(st.mean) + (st.sd !== null ? ' \u00b1 ' + fmt(st.sd) : '') + ' ' + m.unit;
        };
        var deviation = function (r, i, m) {
            var v = value(r, m), st = statFor(i, m);
            if (v === null || !st || st.sd === null || st.sd === 0) { return '\u2013'; }
            var z = (v - st.mean) / st.sd;
            return (z >= 0 ? '+' : '\u2212') + Math.abs(z).toFixed(1) + ' SD';
        };

        var infoBox = root.querySelector('.wrm-info');
        var plotsBox = root.querySelector('.wrm-plots');
        var tableBox = root.querySelector('.wrm-table-wrap');
        var tip = root.querySelector('.wrm-tip');
        var plots = [], tableRows = [], selected = null;

        function valuesTable(r) {
            var t = el('table'), tb = el('tbody');
            metrics.forEach(function (m) {
                var tr = el('tr');
                tr.appendChild(el('td', null, m.title));
                tr.appendChild(el('td', 'n', shown(r, m)));
                tb.appendChild(tr);
            });
            t.appendChild(tb);
            return t;
        }
        function showInfo() {
            infoBox.innerHTML = '';
            infoBox.hidden = selected === null;   // empty until a run is hovered (the note above explains the plots)
            if (selected === null) { return; }
            var r = runs[selected];
            infoBox.appendChild(el('b', null, (stage ? '' : 'Run ') + r.date));
            metrics.forEach(function (m) {
                infoBox.appendChild(el('span', 'sep', '|'));
                infoBox.appendChild(document.createTextNode(m.title + ' '));
                infoBox.appendChild(el('b', null, shown(r, m)));
            });
            infoBox.appendChild(el('span', 'sep', '|'));
            var a = el('a', null, stage ? 'open stage execution page' : 'open run page');
            a.href = link(r.uri);
            infoBox.appendChild(a);
        }
        function showTip(i, x, y) {
            var r = runs[i];
            tip.innerHTML = '';
            tip.appendChild(el('b', null, (stage ? '' : 'Run ') + r.date));
            var t = el('table'), th = el('tr'), tb = el('tbody');
            th.appendChild(el('th'));
            th.appendChild(el('th', null, 'this run'));
            var h3 = el('th'), key = el('span', 'key');
            if (grouped) { key.style.background = colourOf(gk(r)); }
            h3.appendChild(key);
            h3.appendChild(document.createTextNode((grouped ? groupName(gk(r)) + ' runs' : 'runs used') + ': mean \u00b1 SD'));
            th.appendChild(h3);
            th.appendChild(el('th', null, 'deviation'));
            t.appendChild(th);
            metrics.forEach(function (m) {
                var tr = el('tr');
                tr.appendChild(el('td', null, m.title));
                tr.appendChild(el('td', 'n v', shown(r, m)));
                tr.appendChild(el('td', 'n', meanSd(statFor(i, m), m)));
                tr.appendChild(el('td', 'n', deviation(r, i, m)));
                tb.appendChild(tr);
            });
            t.appendChild(tb); tip.appendChild(t);
            var ex = excludedList();
            tip.appendChild(el('div', 'foot', 'Runs used: ' + (n - ex.length) + ' of ' + n + (excluded[i] ? ' (this run is left out)' : '')
                + '. SD = sample standard deviation.'));
            if (r.cluster) { tip.appendChild(el('div', null, 'Cluster: ' + r.cluster)); }
            if (r.use) { tip.appendChild(el('div', null, 'Node use: ' + r.use)); }
            if (r.cov) { tip.appendChild(el('div', null, 'Energy measurement coverage: ' + r.cov)); }
            tip.hidden = false;
            var w = tip.offsetWidth, h = tip.offsetHeight, px = x + 16, py = y + 16;
            if (px + w > window.innerWidth - 8) { px = x - w - 16; }
            if (py + h > window.innerHeight - 8) { py = y - h - 16; }
            tip.style.left = Math.max(8, px) + 'px'; tip.style.top = Math.max(8, py) + 'px';
        }
        function hideTip() { tip.hidden = true; }
        // mark run i in every plot (crosshair + ring); null = back to the selected run
        function mark(i) {
            var k = i === null ? selected : i;
            plots.forEach(function (p) {
                if (!p.svg) { return; }
                p.svg.classList.toggle('focus', i !== null);
                Object.keys(p.above).forEach(function (j) { p.above[j].classList.toggle('wrm-hot', k !== null && +j === k); });
                if (k === null) { p.cross.setAttribute('visibility', 'hidden'); p.ring.setAttribute('visibility', 'hidden'); return; }
                var x = p.x(k), v = value(runs[k], p.m);
                if (x === null) { p.cross.setAttribute('visibility', 'hidden'); p.ring.setAttribute('visibility', 'hidden');
                    p.bar.setAttribute('visibility', 'hidden'); return; }
                p.cross.setAttribute('x1', x); p.cross.setAttribute('x2', x); p.cross.setAttribute('visibility', 'visible');
                if (v === null || p.above[k]) { p.ring.setAttribute('visibility', 'hidden'); }
                else { p.ring.setAttribute('cx', x); p.ring.setAttribute('cy', p.y(v)); p.ring.setAttribute('visibility', 'visible'); }
                var st = statFor(k, p.m);
                if (!st) { p.bar.setAttribute('visibility', 'hidden'); return; }
                var sd = st.sd === null ? 0 : st.sd;
                var yTop = p.y(st.mean + sd), yBot = p.y(Math.max(0, st.mean - sd)), yMean = p.y(st.mean), c = 5;
                p.bar.style.stroke = grouped ? colourOf(gk(runs[k])) : '';
                p.bar.setAttribute('d', (sd > 0 ? 'M' + x + ',' + yTop + 'V' + yBot + 'M' + (x - c) + ',' + yTop + 'H' + (x + c)
                    + 'M' + (x - c) + ',' + yBot + 'H' + (x + c) : '') + 'M' + (x - 8) + ',' + yMean + 'H' + (x + 8));
                p.bar.setAttribute('visibility', 'visible');
            });
            tableRows.forEach(function (tr, j) { tr.classList.toggle('hl', j === k); });
        }
        function select(i) { selected = i; showInfo(); mark(null); }

        // ---- one scatter plot
        function drawPlot(p) {
            if (p.svg) { p.fig.removeChild(p.svg); p.svg = null; }
            var W = Math.floor(p.fig.clientWidth);
            if (W < 10) { return; }
            var m = p.m, vals = runs.map(function (r) { return value(r, m); });
            // the axis fits the runs in use (all runs when every run is excluded) and the mean + SD shown on hover
            var anyUsed = runs.some(function (r, i) { return !excluded[i] && vals[i] !== null; });
            var max = Math.max.apply(null, vals.map(function (v, i) { return v === null || (anyUsed && excluded[i]) ? 0 : v; })
                .concat(m.all ? [m.all.mean + (m.all.sd || 0)] : [])
                .concat(grouped ? groups.map(function (g) { var st = m.by[g]; return st ? st.mean + (st.sd || 0) : 0; }) : []));
            // values spanning more than ~1.5 orders of magnitude get a logarithmic axis,
            // so that small values are not flattened onto zero
            var pos = vals.filter(function (v) { return v !== null && v > 0; });
            var minPos = pos.length ? Math.min.apply(null, pos) : 0;
            var logScale = false;   // linear axis (log scale switched off on request)
            var step = max > 0 ? niceStep(max, 4) : 1, top = Math.ceil(max / step) * step || step;
            var ticks = [], lo = 0, hi = 0;
            if (logScale) {
                lo = Math.floor(Math.log(minPos) / Math.LN10 + 1e-9); hi = Math.ceil(Math.log(max) / Math.LN10 - 1e-9);
                if (hi === lo) { hi = lo + 1; }
                for (var d = lo; d <= hi; d++) { ticks.push(Math.pow(10, d)); }
            } else {
                for (var t = 0; t <= top + step / 2; t += step) { ticks.push(t); }
            }
            p.unitSpan.textContent = '(' + m.unit + (logScale ? ', log scale' : '') + ')';
            var padL = Math.ceil(Math.max.apply(null, ticks.map(function (t) { return fmtTick(t).length; })) * 6.5) + 10;
            var padR = 10, padT = 10, plotH = 140, band = 36, H = padT + plotH + band;
            // FONDA 2026-11-06: only the runs in use are drawn (all runs when every run is left out), evenly spaced
            var someIn = runs.some(function (r, i) { return !excluded[i]; });
            var vis = runs.map(function (r, i) { return i; }).filter(function (i) { return !someIn || !excluded[i]; });
            if (grouped && someIn) {   // runs grouped by cluster, each group oldest to newest
                vis.sort(function (a, b) { return groups.indexOf(gk(runs[a])) - groups.indexOf(gk(runs[b])) || a - b; });
            }
            var posOf = {}; vis.forEach(function (i, k) { posOf[i] = k; });
            var nv = vis.length;
            var plotW = Math.max(40, W - padL - padR), slot = plotW / nv;
            var x = function (i) { return posOf.hasOwnProperty(i) ? padL + slot * (posOf[i] + 0.5) : null; };
            var y = logScale
                ? function (v) { var l = v > 0 ? Math.log(v) / Math.LN10 : lo; return padT + plotH - ((Math.max(lo, l) - lo) / (hi - lo)) * plotH; }
                : function (v) { return padT + plotH - (Math.min(v, top) / top) * plotH; };   // above the axis: top edge
            var rDot = n > 150 ? 3 : 4;

            var svg = svgEl('svg', { width: W, height: H, viewBox: '0 0 ' + W + ' ' + H, tabindex: 0, role: 'img',
                'aria-label': m.title + ' per run in ' + m.unit + ', ' + nv + ' runs. Use the arrow keys to step through the runs.' });
            ticks.forEach(function (t) {
                var ty = Math.round(y(t)) + 0.5;
                svg.appendChild(svgEl('line', { 'class': (logScale ? t > ticks[0] : t > 0) ? 'wrm-gridline' : 'wrm-axis', x1: padL, x2: padL + plotW, y1: ty, y2: ty }));
                svg.appendChild(svgEl('text', { 'class': 'wrm-tick', x: padL - 8, y: ty, dy: '.32em', 'text-anchor': 'end' }, fmtTick(t)));
            });
            // x axis: start dates of the runs, one label at the first run of a day. When labels would be closer than
            // 58 px, the days with the most runs get them, so a long stretch of runs is never left without its date.
            // When all runs started on the same day: their start times (hour) instead.
            var dayOf = function (i) { var w = runs[i].when; return w ? w.text.slice(0, 10) : ''; };
            var dayText = function (d) { return MONTHS[+d.slice(5, 7) - 1] + ' ' + (+d.slice(8, 10)); };
            var days = {}; vis.forEach(function (i) { if (dayOf(i)) { days[dayOf(i)] = true; } });
            var oneDay = Object.keys(days).length === 1, segs = [], prevKey = null;
            vis.forEach(function (i, k) {
                var w = runs[i].when; if (!w) { prevKey = null; return; }
                var key = oneDay ? w.text.slice(11, 13) + ':00' : w.text.slice(0, 10);
                var gkey = (grouped ? gk(runs[i]) + '|' : '') + key;   // a new cluster group starts a new label
                if (gkey === prevKey) { segs[segs.length - 1].count++; return; }
                prevKey = gkey;
                segs.push({ px: padL + slot * (k + 0.5), text: oneDay ? key : dayText(key), count: 1 });
            });
            var xLabels = [];
            segs.slice().sort(function (a, b) { return b.count - a.count || a.px - b.px; }).forEach(function (sg) {
                if (xLabels.every(function (t) { return Math.abs(t.px - sg.px) >= 58; })) { xLabels.push(sg); }
            });
            xLabels.sort(function (a, b) { return a.px - b.px; });
            xLabels.forEach(function (t) {
                var tx = Math.min(padL + plotW - 14, Math.max(padL + 14, t.px));
                svg.appendChild(svgEl('line', { 'class': 'wrm-axis', x1: t.px, x2: t.px, y1: padT + plotH, y2: padT + plotH + 4 }));
                svg.appendChild(svgEl('text', { 'class': 'wrm-tick', x: tx, y: padT + plotH + 16, 'text-anchor': 'middle' }, t.text));
            });
            var firstDay = Object.keys(days).sort()[0];
            svg.appendChild(svgEl('text', { 'class': 'wrm-xtitle', x: padL + plotW / 2, y: padT + plotH + 31, 'text-anchor': 'middle' },
                oneDay ? 'run start on ' + dayText(firstDay) + ', ' + firstDay.slice(0, 4) : 'run start date (runs in use, oldest to newest)'));
            // mean +- 1 SD: one band over all runs in use, or one band per cluster over its group of runs
            var sdBand = null;
            (grouped ? groups : [null]).forEach(function (g, gi) {
                var st = g === null ? m.all : m.by[g];
                var ks = vis.map(function (i, k) { return (g === null || gk(runs[i]) === g) ? k : -1; }).filter(function (k) { return k >= 0; });
                if (!st || !ks.length) { return; }
                var x0 = padL + slot * ks[0], x1 = padL + slot * (ks[ks.length - 1] + 1), sd = st.sd === null ? 0 : st.sd;
                var colour = g === null ? '' : colourOf(g);
                if (sd > 0) {
                    var yT = y(st.mean + sd), yB = y(Math.max(0, st.mean - sd));
                    var rect = svgEl('rect', { 'class': 'wrm-band', x: x0, width: Math.max(1, x1 - x0), y: yT, height: Math.max(0, yB - yT) });
                    if (colour) { rect.style.fill = colour; rect.style.opacity = '.22'; }
                    svg.appendChild(rect);
                }
                var ml = svgEl('line', { 'class': 'wrm-meanline', x1: x0, x2: x1, y1: Math.round(y(st.mean)) + 0.5, y2: Math.round(y(st.mean)) + 0.5 });
                ml.style.stroke = colour || 'var(--wrm-ref)';
                if (colour) { ml.style.strokeWidth = '1.5'; ml.style.opacity = '.9'; }
                svg.appendChild(ml);
                if (g !== null && gi > 0) {
                    svg.appendChild(svgEl('line', { 'class': 'wrm-sep', x1: Math.round(x0) + 0.5, x2: Math.round(x0) + 0.5, y1: padT, y2: padT + plotH }));
                }
            });
            var cross = svgEl('line', { 'class': 'wrm-cross', y1: padT, y2: padT + plotH, visibility: 'hidden' });
            svg.appendChild(cross);
            var above = {};   // run index -> triangle of an excluded run above the axis
            vals.forEach(function (v, i) {
                if (v === null || !posOf.hasOwnProperty(i)) { return; }
                if (!logScale && v > top * 1.0001) {   // excluded run above the axis: triangle at the top edge
                    var cx = x(i), s = rDot + 1.5;
                    above[i] = svgEl('path', { 'class': 'wrm-dot wrm-excl wrm-above', d: 'M' + cx + ',' + (padT - s) + 'L' + (cx + s) + ',' + (padT + s * 0.8) + 'H' + (cx - s) + 'Z' });
                    svg.appendChild(above[i]);
                    return;
                }
                svg.appendChild(svgEl('circle', { 'class': 'wrm-dot' + (excluded[i] ? ' wrm-excl' : ''), cx: x(i), cy: y(v), r: rDot }));
            });
            if (max === 0 && vals.every(function (v) { return v === null; })) {
                svg.appendChild(svgEl('text', { 'class': 'wrm-tick', x: padL + plotW / 2, y: padT + plotH / 2, 'text-anchor': 'middle' }, 'no values recorded for these runs'));
            }
            var bar = svgEl('path', { 'class': 'wrm-bar', d: 'M0,0', visibility: 'hidden' });
            svg.appendChild(bar);
            var ring = svgEl('circle', { 'class': 'wrm-focus', r: rDot + 2, visibility: 'hidden' });
            svg.appendChild(ring);
            var hit = svgEl('rect', { 'class': 'wrm-hit', x: padL, y: 0, width: plotW, height: padT + plotH + band });
            svg.appendChild(hit);

            var nearest = function (clientX) {
                var b = svg.getBoundingClientRect(), k = Math.floor((clientX - b.left - padL) / slot);
                return vis[Math.max(0, Math.min(nv - 1, k))];
            };
            hit.addEventListener('mousemove', function (ev) {
                var i = nearest(ev.clientX);
                if (i !== selected) { selected = i; showInfo(); }
                mark(i); showTip(i, ev.clientX, ev.clientY);
            });
            hit.addEventListener('mouseleave', function () { mark(null); hideTip(); });
            hit.addEventListener('click', function (ev) { window.location.href = link(runs[nearest(ev.clientX)].uri); });
            svg.addEventListener('keydown', function (ev) {
                var k = selected !== null && posOf.hasOwnProperty(selected) ? posOf[selected] : nv - 1;
                if (ev.key === 'ArrowLeft') { k = Math.max(0, k - 1); }
                else if (ev.key === 'ArrowRight') { k = Math.min(nv - 1, k + 1); }
                else if (ev.key === 'Home') { k = 0; }
                else if (ev.key === 'End') { k = nv - 1; }
                else if (ev.key === 'Enter' && selected !== null) { window.location.href = link(runs[selected].uri); return; }
                else { return; }
                ev.preventDefault(); select(vis[k]);
            });
            p.above = above; p.svg = svg; p.x = x; p.y = y; p.cross = cross; p.ring = ring; p.bar = bar;
            p.fig.appendChild(svg);
        }

        metrics.forEach(function (m) {
            var fig = el('figure'), cap = el('figcaption', null, m.title + ' ');
            var unitSpan = el('span', null, '(' + m.unit + ')');
            cap.appendChild(unitSpan);
            fig.appendChild(cap);
            plotsBox.appendChild(fig);
            plots.push({ fig: fig, m: m, svg: null, unitSpan: unitSpan });
        });
        var lastW = -1;
        function drawAll() {
            var w = plotsBox.clientWidth;
            if (w < 10 || w === lastW) { return; }
            lastW = w; hideTip();
            plots.forEach(drawPlot);
            mark(null);
        }

        // ---- table view (collapsed)
        var details = el('details');
        details.appendChild(el('summary', null, 'values per run (' + n + ')'));
        var table = el('table'), thead = el('thead'), hr = el('tr');
        // headers on two lines (name, then unit) so the table stays narrow
        [['use', 'use', 'Untick a run to leave it out of mean and SD and of the plots.'], ['run', ''], ['cluster', '']].concat(metrics.map(function (m) { return [m.title, 'n', null, '(' + m.unit + ')']; }))
            .concat([['Energy measurement', 'n', 'Kubernetes: share of the run\u2019s pods whose energy Kepler measured; the rest are missing or scaled up. Slurm: the job\u2019s share of its node; below 100% the energy is an estimate (the job\u2019s CPU-time share of the node energy).', 'coverage']]).forEach(function (h) {
            var th = el('th', h[1] || null, h[0]); th.scope = 'col';
            if (h[3]) { th.appendChild(el('br')); th.appendChild(document.createTextNode(h[3])); }
            if (h[2]) { th.title = h[2]; th.style.cursor = 'help'; }
            hr.appendChild(th);
        });
        thead.appendChild(hr); table.appendChild(thead);
        var tbody = el('tbody'), manualOff = {}, useBoxes = [];
        runs.forEach(function (r, i) {
            var tr = el('tr'), td = el('td'), a = el('a', null, r.date);
            var useTd = el('td', 'use'), useBox = el('input');
            useBox.type = 'checkbox'; useBox.checked = true; useBox.setAttribute('aria-label', 'use the run of ' + r.date);
            useBox.addEventListener('change', function () { manualOff[i] = !useBox.checked; applyExclusion(); });
            useTd.appendChild(useBox); tr.appendChild(useTd); useBoxes.push(useBox);
            a.href = link(r.uri); a.title = r.label; td.appendChild(a); tr.appendChild(td);
            tr.appendChild(el('td', null, r.cluster || '\u2013'));
            metrics.forEach(function (m) { tr.appendChild(el('td', 'n', fmt(value(r, m)))); });
            tr.appendChild(el('td', 'n', r.cov || '\u2013'));
            tr.addEventListener('mouseenter', function () { mark(i); });
            tr.addEventListener('mouseleave', function () { mark(null); });
            tbody.appendChild(tr); tableRows.push(tr);
        });
        table.appendChild(tbody);
        var tfoot = el('tfoot');
        function buildFoot() {
        tfoot.innerHTML = '';
        var used = n - excludedList().length;
        var ms = function (st) { return st ? fmt(st.mean) + (st.sd !== null ? ' \u00b1 ' + fmt(st.sd) : '') : '\u2013'; };
        var se = function (st) { return st && st.se !== null ? fmt(st.se) : '\u2013'; };
        var rows = grouped
            ? [].concat.apply([], groups.map(function (g) {
                  var k = runs.filter(function (r, j) { return !excluded[j] && gk(r) === g; }).length;
                  return [[groupName(g) + ' (' + k + ' runs): mean \u00b1 SD', ms, g], [groupName(g) + ': standard error of the mean', se, g]];
              }))
            : [[(used === n ? 'all runs' : used + ' of ' + n + ' runs') + ': mean \u00b1 SD', ms, null], ['standard error of the mean', se, null]];
        rows.forEach(function (row) {
            var tr = el('tr');
            tr.appendChild(el('td'));
            var lab = el('td', null, row[0]); lab.colSpan = 2; tr.appendChild(lab);
            metrics.forEach(function (m) { tr.appendChild(el('td', 'n', row[1](row[2] === null ? m.all : m.by[row[2]]))); });
            tr.appendChild(el('td'));
            tfoot.appendChild(tr);
        });
        }
        buildFoot();
        table.appendChild(tfoot); details.appendChild(table); tableBox.appendChild(details);
        showInfo();

        // ---- runs left out: unticked in the table (manualOff) or by the tick boxes above
        var exMsg = root.querySelector('.wrm-excl-msg'), usedBox = root.querySelector('.wrm-used');
        var legendBox = root.querySelector('.wrm-legend');
        function showUsed() {
            var used = n - excludedList().length;
            if (usedBox) { usedBox.textContent = used === n ? 'all ' + n : used + ' of ' + n; }
            if (!legendBox) { return; }
            legendBox.innerHTML = '';
            legendBox.hidden = !grouped;
            if (!grouped) { return; }
            groups.forEach(function (g) {
                var k = runs.filter(function (r, j) { return !excluded[j] && gk(r) === g; }).length;
                var item = el('span'), sw = el('span', 'sw');
                sw.style.background = colourOf(g); sw.style.opacity = '.6';
                item.appendChild(sw);
                item.appendChild(document.createTextNode(groupName(g) + ': mean \u00b1 SD of ' + k + (k === 1 ? ' run' : ' runs')));
                legendBox.appendChild(item);
            });
        }
        showUsed();
        function applyExclusion() {
            var set = {};
            Object.keys(manualOff).forEach(function (j) { if (manualOff[j]) { set[j] = true; } });
            runs.forEach(function (r, j) { if (clusterOff[r.cl] || nodeCountOff[r.nodes] || nodeOff[r.node] || byOff(r)) { set[j] = true; } });
            excluded = set;
            recomputeStats();
            var list = excludedList();
            showUsed();
            var byHand = Object.keys(manualOff).filter(function (j) { return manualOff[j]; }).length;
            exMsg.innerHTML = '';
            if (byHand) {
                exMsg.appendChild(document.createTextNode(byHand + (byHand > 1 ? ' runs' : ' run') + ' unticked'));
                var reset = el('button', null, 'use all again'); reset.type = 'button';
                reset.addEventListener('click', function () { manualOff = {}; useBoxes.forEach(function (b) { b.checked = true; }); applyExclusion(); });
                exMsg.appendChild(reset);
            }
            tableRows.forEach(function (tr, j) { tr.classList.toggle('excl', !!excluded[j]); });
            buildFoot();
            lastW = -1; drawAll();
        }

        // ---- tick boxes for clusters, number of nodes, node use and persons, all selected at first; removing a tick
        //      leaves the runs of that cluster, number of nodes, node use or person out of mean and SD. Only options with runs are listed.
        var SHOW_SINGLE_VALUE = false;
        function tickBoxes(boxSel, listSel, options, off, key) {
            var box = root.querySelector(boxSel), list = root.querySelector(listSel);
            var withRuns = options.filter(function (o) { return o.count > 0; });
            if (!box || !list || !withRuns.length) { return; }
            // one value for all runs: nothing to choose, so it is shown as text; a line with only "not recorded" is left out
            if (withRuns.length === 1) {
                if (!SHOW_SINGLE_VALUE || !withRuns[0][key]) { return; }
                var only = el('span', 'only', withRuns[0].name + ' ');
                if (withRuns[0].title) { only.title = withRuns[0].title; }
                only.appendChild(el('span', 'count', '(all ' + withRuns[0].count + ' runs)'));
                list.appendChild(only);
                box.hidden = false;
                return;
            }
            withRuns.forEach(function (o) {
                var label = el('label'), input = el('input');
                input.type = 'checkbox'; input.checked = true;
                if (o.title) { label.title = o.title; }
                input.addEventListener('change', function () { off[o[key]] = !input.checked; applyExclusion(); });
                label.appendChild(input);
                label.appendChild(document.createTextNode(o.name + ' '));
                label.appendChild(el('span', 'count', '(' + o.count + (o.count === 1 ? ' run)' : ' runs)')));
                list.appendChild(label);
            });
            box.hidden = false;
        }
        tickBoxes('.wrm-cluster-box', '.wrm-cluster-box .wrm-cluster-list', clusters, clusterOff, 'uri');
        tickBoxes('.wrm-nodes-box', '.wrm-nodes-list', nodeCounts, nodeCountOff, 'key');
        tickBoxes('.wrm-node-box', '.wrm-node-list', nodeUses, nodeOff, 'key');
        tickBoxes('.wrm-by-box', '.wrm-by-list', people, personOff, 'key');

        // ---- "Compare by": all runs together, or one mean and SD per cluster, number of nodes, node use or person.
        //      Only dimensions in which the runs differ are offered.
        (function () {
            var box = root.querySelector('.wrm-cmp-box'), list = root.querySelector('.wrm-cmp-list');
            if (!box || !list) { return; }
            var dims = [['', 'all runs together'], ['cluster', 'cluster'], ['nodes', 'number of nodes'], ['node', 'node use'], ['by', 'run by']];
            var offered = dims.filter(function (d) {
                if (!d[0]) { return true; }
                var keep = compareBy; compareBy = d[0];
                var k = optionsFor().length; compareBy = keep;
                return k > 1;
            });
            if (offered.length < 2) { return; }
            offered.forEach(function (d) {
                var label = el('label'), input = el('input');
                input.type = 'radio'; input.name = 'wrm-cmp'; input.value = d[0]; input.checked = d[0] === compareBy;
                input.addEventListener('change', function () { if (input.checked) { compareBy = d[0]; applyExclusion(); } });
                label.appendChild(input);
                label.appendChild(document.createTextNode(d[1]));
                list.appendChild(label);
            });
            box.hidden = false;
        })();

        // ---- place below the "workflow runs" list (stage pages: the "stage executions" list), then draw
        //      whenever the tab is shown or resized
        var runsTitle = document.getElementById(stage ? 'hasStageExecution' : 'hasRun');
        var runsArticle = runsTitle && runsTitle.closest ? runsTitle.closest('article') : null;
        var pane = document.getElementById('run_metadataGroup');
        var intro = document.getElementById('individual-intro');
        if (runsArticle && runsArticle.parentNode) {
            runsArticle.parentNode.insertBefore(root, runsArticle.nextSibling);
        } else if (pane) {
            pane.appendChild(root);
        } else if (intro && intro.parentNode && intro.contains(root)) {
            intro.parentNode.insertBefore(root, intro.nextSibling);
        }
        root.hidden = false;
        var pending = false;
        var schedule = function () {
            if (pending) { return; }
            pending = true;
            window.requestAnimationFrame(function () { pending = false; drawAll(); });
        };
        if (window.ResizeObserver) { new ResizeObserver(schedule).observe(plotsBox); }
        window.addEventListener('resize', schedule);
        schedule();
    };

    var start = function () {
        window.fondaWorkflowRunMetrics(document.getElementById('workflow-run-metrics'), "${urls.base?js_string}", [
<#list wrmRows as row>
            {r: "${row.run?js_string}", l: "${(row.label!"")?js_string}", s: "${(row.start!"")?js_string}", e: "${(row.energy!"")?js_string}", c: "${(row.carbon!"")?js_string}", cpu: "${(row.cpu!"")?js_string}", d: "${(row.duration!"")?js_string}", m: "${(row.energyMethod!"")?js_string}", cv: "${(row.coverage!"")?js_string}", cl: "${(row.cluster!"")?js_string}", cn: "${(row.clusterName!"")?js_string}", rcv: "${(row.runCoverage!"")?js_string}", by: "${(row.runBy!"")?js_string}", use: "${(row.nodeUse!"")?js_string}", nc: "${(row.nodes!"")?js_string}"<#if fondaShowAboveIdle>, ai: "${(row.energyAboveIdle!"")?js_string}"</#if>}<#sep>,</#sep>
</#list>
        ], ${wrmStage?c});
    };
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', start); } else { start(); }
})();
</script>
</#if>

<#-- FONDA 2026-10-18: "values per run (N)" below the plots did not look clickable. Bootstrap 3 (used by the theme)
     sets summary to display: block, which hides the browser's own arrow. The line now looks like the other
     "... more" toggles of the site (dark blue text in a light grey-blue box, also in dark mode) and has its own arrow,
     which points right when the table is closed and down when it is open. Styles only, added at the end. -->
<style>
#workflow-run-metrics .wrm-table-wrap > details { margin-top: 1.2em; }
#workflow-run-metrics .wrm-table-wrap > details > summary {
    display: inline-flex; align-items: center; gap: .6em; list-style: none; cursor: pointer; user-select: none;
    margin: 0; padding: 5px 12px 5px 11px; border-radius: 4px;
    background: #eceff3; color: #23395d; font-size: 13px; font-weight: 600; line-height: 1.4; }
#workflow-run-metrics .wrm-table-wrap > details > summary::-webkit-details-marker { display: none; }
#workflow-run-metrics .wrm-table-wrap > details > summary::marker { content: ''; }
#workflow-run-metrics .wrm-table-wrap > details > summary::before {
    content: ''; flex: 0 0 auto; width: 6px; height: 6px; border-right: 2px solid currentColor;
    border-bottom: 2px solid currentColor; transform: rotate(-45deg); transition: transform .15s; }
#workflow-run-metrics .wrm-table-wrap > details[open] > summary::before { transform: translateY(-2px) rotate(45deg); }
#workflow-run-metrics .wrm-table-wrap > details > summary:hover { background: #dfe4ea; }
#workflow-run-metrics .wrm-table-wrap > details > summary:focus-visible { outline: 2px solid #2a78d6; outline-offset: 2px; }
html.dark-mode #workflow-run-metrics .wrm-table-wrap > details > summary { background: #1f2a3d; color: #7fc0dd; }
html.dark-mode #workflow-run-metrics .wrm-table-wrap > details > summary:hover { background: #273349; }
</style>
