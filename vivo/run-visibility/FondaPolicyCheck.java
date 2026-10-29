import java.io.File;
import java.io.StringReader;
import java.util.*;

import org.apache.jena.query.*;
import org.apache.jena.rdf.model.*;
import org.apache.jena.riot.Lang;
import org.apache.jena.riot.RDFDataMgr;

/**
 * FONDA 2026-10-26: checks fonda-run-visibility.n3 before it is installed, with the Jena of VIVO itself.
 * 1. The file parses.
 * 2. Together with VIVO's access-control vocabulary, every check of the policy has an operator, a type and a
 *    value, as VIVO's PolicyLoader requires.
 * 3. The four SPARQL queries, filled in the way VIVO fills them, give the expected answers on test data.
 * Usage: java -cp "/opt/tomcat9/webapps/vivo/WEB-INF/lib/*" FondaPolicyCheck.java POLICY_FILE ACCESS_CONTROL_FIRSTTIME_DIR
 * Prints "ALL CHECKS PASSED" and exits 0, or prints the failures and exits 1. Reads only.
 */
public class FondaPolicyCheck {
    static final String RM = "http://example.org/ontology/run-metadata#";
    static final String MATCH = "https://vivoweb.org/ontology/vitro-application/auth/individual/fonda-run-visibility/Match";
    static final String EX = "http://example.org/test/";
    static int failures = 0;

    public static void main(String[] args) throws Exception {
        Model policy = RDFDataMgr.loadModel(args[0], Lang.TURTLE);
        System.out.println("1. parsed: " + policy.size() + " statements");

        Model all = ModelFactory.createDefaultModel().add(policy);
        for (String name : new String[] {"operators.n3", "attributes.n3", "decisions.n3", "operations.n3",
                "object_types.n3", "roles.n3"}) {
            File f = new File(args[1], name);
            if (!f.isFile()) { fail("VIVO vocabulary file missing: " + f); continue; }
            RDFDataMgr.read(all, f.getPath(), Lang.TURTLE);
        }
        String rulesQuery = String.join("\n",
            "PREFIX access: <https://vivoweb.org/ontology/vitro-application/auth/vocabulary/>",
            "SELECT ?rule ?check ?testId ?typeId ?value ?lit_value ?decision_id ?config WHERE {",
            "  ?policy a access:Policy ; access:hasRule ?rule . ?rule access:requiresCheck ?check .",
            "  OPTIONAL { ?check access:useOperator ?t . OPTIONAL { ?t access:id ?testId } }",
            "  OPTIONAL { ?check access:hasTypeToCheck ?ty . OPTIONAL { ?ty access:id ?typeId } }",
            "  OPTIONAL { ?check access:useConfiguration ?c . ?c access:id ?config }",
            "  OPTIONAL { ?rule access:hasDecision ?d . ?d access:id ?decision_id }",
            "  { ?check access:values ?vs . ?vs access:value ?value . OPTIONAL { ?value access:id ?lit_value } }",
            "  UNION { ?check access:value ?value . OPTIONAL { ?value access:id ?lit_value } }",
            "} ORDER BY ?rule ?check");
        Map<String, Integer> rows = new TreeMap<>();
        try (QueryExecution qe = QueryExecutionFactory.create(rulesQuery, all)) {
            ResultSet rs = qe.execSelect();
            while (rs.hasNext()) {
                QuerySolution qs = rs.next();
                String check = qs.getResource("check").getLocalName();
                rows.merge(check, 1, Integer::sum);
                if (!qs.contains("testId") || !qs.contains("typeId")) fail("check " + check + " has no operator or type id");
                if (!qs.contains("decision_id") || !"DENY".equals(qs.getLiteral("decision_id").getString()))
                    fail("rule " + qs.getResource("rule").getLocalName() + " is not a DENY rule");
                String op = qs.contains("testId") ? qs.getLiteral("testId").getString() : "";
                if (op.startsWith("SPARQL") && !qs.contains("config")) fail("check " + check + " has no query");
            }
        }
        String[] expected = {"M_IsDisplay", "M_IsIndividual", "M_IsVisitor", "M_RunIsMembersOnly", "P_IsDisplay",
            "P_IsIndividual", "P_NotAdminOrCurator", "P_RunIsPrivate", "P_UserIsNotRunner", "P_UserIsNotRunnerByProxy"};
        for (String c : expected) if (!rows.containsKey(c)) fail("check " + c + " not found by VIVO's loader query");
        if (rows.getOrDefault("P_NotAdminOrCurator", 0) != 2) fail("P_NotAdminOrCurator should have 2 roles");
        System.out.println("2. loader view: " + rows);

        String data = String.join("\n",
            "@prefix rm: <" + RM + "> . @prefix ex: <" + EX + "> .",
            "ex:privRun rm:visibility rm:VisibilityPrivate ; rm:runOperator ex:alice .",
            "ex:privStage rm:isWorkflowProcessOf ex:privRun .",
            "ex:privRun rm:hasWorkflowProcess ex:privStage2 .",
            "ex:memRun rm:visibility rm:VisibilityMembers ; rm:runOperator ex:alice .",
            "ex:memStage rm:isWorkflowProcessOf ex:memRun .",
            "ex:pubRun rm:visibility rm:VisibilityPublic ; rm:runOperator ex:alice .",
            "ex:plainRun rm:runOperator ex:bob .",
            "ex:alice ex:loginId \"alice\" . ex:bob ex:loginId \"bob\" .");
        Model d = ModelFactory.createDefaultModel();
        RDFDataMgr.read(d, new StringReader(data), null, Lang.TURTLE);

        Map<String, String> q = new HashMap<>();
        try (QueryExecution qe = QueryExecutionFactory.create(
                "PREFIX access: <https://vivoweb.org/ontology/vitro-application/auth/vocabulary/> "
                + "SELECT ?q ?t WHERE { ?q a access:SparqlSelectValuesQuery ; access:id ?t }", policy)) {
            ResultSet rs = qe.execSelect();
            while (rs.hasNext()) { QuerySolution s = rs.next(); q.put(s.getResource("q").getLocalName(), s.getLiteral("t").getString()); }
        }
        // query, object, login id, proxied profile, expected match
        test(q, d, "PrivateRunQuery", "privRun", null, "", true);
        test(q, d, "PrivateRunQuery", "privStage", null, "", true);
        test(q, d, "PrivateRunQuery", "privStage2", null, "", true);
        test(q, d, "PrivateRunQuery", "memRun", null, "", false);
        test(q, d, "PrivateRunQuery", "pubRun", null, "", false);
        test(q, d, "PrivateRunQuery", "plainRun", null, "", false);
        test(q, d, "MembersRunQuery", "memRun", null, "", true);
        test(q, d, "MembersRunQuery", "memStage", null, "", true);
        test(q, d, "MembersRunQuery", "privRun", null, "", false);
        test(q, d, "MembersRunQuery", "plainRun", null, "", false);
        test(q, d, "RunnerQuery", "privRun", "alice", "", true);
        test(q, d, "RunnerQuery", "privStage", "alice", "", true);
        test(q, d, "RunnerQuery", "privRun", "bob", "", false);
        test(q, d, "RunnerByProxyQuery", "privRun", null, EX + "alice", true);
        test(q, d, "RunnerByProxyQuery", "privStage2", null, EX + "alice", true);
        test(q, d, "RunnerByProxyQuery", "privRun", null, EX + "bob", false);
        System.out.println(failures == 0 ? "ALL CHECKS PASSED" : failures + " CHECK(S) FAILED");
        System.exit(failures == 0 ? 0 : 1);
    }

    // Fills the query the way VIVO's SparqlSelectQueryResultsChecker.setVariables does.
    static void test(Map<String, String> q, Model d, String name, String object, String login, String profile,
            boolean expectMatch) {
        String text = q.get(name);
        if (text == null) { fail("query " + name + " missing"); return; }
        ParameterizedSparqlString pss = new ParameterizedSparqlString();
        pss.setCommandText(text);
        pss.setIri("profileUri", profile);
        pss.setIri("objectUri", EX + object);
        if (login != null) pss.setLiteral("externalAuthId", login);
        pss.setIri("matchingPropertyUri", EX + "loginId");
        boolean match = false;
        try (QueryExecution qe = QueryExecutionFactory.create(QueryFactory.create(pss.toString()), d)) {
            ResultSet rs = qe.execSelect();
            while (rs.hasNext()) {
                RDFNode n = rs.next().get("match");
                if (n != null && n.isURIResource() && MATCH.equals(n.asResource().getURI())) match = true;
            }
        } catch (Exception e) { fail(name + " on " + object + ": " + e); return; }
        String line = String.format("3. %-19s %-10s login=%-5s proxy=%-6s -> %s", name, object, login,
            profile.isEmpty() ? "-" : profile.substring(EX.length()), match ? "match" : "no match");
        if (match != expectMatch) fail(line + " (expected " + (expectMatch ? "match" : "no match") + ")");
        else System.out.println(line);
    }

    static void fail(String message) { failures++; System.out.println("FAIL: " + message); }
}
