<#-- $This file is distributed under the terms of the license in LICENSE$ -->
<#--
  FONDA 2026-09-29: custom display view for fonda:Subproject pages
  (Ontology editor > class Subproject > "Custom display view" = individual--fonda-subproject.ftl).
  Renders the standard VIVO individual page and adds the "Collaboration with other
  subprojects" chord through VIVO's classSpecificExtension hook in individual.ftl.
  To undo: clear the class's custom display view; this file is then unused.
-->
<#assign classSpecificExtension>
    <#include "individual-subproject-collaboration.ftl">
</#assign>
<#include "individual.ftl">
