<#-- FONDA person layout; site administrators retain the complete original editor. -->
<#if (visRequestingTemplate!"") == "foaf-person-tenderfoot" && !((user.hasSiteAdminAccess)!false)>
    <#include "individual-person-editor-tabs.ftl">
<#else>
<#-- $This file is distributed under the terms of the license in /doc/license.txt$ -->

<#-- Template for property listing on individual profile page -->

<#import "lib-properties.ftl" as p>
<#assign subjectUri = individual.controlPanelUrl()?split("=") >
<#assign tabCount = 1 >
<#assign sectionCount = 1 >

<div class="row">
    <div class="col-md-12">
        <ul class="nav nav-tabs">
		<#list propertyGroups.all as groupTabs>
			<#if ( groupTabs.properties?size > 0 ) >
				<#assign groupName = groupTabs.getName(nameForOtherGroup)>
				<#if groupName?has_content>
					<#--the function replaces spaces in the name with underscores, also called for the property group menu-->
					<#assign groupNameHtmlId = p.createPropertyGroupHtmlId(groupName) >
				<#else>
					<#assign groupName = "${i18n().properties_capitalized}">
					<#assign groupNameHtmlId = "${i18n().properties}" >
				</#if>
				<#if tabCount = 1 >
                    <li data-toggle="tab" groupName="${groupNameHtmlId?replace("/","-")}" class="active" href="#${groupNameHtmlId?replace("/","-")}Group"><a href="#">${groupName?capitalize}</a></li>
					<#assign tabCount = 2>
				<#else>
                    <li data-toggle="tab" groupName="${groupNameHtmlId?replace("/","-")}" href="#${groupNameHtmlId?replace("/","-")}Group"><a href="#">${groupName?capitalize}</a></li>
				</#if>
			</#if>
		</#list>
		<#if (propertyGroups.all?size > 1) >
            <li id="viewAllTab" data-toggle="tab" groupName="viewAll" href="#viewAll"><a href="#">${i18n().view_all_capitalized}</a></li>
		</#if>
        </ul>
    </div>
</div>
<div class="row">
    <div class="col-md-12 tab-content">
		<#list propertyGroups.all as group>
			<#if (group.properties?size > 0)>
				<#assign groupName = group.getName(nameForOtherGroup)>
				<#assign groupNameHtmlId = p.createPropertyGroupHtmlId(groupName) >
				<#assign verbose = (verbosePropertySwitch.currentValue)!false>

                <div id="${groupNameHtmlId?replace("/","-")}Group"
                     class="tab-pane <#if (sectionCount == 1) >active</#if>"
                     role="tabpanel">
					<#-- Display the group heading -->
					<#if groupName?has_content>
						<#--the function replaces spaces in the name with underscores, also called for the property group menu-->
						<#assign groupNameHtmlId = p.createPropertyGroupHtmlId(groupName) >
                        <h2 id="${groupNameHtmlId?replace("/","-")}" pgroup="tabs" class="hidden">${groupName?capitalize}</h2>
					<#else>
                        <h2 id="properties" pgroup="tabs" class="hidden">${i18n().properties_capitalized}</h2>
					</#if>
					<#-- List the properties in the group   -->
					<#include "individual-properties.ftl">
                </div>
				<#assign sectionCount = 2 >
			</#if>
		</#list>
    </div>
</div>
<script>
    var individualLocalName = "${individual.localName}";
</script>

${stylesheets.add('<link rel="stylesheet" href="${urls.base}/css/individual/individual-property-groups.css" />')}
${headScripts.add('<script type="text/javascript" src="${urls.base}/js/amplify/amplify.store.min.js"></script>')}
${scripts.add('<script src="${urls.theme}/js/propertyGroupControls-bootstrap.js"></script>')}
${scripts.add('<script src="${urls.theme}/js/long-value-clamp.js?v=5"></script>')}
${scripts.add('<script src="${urls.theme}/js/round-decimals.js?v=1"></script>')}

</#if>

<#-- FONDA 2026-10-15: every "... more" / "less" under a list looks like the one under long texts (dark blue text in a
     light grey-blue box, 14px), also in dark mode. Styles only, added at the end; the lines above are unchanged. -->
<style>
    body article.property a.more-less:not(.f-clamp-toggle) {
        display: inline-block; margin: 2px 0 12px 0; padding: 4px 12px; border-radius: 4px;
        background: #eceff3; color: #23395d; font-size: 14px; text-decoration: none; }
    body article.property a.more-less:not(.f-clamp-toggle):hover,
    body article.property a.more-less:not(.f-clamp-toggle):focus { background: #dfe4ea; color: #23395d; text-decoration: none; }
    html.dark-mode body article.property a.more-less:not(.f-clamp-toggle) { background: #1f2a3d; color: #7fc0dd; }
    html.dark-mode body article.property a.more-less:not(.f-clamp-toggle):hover,
    html.dark-mode body article.property a.more-less:not(.f-clamp-toggle):focus { background: #273349; color: #7fc0dd; }
</style>

<#-- FONDA 2026-10-15 (3): the "... more" under "selected publications" is a button of the person tabs (class
     fonda-publication-more), not a link, so the lines above did not reach it. It gets the same look as the other
     "... more": dark blue text in a light grey-blue box, 14px, also in dark mode. Styles only, added at the end. -->
<style>
    body .fonda-person-tabs button.fonda-publication-more {
        display: inline-block; margin: 2px 0 12px 0; padding: 4px 12px; border: 0; border-radius: 4px;
        background: #eceff3; color: #23395d; font-size: 14px; width: auto; justify-self: start; }
    body .fonda-person-tabs button.fonda-publication-more:hover,
    body .fonda-person-tabs button.fonda-publication-more:focus { background: #dfe4ea; color: #23395d; }
    html.dark-mode body .fonda-person-tabs button.fonda-publication-more { background: #1f2a3d; color: #7fc0dd; }
    html.dark-mode body .fonda-person-tabs button.fonda-publication-more:hover,
    html.dark-mode body .fonda-person-tabs button.fonda-publication-more:focus { background: #273349; color: #7fc0dd; }
</style>

<#-- FONDA 2026-10-15: "Find on this page" at the right end of the tabs (fonda-page-find.ftl) -->
<#attempt><#include "fonda-page-find.ftl"><#recover></#attempt>
