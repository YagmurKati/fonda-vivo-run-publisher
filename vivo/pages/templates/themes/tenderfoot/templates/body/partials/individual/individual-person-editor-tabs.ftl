<#-- FONDA: retain the permitted property objects and their existing edit forms; reorganize only their presentation. -->
<#import "lib-properties.ftl" as p>
<#assign subjectUri = individual.controlPanelUrl()?split("=")>
<#assign verbose = (verbosePropertySwitch.currentValue)!false>
<#assign fondaSimplifiedPersonEditor = (editable!false) && !((user.hasSiteAdminAccess)!false)>
<#assign fondaPublicViewAll = !(editable!false)>
<#assign fondaCompactPersonProfile = true>

<#function fondaHasValues property>
    <#if (property.collatedBySubclass)!false>
        <#list property.subclasses![] as subclass>
            <#if subclass.statements?has_content><#return true></#if>
        </#list>
        <#return false>
    </#if>
    <#return (property.statements![])?has_content>
</#function>
<#function fondaDestination source property>
    <#local field = (property.name!"")?lower_case?trim>
    <#if source == "overview" || source == "affiliation"><#return "About"></#if>
    <#if source == "identity" || source == "identifiers" || source == "contact"><#return "Contact"></#if>
    <#if source == "teaching" || source == "service"><#return "Activities"></#if>
    <#if source == "other">
        <#if field == "performs technique"><#return "Research"></#if>
        <#return "Activities">
    </#if>
    <#return source?capitalize>
</#function>
<#function fondaIsDefault entry>
    <#local field = (entry.property.name!"")?lower_case?trim>
    <#return ["overview", "member of", "research overview", "keywords", "workflows", "selected publications", "presentations", "attended event", "organizer of event", "education and training", "awards and honors", "advisee of", "primary email", "webpage", "phone", "orcid id"]?seq_contains(field)>
</#function>
<#function fondaActivitySection entry>
    <#local field = (entry.property.name!"")?lower_case?trim>
    <#if entry.source == "teaching"><#return "Teaching"></#if>
    <#if field == "outreach overview" || field == "outreach and community service activities"><#return "Outreach"></#if>
    <#return "Service">
</#function>
<#function fondaIsIdentifier entry>
    <#return entry.source == "identity" || entry.source == "identifiers">
</#function>

<#assign fondaGroups = {}>
<#assign fondaPublicContactProperties = []>
<#assign fondaGroupOrder = ["About", "Research", "Workflows", "Publications", "Events", "Activities", "Background", "Contact"]>
<#list propertyGroups.all as originalGroup>
    <#assign fondaSource = originalGroup.getName(nameForOtherGroup)?lower_case?trim>
    <#list originalGroup.properties as originalProperty>
        <#if (editable!false) || fondaHasValues(originalProperty)>
            <#assign fondaTarget = fondaDestination(fondaSource, originalProperty)>
            <#if fondaPublicViewAll && fondaTarget == "Contact">
                <#-- Reuse only the permitted populated contact/identifier properties in the sidebar. -->
                <#assign fondaPublicContactProperties = fondaPublicContactProperties + [originalProperty]>
            <#else>
            <#assign fondaEntries = fondaGroups[fondaTarget]![]>
            <#assign fondaGroups = fondaGroups + {fondaTarget: fondaEntries + [{"property": originalProperty, "source": fondaSource}]}>
            <#if !fondaGroupOrder?seq_contains(fondaTarget)><#assign fondaGroupOrder = fondaGroupOrder + [fondaTarget]></#if>
            </#if>
        </#if>
    </#list>
</#list>

<#macro fondaRender entries>
    <#local fields = []>
    <#list entries as entry><#local fields = fields + [entry.property]></#list>
    <#local group = {"properties": fields}>
    <#include "individual-properties.ftl">
</#macro>
<#macro fondaFieldSection entries moreLabel="More fields" emptyLabel="">
    <#local visible = []><#local additional = []>
    <#list entries as entry>
        <#if !fondaSimplifiedPersonEditor || fondaHasValues(entry.property) || (emptyLabel == "" && fondaIsDefault(entry))>
            <#local visible = visible + [entry]>
        <#else><#local additional = additional + [entry]></#if>
    </#list>
    <#if visible?has_content>
        <#if emptyLabel?has_content && !fondaPublicViewAll><h3 class="fonda-field-section-heading">${emptyLabel?html}</h3></#if>
        <@fondaRender visible />
    </#if>
    <#if additional?has_content>
        <details class="fonda-more-fields">
            <summary><#if !visible?has_content && emptyLabel?has_content>${emptyLabel?html}<#else>${moreLabel?html}</#if></summary>
            <@fondaRender additional />
        </details>
    </#if>
</#macro>

<style>
    .fonda-person-tabs .nav-tabs { display: flex; flex-wrap: wrap; margin-bottom: 0; }
    .fonda-person-tabs .nav-tabs > li { float: none; }
    .fonda-person-tabs .nav-tabs > li > a { font-size: 14px; line-height: 1.4; padding: 8px 11px; }
    .fonda-person-tabs .tab-content { padding-top: 0; }
    #wrapper-content .fonda-person-tabs article.property { margin: 0; padding: 4px 0; }
    #wrapper-content .fonda-person-tabs article.property > h3 { font-size: 15px; line-height: 1.45; padding: 4px 16px 4px 0; }
    .fonda-person-tabs article.property > ul.property-list > li,
    .fonda-person-tabs article.property .subclass-property-list > li,
    .fonda-person-tabs article.property .fonda-publication-items > li,
    .fonda-person-tabs article.property > ul.property-list > .additionalItems > li { font-size: 15px; line-height: 1.45; padding: 4px 0; }
    .fonda-person-tabs article.property > ul.property-list > li.subclass { padding: 0 0 8px; }
    .fonda-person-tabs article.property li.subclass > h3 { font-size: 13px; line-height: 1.4; font-weight: 600; color: #647487; margin: 0 0 3px; padding: 0; }
    #wrapper-content .fonda-person-tabs details.fonda-more-fields { font-size: 14px; line-height: 1.4; margin: 6px 0; border: 1px solid #dce6ee; border-radius: 5px; padding: 6px 10px; }
    #wrapper-content .fonda-person-tabs details.fonda-more-fields > summary { cursor: pointer; color: #526476; font-family: inherit; font-size: 14px; line-height: 1.4; font-weight: 600; margin: 0; padding: 0; min-height: 0; }
    #wrapper-content .fonda-person-tabs details.fonda-more-fields > summary::marker { font-size: 0.8em; }
    #wrapper-content .fonda-person-tabs details.fonda-more-fields[open] > summary { margin-bottom: 6px; }
    .fonda-person-tabs .fonda-field-hint { color: #647487; font-size: 12px; line-height: 1.5; margin: 4px 0 8px; }
    .fonda-person-tabs .fonda-pane-heading,
    .fonda-person-tabs .fonda-field-section-heading { color: #526476; font-size: 14px; line-height: 1.4; font-weight: 600; margin: 12px 0 2px; padding: 0; }
    .fonda-person-tabs .fonda-pane-heading { display: none; }
    .fonda-person-tabs.is-view-all .fonda-pane-heading { display: block; }
    .fonda-person-tabs.is-view-all .tab-pane:first-child > .fonda-pane-heading { margin-top: 8px; }
    .fonda-person-tabs [hidden] { display: none !important; }
    .fonda-person-tabs button.fonda-publication-more { font: inherit; font-size: 13px; color: #526476; background: #edf0f2; border: 0; border-radius: 5px; padding: 3px 8px; cursor: pointer; }
    .fonda-person-tabs button.fonda-publication-more:hover { background: #e1e7ec; }
    .fonda-person-tabs button.fonda-publication-more:focus-visible { outline: 2px solid #205584; outline-offset: 2px; }
    @media (min-width: 768px) {
        .fonda-person-tabs article.property { grid-template-columns: minmax(140px, 30%) minmax(0, 1fr); }
    }
    html.dark-mode #wrapper-content .fonda-person-tabs details.fonda-more-fields { border-color: #2b3b50; }
    html.dark-mode #wrapper-content .fonda-person-tabs details.fonda-more-fields > summary { color: #b6c7d8; }
    html.dark-mode .fonda-person-tabs .fonda-pane-heading,
    html.dark-mode .fonda-person-tabs .fonda-field-hint,
    html.dark-mode .fonda-person-tabs .fonda-field-section-heading,
    html.dark-mode .fonda-person-tabs article.property li.subclass > h3 { color: #b6c7d8; }
    html.dark-mode .fonda-person-tabs button.fonda-publication-more { color: #c3d6e7; background: #243449; }
    html.dark-mode .fonda-person-tabs button.fonda-publication-more:hover { background: #30435b; }
</style>
<div class="fonda-person-tabs<#if fondaPublicViewAll> is-view-all</#if>">
    <ul class="nav nav-tabs" role="tablist" aria-label="Profile sections">
        <#assign fondaFirst = true>
        <#list fondaGroupOrder as fondaLabel>
            <#if (fondaGroups[fondaLabel]![])?has_content>
                <#assign fondaGroupId = p.createPropertyGroupHtmlId(fondaLabel)?replace("/", "-")>
                <li role="presentation" data-toggle="tab" groupName="${fondaGroupId?html}" href="#${fondaGroupId?html}Group" <#if fondaFirst && !fondaPublicViewAll>class="active"</#if>>
                    <a id="fonda-tab-${fondaGroupId?html}" href="#${fondaGroupId?html}Group" role="tab" aria-controls="${fondaGroupId?html}Group" aria-selected="${(fondaFirst && !fondaPublicViewAll)?c}">${fondaLabel?html}</a>
                </li>
                <#assign fondaFirst = false>
            </#if>
        </#list>
        <li id="viewAllTab" role="presentation"<#if fondaPublicViewAll> class="active"</#if>>
            <a class="fonda-view-all" href="#viewAll" role="tab" aria-controls="fonda-profile-sections" aria-selected="${fondaPublicViewAll?c}">${i18n().view_all_capitalized}</a>
        </li>
    </ul>
    <div id="fonda-profile-sections" class="tab-content">
        <#assign fondaFirst = true>
        <#list fondaGroupOrder as fondaLabel>
            <#assign fondaEntries = fondaGroups[fondaLabel]![]>
            <#if fondaEntries?has_content>
                <#assign fondaGroupId = p.createPropertyGroupHtmlId(fondaLabel)?replace("/", "-")>
                <div id="${fondaGroupId?html}Group" class="tab-pane <#if fondaFirst || fondaPublicViewAll>active</#if>" role="tabpanel" aria-labelledby="fonda-tab-${fondaGroupId?html}">
                    <#if !fondaPublicViewAll>
                    <h2 id="${fondaGroupId?html}" class="fonda-pane-heading" pgroup="tabs">${fondaLabel?html}</h2>
                    </#if>
                    <#if fondaLabel == "Activities">
                        <#list ["Teaching", "Service", "Outreach"] as section>
                            <#assign sectionEntries = []>
                            <#list fondaEntries as entry><#if fondaActivitySection(entry) == section><#assign sectionEntries = sectionEntries + [entry]></#if></#list>
                            <@fondaFieldSection sectionEntries "More " + section?lower_case + " fields" section />
                        </#list>
                    <#elseif fondaLabel == "Contact">
                        <#assign contactEntries = []><#assign identifierEntries = []>
                        <#list fondaEntries as entry>
                            <#if fondaIsIdentifier(entry)><#assign identifierEntries = identifierEntries + [entry]><#else><#assign contactEntries = contactEntries + [entry]></#if>
                        </#list>
                        <@fondaFieldSection contactEntries />
                        <#if identifierEntries?has_content><h3 class="fonda-field-section-heading">Identifiers</h3></#if>
                        <@fondaFieldSection identifierEntries "More identifiers" />
                    <#else><@fondaFieldSection fondaEntries /></#if>
                </div>
                <#assign fondaFirst = false>
            </#if>
        </#list>
    </div>
</div>
<script>
    $(document).ready(function () {
        var scope = document.querySelector('#property-tabs .fonda-person-tabs');
        if (!scope) return;
        // One preview across publication types. Retain every original record and edit link.
        function previewPublications(list) {
            var items = [], groups = [];
            Array.prototype.forEach.call(list.children, function (child) {
                if (child.matches('li.subclass')) {
                    var sublist = child.querySelector(':scope > ul.subclass-property-list');
                    if (!sublist) return;
                    // This list has its own overall toggle; avoid the global per-type controller.
                    sublist.classList.remove('subclass-property-list');
                    sublist.classList.add('fonda-publication-items');
                    var groupItems = Array.prototype.filter.call(sublist.children, function (item) { return item.matches('li'); });
                    groups.push({element: child, items: groupItems});
                    items = items.concat(groupItems);
                } else if (child.matches('li')) {
                    items.push(child);
                }
            });
            if (items.length <= 5) return;
            var toggleRow = document.createElement('li');
            toggleRow.className = 'fonda-publication-toggle';
            var button = document.createElement('button');
            button.type = 'button';
            button.className = 'more-less fonda-publication-more';
            button.setAttribute('aria-controls', list.id);
            toggleRow.appendChild(button);
            list.appendChild(toggleRow);
            function setExpanded(expanded) {
                items.forEach(function (item, index) { item.hidden = !expanded && index >= 5; });
                groups.forEach(function (group) {
                    group.element.hidden = !group.items.some(function (item) { return !item.hidden; });
                });
                button.setAttribute('aria-expanded', String(expanded));
                button.setAttribute('aria-label', expanded ? 'Show fewer publications' : 'Show all publications');
                button.textContent = expanded ? ((window.i18nStrings && i18nStrings.displayLess) || 'less') : ((window.i18nStrings && i18nStrings.displayMoreEllipsis) || '... more');
            }
            button.addEventListener('click', function () { setExpanded(button.getAttribute('aria-expanded') !== 'true'); });
            setExpanded(false);
        }
        Array.prototype.forEach.call(scope.querySelectorAll('#PublicationsGroup ul.property-list[id$="-Authorship-List"]'), previewPublications);
        var tabs = $(scope).find('li[data-toggle="tab"]');
        var panes = $(scope).find('.tab-pane');
        var allTab = $(scope).find('#viewAllTab');
        var allLink = scope.querySelector('.fonda-view-all');
        var isEditing = ${fondaSimplifiedPersonEditor?c};
        var key = 'fondaPersonActiveTab';
        var aliases = {'#OverviewGroup': '#AboutGroup', '#AffiliationGroup': '#AboutGroup', '#TeachingGroup': '#ActivitiesGroup', '#ServiceGroup': '#ActivitiesGroup', '#OtherGroup': '#ActivitiesGroup', '#IdentityGroup': '#ContactGroup'};
        var firstTab = tabs.first().attr('href');
        function store(value) { if (isEditing) { try { localStorage.setItem(key, value); } catch (e) {} } }
        function findTab(target) { return tabs.filter(function () { return this.getAttribute('href') === target; }); }
        function update(tab) {
            var target = tab.getAttribute('href');
            scope.classList.remove('is-view-all');
            allTab.removeClass('active');
            allLink.setAttribute('aria-selected', 'false');
            tabs.removeClass('active');
            $(tab).addClass('active');
            tabs.find('a').attr('aria-selected', 'false');
            $(tab).find('a').attr('aria-selected', 'true');
            panes.removeClass('active');
            panes.filter(function () { return '#' + this.id === target; }).addClass('active');
            store(target);
        }
        function activate(target) {
            var tab = findTab(aliases[target] || target);
            if (!tab.length) return false;
            tabs.removeClass('active');
            tab.tab('show');
            update(tab[0]);
            return true;
        }
        function showAll() {
            tabs.removeClass('active');
            tabs.find('a').attr('aria-selected', 'false');
            panes.addClass('active');
            scope.classList.add('is-view-all');
            allTab.addClass('active');
            allLink.setAttribute('aria-selected', 'true');
            store('#viewAll');
        }
        tabs.on('click', function (event) { event.preventDefault(); activate(this.getAttribute('href')); });
        tabs.on('shown.bs.tab', function () { update(this); });
        $(allLink).on('click', function (event) { event.preventDefault(); showAll(); });
        function navigate(target) {
            if (target === '#viewAll') { showAll(); return true; }
            if (activate(target)) return true;
            var field = target && document.getElementById(target.replace(/^#/, ''));
            if (field && scope.contains(field)) {
                var pane = field.closest('.tab-pane');
                var details = field.closest('details');
                if (pane) activate('#' + pane.id);
                if (details) details.open = true;
                return true;
            }
            return false;
        }
        var saved;
        if (isEditing) { try { saved = localStorage.getItem(key) || localStorage.getItem('activeTab'); } catch (e) {} }
        if (!navigate(location.hash || saved || (isEditing ? firstTab : '#viewAll'))) {
            navigate(isEditing ? firstTab : '#viewAll');
        }
        $(window).on('hashchange', function () { navigate(location.hash || (isEditing ? firstTab : '#viewAll')); });
    });
</script>
${stylesheets.add('<link rel="stylesheet" href="${urls.base}/css/individual/individual-property-groups.css" />')}
${scripts.add('<script src="${urls.theme}/js/long-value-clamp.js?v=5"></script>')}
${scripts.add('<script src="${urls.theme}/js/round-decimals.js?v=1"></script>')}
