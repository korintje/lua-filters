# pandoc-doi2cite
This pandoc lua filiter helps users to insert references in a document with using DOI(Digital Object Identifier) tags.
With this filter, users do not need to make bibtex file by themselves. Instead, the filter automatically generate .bib file from the DOI tags, and convert the DOI tags into citation keys available by `pandoc-crossref`.

<img src="https://user-images.githubusercontent.com/30950088/117561410-87ec5d00-b0d1-11eb-88be-931f3158ec44.png" width="960">

What the filter do are as follows:

1. Search citations with DOI tags in the document
2. Search corresponding bibtex data from the designated .bib file
3. If not found, get bibtex data of the DOI from http://api.crossref.org
4. Add reference data to a .bib file
5. Check duplications of reference keys
6. Replace DOI tags to the correspoinding citation keys.

# Prerequisites
- Pandoc version 2.0 or newer
- This filter does not need any external dependencies
- This filter must be executed before `pandoc-crossref` or `--citeproc`

# DOI tags
Following DOI tags can be used:
* @https://doi.org/
* @doi.org/
* @DOI:
* @doi:

The first one (@https://doi.org/) may be the most useful because it is same as the accessible URL.

# Specify auto-generated bibliography file path
The path of the auto-generated bibliography file can be designated in the document yaml header.
The yaml key is `from_doi`.
Both of the string and array are acceptable(If it is given as an array, only first item will be used).
Note that users typically should add same file path also in `bibliography`, in order to be recognized by `--citeproc`.

# Example
example1.md:

<pre>
---
bibliography:
  - "doi_refs.bib"
  - "my_refs.bib"
bib_from_doi: "doi_refs.bib"
---

# Introduction
The Laemmli system is one of the most widely used gel systems for the separation of proteins.[@LAEMMLI_1970]
By the way, Einstein is genius.[@https://doi.org/10.1002/andp.19053220607; @doi.org/10.1002/andp.19053220806; @doi:10.1002/andp.19053221004]


</pre>

Example command 1 (.md -> .md)

```sh
pandoc --lua-filter=doi2cite.lua --wrap=preserve -s example1.md -o expected1.md
```

Example command 2 (.md -> .pdf with [ACS](https://pubs.acs.org/journal/jacsat) style):

```sh
pandoc --lua-filter=doi2cite.lua --filter=pandoc-crossref --citeproc --csl=sample1.csl -s example1.md -o expected1.pdf
```

Example result

![expected1](https://user-images.githubusercontent.com/30950088/119964566-4d952200-bfe4-11eb-90d9-ed2366c639e8.png)
