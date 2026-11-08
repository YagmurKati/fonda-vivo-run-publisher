#!/usr/bin/env python3
"""Build one Turtle file for a reasoner check: the ontology (core and research software module), an import of
PROV-O, and the exported VIVO records. Also writes a control file with one deliberate error (one run typed
prov:Entity, which PROV-O declares disjoint with prov:Activity), which a reasoner must report as inconsistent.

usage: build_check_file.py workflow-energy-core.ttl research-software.ttl records.rdf
writes check.ttl and check-CONTROL.ttl
"""
import re, subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import turtle_reader as t  # noqa: E402

OWL = "http://www.w3.org/2002/07/owl#"; TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
def term(x, prefix):
    if x[0] == "u": return f"<{x[1]}>"
    if x[0] == "b": return f"_:{prefix}{x[1]}"
    lex = x[1].replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r")
    return f'"{lex}"^^<{x[3]}>' if x[3] else (f'"{lex}"@{x[2]}' if x[2] else f'"{lex}"')
core, rs, records = sys.argv[1:4]
head = [f"<http://example.org/check/fonda-records> <{TYPE}> <{OWL}Ontology> .",
        f"<http://example.org/check/fonda-records> <{OWL}imports> <http://www.w3.org/ns/prov-o> ."]
onto = []
for f, pre in ((core, "core"), (rs, "rs")):
    _, tr = t.parse(open(f, encoding="utf-8").read())
    headers = {s for s, p, o in tr if p[1] == TYPE and o[1] == OWL + "Ontology"}
    onto += [f"{term(s, pre)} {term(p, pre)} {term(o, pre)} ." for s, p, o in tr if s not in headers]
if records.endswith(".nt"):
    data = open(records, encoding="utf-8").read().splitlines()
else:
    subprocess.run([sys.executable, str(Path(__file__).with_name("rdfxml2nt.py")), records, "records.nt"], check=True)
    data = open("records.nt", encoding="utf-8").read().splitlines()
Path("check.ttl").write_text("\n".join(head + onto + data) + "\n", encoding="utf-8")
run = next(l.split(" ")[0] for l in data if l.split(" ")[2] == "<http://example.org/ontology/run-metadata#RunMetadata>")
Path("check-CONTROL.ttl").write_text("\n".join(head + onto + data + [f"{run} <{TYPE}> <http://www.w3.org/ns/prov#Entity> ."]) + "\n", encoding="utf-8")
print(f"check.ttl: {len(onto)} ontology triples, {len(data)} record triples; check-CONTROL.ttl adds: {run} a prov:Entity")
