<#-- $This file is distributed under the terms of the license in LICENSE$ -->

<#-- FONDA 2026-10-11: statement view for rm:runOperatorOf ("workflow runs" on person pages), list view
     listViewConfig-fondaRunWorkflows.xml: one line per workflow with the number of runs and the latest date,
     e.g. "Event query discovery from Google cluster traces  5 runs, latest 2026-10-03".

     This template must be self-contained and not rely on other variables set for the individual page, because it
     is also used to generate the property statement during a deletion.
-->

<@showStatement statement />

<#macro showStatement statement>
    <#local n = (statement.runCount!"0")?trim />
    <#local latest = (statement.latest!"")?trim />
    <a href="${profileUrl(statement.uri("object"))}" title="${i18n().name}">${statement.label!statement.localName!}</a><#if n?has_content && n != "0">&nbsp; ${n} <#if n == "1">run<#else>runs</#if><#if latest?has_content>, latest ${latest}</#if></#if>
</#macro>
