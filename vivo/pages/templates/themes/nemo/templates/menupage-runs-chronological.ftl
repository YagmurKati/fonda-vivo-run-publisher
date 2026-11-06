<#-- Only included on the Runs browse page when the timestamp query has results. -->
<section id="runs-chronological" aria-label="Workflow runs, newest first">
    <div style="display:flex; align-items:center; justify-content:space-between; flex-wrap:wrap; gap:12px; margin-bottom:10px;">
        <span>${runsByStartDG?size} runs</span>
        <label for="runs-sort">Sort
            <select id="runs-sort" disabled>
                <option value="newest">Newest first</option>
                <option value="name">Name A-Z</option>
            </select>
        </label>
    </div>
    <ul id="runs-list" role="list" style="list-style:none; margin:0; padding:0;">
        <#list runsByStartDG as row>
            <li data-newest-position="${row_index}" style="padding:12px 2px; border-bottom:1px solid #d8e0e9;">
                <a href="${urls.base}/individual?uri=${row["run"]?url}">${(row["runLabel"]!row["run"])?html}</a>
            </li>
        </#list>
    </ul>
</section>
<script>
(function () {
    var select = document.getElementById('runs-sort');
    var list = document.getElementById('runs-list');
    if (!select || !list) return;
    select.disabled = false;
    select.addEventListener('change', function () {
        var rows = Array.prototype.slice.call(list.children);
        rows.sort(function (a, b) {
            var original = Number(a.getAttribute('data-newest-position')) - Number(b.getAttribute('data-newest-position'));
            if (select.value === 'newest') return original;
            var aName = a.querySelector('a').textContent;
            var bName = b.querySelector('a').textContent;
            return aName.localeCompare(bName, undefined, {sensitivity: 'base'}) || original;
        });
        rows.forEach(function (row) { list.appendChild(row); });
    });
})();
</script>
