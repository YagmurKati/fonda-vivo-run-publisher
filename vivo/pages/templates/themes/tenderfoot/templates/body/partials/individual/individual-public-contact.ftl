<#-- Public person contact details: render the existing permitted property objects once. -->
<#import "lib-properties.ftl" as p>
<#assign fondaContactProperties = fondaPublicContactProperties![]>
<#if fondaContactProperties?has_content>
    <#assign fondaContactOrdered = []>
    <#assign fondaContactOrder = ["primary email", "phone", "webpage", "orcid id", "additional emails", "mailing address", "geographic location", "researcherid", "scopus id"]>
    <#list fondaContactOrder as field>
        <#list fondaContactProperties as property>
            <#if (property.name!"")?lower_case?trim == field><#assign fondaContactOrdered = fondaContactOrdered + [property]></#if>
        </#list>
    </#list>
    <#list fondaContactProperties as property>
        <#if !fondaContactOrder?seq_contains((property.name!"")?lower_case?trim)><#assign fondaContactOrdered = fondaContactOrdered + [property]></#if>
    </#list>
    <style>
        #wrapper-content .fonda-public-contact { margin: 18px 0 16px; }
        #wrapper-content .fonda-public-contact > h2 { margin: 0 0 8px; padding: 0; font-size: 14px; line-height: 1.4; font-weight: 600; color: #526476; }
        #wrapper-content .fonda-public-contact-field { margin: 0 0 10px; }
        #wrapper-content .fonda-public-contact-field > h3 { margin: 0 0 2px; padding: 0; font-size: 13px; line-height: 1.4; font-weight: 600; color: #647487; }
        #wrapper-content .fonda-public-contact-values,
        #wrapper-content .fonda-public-contact-values > li { margin: 0; padding: 0; list-style: none; font-size: 15px; line-height: 1.45; overflow-wrap: anywhere; }
        #wrapper-content .fonda-public-contact-values a { font-size: inherit; line-height: inherit; }
        html.dark-mode #wrapper-content .fonda-public-contact > h2,
        html.dark-mode #wrapper-content .fonda-public-contact-field > h3 { color: #b6c7d8; }
    </style>
    <section id="ContactGroup" class="fonda-public-contact" aria-labelledby="fonda-public-contact-heading">
        <h2 id="fonda-public-contact-heading">${i18n().contact_info}</h2>
        <#list fondaContactOrdered as property>
            <#assign field = (property.name!"")?lower_case?trim>
            <#assign label = property.name!"">
            <#if field == "primary email"><#assign label = "Email">
            <#elseif field == "phone"><#assign label = "Phone">
            <#elseif field == "webpage"><#assign label = "Websites">
            <#elseif field == "additional emails"><#assign label = "Additional emails">
            <#elseif field != "orcid id" && field != "researcherid" && field != "scopus id"><#assign label = label?capitalize>
            </#if>
            <div class="fonda-public-contact-field">
                <h3 id="fonda-contact-${property?index}-label">${label?html}</h3>
                <ul class="fonda-public-contact-values" id="fonda-contact-${property?index}-values" aria-labelledby="fonda-contact-${property?index}-label">
                    <#if (field == "primary email" || field == "additional emails") && (property.statements![])?has_content && property.statements[0].emailAddress??>
                        <#list property.statements as statement><li><a itemprop="email" href="mailto:${statement.emailAddress!?html}">${statement.emailAddress!?html}</a></li></#list>
                    <#elseif field == "phone" && (property.statements![])?has_content && property.statements[0].number??>
                        <#list property.statements as statement><li><span itemprop="telephone">${statement.number!?html}</span></li></#list>
                    <#elseif property.type == "data"><@p.dataPropertyList property false />
                    <#else><@p.objectProperty property false />
                    </#if>
                </ul>
            </div>
        </#list>
    </section>
</#if>
