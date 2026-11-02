# Add publications to FONDA VIVO

Use the [FONDA publication importer](https://vivo-fonda.hu-berlin.de/vivo/fonda-publications)
to add your publications and connect them to existing researchers and FONDA
subprojects. It retrieves metadata from a DOI and lets you review the connections
before saving.

This guide covers journal articles, conference papers, preprints, books and
chapters, posters, reports, and software outputs. You use the VIVO website;
no repository download, cluster access, or command-line setup is needed.

## Before you start

Have these ready:

- a VIVO account connected to your researcher profile, with permission to edit it;
- the DOI of each publication you want to add;
- the names of its FONDA co-authors and the subprojects that contributed.

If you need an account or your account opens the wrong profile, contact
[yagmur.kati@hu-berlin.de](mailto:yagmur.kati@hu-berlin.de) with your name,
institutional email, and the URL of your VIVO researcher profile if it already
exists.

## 1. Open the publication importer

1. [Sign in to FONDA VIVO](https://vivo-fonda.hu-berlin.de/vivo/authenticate).
2. Open your researcher profile and choose **Add publications (DOI)**.
3. Check the name after **Adding publications for**. It should be your name.

You can also open [Add publications to FONDA](https://vivo-fonda.hu-berlin.de/vivo/fonda-publications)
directly after signing in.

## 2. Look up your DOIs

Paste up to **five different DOIs**, one per line, then choose
**Look up publications**. Both a bare DOI and a `https://doi.org/…` link are
accepted.

For example, these two lines show the accepted formats. Replace them with DOIs
for your own publications:

```text
10.48550/arxiv.2505.09375
https://doi.org/10.1016/j.suscom.2026.101438
```

Use the DOI of the individual contribution, rather than the DOI of an entire
proceedings volume or book, when adding a paper or chapter. For an arXiv preprint,
use its DOI link rather than only its arXiv identifier.

VIVO first checks for an existing record with the same DOI. Otherwise it retrieves
available metadata from Crossref or DataCite. Check the title and publication
details when the review screen opens.

## 3. Confirm the publication type

The **Publication type** panel shows the type and the **Chart category** it belongs
to. For a new record, choose the precise type from the grouped list:

| Category in the profile chart | Type to choose |
| --- | --- |
| Journal articles | Journal article |
| Conference papers | Conference paper |
| Preprints | Preprint |
| Books and chapters | Book or Book chapter |
| Other outputs | Poster, Report, or Software output |

The type suggested by the metadata source needs your review. In particular:

- a publisher may describe a conference contribution as a book chapter;
- a poster and a written conference paper have different types;
- a preprint and its later published version should retain their respective
  types and identifiers;
- a software output or report belongs in **Other outputs**, even if its title
  sounds like an article.

Check **I confirm this publication type and chart category** for each publication.
Changing a selected type clears its confirmation, so confirm the new choice
again.

If the DOI already exists, VIVO displays its **Recorded type** and preserves it.
Ask the administrator to correct an incorrect existing type before completing
the review.

## 4. Check the authors or creators

The author list keeps the publication's order. For each entry:

- select your researcher profile at your position in the list;
- check suggested FONDA co-author profiles and select any missing matches;
- use the name filter to find an existing researcher;
- leave other co-authors as **External author / keep name only**.

ORCID identifiers and matching names help suggest profiles. Check the actual
identity before accepting a match, particularly when people have similar names.
If the correct profile is missing, ask the administrator rather than selecting
another person.

External co-authors remain in the ordered author list without creating new
researcher profiles. Existing profile links are preserved when a DOI record is
reused. Incorrect existing author links need administrator review.

Each publication in a batch must include your profile in its author or creator
list. Add publications that you authored or created.

## 5. Select the contributing subprojects

Choose at least one FONDA subproject that contributed to each publication.

**Suggested from author membership** helps you find possible projects. Suggestions
are left unchecked until you select them. A person's membership in several
subprojects does not mean that every publication belongs to all of them.

Existing project links are marked **Already linked** and are preserved.

## 6. Save the reviewed publications

1. Make sure every publication's type confirmation is checked.
2. Check the author identities and contributing subprojects.
3. Check the final review confirmation.
4. Choose **Save publications and connections**.

VIVO saves the reviewed author and subproject connections together and checks the
result. The success screen links to the saved publication records.

## 7. Check the result in VIVO

Open each saved publication and check its title, date, type, author order, and
subproject links. Then check your researcher profile and the relevant subproject
pages. Listings and the publication chart may take a moment to refresh.

The profile chart uses the five categories in the table above. Books and chapters
share a category, while posters, reports, and software outputs appear under
**Other outputs**.

If the publication should be connected to a workflow or dataset, open its VIVO
page and add the appropriate relationship where your editing permissions allow
it, or ask the administrator. DOI import does not infer those connections.

## Existing records and publication versions

An existing DOI is reused, so you do not need to create another record when a
co-author has already added the publication. Existing author links, project links,
and the recorded type are preserved.

A preprint and a published article can have different DOIs. Check which version
you are adding and choose the appropriate type; a shared title alone does not
make them the same record.

## Publications without a DOI

Use the publication add control in your profile's **Publications** section to
enter the available metadata manually. Choose the correct publication type and
reuse existing researcher and subproject records wherever the form allows it.
Ask the administrator for help with fields or relationships your account cannot
edit.

The DOI importer creates a publication record and its connections; it does not
upload the article PDF. BibTeX and RIS file uploads are not part of this form.

## If something goes wrong

| What you see | What to do |
| --- | --- |
| Your profile or the **Add publications (DOI)** button is missing | Ask the administrator to check your account's profile connection and editing access. |
| Metadata cannot be retrieved | Check the individual publication DOI, try again later, or use the manual publication form. |
| The source suggests the wrong type | Choose the correct type for a new record. Ask the administrator to correct an existing record. |
| An author match is uncertain | Check the person's identity before selecting a profile; leave external co-authors as name-only entries. |
| VIVO asks you to select your profile | Choose your own profile at the correct author position for every publication in the batch. |
| A DOI has duplicate records, or the record changed during review | Follow the displayed message. Ask the administrator to review duplicates, or look up the DOI again to load the latest record. |
| Saving reports an error | Check whether the record was saved and contact the administrator before retrying or creating a manual duplicate. |
| The profile or chart has not updated yet | Allow a moment for processing, then refresh the relevant pages. |

For help, email [yagmur.kati@hu-berlin.de](mailto:yagmur.kati@hu-berlin.de) with the
DOI, your profile URL, and the message you saw. Keep passwords out of support
messages.

[Back to the repository guide](../README.md)
