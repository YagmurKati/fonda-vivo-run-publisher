<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-10-18: custom display view for workflow run pages (class rm:RunMetadata, set with
  vitro:customDisplayViewAnnot). Renders the standard VIVO individual page and adds, through VIVO's
  classSpecificExtension hook in individual.ftl:
    - "where the run's resources went" (individual-run-stage-breakdown.ftl)
    - "idle vs. work" (individual-run-idle-work.ftl; only on runs with an energy above idle)
    - "this run among the workflow's runs" (individual-run-peers.ftl)
  To undo: remove the class annotation ("remove mixed RDF"); this file is then unused.
-->
<#assign classSpecificExtension>
    <#include "individual-run-stage-breakdown.ftl">
    <#include "individual-run-idle-work.ftl">
    <#include "individual-run-power-time.ftl">
    <#include "individual-run-grid-timing.ftl">
    <#include "individual-run-peers.ftl">
</#assign>
<#include "individual.ftl">
