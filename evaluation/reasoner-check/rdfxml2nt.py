#!/usr/bin/env python3
"""Small RDF/XML reader (typed nodes, nesting, parseType=Resource, nodeID, datatype, xml:lang) -> N-Triples."""
import sys
from lxml import etree
RDF = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
XML = "http://www.w3.org/XML/1998/namespace"
SKIP = {"{%s}%s" % (ns, l) for ns, l in [(RDF, "about"), (RDF, "nodeID"), (RDF, "ID"), (RDF, "resource"), (RDF, "datatype"), (RDF, "parseType"), (XML, "lang"), (XML, "base")]}
cnt = [0]
def bnode():
    cnt[0] += 1; return f"_:g{cnt[0]}"
def iri(t): return f"<{t}>"
def esc(s): return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r")
def lit(text, dt, lang):
    s = f'"{esc(text or "")}"'
    if dt: return s + f"^^<{dt}>"
    if lang: return s + "@" + lang
    return s
def tagiri(e):
    q = etree.QName(e); return q.namespace + q.localname
def node(e, out, lang):
    lang = e.get(f"{{{XML}}}lang", lang)
    if e.get(f"{{{RDF}}}about") is not None: s = iri(e.get(f"{{{RDF}}}about"))
    elif e.get(f"{{{RDF}}}nodeID") is not None: s = "_:n" + e.get(f"{{{RDF}}}nodeID")
    else: s = bnode()
    t = tagiri(e)
    if t != RDF + "Description": out.append((s, iri(RDF + "type"), iri(t)))
    for k, v in e.attrib.items():
        if k not in SKIP: out.append((s, iri(k.replace("{", "").replace("}", "")), lit(v, None, lang)))
    for p in e:
        if not isinstance(p.tag, str): continue
        props(s, p, out, lang)
    return s
def props(s, p, out, lang):
    lang = p.get(f"{{{XML}}}lang", lang)
    pi = iri(tagiri(p))
    if p.get(f"{{{RDF}}}resource") is not None: out.append((s, pi, iri(p.get(f"{{{RDF}}}resource")))); return
    if p.get(f"{{{RDF}}}nodeID") is not None: out.append((s, pi, "_:n" + p.get(f"{{{RDF}}}nodeID"))); return
    if p.get(f"{{{RDF}}}parseType") == "Resource":
        b = bnode(); out.append((s, pi, b))
        for c in p:
            if isinstance(c.tag, str): props(b, c, out, lang)
        return
    kids = [c for c in p if isinstance(c.tag, str)]
    if kids:
        o = node(kids[0], out, lang); out.append((s, pi, o)); return
    out.append((s, pi, lit(p.text, p.get(f"{{{RDF}}}datatype"), None if p.get(f"{{{RDF}}}datatype") else lang)))
if __name__ == "__main__":
    root = etree.parse(sys.argv[1]).getroot(); out = []
    for e in root:
        if isinstance(e.tag, str): node(e, out, root.get(f"{{{XML}}}lang"))
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        for t in out: f.write(" ".join(t) + " .\n")
    print(len(out), "triples")
