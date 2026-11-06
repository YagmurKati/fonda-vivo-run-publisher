<#-- $This file is distributed under the terms of the license in LICENSE$ -->

<#-- FONDA 2026-10-04: statement view for vivo:subjectAreaOf, the "publications" list on subproject
     pages (list view listViewConfig-fondaSubjectAreaOf.xml, which sorts newest first).
     Same line as VIVO's propStatement-default.ftl, followed by the publication year when there is one.

     This template must be self-contained and not rely on other variables set for the individual page, because it
     is also used to generate the property statement during a deletion.
-->

<#import "lib-meta-tags.ftl" as lmt>

<@showStatement statement />

<#macro showStatement statement>
    <#-- Post-processing removes all but one row per object. -->
    <#if statement.subclass??>
        <a href="${profileUrl(statement.uri("object"))}" title="${i18n().name}">${statement.label!statement.localName!}</a>
    <#else>
        <a href="${profileUrl(statement.uri("object"))}" title="${i18n().name}">${statement.label!statement.localName!}</a>&nbsp; ${statement.title!statement.type!}
    </#if>
    <#-- FONDA: the year, taken from the first four characters of the date -->
    <#local dateTime = statement.dateTime!"" />
    <#if dateTime?matches("\\d{4}.*")>
        <span class="listDateTime">${dateTime?substring(0, 4)}</span>
    </#if>
    <@lmt.addCitationMetaTag uri=(statement.specificObjectType) content=(statement.label!) />
</#macro>
