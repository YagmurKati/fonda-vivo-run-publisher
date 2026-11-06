<#setting number_format="computer">
<style>
.fonda-import{max-width:1020px;margin:20px auto 55px;color:#24364b}.fonda-import h1{font-size:30px;margin:0 0 12px}.fonda-import h2{font-size:22px;margin:0 0 12px}.fonda-import h3{font-size:18px;margin:24px 0 10px}.fonda-import p{line-height:1.6}.fonda-import .intro{max-width:780px;color:#526278;font-size:16px}.fonda-import .steps{padding:14px 18px;background:#edf4f9;border-radius:8px;margin:20px 0}.fonda-import .work{border:1px solid #d8e1ea;border-radius:10px;padding:24px;margin:22px 0;background:#fff}.fonda-import .metadata{color:#526278;margin-bottom:16px}.fonda-import label{font-weight:normal}.fonda-import select,.fonda-import textarea{box-sizing:border-box;border:1px solid #a9b9c8;border-radius:5px;background:#fff;padding:9px;color:#24364b;font:inherit}.fonda-import textarea{width:100%;max-width:760px;min-height:140px}.fonda-import select{max-width:100%;width:100%}.fonda-import .type{max-width:350px}.fonda-import .author-row{display:grid;grid-template-columns:minmax(150px,1fr) minmax(230px,1.5fr);gap:18px;border-top:1px solid #e8edf2;padding:12px 0}.fonda-import .author-name{font-weight:600;padding-top:8px}.fonda-import .hint{display:block;color:#617086;font-size:13px;margin-top:5px}.fonda-import .project-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px 20px}.fonda-import .project-grid label{display:flex;gap:9px;align-items:flex-start;line-height:1.45}.fonda-import input[type=checkbox]{flex:none;margin-top:4px}.fonda-import .badge{font-size:12px;padding:3px 8px;background:#edf4f9;border-radius:4px;display:inline-block;color:#36576f}.fonda-import .error{border-left:4px solid #b72832;background:#fff1f1;padding:16px;margin:20px 0}.fonda-import .success{border-left:4px solid #287354;background:#edf8f1;padding:18px;margin:20px 0}.fonda-import .actions{display:flex;align-items:center;gap:20px;margin-top:24px}.fonda-import button{border:0;border-radius:6px;background:#173f63;color:#fff;padding:12px 22px;font-size:16px;cursor:pointer}.fonda-import button:disabled{opacity:.6;cursor:wait}.fonda-import .confirm{display:flex;gap:10px;line-height:1.6;padding:16px;background:#f3f6f9;border-radius:7px}.fonda-import .search-people{width:100%;box-sizing:border-box;padding:8px;margin:6px 0;border:1px solid #a9b9c8;border-radius:5px;font:inherit}.fonda-import details{margin-top:28px}.fonda-import summary{cursor:pointer;font-weight:600}.fonda-import a{color:#195a88;text-decoration:underline}@media(max-width:700px){.fonda-import .author-row,.fonda-import .project-grid{grid-template-columns:1fr}.fonda-import .work{padding:16px}.fonda-import .actions{align-items:flex-start;flex-direction:column}}
.fonda-import [hidden]{display:none!important}
.fonda-import .type-review{border:1px solid #b8cddd;border-left:4px solid #286a91;border-radius:6px;background:#f2f7fb;padding:16px;margin:20px 0}.fonda-import .type-review h3{margin:0 0 10px}.fonda-import .type-confirm{display:flex;gap:9px;align-items:flex-start;line-height:1.5;margin-top:14px}.fonda-import .chart-category{font-weight:600}.fonda-import .type{max-width:100%;width:430px}
.fonda-import input[type=text],.fonda-import input[type=url],.fonda-import input[type=number]{box-sizing:border-box;padding:9px;border:1px solid #a9b9c8;border-radius:5px;font:inherit;max-width:100%;width:100%;margin:5px 0 14px}.fonda-import .entry-options{border:1px solid #d8e1ea;border-radius:8px;padding:16px;margin:20px 0}.fonda-import .entry-options summary{font-size:18px}.fonda-import .entry-options form{margin-top:20px}.fonda-import .resource-list{max-height:240px;overflow:auto;border:1px solid #d8e1ea;border-radius:5px;padding:12px}.fonda-import .resource-list label{display:flex;gap:9px;line-height:1.45;padding:7px 0}.fonda-import .resource-filter{box-sizing:border-box;width:100%;padding:9px;margin:5px 0 10px;border:1px solid #a9b9c8;border-radius:5px;font:inherit}
</style>
<section class="fonda-import" aria-labelledby="fonda-import-title">
<h1 id="fonda-import-title">Add publications to FONDA</h1>
<p class="intro">Import by DOI, enter a publication without a DOI, or add links to an existing publication. Review the authors, subprojects, workflows, and datasets together.</p>
<#if profileName??><p>Adding publications for <strong>${profileName?html}</strong> · <a href="${urls.base}/individual?uri=${profileUri?url('UTF-8')}">Back to profile</a></p></#if>
<div class="steps" aria-label="Import steps">1. Choose a publication &nbsp; → &nbsp; 2. Review details and links &nbsp; → &nbsp; 3. Save</div>
<#if error??><div class="error" role="alert">${error?html}</div></#if>
<#if saved??>
 <div class="success" role="status"><h2>Publications saved</h2><p>The publication connections have been verified. Profile and linked resource pages may take a moment to refresh.</p>
 <ul><#list saved as work><li><a href="${urls.base}/individual?uri=${work.uri?url('UTF-8')}">${work.title?html}</a></li></#list></ul></div>
</#if>
<#if works??>
<form method="post" action="${urls.base}/fonda-publications" id="fonda-import-review">
 <input type="hidden" name="csrf" value="${csrf?html}"><input type="hidden" name="profileUri" value="${profileUri?html}"><input type="hidden" name="draft" value="${draft?html}"><input type="hidden" name="action" value="save">
 <p class="intro">Check every suggested identity. An author name alone may match the wrong person. External co-authors stay in the author list without creating a new researcher profile.</p>
 <#list works as work>
 <article class="work" data-work="${work.index}">
  <h2>${work.title?html}</h2>
  <div class="metadata"><#if work.doi?has_content><a href="https://doi.org/${work.doi?html}" target="_blank" rel="noopener noreferrer">${work.doi?html}</a> · </#if>${work.source?html}<#if work.venue?has_content><br>${work.venue?html}</#if><#if work.date?has_content> · ${work.date?html}</#if></div>
  <#if work.uri?has_content><p class="badge">Already in VIVO — this form adds confirmed links to the existing record.</p></#if>
  <section class="type-review" aria-labelledby="type-heading-${work.index}">
  <h3 id="type-heading-${work.index}">Publication type</h3>
  <#if work.uri?has_content><p>Recorded type: <strong>${work.kindLabel?html}</strong></p><input type="hidden" name="kind_${work.index}" value="${work.kind?html}">
  <#else><label for="kind_${work.index}">Choose the exact type</label><br><select class="type publication-type" id="kind_${work.index}" name="kind_${work.index}" required>
   <option value="">Choose a type</option>
   <#list typeGroups as group>
    <optgroup label="${group.label?html}"><#list group.options as type>
    <option value="${type.id}" data-category="${group.label?html}"<#if work.kind==type.id> selected</#if>>${type.label?html}</option>
    </#list></optgroup>
   </#list>
  </select>
  <#if work.providerType?has_content><span class="hint">Type reported by ${work.source?html}: ${work.providerType?replace('-', ' ')?html}</span></#if>
  <span class="hint">Check the type rather than relying only on the source suggestion. A conference contribution may be described as a book chapter; a poster is different from a conference paper.</span></#if>
  <p>Chart category: <span class="chart-category" aria-live="polite">${work.category?html}</span></p>
  <#if work.uri?has_content><span class="hint">The existing type is preserved. This review updates the publication's connections.</span></#if>
  <label class="type-confirm"><input type="checkbox" name="typeConfirmed_${work.index}" value="yes" required><span>I confirm this publication type and chart category.</span></label>
  </section>
  <h3>Authors / creators, in publication order</h3>
  <#list work.authors as author>
   <div class="author-row"><div class="author-name"><label for="author_${work.index}_${author.index}">${author?counter}. ${author.name?html}</label></div><div>
    <#if author.locked>
      <input type="hidden" name="author_${work.index}_${author.index}" value="${author.selected?html}" data-projects="${author.memberships?html}"><span>Linked researcher profile</span>
    <#else>
     <input class="search-people" type="search" aria-label="Filter researcher choices for ${author.name?html}" placeholder="Filter researcher names…" autocomplete="off">
     <select class="author-choice" id="author_${work.index}_${author.index}" name="author_${work.index}_${author.index}">
      <option value="">External author / keep name only</option>
      <#list people as person><option value="${person.uri?html}" data-projects="${person.projects?html}"<#if person.uri==author.selected> selected</#if>>${person.name?html}<#if person.uri==profileUri> (you)</#if></option></#list>
     </select>
    </#if><span class="hint">${author.reason?html}</span>
   </div></div>
  </#list>
  <h3>Contributing FONDA subprojects</h3>
  <p>Select the subprojects that contributed to this publication. Membership-based suggestions are starting points; they do not establish which project supported a paper.</p>
  <div class="project-grid"><#list work.projects as project><label><input type="checkbox" name="project_${work.index}" value="${project.uri?html}"<#if project.existing> checked disabled</#if>><span>${project.name?html}<#if project.existing> <span class="badge">Already linked</span><#elseif project.suggested> <span class="badge project-suggestion">Suggested from author membership</span><#else><span class="badge project-suggestion" hidden>Suggested from author membership</span></#if></span></label></#list></div>
  <#list [{'key':'workflows','field':'workflow','title':'Workflows used (optional)'},{'key':'datasets','field':'dataset','title':'Datasets used or cited (optional)'}] as resource>
  <details class="resource-picker"><summary>${resource.title}</summary>
   <#if work[resource.key]?size gt 0>
    <input type="search" class="resource-filter" aria-label="Filter ${resource.key}" placeholder="Filter by name…">
    <div class="resource-list"><#list work[resource.key] as item><label><input type="checkbox" name="${resource.field}_${work.index}" value="${item.uri?html}"<#if item.selected> checked</#if><#if item.existing> disabled</#if>><span>${item.name?html}<#if item.existing> <span class="badge">Already linked</span></#if></span></label></#list></div>
   <#else><p>No existing ${resource.key} are available to select.</p></#if>
  </details>
  </#list>
 </article>
 </#list>
 <label class="confirm"><input type="checkbox" name="confirmed" value="yes" required><span>I have checked the authors, publication types, subprojects, workflows, and datasets. I am an author of each publication.</span></label>
 <div class="actions"><button type="submit">Save publications and connections</button><a href="${urls.base}/fonda-publications?profileUri=${profileUri?url('UTF-8')}&new=1">Start again</a></div>
 <p class="hint" id="fonda-submit-status" role="status"></p>
</form>
<#elseif profileUri??>
<form method="post" action="${urls.base}/fonda-publications" id="fonda-import-lookup">
 <input type="hidden" name="csrf" value="${csrf?html}"><input type="hidden" name="profileUri" value="${profileUri?html}"><input type="hidden" name="action" value="lookup">
 <h2><label for="fonda-dois">Publication DOIs</label></h2>
 <p id="fonda-dois-hint">Enter up to five DOIs or doi.org links, one per line. VIVO checks for existing records first.</p>
 <p>Supports all five FONDA categories: <strong>Journal articles</strong>, <strong>Conference papers</strong>, <strong>Preprints</strong>, <strong>Books and chapters</strong>, and <strong>Other outputs</strong> (posters, reports, software outputs). You will review and confirm the type of each publication before saving.</p>
 <textarea name="dois" id="fonda-dois" required maxlength="6000" aria-describedby="fonda-dois-hint" placeholder="10.1234/example&#10;https://doi.org/10.5678/example"></textarea>
 <div class="actions"><button type="submit">Look up publications</button></div><p class="hint" id="fonda-submit-status" role="status"></p>
</form>
<details class="entry-options"><summary>No DOI? Enter publication details</summary>
<form method="post" action="${urls.base}/fonda-publications" id="fonda-manual-entry">
 <input type="hidden" name="csrf" value="${csrf?html}"><input type="hidden" name="profileUri" value="${profileUri?html}"><input type="hidden" name="action" value="manual">
 <label for="manual-title">Title</label><input type="text" id="manual-title" name="manualTitle" maxlength="800" required>
 <label for="manual-kind">Publication type</label><select id="manual-kind" name="manualKind" required><option value="">Choose a type</option><#list typeGroups as group><optgroup label="${group.label?html}"><#list group.options as type><option value="${type.id}">${type.label?html}</option></#list></optgroup></#list></select>
 <label for="manual-year">Publication year</label><input type="number" id="manual-year" name="manualYear" min="1000" max="2999" required>
 <label for="manual-authors">Authors / creators, one per line, in publication order</label><textarea id="manual-authors" name="manualAuthors" maxlength="30000" required>${profileName?html}</textarea>
 <p class="hint">Include yourself at the correct position. You will connect these names to existing researcher profiles in the next step.</p>
 <label for="manual-venue">Journal, proceedings, or book title (optional)</label><input type="text" id="manual-venue" name="manualVenue" maxlength="500">
 <label for="manual-url">Publication link (optional)</label><input type="url" id="manual-url" name="manualUrl" maxlength="2000" placeholder="https://…">
 <div class="actions"><button type="submit">Review publication and links</button></div><p role="status" class="hint"></p>
</form></details>
<details class="entry-options"><summary>Manage existing publication links</summary>
<#if myPublications?? && myPublications?size gt 0>
<form method="post" action="${urls.base}/fonda-publications" id="fonda-existing-links">
 <input type="hidden" name="csrf" value="${csrf?html}"><input type="hidden" name="profileUri" value="${profileUri?html}"><input type="hidden" name="action" value="editLinks">
 <label for="existing-publication">Choose a publication linked to your profile</label><select id="existing-publication" name="publicationUri" required><option value="">Choose a publication</option><#list myPublications as publication><option value="${publication.uri?html}">${publication.name?html}</option></#list></select>
 <div class="actions"><button type="submit">Review publication links</button></div><p role="status" class="hint"></p>
</form>
<#else><p>Your profile has no linked publications yet.</p></#if>
</details>
</#if>
<details><summary>Help with publication imports</summary>
 <p>A DOI is a publication identifier, often shown as a link beginning with <code>https://doi.org/</code>. This form imports the publication record and its connections. It does not upload the article PDF.</p>
 <p>Choose your own profile at the correct position in each author list. Select existing profiles for FONDA co-authors; leave other authors as external. When a DOI is already in VIVO, the existing record is reused and existing profile links are preserved.</p>
 <p>Use <strong>No DOI? Enter publication details</strong> to add a publication manually. Use <strong>Manage existing publication links</strong> to add subprojects, workflows, and datasets to a publication already linked to your profile. Existing links are retained.</p>
</details>
</section>
<script>
(function(){'use strict';
 document.querySelectorAll('.fonda-import .publication-type').forEach(function(select){select.addEventListener('change',function(){var section=select.closest('.type-review');var option=select.options[select.selectedIndex];section.querySelector('.chart-category').textContent=option.dataset.category||'Choose a publication type';section.querySelector('.type-confirm input').checked=false;});});
 document.querySelectorAll('.fonda-import .search-people').forEach(function(input){input.addEventListener('input',function(){var query=input.value.toLocaleLowerCase();input.nextElementSibling.querySelectorAll('option').forEach(function(option){option.hidden=!!option.value&&option.textContent.toLocaleLowerCase().indexOf(query)===-1&&!option.selected;});});});
 document.querySelectorAll('.fonda-import .resource-filter').forEach(function(input){input.addEventListener('input',function(){var query=input.value.toLocaleLowerCase();input.nextElementSibling.querySelectorAll('label').forEach(function(label){label.hidden=label.textContent.toLocaleLowerCase().indexOf(query)===-1;});});});
 document.querySelectorAll('.fonda-import .author-choice').forEach(function(select){select.addEventListener('change',function(){var work=select.closest('.work');var suggestions=new Set();work.querySelectorAll('.author-choice option:checked, input[type="hidden"][data-projects]').forEach(function(option){(option.dataset.projects||'').split('|').filter(Boolean).forEach(function(uri){suggestions.add(uri);});});work.querySelectorAll('.project-grid input:not(:disabled)').forEach(function(input){var badge=input.parentElement.querySelector('.project-suggestion');if(badge)badge.hidden=!suggestions.has(input.value);});});});
 document.querySelectorAll('.fonda-import form').forEach(function(form){form.addEventListener('submit',function(){if(!form.checkValidity())return;form.querySelector('button[type="submit"]').disabled=true;var status=form.querySelector('[role="status"]');if(status)status.textContent=form.id==='fonda-import-review'?'Saving and verifying publication connections…':'Preparing publication review…';});});
})();
</script>
