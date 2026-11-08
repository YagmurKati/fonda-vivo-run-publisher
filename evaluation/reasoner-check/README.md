# Reasoner check of the records

Checks that the ontology, PROV-O and all records of the extension in VIVO are free of contradictions.

1. Run `export-records.rq` on the VIVO SPARQL query page and save the result (RDF/XML or N-Triples).
2. `python3 build_check_file.py workflow-energy-core.ttl research-software.ttl <export file>`
   (the two ontology files are from the Workflow Energy Ontology, version 0.9.3).
   This writes `check.ttl` and `check-CONTROL.ttl`.
3. Open `check.ttl` in Protégé (online, it imports PROV-O), choose Reasoner > HermiT, Start reasoner.
4. Do the same with `check-CONTROL.ttl`. It has one deliberate error (one run typed `prov:Entity`, which PROV-O
   declares disjoint with `prov:Activity`), so the reasoner must report it as inconsistent.

Result on 2026-11-08 (95,850 record triples, 2,195 records): `check.ttl` consistent, `check-CONTROL.ttl`
inconsistent, with HermiT in Protégé.
