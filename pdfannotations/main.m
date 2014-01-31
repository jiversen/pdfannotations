//
//  main.m
//  pdfannotations
//
//  Created by John Iversen on 9/26/11.
//  Copyright 2011 technophobe-anodyne. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>

void processPage(PDFPage *aPage);
NSString *styledTextForAnnotations(NSArray *annotations);
NSString *deHyphenate(NSString *aString);

int main (int argc, const char * argv[])
{
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    PDFDocument *pdfDoc;
    NSString *fname;
    

    if (argc < 2) {
        fname = @"/Users/Shared/dev/Projects/annotations/hilighttest.pdf";
        //fname = @"/Users/Shared/dev/Projects/annotations/Zarco.pdf";
        //fname = @"/Users/jri/Documents/Papers2/Articles/Conway/Conway 2009 - The Importance of Sound for Cognitive Sequencing Abilities The Auditory Scaffolding Hypothesis - Curr Dir Psych Sci.pdf";
        //fname = @"/blorg";
        //fprintf(stdout, "Usage: %s fname.pdf\n", argv[0]);
        //exit(1);
    } else {
        fname = [NSString stringWithUTF8String:argv[1]];
    }

    pdfDoc = [[PDFDocument alloc] initWithURL: [NSURL fileURLWithPath: fname ]];
    if (pdfDoc == NULL) {
        fprintf(stderr,"%s: %s appears not to be a valid pdf file.\n", argv[0], [fname UTF8String]);
        exit(2);
    }
    
    NSUInteger nPage = [pdfDoc pageCount];
    //NSLog(@"%lu pages.",nPage);
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    //NSString *dft = [NSDateFormatter dateFormatFromTemplate:@"MM/dd/yyyy h:mm:ss a" options:0 locale:nil];
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    NSString *header = [NSString stringWithFormat:@"%@\n\n%lu pages.\n\n%@\n\n", fname, [pdfDoc pageCount], date];
    [header writeToFile:@"/dev/stdout" atomically:NO];
    
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
        pageText = [NSString stringWithFormat:@"# Page %@\n\n", [aPage label]];
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
    
    outputText = [ NSMutableString stringWithCapacity:100 ];
    

    for (thisAnnotation in annotations) {
        annotationType = [thisAnnotation type];
        annotationContents = [thisAnnotation contents]; //contains text of note or text box
        annotationPage = [thisAnnotation page];
        
        //markup, extract text
        if ( [thisAnnotation isKindOfClass:[PDFAnnotationMarkup class]] ) {
            //find start and end of highlighted region
            quadPoints = [thisAnnotation quadrilateralPoints];
            //nQuads = [quadPoints count] / 4;
            bounds = [thisAnnotation bounds];
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
            annotationText = [NSString stringWithFormat:@"\"%@\"", annotationText]; // in quotes
            
            // underlined text becomes bold
            //  TODO: underline within hilight: if hilight, search annotations for
            //  any underlines within it. Generally such an annotation will be created after the parent
            //  so could check only previous.
            if ([annotationType isEqualToString: @"Underline"]) {
                //check if it falls within another annotation
                annotationText = [NSString stringWithFormat:@"**%@**", annotationText];
            } 
            
            // assemble annotation text & note (contents). Could get fancy: if note has two paras,
            //  make first a heading (only if begin with #?) and second a post-text comment:
            // ## fist para of comment (only if have > 1 para)
            // selection text
            //      remainder of comment
            //
            
            NSArray *contentParts = [annotationContents componentsSeparatedByString:@"\n\n"];

            switch ([contentParts count]) {
                case 0: //no note
                {
                    [outputText appendFormat:@"%@\n\n", annotationText];
                    break;
                }
                    
                case 1: //simple comment, italicize
                {
                    NSString *note = [contentParts objectAtIndex:0];
                    if ([note length] > 0) {
                        [outputText appendFormat:@"%@\n\n\t_%@_\n\n", annotationText, note];
                    } else {
                        [outputText appendFormat:@"%@\n\n", annotationText];                        
                    }
                    break;
                }
                    
                    
                default: //comment w/ header
                {
                    NSMutableArray *parts = [NSMutableArray arrayWithArray:contentParts];
                    NSString *hdr = [parts objectAtIndex:0];
                    [parts removeObjectAtIndex:0];
                    [outputText appendFormat:@"\n## %@\n\n%@\n\n\t_%@_\n\n", hdr, annotationText, [parts componentsJoinedByString:@"\n" ] ];
                    break;
                }
            }


        // free text, direct
        } else if ([thisAnnotation isKindOfClass:[PDFAnnotationFreeText class]]) {
            if ([annotationContents length] > 0) {
                [outputText appendFormat:@"\n_%@_\n\n", annotationContents];
            }
        }
    }
    
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

