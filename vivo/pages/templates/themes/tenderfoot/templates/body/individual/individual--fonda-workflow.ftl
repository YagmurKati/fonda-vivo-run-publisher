<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-09-29: custom display view for workflow pages
  (class http://example.org/ontology/run-metadata#Workflow, set with vitro:customDisplayViewAnnot).
  Renders the standard VIVO individual page and adds the "energy, carbon and time per run"
  plots through VIVO's classSpecificExtension hook in individual.ftl.
  To undo: remove the class annotation ("remove mixed RDF"); this file is then unused.
-->
<#assign classSpecificExtension>
    <#include "individual-workflow-run-metrics.ftl">
    <#include "individual-workflow-stage-mix.ftl">
</#assign>
<#include "individual.ftl">
