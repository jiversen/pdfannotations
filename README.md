pdfannotations
==============

_New Solution to extracting highlights and annotations from pdfs (annotated using non-papers apps)_

*The key contribution here is that it also extracts highlighted text, and nicely styles the results, making clear
the distinction between quotes and your own thoughts. Excellent for extracting notes taken on papers to create a concise summary.*

I've made a set of programs for my own use that extract my annotations--highlights, notes, underlines--and put a formatted rich text into the clipboard that you can paste into any app.

If you're interested in testing it out, please check it out: http://johniversen.org/data/PDFAnnotationsToClipboard.mpkg.zip
It works for me, but let me know here if you run into problems.

Enjoy,

John


Extract annotations, including highlighted text, from pdf

*/usr/local/bin/pdfannotations*

	A command line program that takes the name of a pdf file as an argument, and outputs an HTML formatted stream of annotations and comments, indexed by page. This is the business end of the apps above.

  Complete installation package (including OS X services to place rich-text annotation into clipboard) can be downloaded at: http://johniversen.org/data/PDFAnnotationsToClipboard.mpkg.zip
  
*PDF Annotations to Clipboard.app*

*PDF Annotations to Clipboard.workflow*

	This app and service both take a pdf file and harvest notes, highlighst and other annotations from it, placing a richly formatted list in the clipboard. Usage: Drop a pdf onto the app, or select it as the target for "Open With…" in a contextual menu.

  
Usage: 

This works for standard pdf annotations, as created in e.g. Preview.app. Right click on a pdf and use either the service or "Open With…" menus. Move to your text editor or pdf database and paste the styled annotations.

As seen in the example below, highlighted text is rendered as a quotation. Additional fanciness: a note associated with a highlight is rendered as an italicized comment under the quote, so you can add commentary and your own thoughts. If the note contains a two paragraphs, the first is printed as a bold header above the quotation, and the second becomes the comment. This is useful to structure your notes.

Underlined text contained within a highlighted section is emphasized in bold. Underlined text on its own is rendered as a quotation in bold. 

Text boxes (free text) are rendered as comments in brackets.


PDF:
￼

EXTRACTED ANNOTATIONS:

Annotations extracted 2/4/14 5:35:09 PM

Page 1
[A Text Box Comment]

INTRODUCTION
"The perception of rhythm is central to how we find structure and meaning in speech and music"
    Notes are used for commentary on a highlighted passage. For two paragraph notes the first paragraph is displayed as a header above the quote. Remaining paragraphs are placed as comments below the quote.

"we naturally perceive events as grouped into higher-level patterns"
     Notice how the underlined word within the highlight is rendered in bold?

"The human proclivity for auditory grouping is so strong that it is even applied to sequences of physically identical sounds, as, for example, when an electronic metronome is heard as "tick tock" when, in fact, each sound is the same (Bolton, 1894)"
    Underlined text is quoted in bold. Comments are added within the note, as for highlights.

