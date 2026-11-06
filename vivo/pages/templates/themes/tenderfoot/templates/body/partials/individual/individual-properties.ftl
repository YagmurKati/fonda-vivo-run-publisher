<#-- $This file is distributed under the terms of the license in LICENSE$ -->

<#-- Template for property listing on individual profile page -->

		<#list group.properties as property>
		    <#assign rangeClass = "noRangeClass">
            <#if property.rangeUri?has_content && property.rangeUri?contains("#")>
                <#assign rangeClass = property.rangeUri?substring(property.rangeUri?last_index_of("#")+1)>
		    <#elseif property.rangeUri?has_content >
		        <#assign rangeClass = property.rangeUri?substring(property.rangeUri?last_index_of("/")+1)>
		    </#if>
		    <#assign hideEmptyLegacyResearcher =
		        individual.uri?starts_with("http://example.org/vivo-import/run-metadata/")
		        && property.localName == "responsibleResearcher"
		        && property.type == "data"
		        && !property.statements?has_content>

		    <#if !hideEmptyLegacyResearcher>
		    <article class="property" role="article">
                <#-- Property display name -->
                <#if rangeClass == "Authorship" && individual.editable && (property.domainUri)?? && property.domainUri?contains("Person")>
                    <h3 id="${property.localName}-${rangeClass}" title="${property.publicDescription!}">${property.name}
                        <#-- Use the guided form for the permitted publication-add action on compact editable person profiles. -->
                        <#if (fondaSimplifiedPersonEditor!false)
                            && property.uri == "http://vivoweb.org/ontology/core#relatedBy"
                            && property.addUrl?has_content>
                            <@p.showAddLink property.localName property.name "${urls.base}/fonda-publications?profileUri=${individual.uri?url('UTF-8')}" property.rangeUri property.domainUri />
                        <#else>
                            <@p.addLink property editable />
                        </#if>
                        <@p.verboseDisplay property />
<#if user.hasSiteAdminAccess><#-- FONDA: manage publications only for site admins -->
                        <a id="managePubLink" class="manageLinks" href="${urls.base}/managePublications?subjectUri=${subjectUri[1]!}" title="${i18n().manage_publications_link}" <#if verbose>style="padding-top:10px"</#if> >
                            ${i18n().manage_publications_link}
                        </a>
</#if>
                    </h3>
                <#elseif rangeClass == "ResearcherRole" && individual.editable  >
                    <h3 id="${property.localName}-${rangeClass}" title="${property.publicDescription!}">${property.name} <@p.addLink property editable /> <@p.verboseDisplay property />
                        <a id="manageGrantLink" class="manageLinks" href="${urls.base}/manageGrants?subjectUri=${subjectUri[1]!}" title="${i18n().manage_grants_and_projects_link}" <#if verbose>style="padding-top:10px"</#if> >
                            ${i18n().manage_grants_and_projects_link}
                        </a>
                    </h3>
                <#elseif rangeClass == "Position" && individual.editable  >
                    <h3 id="${property.localName}-${rangeClass}" title="${property.publicDescription!}">${property.name} <@p.addLink property editable /> <@p.verboseDisplay property />
                        <a id="managePeopleLink" class="manageLinks" href="${urls.base}/managePeople?subjectUri=${subjectUri[1]!}" title="${i18n().manage_affiliated_people}" <#if verbose>style="padding-top:10px"</#if> >
                            ${i18n().manage_affiliated_people_link}
                        </a>
                    </h3>
                <#elseif rangeClass == "Name" && property.statements?has_content && editable >
                    <h3 id="${property.localName}" title="${property.publicDescription!}">${property.name}  <@p.verboseDisplay property /> </h3>
                <#elseif rangeClass == "Title" && property.statements?has_content && editable >
                    <h3 id="${property.localName}" title="${property.publicDescription!}">${property.name}  <@p.verboseDisplay property /> </h3>
				<#elseif rangeClass == "Authorship" && !individual.editable && (property.domainUri)?? && property.domainUri?contains("Person")>
					<h3 id="${property.localName}-${rangeClass}" title="${property.publicDescription!}">${property.name} <@p.addLink property editable /> <@p.verboseDisplay property /> </h3>
				<#elseif rangeClass == "ResearcherRole" && !individual.editable>
					<h3 id="${property.localName}-${rangeClass}" title="${property.publicDescription!}">${property.name} <@p.addLink property editable /> <@p.verboseDisplay property /> </h3>
				<#else>
                    <h3 id="${property.localName}" title="${property.publicDescription!}">${property.name} <@p.addLink property editable /> <@p.verboseDisplay property /> </h3>
                </#if>
                <#if (fondaSimplifiedPersonEditor!false) && (property.rangeUri!"") == "http://vivoweb.org/ontology/core#EducationalProcess">
                    <p class="fonda-field-hint">Record each degree separately: institution, degree (Bachelor’s, Master’s or PhD), subject, and start/end years. Use “Major field” for the subject.</p>
                </#if>
                <#-- List the statements for each property -->
					<#assign limit = property.getDisplayLimit()!5 />
					<#if limit == -1 || limit == 0 >
						<#assign limit = 5 />
					</#if>
                <#-- FONDA: keep workflow runs compact on personal pages. -->
                <#if (visRequestingTemplate!"") == "foaf-person-tenderfoot"
                    && property.uri == "http://example.org/ontology/run-metadata#runOperatorOf">
                    <#assign limit = 1 />
                </#if>
                <#-- The compact person layout uses one accessible overall publication preview. -->
                <#if (fondaCompactPersonProfile!false) && rangeClass == "Authorship">
                    <#assign limit = "999999" />
                </#if>
                <ul class="property-list" role="list" id="${property.localName}-${rangeClass}-List" displayLimit="${limit}">
                    <#-- data property -->
                    <#if property.type == "data">
                        <@p.dataPropertyList property editable />
                    <#-- object property -->
                    <#else>
                        <@p.objectProperty property editable />
                    </#if>
                </ul>
		    </article> <!-- end property -->
		    </#if>
		</#list>
