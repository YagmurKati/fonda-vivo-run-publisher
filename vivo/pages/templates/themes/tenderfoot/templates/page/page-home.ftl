<#-- $This file is distributed under the terms of the license in /doc/license.txt$  -->

<@widget name="login" include="assets" />

<#--
        With release 1.6, the home page no longer uses the "browse by" class group/classes display.
        If you prefer to use the "browse by" display, replace the import statement below with the
        following include statement:

            <#include "browse-classgroups.ftl">

        Also ensure that the homePage.geoFocusMaps flag in the runtime.properties file is commented
        out.
-->
<#import "lib-home-page.ftl" as lh>

<#-- Keep small measured footprints visible instead of rounding them to zero. -->
<#function fondaEnergy value>
    <#if (value >= 0.001)>
        <#return value?string("0.###") + " kWh">
    <#else>
        <#return (value * 1000)?string("0.###") + " Wh">
    </#if>
</#function>

<#function fondaCarbon value>
    <#if (value >= 0.001)>
        <#return value?string("0.###") + " kg CO&#8322;e">
    <#else>
        <#return (value * 1000)?string("0.###") + " g CO&#8322;e">
    </#if>
</#function>

<#-- Energy expressed as how long an average German household runs on it:
     2,434 kWh per year (BDEW, "Stromverbrauch im Haushalt 2025"). The unit grows with the total. -->
<#function fondaHouseholdTime kWh>
    <#local days = kWh * 365 / 2434>
    <#local n = (days * 1440)?round>
    <#if (n < 60)><#return fondaPlural([n, 1]?max, "minute")></#if>
    <#local n = (days * 24)?round>
    <#if (n < 24)><#return fondaPlural(n, "hour")></#if>
    <#local n = days?round>
    <#if (n < 14)><#return fondaPlural(n, "day")></#if>
    <#local n = (days / 7)?round>
    <#if (n < 9)><#return fondaPlural(n, "week")></#if>
    <#local n = (days * 12 / 365)?round>
    <#if (n < 12)><#return fondaPlural(n, "month")></#if>
    <#local years = (days / 365)?string("0.#")>
    <#return years + " year" + (years == "1")?then("", "s")>
</#function>

<#function fondaPlural n unit>
    <#return n?string("0") + " " + unit + (n == 1)?then("", "s")>
</#function>

<!DOCTYPE html>
<html lang="${.locale?split('_')[0]}">
    <head>
        <#include "head.ftl">
        <#if geoFocusMapsEnabled >
            <#include "geoFocusMapScripts.ftl">
        </#if>
        <script async type="text/javascript" src="${urls.base}/js/homePageUtils.js?version=x"></script>
    </head>

    <body class="${bodyClasses!} home-page" onload="${bodyOnload!}">
        <#-- supplies the faculty count to the js function that generates a random row number for the search query -->
        <@lh.facultyMemberCount  vClassGroups! />
		<header id="branding" role="banner">
			<#include "identity.ftl">
		</header>
        <#include "developer.ftl">
        <#include "menu.ftl">
        <#include "message.ftl">
        <div class="row hero">
            <div class="theme-showcase">
                <div class="col-md-12">
                    <div class="container" role="main">
                        <div class="jumbotron">
                            <h1>Discover FONDA's research on sustainable scientific data analysis</h1>
                        </div>
                        <form id="search-homepage" action="${urls.search}" name="search-home" role="search" method="GET" class="form-horizontal">
                            <fieldset>
                                <div class="form-group pull-left" style="margin-right: 5px;">
                                    <select class="form-control" id="classgroup" name="filters_category">
                                        <option value="">${i18n().all_capitalized}</option>
                                        <#list vClassGroups as group>
                                            <#if (group.individualCount > 0)>
                                                <option value="category:${group.uri}">${group.displayName?capitalize}</option>
                                            </#if>
                                        </#list>
                                    </select>
                                </div>
                                <div class="form-group">
                                    <div class="input-group">
                                        <input type="text" name="querytext" class="form-control" value="" placeholder="Search people, workflows, publications..." autocapitalize="off" />
                                        <span class="input-group-btn">
                                            <button class="btn btn-default" type="submit">
                                                <span class="icon-search">${i18n().search_button}</span>
                                            </button>
                                        </span>
                                    </div>
                                </div>
                            </fieldset>
                        </form>
                    </div>
                </div>
                <div class="col-md-12">
                    <div class="container">
                        <div class="jumbotron">
                            <p>Connecting researchers, publications, workflows, and their energy and carbon footprint so you can see the real cost of scientific computing, and how it is improving.</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <#-- FONDA: Research + random-Faculty boxes replaced by Workflows (with footprint) and Recent Publications. -->
        <div class="row faculty-home">
            <div class="container">
                <div class="col-md-6">
                    <#if workflowsDG?? && workflowsDG?has_content>
                    <section class="home-sections">
                        <h4>Workflows</h4>
                        <div class="f-panel">
                            <#-- FONDA: show at most 4 workflows so this column matches the Recent Publications column height -->
                            <#list workflowsDG[0..*4] as row>
                            <div class="f-item">
                                <a href="${urls.base}/individual?uri=${row["wf"]?url}" style="font-weight:600;">${row["wfLabel"]!row["wf"]}</a>
                                <div class="f-sub">
                                    <#assign wfRuns = (row["runCount"]!"0")?number>
                                    <#-- FONDA: read as intentional rather than as missing data when nothing has been measured yet -->
                                    <#if (wfRuns > 0)>${wfRuns?string("0")} run<#if wfRuns != 1>s</#if><#else><span class="f-noruns">no runs recorded yet</span></#if><#if row["energy"]?? && row["energy"]?has_content && (row["energy"]?number > 0)> <span class="f-badge f-badge-green">&#9889; ${fondaEnergy(row["energy"]?number)}</span></#if><#if row["co2"]?? && row["co2"]?has_content && (row["co2"]?number > 0)> <span class="f-badge f-badge-amber">&#127807; ${fondaCarbon(row["co2"]?number)}</span></#if>
                                </div>
                            </div>
                            </#list>
                            <div class="f-more"><a href="${urls.base}/workflows">View all ...</a></div>
                        </div>
                    </section>
                    </#if>
                </div>
                <div class="col-md-6">
                    <#if recentPubsDG?? && recentPubsDG?has_content>
                    <section class="home-sections">
                        <h4>Recent Publications</h4>
                        <div class="f-panel">
                            <#list recentPubsDG as row>
                            <div class="f-item">
                                <a href="${urls.base}/individual?uri=${row["pub"]?url}">${row["pubLabel"]!row["pub"]}</a>
                                <#if row["date"]?? && row["date"]?has_content><span class="f-year">(${row["date"]?substring(0,4)})</span></#if>
                            </div>
                            </#list>
                            <div class="f-more"><a href="${urls.base}/publications">View all ...</a></div>
                        </div>
                    </section>
                    </#if>
                </div>
            </div>
        </div>

        <#if geoFocusMapsEnabled >
            <div class="row geo-focus">
                <div class="container">
                    <div class="col-md-12">
                        <!-- Map display of researchers' areas of geographic focus. Must be enabled in runtime.properties -->
                        <@lh.geographicFocusHtml />
                    </div>
                </div>
            </div>
        </#if>



<!-- FONDA: Energy & Carbon impact band + latest workflow run cards.                              -->
<!-- Data getters: fondaRunImpactDataGetter (runImpactDG) and fondaLatestRunsDataGetter          -->
<!-- (latestRunsDG), defined in /opt/vivo/vivo/rdf/display/everytime/fondaHomePageDataGetters.n3 -->
<style>
.faculty-home .home-sections h4, #home-latest-runs h4 {margin-left:0 !important; margin-right:0 !important;}
.f-panel {background:#fbfcfd; border:1px solid #e6eaef; border-radius:10px; padding:6px 16px; box-shadow:0 1px 3px rgba(0,0,0,0.05); margin-left:0;}
.f-item {padding:12px 4px; border-bottom:1px solid #eceff3;}
.f-item:last-of-type {border-bottom:none;}
.f-item:hover {background:#f2f6fa;}
.f-sub {margin-top:5px; font-size:0.85em; color:#666;}
.f-noruns {font-style:italic; opacity:0.85;}
.f-year {color:#888; font-size:0.85em; margin-left:4px;}
.f-more {padding:10px 4px;}
.f-cards {display:flex; flex-wrap:wrap; gap:14px;}
.f-stat {flex:1; min-width:170px; border-radius:10px; padding:16px 18px; box-shadow:0 1px 4px rgba(0,0,0,0.07); transition:transform .15s ease;}
.f-stat:hover {transform:translateY(-3px);}
.f-num {font-size:1.8em; font-weight:700;}
.f-cap {color:#555; font-size:0.9em; margin-top:2px;}
.f-badge {display:inline-block; font-weight:600; padding:3px 10px; border-radius:12px; font-size:0.85em; margin:2px 6px 2px 0;}
.f-badge-green {background:#eef6ee; color:#2e7d32;}
.f-badge-amber {background:#fdf3e7; color:#b25f00;}
.f-run-card {flex:1 1 46%; min-width:280px; background:#fbfcfd; border:1px solid #e6eaef; border-radius:10px; padding:15px 17px; box-shadow:0 1px 3px rgba(0,0,0,0.05); transition:box-shadow .15s ease, transform .15s ease;}
.f-run-card:hover {box-shadow:0 5px 16px rgba(0,0,0,0.11); transform:translateY(-2px);}
.f-chart-row {display:flex; align-items:center; gap:12px; margin:8px 0;}
.f-chart-label {flex:0 0 135px; font-size:0.82em; color:#555; text-align:right;}
.f-chart-track {flex:1; background:#edf1f5; border-radius:8px; height:16px; overflow:hidden;}
.f-chart-bar {height:16px; border-radius:8px; background:linear-gradient(90deg,#2e7d32,#7cb342); min-width:2px;}
.f-chart-val {flex:0 0 95px; font-size:0.82em; color:#2e7d32; font-weight:600;}
#home-stats ul#stats {display:flex !important; flex-wrap:wrap; justify-content:space-between; align-items:center; width:100%; list-style:none; padding:0; margin:14px 0 0 0;}
#home-stats ul#stats li {flex:1 1 0; min-width:120px; text-align:center; float:none !important; margin:0 !important;}
</style>
<#if latestRunsDG?? && latestRunsDG?has_content>
<div class="row faculty-home">
    <div class="container">
        <div class="col-md-12">
            <section id="home-latest-runs" class="home-sections">
                <h4>Energy &amp; Carbon of FONDA Workflows</h4>

                <#if runImpactDG?? && runImpactDG?has_content>
                    <#assign imp = runImpactDG[0]>
                    <#assign totE = (imp["totalEnergy"]!"0")?number>
                    <#assign totC = (imp["totalCO2"]!"0")?number>
                    <#assign totCpu = (imp["totalCpu"]!"0")?number>
                    <#assign nRuns = (imp["runCount"]!"0")?number>
                    <div class="f-cards" style="margin:18px 0 6px 0;">
                        <#if (totE > 0)>
                        <div class="f-stat" style="background:#eef6ee; border-left:5px solid #2e7d32;">
                            <div class="f-num" style="color:#2e7d32;">${fondaEnergy(totE)}</div>
                            <div class="f-cap">total energy measured<br/>&#8776; ${fondaHouseholdTime(totE)} of electricity for an average German household</div>
                        </div>
                        </#if>
                        <#if (totC > 0)>
                        <div class="f-stat" style="background:#fdf3e7; border-left:5px solid #e07b00;">
                            <div class="f-num" style="color:#e07b00;">${fondaCarbon(totC)}</div>
                            <div class="f-cap">total carbon footprint<br/>&#8776; ${(totC/0.17)?string("0.#")} km driven by car</div>
                        </div>
                        </#if>
                        <#if (totCpu > 0)>
                        <div class="f-stat" style="background:#eaf1f8; border-left:5px solid #23395d;">
                            <div class="f-num" style="color:#23395d;">${(totCpu/3600)?string("0.#")} CPU-hours</div>
                            <div class="f-cap">of compute across ${nRuns?string("0")} tracked run<#if nRuns != 1>s</#if></div>
                        </div>
                        </#if>
                    </div>
                    <p style="font-size:0.78em; color:#888; margin:4px 0 0 2px;">Totals are sums of per-run values measured on the clusters. Equivalences assume 2,434&nbsp;kWh per year for an average German household (BDEW&nbsp;2025) and 170&nbsp;g&nbsp;CO&#8322;e/km for an average passenger car.</p>
                </#if>

                <#-- FONDA: choose the runs that the chart and the cards below both show.
                     latestRunsDG arrives newest-first. Pass 1 keeps the newest run of each
                     distinct workflow, so one heavily-run workflow cannot take every slot.
                     Pass 2 tops the list back up to runSlots with the newest runs not already
                     taken. Pass 3 walks latestRunsDG once more to restore newest-first order
                     and drop duplicate rows the OPTIONALs in the query can produce. -->
                <#assign runSlots = 4>
                <#assign pickedUris = []>
                <#assign seenWf = []>
                <#list latestRunsDG as r>
                    <#-- FONDA 2026-10-30: one run per workflow + cluster pair (was: per workflow) -->
                    <#assign wfKey = (r["wf"]!"") + "|" + (r["cluster"]!"")>
                    <#if (wfKey != "|") && !seenWf?seq_contains(wfKey) && (pickedUris?size < runSlots)>
                        <#assign seenWf = seenWf + [wfKey]>
                        <#assign pickedUris = pickedUris + [r["run"]]>
                    </#if>
                </#list>
                <#list latestRunsDG as r>
                    <#if (pickedUris?size < runSlots) && !pickedUris?seq_contains(r["run"])>
                        <#assign pickedUris = pickedUris + [r["run"]]>
                    </#if>
                </#list>
                <#assign runRows = []>
                <#assign emittedUris = []>
                <#list latestRunsDG as r>
                    <#if pickedUris?seq_contains(r["run"]) && !emittedUris?seq_contains(r["run"])>
                        <#assign emittedUris = emittedUris + [r["run"]]>
                        <#assign runRows = runRows + [r]>
                    </#if>
                </#list>

                <#-- Energy-per-run mini chart (chronological, CSS bars scaled to the largest run) -->
                <#assign maxE = 0>
                <#list runRows as r>
                    <#if r["energy"]?? && r["energy"]?has_content>
                        <#assign ev = r["energy"]?number>
                        <#if (ev > maxE)><#assign maxE = ev></#if>
                    </#if>
                </#list>
                <#if (maxE > 0)>
                <div class="f-panel" style="margin-top:14px; padding:14px 18px;">
                    <div style="font-weight:600; color:#23395d; margin-bottom:8px;">Energy per run</div>
                    <#list runRows?reverse as r>
                        <#if r["energy"]?? && r["energy"]?has_content>
                            <#assign ev = r["energy"]?number>
                            <div class="f-chart-row">
                                <div class="f-chart-label"><#if r["start"]?? && r["start"]?has_content>${r["start"]?substring(0,16)?replace("T", " ")}<#else>run</#if></div>
                                <div class="f-chart-track"><a href="${urls.base}/individual?uri=${r["run"]?url}" title="${r["runLabel"]!""}"><div class="f-chart-bar" style="width:${((ev/maxE)*100)?string("0")}%;"></div></a></div>
                                <div class="f-chart-val">${fondaEnergy(ev)}</div>
                            </div>
                        </#if>
                    </#list>
                </div>
                </#if>

                <div class="f-cards" style="margin-top:14px;">
                    <#list runRows as row>
                    <div class="f-run-card">
                        <a href="${urls.base}/individual?uri=${row["run"]?url}" style="font-weight:600;">${row["runLabel"]!row["run"]}</a>
                        <div style="margin-top:10px;">
                            <#if row["energy"]?? && row["energy"]?has_content><span class="f-badge f-badge-green">&#9889; ${fondaEnergy(row["energy"]?number)}</span></#if>
                            <#if row["co2"]?? && row["co2"]?has_content><span class="f-badge f-badge-amber">&#127807; ${fondaCarbon(row["co2"]?number)}</span></#if>
                            <#if row["cluster"]?? && row["cluster"]?has_content><span style="font-size:0.85em; color:#666;">on <a href="${urls.base}/individual?uri=${row["cluster"]?url}" style="color:#444;">${row["clusterLabel"]!""}</a></span></#if>
                        </div>
                    </div>
                    </#list>
                </div>
                <ul style="margin-top:12px;">
                    <li><a href="${urls.base}/runs">View all runs ...</a></li>
                </ul>
            </section>
        </div>
    </div>
</div>
</#if>

<#-- FONDA 2026-10-15: statistics row - each number stays on one line with its word (e.g. "145 publication sources");
     when the row is too narrow, whole items move to the next line -->
<style>
    body #home-stats #stats > li { flex: 1 0 auto !important; white-space: nowrap !important; }
    body #home-stats #stats > li a, body #home-stats #stats p { white-space: nowrap !important; }
</style>
<!-- FONDA: Statistics row. Shows populated classgroups except locations & infrastructure. -->
<!-- "research" is displayed as "publications". Each stat links to its browse page.        -->
<div class="row research-count">
    <div class="container">
        <div class="col-md-12">
            <section id="home-stats" class="home-sections" >
                <h4>${i18n().statistics}</h4>
                <ul id="stats">
                    <#assign statHidden = ["locations", "infrastructure", "equipment", "courses", "domains", "publication sources"]>
                    <#assign statLabels = {"research": "publications", "people": "researchers"}>
                    <#assign statLinks  = {"subprojects": "/subprojects", "people": "/people", "organizations": "/organizations", "research": "/publications", "publications": "/publications", "workflows": "/workflows", "runs": "/runs", "domains": "/workflows", "venues": "/venues", "publication sources": "/sources", "events": "/events"}>
                    <#assign statOrder  = ["subprojects", "people", "organizations", "research", "workflows", "runs"]>
                    <#macro statItem group gname>
                            <li>
                                <a href="${urls.base}${statLinks[gname]!"/browse"}">
                                    <p class="stats-count">${group.individualCount}<span>&nbsp;</span></p>
                                    <p class="stats-type">${(statLabels[gname]!gname)?capitalize}</p>
                                </a>
                            </li>
                    </#macro>
                    <#-- collect groups by lowercase name -->
                    <#assign groupsByName = {}>
                    <#list vClassGroups! as g>
                        <#assign groupsByName = groupsByName + {g.displayName?lower_case: g}>
                    </#list>
                    <#-- fixed order first -->
                    <#list statOrder as key>
                        <#if groupsByName[key]?? && (groupsByName[key].individualCount > 0)>
                            <@statItem groupsByName[key] key />
                        </#if>
                    </#list>
                    <#-- then any other populated, non-hidden groups -->
                    <#list vClassGroups! as group>
                        <#assign gname = group.displayName?lower_case>
                        <#if (group.individualCount > 0) && !statHidden?seq_contains(gname) && !statOrder?seq_contains(gname)>
                            <@statItem group gname />
                        </#if>
                    </#list>
                </ul>
            </section>
        </div>
    </div>
</div>

<#include "footer.ftl">
        <#-- builds a json object that is used by js to render the academic departments section -->
        <@lh.listAcademicDepartments />
    <script>
        var i18nStrings = {
            researcherString: '${i18n().researcher?js_string}',
            researchersString: '${i18n().researchers?js_string}',
            currentlyNoResearchers: '${i18n().currently_no_researchers?js_string}',
            countriesAndRegions: '${i18n().countries_and_regions?js_string}',
            countriesString: '${i18n().countries?js_string}',
            regionsString: '${i18n().regions?js_string}',
            statesString: '${i18n().map_states_string?js_string}',
            stateString: '${i18n().map_state_string?js_string}',
            statewideLocations: '${i18n().statewide_locations?js_string}',
            researchersInString: '${i18n().researchers_in?js_string}',
            inString: '${i18n().in?js_string}',
            noFacultyFound: '${i18n().no_faculty_found?js_string}',
            placeholderImage: '${i18n().placeholder_image?js_string}',
            viewAllFaculty: '${i18n().view_all_faculty?js_string}',
            viewAllString: '${i18n().view_all?js_string}',
            viewAllDepartments: '${i18n().view_all_departments?js_string}',
            noDepartmentsFound: '${i18n().no_departments_found?js_string}'
        };
        // set the 'limmit search' text and alignment
        if  ( $('input.search-homepage').css('text-align') == "right" ) {
             $('input.search-homepage').attr("placeholder","${i18n().limit_search} →");
        }
    </script>
<#-- FONDA 2026-10-15: the search field keeps its colours when a word is picked from the browser's list of earlier
     searches. The browser's white "filled in" colour is held back, so the field looks as before. Styles only. -->
<style>
    input[name="querytext"]:-webkit-autofill {
        transition: background-color 0s 600000s, color 0s 600000s !important; }
    input[name="querytext"]:autofill {
        transition: background-color 0s 600000s, color 0s 600000s !important; }
</style>

<#-- FONDA 2026-10-15 (3): one search bar on the home page. The category list and the search field share one rounded
     box with a thin divider; the arrow sits right after the chosen word (the list is as wide as that word); the
     search button is a magnifier inside the bar; the whole bar lights up while typing. Light mode: white bar;
     dark mode: dark bar. Styles and a small width script only; the form, its fields and the search are unchanged. -->
<style>
    #search-homepage#search-homepage fieldset {
        display: flex !important; align-items: center !important; gap: 0 !important; height: 46px !important;
        box-sizing: border-box !important; margin: 0 !important; padding: 0 !important; min-width: 0 !important;
        background: #ffffff !important; border: 1px solid #c7d1dc !important; border-radius: 10px !important;
        box-shadow: 0 2px 12px rgba(10, 30, 60, .18) !important; transition: border-color .15s, box-shadow .15s; }
    #search-homepage#search-homepage fieldset:focus-within {
        border-color: #064d68 !important; box-shadow: 0 0 0 3px rgba(6, 77, 104, .18), 0 2px 12px rgba(10, 30, 60, .18) !important; }
    #search-homepage#search-homepage .form-group {
        margin: 0 !important; padding: 0 !important; float: none !important; }
    #search-homepage#search-homepage .form-group.pull-left { flex: 0 0 auto !important; max-width: 55% !important; }
    #search-homepage#search-homepage .form-group:not(.pull-left) { flex: 1 1 auto !important; min-width: 0 !important; }
    #search-homepage#search-homepage .input-group { display: flex !important; align-items: center !important; width: 100% !important; }
    #search-homepage#search-homepage select#classgroup {
        -webkit-appearance: none !important; appearance: none !important; display: block !important;
        width: auto; min-width: 0 !important; max-width: 100% !important; height: 30px !important;
        margin: 0 !important; padding: 0 32px 0 16px !important; line-height: 30px !important;
        font-family: inherit !important; font-size: 15px !important; font-weight: 500 !important;
        color: #1f2d3d !important; cursor: pointer; text-overflow: ellipsis;
        border: 0 !important; border-right: 1px solid #dbe2ea !important; border-radius: 0 !important; box-shadow: none !important;
        background: #ffffff url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' viewBox='0 0 12 8'%3E%3Cpath d='M1 1.5l5 5 5-5' fill='none' stroke='%235c6b7c' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E") no-repeat right 12px center / 12px 8px !important; }
    #search-homepage#search-homepage select#classgroup option { background: #ffffff; color: #1f2d3d; }
    #search-homepage#search-homepage input[name="querytext"] {
        flex: 1 1 auto !important; float: none !important; width: auto !important; min-width: 0 !important;
        height: 44px !important; margin: 0 !important; padding: 0 10px 0 14px !important; line-height: 44px !important;
        font-family: inherit !important; font-size: 15px !important; color: #1f2d3d !important;
        background: transparent !important; border: 0 !important; border-radius: 0 !important; box-shadow: none !important; outline: 0 !important; }
    #search-homepage#search-homepage input[name="querytext"]::placeholder { color: #7b8794 !important; opacity: 1; }
    #search-homepage#search-homepage .input-group-btn { display: flex !important; align-items: center !important; width: auto !important; }
    #search-homepage#search-homepage .input-group-btn .btn {
        width: 36px !important; height: 36px !important; margin: 0 5px 0 0 !important; padding: 0 !important;
        border: 0 !important; border-radius: 6px !important; box-shadow: none !important; text-shadow: none !important;
        background: transparent url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%235c6b7c' stroke-width='2.2' stroke-linecap='round'%3E%3Ccircle cx='10.5' cy='10.5' r='6.5'/%3E%3Cline x1='15.5' y1='15.5' x2='21' y2='21'/%3E%3C/svg%3E") no-repeat center / 18px 18px !important; }
    #search-homepage#search-homepage .input-group-btn .btn:hover,
    #search-homepage#search-homepage .input-group-btn .btn:focus { background-color: #eef2f6 !important; }
    #search-homepage#search-homepage .input-group-btn .btn .icon-search {
        position: absolute !important; width: 1px !important; height: 1px !important; overflow: hidden !important;
        clip: rect(0 0 0 0) !important; white-space: nowrap !important; }

    html.dark-mode #search-homepage#search-homepage fieldset {
        background: rgba(20, 28, 44, .85) !important; border-color: #3a4f6d !important; box-shadow: 0 0 16px rgba(90, 150, 220, .24) !important; }
    html.dark-mode #search-homepage#search-homepage fieldset:focus-within {
        border-color: #5d7aa5 !important; box-shadow: 0 0 0 3px rgba(93, 140, 205, .25), 0 0 18px rgba(90, 150, 220, .3) !important; }
    html.dark-mode #search-homepage#search-homepage select#classgroup {
        color: #e6edf5 !important; border-right-color: #3a4f6d !important;
        background: transparent url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' viewBox='0 0 12 8'%3E%3Cpath d='M1 1.5l5 5 5-5' fill='none' stroke='%23aab6c6' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E") no-repeat right 12px center / 12px 8px !important; }
    html.dark-mode #search-homepage#search-homepage select#classgroup option { background: #151c2c; color: #e6edf5; }
    html.dark-mode #search-homepage#search-homepage input[name="querytext"] { color: #e6edf5 !important; }
    html.dark-mode #search-homepage#search-homepage input[name="querytext"]::placeholder { color: #8d96a6 !important; }
    html.dark-mode #search-homepage#search-homepage .input-group-btn .btn {
        background: transparent url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23aab6c6' stroke-width='2.2' stroke-linecap='round'%3E%3Ccircle cx='10.5' cy='10.5' r='6.5'/%3E%3Cline x1='15.5' y1='15.5' x2='21' y2='21'/%3E%3C/svg%3E") no-repeat center / 18px 18px !important; }
    html.dark-mode #search-homepage#search-homepage .input-group-btn .btn:hover,
    html.dark-mode #search-homepage#search-homepage .input-group-btn .btn:focus { background-color: rgba(127, 192, 221, .14) !important; }

    /* phones: the form reaches the screen edges there, so the bar keeps a small gap to them */
    @media (max-width: 480px) {
        #search-homepage#search-homepage fieldset { margin: 0 10px !important; }
        #search-homepage#search-homepage select#classgroup { padding-left: 12px !important; font-size: 14px !important; }
        #search-homepage#search-homepage input[name="querytext"] { font-size: 14px !important; }
    }
</style>
<script>
    /* the category list gets the width of the chosen word, so the arrow sits right after it */
    (function () {
        var sel = document.getElementById('classgroup');
        if (!sel || !document.getElementById('search-homepage')) { return; }
        function fit() {
            var o = sel.options[sel.selectedIndex];
            if (!o) { return; }
            var cs = window.getComputedStyle(sel);
            var c = fit.ctx || (fit.ctx = document.createElement('canvas').getContext('2d'));
            c.font = cs.fontStyle + ' ' + cs.fontWeight + ' ' + cs.fontSize + ' ' + cs.fontFamily;
            var w = c.measureText(o.text).width + parseFloat(cs.paddingLeft) + parseFloat(cs.paddingRight)
                    + parseFloat(cs.borderLeftWidth) + parseFloat(cs.borderRightWidth);
            sel.style.setProperty('width', Math.ceil(w + 2) + 'px', 'important');
        }
        fit();
        if (document.fonts && document.fonts.ready) { document.fonts.ready.then(fit); }
        sel.addEventListener('change', fit);
        window.addEventListener('pageshow', fit);
    })();
</script>

    </body>
</html>
