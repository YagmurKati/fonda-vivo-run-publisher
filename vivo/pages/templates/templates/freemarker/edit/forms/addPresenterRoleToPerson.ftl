<#-- $This file is distributed under the terms of the license in LICENSE$ -->

<#-- this is in request.subject.name -->

<#-- leaving this edit/add mode code in for reference in case we decide we need it -->

<#import "lib-vivo-form.ftl" as lvf>

<#--Retrieve certain edit configuration information-->
<#if editConfiguration.objectUri?has_content>
    <#assign editMode = "edit">
<#else>
    <#assign editMode = "add">
</#if>

<#assign blankSentinel = "" />
<#if editConfigurationConstants?has_content && editConfigurationConstants?keys?seq_contains("BLANK_SENTINEL")>
	<#assign blankSentinel = editConfigurationConstants["BLANK_SENTINEL"] />
</#if>

<#--This flag is for clearing the label field on submission for an existing object being selected from autocomplete.
Set this flag on the input acUriReceiver where you would like this behavior to occur. -->
<#assign flagClearLabelForExisting = "flagClearLabelForExisting" />


<#assign htmlForElements = editConfiguration.pageData.htmlForElements />

<#--Retrieve variables needed-->
<#assign existingPresentationValue = lvf.getFormFieldValue(editSubmission, editConfiguration, "existingPresentation") />
<#assign presentationLabelValue = lvf.getFormFieldValue(editSubmission, editConfiguration, "presentationLabel") />
<#assign presentationLabelDisplayValue = lvf.getFormFieldValue(editSubmission, editConfiguration, "presentationLabelDisplay") />
<#assign presentationTypeValue = lvf.getFormFieldValue(editSubmission, editConfiguration, "presentationType") />
<#assign roleLabelValue = lvf.getFormFieldValue(editSubmission, editConfiguration, "roleLabel") />
<#assign eventTypeValue = lvf.getFormFieldValue(editSubmission, editConfiguration, "eventType") />
<#if !eventTypeValue?has_content><#assign eventTypeValue = "http://purl.org/NET/c4dm/event.owl#Event"></#if>
<#assign conferenceValue = lvf.getFormFieldValue(editSubmission, editConfiguration, "existingConference") />
<#assign conferenceLabelValue = lvf.getFormFieldValue(editSubmission, editConfiguration, "conferenceLabel") />
<#assign conferenceLabelDisplayValue = lvf.getFormFieldValue(editSubmission, editConfiguration, "conferenceLabelDisplay") />

<#--If edit submission exists, then retrieve validation errors if they exist-->
<#if editSubmission?has_content && editSubmission.submissionExists = true && editSubmission.validationErrors?has_content>
	<#assign submissionErrors = editSubmission.validationErrors/>
</#if>

<#if editMode == "edit">
        <#assign titleVerb="${i18n().edit_capitalized}">
        <#assign submitButtonText="${i18n().save_changes}">
        <#assign disabledVal="disabled">
<#else>
        <#assign titleVerb="${i18n().create_capitalized}">
        <#assign submitButtonText="${i18n().create_entry}">
        <#assign disabledVal=""/>
</#if>

<#assign requiredHint = "<span class='requiredHint'> *</span>" />
<#assign yearHint     = "<span class='hint'>(${i18n().year_hint_format})</span>" />

<h2>${titleVerb}&nbsp;${i18n().presentation_entry_for} ${editConfiguration.subjectName}</h2>
<#if editMode == "add">
<p>Add a talk, demo, or other presentation. No DOI or accompanying publication is required. Choose a type, enter the title, and select the event. This presentation will be linked to your profile. Reuse an existing title or event when it is already listed.</p>
<details style="margin: 12px 0 20px;"><summary>Poster with a DOI?</summary>
<p>A standalone talk, demo, or poster presentation needs no publication entry. If you also have a published poster file, with or without a DOI, you can add that material through <strong>Add / manage publications</strong> and choose <strong>Poster</strong>. Use this form for the presentation at an event.</p>
</details>
</#if>

<#--Display error messages if any-->
<#if submissionErrors?has_content>
    <#if conferenceLabelDisplayValue?has_content >
        <#assign conferenceLabelValue = conferenceLabelDisplayValue />
    </#if>
    <#if presentationLabelDisplayValue?has_content >
        <#assign presentationLabelValue = presentationLabelDisplayValue />
    </#if>
    <section id="error-alert" role="alert">
        <img src="${urls.images}/iconAlert.png" width="24" height="24" alert="${i18n().error_alert_icon}" />
        <p>
        <#--Checking if any required fields are empty-->
        <#if lvf.submissionErrorExists(editSubmission, "presentationType")>
 	        Please select a presentation type.
        </#if>
        <#if lvf.submissionErrorExists(editSubmission, "presentationLabel")>
 	        ${i18n().select_or_enter_name}
        </#if>
        <#list submissionErrors?keys as errorFieldName>
        	<#if errorFieldName == "startField">
        	    <#if submissionErrors[errorFieldName]?contains("before")>
        	        ${i18n().start_year_must_precede_end}
        	    <#else>
        	        ${submissionErrors[errorFieldName]}
        	    </#if>

        	<#elseif errorFieldName == "endField">
    	        <#if submissionErrors[errorFieldName]?contains("after")>
    	            ${i18n().end_year_must_be_later}
    	        <#else>
    	            ${submissionErrors[errorFieldName]}
    	        </#if>
            <#elseif errorFieldName == "eventType">${submissionErrors[errorFieldName]?html}
	        </#if><br />
        </#list>
        </p>
    </section>
</#if>

<@lvf.unsupportedBrowser urls.base />

<section id="addPresenterRoleToPerson" role="region">

    <form id="addPresenterRoleToPerson" class="customForm noIE67" action="${submitUrl}"  role="add/edit Presentation">
    <p class="inline">
      <label for="typeSelector">Presentation format<#if editMode != "edit"> ${requiredHint}<#else>:</#if></label>
      <#assign presentationTypeOpts = editConfiguration.pageData.presentationType />
      <select id="typeSelector" name="presentationType" acGroupName="presentation">
        <option value="" selected="selected">${i18n().select_one}</option>
        <#list presentationTypeOpts?keys as key>
            <option value="${key}" <#if presentationTypeValue = key>selected</#if>>${presentationTypeOpts[key]}</option>
        </#list>
    </select>
    <#if editMode == "add"><span class="hint" style="display:block;">Choose the format of your contribution. For a talk at a seminar, choose Talk or Invited talk; the seminar is the event. Record a whole course under teaching, rather than as one presentation.</span></#if>
    </p>

    <p>
        <label for="presentation">${i18n().presentation_name_capitalized} ${requiredHint}</label>
            <input class="acSelector" size="50"  type="text" id="presentation" acGroupName="presentation" name="presentationLabel" value="${presentationLabelValue}">
            <input class="display" type="hidden" id="presentationDisplay" acGroupName="presentation" name="presentationLabelDisplay" value="${presentationLabelDisplayValue}">
    </p>

    <div class="acSelection" acGroupName="presentation">
        <p class="inline">
            <label>${i18n().selected_presentation}:</label>
            <span class="acSelectionInfo"></span>
            <a href="" class="verifyMatch"  title="${i18n().verify_match_capitalized}">(${i18n().verify_match_capitalized}</a> ${i18n().or}
            <a href="#" class="changeSelection" id="changeSelection">${i18n().change_selection})</a>
        </p>
        <input class="acUriReceiver" type="hidden" id="presentationUri" name="existingPresentation" value="${existingPresentationValue}" ${flagClearLabelForExisting}="true" />
    </div>

    <p><label for="roleLabel">Your role (optional)</label><span class="hint" style="display:block;">Poster or demo: Presenter. Talk: Speaker. Change the suggestion if you were a moderator, panelist, or had another role.</span>
        <input  size="50"  type="text" id="roleLabel" name="roleLabel" value="${roleLabelValue}" />
    </p>
  <p>
      <label for="conference">Event (optional)</label>
      <input  class="acSelector" size="50" acGroupName="conference" type="text" id="conference" name="conferenceLabel" value="${conferenceLabelValue}" />
      <input  class="display" acGroupName="conference" type="hidden" id="conferenceDisplay" name="conferenceLabelDisplay" value="${conferenceLabelDisplayValue}" />
  </p>
  <div class="acSelection" acGroupName="conference">
      <p class="inline">
          <label>${i18n().selected_conference}:</label>
          <span class="acSelectionInfo"></span>
          <a href="" class="verifyMatch"  title="${i18n().verify_match_capitalized}">(${i18n().verify_match_capitalized}</a> ${i18n().or}
          <a href="#" class="changeSelection" id="changeSelection">${i18n().change_selection})</a>
      </p>
      <input class="acUriReceiver" type="hidden" id="conferenceUri" name="existingConference" value="${conferenceValue}" ${flagClearLabelForExisting}="true" />
  </div>
    <p>
        <label for="eventType">New event type</label>
        <select id="eventType" name="eventType">
            <#list editConfiguration.pageData.eventType?keys as key>
                <option value="${key?html}"<#if eventTypeValue == key> selected</#if>>${editConfiguration.pageData.eventType[key]?html}</option>
            </#list>
        </select>
        <span class="hint" style="display:block;">Used only when creating an event. Selecting an existing event keeps its recorded type.</span>
    </p>
    <fieldset class="fonda-presentation-dates">
        <legend>Presentation date(s) (optional)</legend>
        <p>For a one-day presentation, enter only the start date. Add an end date if the presentation itself spans several days. If the exact date is unknown, you can enter just the year.</p>
        <#assign htmlForElements = editConfiguration.pageData.htmlForElements />
        <#if htmlForElements?keys?seq_contains("startField")>
            <div class="fonda-presentation-date"><strong>Start date</strong>${htmlForElements["startField"]}</div>
        </#if>
        <#if htmlForElements?keys?seq_contains("endField")>
            <div class="fonda-presentation-date"><strong>End date</strong>${htmlForElements["endField"]}</div>
        </#if>
    </fieldset>
    <#if editMode == "add"><p>After saving, open the presentation title to add its website or other details.</p></#if>

    <input type="hidden" id="editKey" name="editKey" value="${editKey}"/>

    <p class="submit">
        <input type="submit" class="submit" value="${submitButtonText}"/><span class="or"> ${i18n().or} </span>
        <a class="cancel" href="${cancelUrl}" title="${i18n().cancel_title}">${i18n().cancel_link}</a>
    </p>

    <p id="requiredLegend" class="requiredHint">* ${i18n().required_fields}</p>

</form>

</section>


<script type="text/javascript">
var customFormData  = {
    acUrl: '${urls.base}/autocomplete?tokenize=true&stem=true',
    acTypes: {presentation: 'http://vivoweb.org/ontology/core#Presentation', conference: 'http://purl.org/NET/c4dm/event.owl#Event'},
    editMode: '${editMode}',
    defaultTypeName: 'presentation',
    multipleTypeNames: {presentation: 'presentation', conference: 'conference'},
    baseHref: '${urls.base}/individual?uri=',
    blankSentinel: '${blankSentinel}',
    flagClearLabelForExisting: '${flagClearLabelForExisting}'
};
var i18nStrings = {
    selectAnExisting: '${i18n().select_an_existing?js_string}',
    selectAnExistingOrCreateNewOne: '${i18n().select_an_existing_or_create_a_new_one?js_string}',
    selectedString: '${i18n().selected?js_string}'
};
</script>


<style>
#addPresenterRoleToPerson .fonda-presentation-dates { clear: both; border: 1px solid #aab8c7; border-radius: 6px; padding: 14px; margin: 20px 0; max-width: 740px; }
#addPresenterRoleToPerson .fonda-presentation-dates legend { width: auto; padding: 0 6px; margin-bottom: 0; font-size: 16px; font-weight: 600; }
#addPresenterRoleToPerson .fonda-presentation-date { margin: 14px 0; }
#addPresenterRoleToPerson .fonda-presentation-date > strong { display: block; margin-bottom: 6px; }
#addPresenterRoleToPerson .fonda-presentation-dates fieldset.dateTime { display: flex; align-items: center; flex-wrap: wrap; gap: 7px; float: none; border: 0; padding: 0; margin: 0; }
#addPresenterRoleToPerson .fonda-presentation-dates fieldset.dateTime label { display: inline; float: none; width: auto; margin: 0; }
#addPresenterRoleToPerson .fonda-presentation-dates fieldset.dateTime input, #addPresenterRoleToPerson .fonda-presentation-dates fieldset.dateTime select { float: none; margin: 0 10px 0 0; }
</style>
<script>
(function(){
    if(customFormData.editMode!=='add')return;
    var type=document.getElementById('typeSelector'),role=document.getElementById('roleLabel'),lastSuggestion='';
    if(!type||!role)return;
    var suggestions={
        'https://fonda.hu-berlin.de/vocab#TalkPresentation':'Speaker',
        'http://vivoweb.org/ontology/core#InvitedTalk':'Speaker',
        'https://fonda.hu-berlin.de/vocab#PosterPresentation':'Presenter',
        'https://fonda.hu-berlin.de/vocab#Demo':'Presenter',
        'https://fonda.hu-berlin.de/vocab#LecturePresentation':'Lecturer',
        'http://vivoweb.org/ontology/core#Presentation':'Presenter'
    };
    type.addEventListener('change',function(){
        var suggestion=suggestions[type.value]||'';
        if(!role.value.trim()||role.value===lastSuggestion){role.value=suggestion;lastSuggestion=suggestion;}
    });
})();
</script>

${stylesheets.add('<link rel="stylesheet" href="${urls.base}/js/jquery-ui/css/smoothness/jquery-ui-1.12.1.css" />')}
${stylesheets.add('<link rel="stylesheet" href="${urls.base}/templates/freemarker/edit/forms/css/customForm.css" />')}
${stylesheets.add('<link rel="stylesheet" href="${urls.base}/templates/freemarker/edit/forms/css/customFormWithAutocomplete.css" />')}

${scripts.add('<script type="text/javascript" src="${urls.base}/js/jquery-ui/js/jquery-ui-1.12.1.min.js"></script>',
             '<script type="text/javascript" src="${urls.base}/js/customFormUtils.js"></script>',
             '<script type="text/javascript" src="${urls.base}/js/extensions/String.js"></script>',
             '<script type="text/javascript" src="${urls.base}/js/browserUtils.js"></script>',
             '<script type="text/javascript" src="${urls.base}/js/jquery_plugins/jquery.bgiframe.pack.js"></script>',
             '<script type="text/javascript" src="${urls.base}/templates/freemarker/edit/forms/js/customFormWithAutocomplete.js"></script>')}
