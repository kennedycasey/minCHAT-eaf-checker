# minCHAT-eaf-checker

This is an adaptation of the ACLEW Annotation Scheme minCHAT checker app found [here](https://github.com/aclew/AAS-minCHAT-Checker). The app allows annotators to automatically check for _potential_ minCHAT errors in their transcriptions so that they can manually fix those errors if needed.

The app, as written, is best suited for users who followed an adapted version of the [ACLEW Annotation Scheme (AAS)](https://osf.io/b2jep/wiki/home/) or for users who want to simply check minCHAT errors in transcription tiers without also checking for issues with non-AAS dependent tiers or validating non-AAS closed-vocabulary annotation values).

The main changes from the original version are as follows:

* minCHAT eaf checker takes raw ELAN files (eaf files) as input rather than txt files, so annotators do not need to complete manual eaf to txt export
* minCHAT eaf checker supports variation in the tier types and names allowed (see [non-AAS customizations](#non-aas-customizations) below)


### What does minCHAT eaf checker look for?

For all tiers (some overlap with [original version](https://github.com/aclew/AAS-minCHAT-Checker)), it checks to see whether:

* tier names match the user-supplied list and/or the standard AAS tier names
* there are empty transcriptions
* there are transcriptions with too few or too many terminal markers
* there are transcriptions with extra spaces, including: 2+ spaces in a row, a space in the utterance-initial postion, a space before a terminal marker, and/or a space after a terminal marker
* the use of square brackets follows one of the following patterns: **\<blabla\> [: blabla]**, **\<blabla\> [=! blabla]**, or **[- lng]**
* the use of @ follows one of the following patterns: **blabla@s:eng**, **blabla@l**, or **blabla@c**

For AAS tiers (same as [original version](https://github.com/aclew/AAS-minCHAT-Checker)), it checks to see whether:

* tier names are either 3 or 7 characters
* there are too many or too few annotations (for dependent AAS tiers: "xds", "vcm", "lex", and/or "mwu")
* the AAS closed-vocabulary annotation values (e.g., XDS, VCM) are valid

### What doesn't the checker look for?

Here's a non-exhaustive list: 
  
* spelling... anywhere
* &=verbs (neither the &= nor the use of present 3ps tense)
* \[=! verbs] (checks the bracket syntax, but not the use of present 3ps tense)
* xxx vs. yyy
* the proper use of capital letters of hyphenated words; but it does return a list of these for manual review
* the proper use of hyphens and ampersands to indicate cut-off/restarted speech (e.g., he- or he&, -in or &in)
* matching speaker names across related tiers
* inner tier structure (i.e., correct hierarchical set-up; requires XML)


## Instructions

* Go to [https://aclew.shinyapps.io/minCHAT-eaf-checker/](https://aclew.shinyapps.io/minCHAT-eaf-checker/)
* Upload your eaf file
* Select whether you followed _exactly_ the [ACLEW Annotation Scheme (AAS)](https://osf.io/b2jep/wiki/home/)
* If not, see the options below for [non-AAS customizations](#non-aas-customizations) before clicking `Submit`
* Then, view and download your [error report](#error-report)

### Non-AAS customizations
`Add new legal tier names?`
You can optionally add new legal tier names by uploading a **csv** file with a single column that contains one tier name per cell.

`Keep any existing AAS tier names?`
If you want these tier names to be counted as legal _in addition_ to standard AAS tier names, then be sure to check this box.

`Remove expected AAS dependent tiers?` 
If your your file does not contain some or all of the AAS dependent tier types ("xds", "vcm", "lex", "mwu"), then check the boxes for the tiers that are not present.

### Error report
As with the [original version](https://github.com/aclew/AAS-minCHAT-Checker), this tool gives the number of possible errors it detected and a list of the capitalized and hyphenated words in the transcription (make sure these match the minCHAT rules!). You can download a more detailed spreadsheet of possible errors at the bottom of the report; remember, this tool finds _potential_ errors&mdash;it is your job to determine whether these are real errors!

**This script won't catch all the errors!**

* It only catches errors as described [here](#what-does-minchat-eaf-checker-look-for)
* It might even catch some "errors" that are _in reality_ perfectly fine
