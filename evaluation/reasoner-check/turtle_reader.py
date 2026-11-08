#!/usr/bin/env python3
"""Reader for the (simple) Turtle of the ontology files; as a script it also writes flat RDF/XML.
usage: ttl2rdfxml.py in.ttl out.rdf"""
import re, sys
from xml.sax.saxutils import escape, quoteattr
from lxml import etree

RDF = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
XSD = "http://www.w3.org/2001/XMLSchema#"

TOK = re.compile(r'''
   (?P<ws>\s+|\#[^\n]*)
 | (?P<iri><[^>]*>)
 | (?P<str>"(?:[^"\\]|\\.)*")
 | (?P<lang>@[a-zA-Z]+(?:-[a-zA-Z0-9]+)*)
 | (?P<dt>\^\^)
 | (?P<punct>[;,.\[\]()])
 | (?P<pname>[A-Za-z_][\w-]*:[\w.-]*[\w-]|[A-Za-z_][\w-]*:|:[\w-]+|a(?=\s))
 | (?P<num>[0-9]+)
''', re.X)

def tokens(text):
    pos = 0
    while pos < len(text):
        m = TOK.match(text, pos)
        if not m:
            raise SystemExit(f"cannot tokenize at {text[pos:pos+40]!r}")
        pos = m.end()
        if m.lastgroup != "ws":
            yield m.lastgroup, m.group()

def unescape(s):
    return re.sub(r'\\(.)', lambda m: {'n': '\n', 't': '\t', 'r': '\r'}.get(m.group(1), m.group(1)), s[1:-1])

def parse(text):
    toks = list(tokens(text)); i = 0; prefixes = {}; triples = []; bn = [0]
    def new_bnode():
        bn[0] += 1; return ("b", f"b{bn[0]}")
    def term():
        nonlocal i
        k, v = toks[i]
        if k == "iri": i += 1; return ("u", v[1:-1])
        if k == "pname":
            i += 1
            if v == "a": return ("u", RDF + "type")
            p, l = v.split(":", 1); return ("u", prefixes[p] + l)
        if k == "num": i += 1; return ("l", v, None, XSD + "integer")
        if k == "str":
            i += 1; lex = unescape(v); lang = dt = None
            if i < len(toks) and toks[i][0] == "lang": lang = toks[i][1][1:]; i += 1
            elif i < len(toks) and toks[i][0] == "dt": i += 1; dt = term()[1]
            return ("l", lex, lang, dt)
        if v == "[":
            i += 1; b = new_bnode()
            if toks[i][1] != "]": pred_list(b)
            assert toks[i][1] == "]"; i += 1; return b
        if v == "(":
            i += 1; items = []
            while toks[i][1] != ")": items.append(term())
            i += 1
            if not items: return ("u", RDF + "nil")
            head = cur = new_bnode()
            for n, it in enumerate(items):
                triples.append((cur, ("u", RDF + "first"), it))
                nxt = new_bnode() if n < len(items) - 1 else ("u", RDF + "nil")
                triples.append((cur, ("u", RDF + "rest"), nxt)); cur = nxt
            return head
        raise SystemExit(f"unexpected token {v!r}")
    def pred_list(s):
        nonlocal i
        while True:
            p = term()
            while True:
                triples.append((s, p, term()))
                if toks[i][1] == ",": i += 1; continue
                break
            if toks[i][1] == ";":
                i += 1
                if toks[i][1] in (".", "]"): return
                continue
            return
    while i < len(toks):
        k, v = toks[i]
        if k == "lang" and v == "@prefix":
            p = toks[i + 1][1].rstrip(":"); prefixes[p] = toks[i + 2][1][1:-1]
            assert toks[i + 3][1] == "."; i += 4; continue
        s = term(); pred_list(s)
        assert toks[i][1] == ".", toks[i]; i += 1
    return prefixes, triples

def split_iri(u):
    m = re.match(r'(.*[#/])([A-Za-z_][\w.-]*)$', u)
    return m.group(1), m.group(2)

def to_xml(prefixes, triples):
    ns = dict(prefixes); ns.setdefault("rdf", RDF)
    rev = {v: k for k, v in ns.items()}; extra = 0
    def qname(u):
        nonlocal extra
        base, local = split_iri(u)
        if base not in rev:
            extra += 1; rev[base] = f"ns{extra}"; ns[f"ns{extra}"] = base
        return f"{rev[base]}:{local}"
    body = []
    for s, p, o in triples:
        subj = f'rdf:about={quoteattr(s[1])}' if s[0] == "u" else f'rdf:nodeID="{s[1]}"'
        q = qname(p[1])
        if o[0] == "u": el = f'<{q} rdf:resource={quoteattr(o[1])}/>'
        elif o[0] == "b": el = f'<{q} rdf:nodeID="{o[1]}"/>'
        else:
            a = f' xml:lang="{o[2]}"' if o[2] else (f' rdf:datatype={quoteattr(o[3])}' if o[3] else "")
            el = f'<{q}{a}>{escape(o[1])}</{q}>'
        body.append(f'  <rdf:Description {subj}>\n    {el}\n  </rdf:Description>')
    head = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<rdf:RDF\n" + "\n".join(
        f'    xmlns:{k}="{v}"' for k, v in ns.items()) + ">\n"
    return head + "\n".join(body) + "\n</rdf:RDF>\n"

def read_back(path):
    root = etree.parse(path).getroot(); out = []
    for d in root:
        s = ("u", d.get(f"{{{RDF}}}about")) if d.get(f"{{{RDF}}}about") else ("b", d.get(f"{{{RDF}}}nodeID"))
        for e in d:
            p = ("u", etree.QName(e).namespace + etree.QName(e).localname)
            if e.get(f"{{{RDF}}}resource"): o = ("u", e.get(f"{{{RDF}}}resource"))
            elif e.get(f"{{{RDF}}}nodeID"): o = ("b", e.get(f"{{{RDF}}}nodeID"))
            else: o = ("l", e.text or "", e.get("{http://www.w3.org/XML/1998/namespace}lang"), e.get(f"{{{RDF}}}datatype"))
            out.append((s, p, o))
    return out

if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    prefixes, triples = parse(open(src, encoding="utf-8").read())
    open(dst, "w", encoding="utf-8").write(to_xml(prefixes, triples))
    back = read_back(dst)
    same = sorted(map(repr, triples)) == sorted(map(repr, back))
    print(f"{src}: {len(triples)} triples, read back {len(back)}, identical: {same}")
    if not same: sys.exit(1)
