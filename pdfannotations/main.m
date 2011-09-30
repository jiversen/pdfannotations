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
        fname = @"/Users/jri/Documents/dev/annotations/hilighttest.pdf";
        //fname = @"/Users/jri/Documents/dev/annotations/Zarco.pdf";
    } else {
        fname = [NSString stringWithUTF8String:argv[1]];
    }

    pdfDoc = [[PDFDocument alloc] initWithURL: [NSURL fileURLWithPath: fname ]];
    NSUInteger nPage = [pdfDoc pageCount];
    //NSLog(@"%lu pages.",nPage);

    
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
        
        [pageText   writeToFile:@"/dev/stdout" atomically:NO];
        [outputText writeToFile:@"/dev/stdout" atomically:NO];
    }
    

}


// find #quads/4, loop over quads, get text within each quad, concatenate
// page points are bounds (1) + quadrilateralPoints
// get contents
// later: find underline within hilight

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
        annotationContents = [thisAnnotation contents];
        annotationPage = [thisAnnotation page];
        
        //markup, extract text
        if ( [thisAnnotation isKindOfClass:[PDFAnnotationMarkup class]] ) {
            //find start and end of highlighted region
            quadPoints = [thisAnnotation quadrilateralPoints];
            //nQuads = [quadPoints count] / 4;
            bounds = [thisAnnotation bounds];
            start = [[quadPoints objectAtIndex:0] pointValue];
            end = [[quadPoints objectAtIndex:[quadPoints count] - 3] pointValue];
            
            midy = (start.y + [[quadPoints objectAtIndex:2] pointValue].y)/2;
            start.y = midy;
            
            midy = (end.y + [[quadPoints objectAtIndex:[quadPoints count] - 2] pointValue].y)/2;
            end.y = midy;
            
            start.x += bounds.origin.x;
            start.y += bounds.origin.y;
            end.x += bounds.origin.x;
            end.y += bounds.origin.y;
            
            sel = [annotationPage selectionFromPoint:start toPoint:end];
            annotationText = deHyphenate([sel string]);
            
            // underlined text becomes bold
            //  TODO: underline within hilight: if hilight, search annotations for
            //  any underlines within it.
            if (annotationType == @"Underline") {
                annotationText = [NSString stringWithFormat:@"x %@ x", annotationText];
            } 
            
            // assemble annotation text & note. Could get fancy: if note has two paras,
            //  make first a heading (only if begin with #?) and second a post-text comment:
            // ## fist para of comment (only if have > 1 para)
            // selection text
            //      remainder of comment
            //
                        
            [outputText appendFormat:@"%@\nText: %@\nContents: %@\n\n", 
             annotationType, annotationText, annotationContents];

        // free text, direct
        } else if ([thisAnnotation isKindOfClass:[PDFAnnotationFreeText class]]) {
            if ([annotationContents length] > 0) {
                [outputText appendFormat:@"%@: %@\n\n", annotationType, annotationContents];
            }
        }
    }
    
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

