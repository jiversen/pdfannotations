//
//  main.m
//  pdfannotations
//
//  Created by John Iversen on 9/26/11.
//  Copyright 2011 technophobe-anodyne. All rights reserved.
//

// written as a shell script, usage pdfannotations file.pdf
// outputs HTML to stdout
//
// target application is to create a service to apply on a pdf file, and then
// place formatted text extracted annotations into clipboard

// e.g.
//   pdfannotations | textutil -stdin -stdout -format html -convert rtf | pbcopy

#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>

void processPage(PDFPage *aPage);
NSString *styledTextForAnnotations(NSArray *annotations);
NSString *deHyphenate(NSString *aString);
NSString *escapeForHTML(NSString *aString);

int main (int argc, const char * argv[])
{
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    PDFDocument *pdfDoc;
    NSString *fname;
    

    if (argc < 2) {
        //fname = @"/Users/Shared/dev/Projects/annotations/hilighttest.pdf";
        fname = @"/Users/Shared/dev/Projects/annotations/Zarco.pdf";
        fname = @"/Users/jri/Google\ Drive/Papers2/Articles/Y/Yoon/Yoon\ 2006\ -\ Using\ the\ brain\ P300\ response\ to\ identify\ novel\ phenotypes\ reflecting\ genetic\ vulnerability\ for\ adolescent\ substance\ misuse.\ -\ Addict\ Behav.pdf";
        //fname = @"/Users/jri/Documents/Papers2/Articles/Conway/Conway 2009 - The Importance of Sound for Cognitive Sequencing Abilities The Auditory Scaffolding Hypothesis - Curr Dir Psych Sci.pdf";

        //fprintf(stderr, "Usage: %s fname.pdf\n\tOutput HTML formatted listing of all highlights, unnderline and textbox annotations in a pdf file.", argv[0]);
        //exit(1);
    } else {
        fname = [NSString stringWithUTF8String:argv[1]];
    }

    pdfDoc = [[PDFDocument alloc] initWithURL: [NSURL fileURLWithPath: fname ]];
    if (pdfDoc == NULL) {
        fprintf(stderr,"%s: %s appears not to be a valid pdf file.\n", argv[0], [fname UTF8String]);
        exit(2);
    }
    
    // write a prefix with page count and date (get last mod date of file?)
    NSUInteger nPage = [pdfDoc pageCount];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    //NSString *dft = [NSDateFormatter dateFormatFromTemplate:@"MM/dd/yyyy h:mm:ss a" options:0 locale:nil];
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    NSString *header = [NSString stringWithFormat:@"%@\n\n%lu pages.\n\n%@\n\n", fname, [pdfDoc pageCount], date];
    //[header writeToFile:@"/dev/stdout" atomically:NO];
    
    //process each page in turn--this writes its result to stdout
    for (int iPage=0; iPage<nPage; iPage++) {
        processPage([pdfDoc pageAtIndex:iPage]);
    }

    [pool drain];
    return 0;
}

// pull and process all annotations on a page
void processPage(PDFPage *aPage) {
    
    NSArray *annotations;
    NSString *outputText, *pageText;
    
    annotations = [aPage annotations];
    //NSLog(@"%lu annotations",[annotations count]);
    
    if ([annotations count] > 0) {
        pageText = [NSString stringWithFormat:@"<h2>Page %@</h2>\n\n", [aPage label]];
        outputText = styledTextForAnnotations(annotations);
        if ([outputText length] > 0) {
            [pageText   writeToFile:@"/dev/stdout" atomically:NO];
            [outputText writeToFile:@"/dev/stdout" atomically:NO];
        }
    }
    

}


// find #quads/4, loop over quads, get text within each quad, concatenate
// page points are bounds (1) + quadrilateralPoints
// get contents
// later: find underline within hilight by finding overlapping/contained quads
// traverses in order annotations were defined (?) rather than based on page position
//  heuristic: output from top to bottom, but this will fail for multi-column text, no?
//  how is multi-column represented internally?

// markdown styling, or attributed txt?
NSString *styledTextForAnnotations(NSArray *annotations) {
    
    NSArray *quadPoints;
    NSRect bounds;
    NSPoint start, end;
    CGFloat midy;
    NSString *annotationType, *annotationContents, *annotationText;
    id thisAnnotation;
    NSMutableString *outputText;
    //NSUInteger nQuads;
    PDFSelection *sel;
    PDFPage *annotationPage;
    //Fill these in and then when we encounter an underline, walk the array to see if it's contained in any previously encountered annotation 
    NSMutableArray *annotationsHilightedText = [[NSMutableArray alloc] initWithCapacity:10];
    NSMutableArray *annotationsContents = [[NSMutableArray alloc] initWithCapacity:10];
    NSMutableArray *annotationsBounds = [[NSMutableArray alloc] initWithCapacity:10];
    NSMutableArray *annotationsClass = [[NSMutableArray alloc] initWithCapacity:10];
    
    Boolean isContained = FALSE;
    int annotationsIdx = 0;
    
    //loop through
    
    for (thisAnnotation in annotations) {
        
        annotationType = [thisAnnotation type];
        annotationContents = [thisAnnotation contents]; //contains text of note or text box
        if (annotationContents == nil) { //kluge, for some reason contents sometimes returns nil
            annotationContents = @"";
        }
        annotationPage = [thisAnnotation page];
        bounds = [thisAnnotation bounds];
        
        isContained = FALSE;
        
        //hilight/underline/strikethrough are special--they don't already contain the hilighted text,
        // so we need to go into the pdf and select and copy the text under the highlight
        if ( [thisAnnotation isKindOfClass:[PDFAnnotationMarkup class]] ) {
            //find start and end of highlighted region
            quadPoints = [thisAnnotation quadrilateralPoints];
            //nQuads = [quadPoints count] / 4;
            
            start = [[quadPoints objectAtIndex:0] pointValue];
            end = [[quadPoints objectAtIndex:([quadPoints count] - 3)] pointValue];
            
            //end = [[quadPoints objectAtIndex:[quadPoints count] - 1] pointValue];
            
            // to ensure we don't pick up extra lines, inset the start and end y values by 1/3 of line height
            midy = (start.y + [[quadPoints objectAtIndex:2] pointValue].y)/2;
            start.y = midy;
            
            midy = (end.y + [[quadPoints objectAtIndex:[quadPoints count] - 2] pointValue].y)/2;
            end.y = midy;
            //end.y = 0;
            
            start.x += bounds.origin.x;
            start.y += bounds.origin.y;
            end.x += bounds.origin.x;
            end.y += bounds.origin.y;
            
            // annotation text (hilighted or underlined) put in quotes
            sel = [annotationPage selectionFromPoint:start toPoint:end];
            annotationText = deHyphenate([sel string]);
            annotationText = escapeForHTML(annotationText);
            
            // underlined text becomes bold
            //  TODO: underline within hilight: if hilight, search annotations for
            //  any underlines within it. Generally such an annotation will be created after the parent
            //  so could check only previous.
            if ([annotationType isEqualToString: @"Underline"]) {
                
                //check if it falls within another annotation
                for (int i=0; i<[annotationsClass count]; i++) {
                    NSRect containerBounds = [annotationsBounds[i] rectValue];
                    if ( NSContainsRect(containerBounds, bounds) ) {
                        //find string within containing string and embolden it
                        annotationsHilightedText[i] = [annotationsHilightedText[i] stringByReplacingOccurrencesOfString:annotationText withString:[NSString stringWithFormat:@"<b>%@</b>",annotationText]];
                        isContained = TRUE;
                        break;
                    }
                }
                
                //if not, treat it as a seperate annotation and embolden it
                if (!isContained) {                    
                    annotationText = [NSString stringWithFormat:@"<b>%@</b>", annotationText];
                }
                
            }
        } else if ( [thisAnnotation isKindOfClass:[PDFAnnotationFreeText class]] ) {
            annotationText = @"";
        } else {
            continue; //many other annotation types, which we ignore
        }
        
        //valid text fragment (not an emphasis embedded within another), save and continue
        if (!isContained) {
            annotationsHilightedText[annotationsIdx] = annotationText;
            annotationsBounds[annotationsIdx] = [NSValue valueWithRect:bounds];
            annotationsContents[annotationsIdx] = annotationContents;
            annotationsClass[annotationsIdx] = [thisAnnotation class];
            
            annotationsIdx++;
        }        
        
    } //loop over pdf's annotations
    
    //now create a sorting variable. We'll assume much text is in two columns and want therefore to sort by y first on left half of the page, and then right half. So, take the min x of bounds + largeNumber*(isOnRightHalf?1:0) to get a monotonic sort
        //isOnRightHalf I guess is defined if min x of bounds > pagewidth/2?
    
    //now loop over collected annotations and format them and output a string containing annotations for this page
    outputText = [ NSMutableString stringWithCapacity:100 ];
    
    for (int i=0; i<[annotationsClass count]; i++) {

            // assemble annotation text & note (contents). Could get fancy: if note has two paras,
            //  make first a heading (only if begin with #?) and second a post-text comment:
            // ## fist para of comment (only if have > 1 para)
            // selection text
            //      remainder of comment
            //
        
        if ([annotationsClass[i] isEqual:[PDFAnnotationMarkup class]])  {

            annotationsHilightedText[i] = [NSString stringWithFormat:@"&quot;%@&quot;", annotationsHilightedText[i]]; // in quotes
            
            NSArray *contentParts = [escapeForHTML(annotationsContents[i]) componentsSeparatedByString:@"<br><br>"];

            switch ([contentParts count]) {
                case 0: //no note
                {
                    [outputText appendFormat:@"%@<br><br>", annotationsHilightedText[i] ];
                    break;
                }
                    
                case 1: //simple comment, indent and italicize
                {
                    NSString *note = [contentParts objectAtIndex:0];
                    if ([note length] > 0) {
                        note = escapeForHTML(note);
                        [outputText appendFormat:@"%@<br>\n&nbsp;&nbsp;&nbsp;&nbsp;<i>%@</i><br><br>\n\n", annotationsHilightedText[i], note];
                    } else {
                        [outputText appendFormat:@"%@<br><br>\n\n", annotationsHilightedText[i]];                        
                    }
                    break;
                }
                    
                default: //comment w/ header: first para becomes header; remainder italicize after quote
                {
                    NSMutableArray *parts = [NSMutableArray arrayWithArray:contentParts];
                    NSString *hdr = [parts objectAtIndex:0];
                    
                    [parts removeObjectAtIndex:0];
                    [outputText appendFormat:@"<h3>%@</h3>\n%@<br>\n&nbsp;&nbsp;&nbsp;&nbsp;<i>%@</i><br><br>\n\n", hdr, annotationsHilightedText[i], [parts componentsJoinedByString:@"<br>" ] ];
                    break;
                }
            }


        // free text, direct
        } else if ( [annotationsClass[i] isEqual:[PDFAnnotationFreeText class]] ) {
            if ([annotationsContents[i] length] > 0) {
                [outputText appendFormat:@"\n[<i>%@</i>]<br><br>\n\n", annotationsContents[i]];
            }
        }
    } // loop over output annotations
    
    // sanitize text (force to UTF-8) incase we want to pipe to pandoc to render
    //  rich text
    outputText = [[NSString alloc] initWithData: [outputText dataUsingEncoding: NSASCIIStringEncoding allowLossyConversion:YES] encoding:NSASCIIStringEncoding];
    return outputText;
    
}

// fix hyphens and stray line-breaks in selected text. Will also remove hyphen from
//  truly hyphenated words if they happen to span a line break.
NSString *deHyphenate(NSString *aString) {
    return [[[[aString stringByReplacingOccurrencesOfString:@"- " withString:@""] \
            stringByReplacingOccurrencesOfString:@"\r\n" withString:@" "] \
            stringByReplacingOccurrencesOfString:@"\r" withString:@" "] \
            stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
}

// escape text for embedding in html
NSString *escapeForHTML(NSString *aString) {
    return [[[[[[aString stringByReplacingOccurrencesOfString: @"&" withString: @"&amp;amp;"]
                stringByReplacingOccurrencesOfString: @"\"" withString: @"&amp;quot;"]
               stringByReplacingOccurrencesOfString: @"'" withString: @"&amp;#39;"]
              stringByReplacingOccurrencesOfString: @">" withString: @"&amp;gt;"]
             stringByReplacingOccurrencesOfString: @"<" withString: @"&amp;lt;"]
            stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
}



