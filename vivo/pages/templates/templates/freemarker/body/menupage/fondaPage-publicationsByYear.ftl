<#-- FONDA: publications grouped by year, newest first.
     Body template for the Page Management page "Publications by Year"
     (content type: SPARQL Query Results, custom template).
     Expects query variables: ?pub ?pubLabel ?year
     (NB: do not use ?title in the query - the data getter substitutes the
     page title into it!)  -->

<#assign resultsExist = false/>
<#if variableName?has_content>
    <#assign resultsExist = true/>
    <#assign rows = .globals[variableName]/>
</#if>

<#if resultsExist && rows?has_content>
    <p style="margin:4px 0 16px 2px;"><a href="${urls.base}/publications">&#8592; Publications by type</a>
       &nbsp;&middot;&nbsp; <a href="${urls.base}/sources">Publication Sources</a></p>
    <#assign lastYear = "">
    <#list rows as row>
        <#assign y = row["year"]!"undated">
        <#if y != lastYear>
            <#if lastYear != ""></ul></#if>
            <h3 style="margin:20px 0 6px 0; color:#23395d;">${y}</h3>
            <ul style="list-style:none; padding:0; margin:0;">
            <#assign lastYear = y>
        </#if>
        <li style="padding:7px 2px; border-bottom:1px solid #eceff3;">
            <a href="${urls.base}/individual?uri=${row["pub"]?url}">${row["pubLabel"]!row["pub"]}</a>
        </li>
    </#list>
    </ul>
<#else>
    <p>${i18n().no_results_returned}</p>
</#if>
