//
//  HTMLParser.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLParser.h"
#import "HTMLTokenizer.h"

typedef NS_ENUM(NSInteger, HTMLInsertionMode)
{
    HTMLInitialInsertionMode,
    HTMLBeforeHtmlInsertionMode,
    HTMLBeforeHeadInsertionMode,
    HTMLInHeadInsertionMode,
    HTMLInHeadNoscriptInsertionMode,
    HTMLAfterHeadInsertionMode,
    HTMLInBodyInsertionMode,
    HTMLTextInsertionMode,
    HTMLInTableInsertionMode,
    HTMLInTableTextInsertionMode,
    HTMLInCaptionInsertionMode,
    HTMLInColumnGroupInsertionMode,
    HTMLInTableBodyInsertionMode,
    HTMLInRowInsertionMode,
    HTMLInCellInsertionMode,
    HTMLInSelectInsertionMode,
    HTMLInSelectInTableInsertionMode,
    HTMLInTemplateInsertionMode,
    HTMLAfterBodyInsertionMode,
    HTMLInFramesetInsertionMode,
    HTMLAfterFramesetInsertionMode,
    HTMLAfterAfterBodyInsertionMode,
    HTMLAfterAfterFramesetInsertionMode,
};

@implementation HTMLParser
{
    HTMLTokenizer *_tokenizer;
    HTMLInsertionMode _insertionMode;
    HTMLInsertionMode _originalInsertionMode;
    HTMLElementNode *_context;
    NSMutableArray *_stackOfOpenElements;
    HTMLElementNode *_headElementPointer;
    HTMLDocument *_document;
    NSMutableArray *_errors;
}

- (id)initWithString:(NSString *)string context:(HTMLElementNode *)context
{
    if (!(self = [super init])) return nil;
    _tokenizer = [[HTMLTokenizer alloc] initWithString:string];
    _insertionMode = HTMLInitialInsertionMode;
    _context = context;
    _stackOfOpenElements = [NSMutableArray new];
    _errors = [NSMutableArray new];
    return self;
}

- (HTMLDocument *)document
{
    if (_document) return _document;
    _document = [HTMLDocument new];
    for (id token in _tokenizer) {
        [self resume:token];
    }
    return _document;
}

- (NSArray *)errors
{
    return [_errors copy];
}

- (void)resume:(id)currentToken
{
    switch (_insertionMode) {
        case HTMLInitialInsertionMode:
            if ([currentToken isKindOfClass:[HTMLCharacterToken class]]) {
                HTMLCharacterToken *token = currentToken;
                switch (token.data) {
                    case '\t':
                    case '\n':
                    case '\f':
                    case '\r':
                    case ' ':
                        return;
                }
            }
            if ([currentToken isKindOfClass:[HTMLCommentToken class]]) {
                HTMLCommentToken *token = currentToken;
                [self insertComment:token.data inNode:_document];
            } else if ([currentToken isKindOfClass:[HTMLDOCTYPEToken class]]) {
                HTMLDOCTYPEToken *token = currentToken;
                if (DOCTYPEIsParseError(token)) {
                    [self addParseError];
                }
                _document.doctype = [[HTMLDocumentTypeNode alloc] initWithName:token.name ?: @""
                                                                      publicId:token.publicIdentifier ?: @""
                                                                      systemId:token.systemIdentifier ?: @""];
                _document.quirksMode = QuirksModeForDOCTYPE(token);
                [self switchInsertionMode:HTMLBeforeHtmlInsertionMode];
            } else {
                [self addParseError];
                _document.quirksMode = HTMLQuirksMode;
                [self switchInsertionMode:HTMLBeforeHtmlInsertionMode];
                [self resume:currentToken];
            }
            break;
            
        case HTMLBeforeHtmlInsertionMode:
            if ([currentToken isKindOfClass:[HTMLCharacterToken class]]) {
                HTMLCharacterToken *token = currentToken;
                switch (token.data) {
                    case '\t':
                    case '\n':
                    case '\f':
                    case '\r':
                    case ' ':
                        return;
                }
            }
            if ([currentToken isKindOfClass:[HTMLDOCTYPEToken class]]) {
                [self addParseError];
                return;
            } else if ([currentToken isKindOfClass:[HTMLCommentToken class]]) {
                HTMLCommentToken *token = currentToken;
                [self insertComment:token.data inNode:_document];
            } else if ([currentToken isKindOfClass:[HTMLStartTagToken class]] &&
                       [[currentToken tagName] isEqualToString:@"html"])
            {
                if ([currentToken selfClosingFlag]) {
                    [self addParseError];
                }
                HTMLElementNode *html = [self createElementForToken:currentToken];
                [_document addChildNode:html];
                [_stackOfOpenElements addObject:html];
                [self switchInsertionMode:HTMLBeforeHeadInsertionMode];
            } else if ([currentToken isKindOfClass:[HTMLEndTagToken class]] &&
                       !([[currentToken tagName] isEqualToString:@"head"] ||
                         [[currentToken tagName] isEqualToString:@"body"] ||
                         [[currentToken tagName] isEqualToString:@"html"] ||
                         [[currentToken tagName] isEqualToString:@"br"]))
            {
                [self addParseError];
                return;
            } else {
                HTMLElementNode *html = [[HTMLElementNode alloc] initWithTagName:@"html"];
                [_document addChildNode:html];
                [_stackOfOpenElements addObject:html];
                [self switchInsertionMode:HTMLBeforeHeadInsertionMode];
                [self resume:currentToken];
            }
            break;
            
        case HTMLBeforeHeadInsertionMode:
            if ([currentToken isKindOfClass:[HTMLCharacterToken class]]) {
                HTMLCharacterToken *token = currentToken;
                switch (token.data) {
                    case '\t':
                    case '\n':
                    case '\f':
                    case '\r':
                    case ' ':
                        return;
                }
            }
            if ([currentToken isKindOfClass:[HTMLCommentToken class]]) {
                HTMLCommentToken *token = currentToken;
                [self insertComment:token.data inNode:nil];
            } else if ([currentToken isKindOfClass:[HTMLDOCTYPEToken class]]) {
                [self addParseError];
                return;
            } else if ([currentToken isKindOfClass:[HTMLStartTagToken class]] &&
                       [[currentToken tagName] isEqualToString:@"html"])
            {
                [self processToken:currentToken usingRulesForInsertionMode:HTMLInBodyInsertionMode];
            } else if ([currentToken isKindOfClass:[HTMLStartTagToken class]] &&
                       [[currentToken tagName] isEqualToString:@"head"])
            {
                if ([currentToken selfClosingFlag]) {
                    [self addParseError];
                }
                HTMLElementNode *head = [self insertElementForToken:currentToken];
                _headElementPointer = head;
                [self switchInsertionMode:HTMLInHeadInsertionMode];
            } else if ([currentToken isKindOfClass:[HTMLEndTagToken class]] &&
                       !([[currentToken tagName] isEqualToString:@"head"] ||
                         [[currentToken tagName] isEqualToString:@"body"] ||
                         [[currentToken tagName] isEqualToString:@"html"] ||
                         [[currentToken tagName] isEqualToString:@"br"]))
            {
                [self addParseError];
                return;
            } else {
                if ([currentToken isKindOfClass:[HTMLStartTagToken class]] && [currentToken selfClosingFlag]) {
                    [self addParseError];
                }
                [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"head"]];
                HTMLElementNode *head = [[HTMLElementNode alloc] initWithTagName:@"head"];
                _headElementPointer = head;
                [self switchInsertionMode:HTMLInHeadInsertionMode];
                [self resume:currentToken];
            }
            break;
            
        case HTMLInHeadInsertionMode:
            if ([currentToken isKindOfClass:[HTMLCharacterToken class]]) {
                HTMLCharacterToken *token = currentToken;
                switch (token.data) {
                    case '\t':
                    case '\n':
                    case '\f':
                    case '\r':
                    case ' ':
                        [self insertCharacter:token.data];
                        return;
                }
            }
            if ([currentToken isKindOfClass:[HTMLCommentToken class]]) {
                [self insertComment:[(HTMLCommentToken *)currentToken data] inNode:nil];
            } else if ([currentToken isKindOfClass:[HTMLDOCTYPEToken class]]) {
                [self addParseError];
                return;
            } else if ([currentToken isKindOfClass:[HTMLStartTagToken class]] &&
                       [[currentToken tagName] isEqualToString:@"html"])
            {
                [self processToken:currentToken usingRulesForInsertionMode:HTMLInBodyInsertionMode];
            } else if ([currentToken isKindOfClass:[HTMLStartTagToken class]] &&
                       ([[currentToken tagName] isEqualToString:@"base"] ||
                        [[currentToken tagName] isEqualToString:@"basefont"] ||
                        [[currentToken tagName] isEqualToString:@"bgsound"] ||
                        [[currentToken tagName] isEqualToString:@"link"]))
            {
                [self insertElementForToken:currentToken];
                [_stackOfOpenElements removeLastObject];
            } else if ([currentToken isKindOfClass:[HTMLStartTagToken class]] &&
                       [[currentToken tagName] isEqualToString:@"meta"])
            {
                [self insertElementForToken:currentToken];
                [_stackOfOpenElements removeLastObject];
            } else if ([currentToken isKindOfClass:[HTMLStartTagToken class]] &&
                       [[currentToken tagName] isEqualToString:@"title"])
            {
                [self insertElementForToken:currentToken];
                _tokenizer.state = HTMLTokenizerRCDATAState;
                _originalInsertionMode = _insertionMode;
                [self switchInsertionMode:HTMLTextInsertionMode];
            } else if ([currentToken isKindOfClass:[HTMLStartTagToken class]] &&
                       ([[currentToken tagName] isEqualToString:@"noframes"] ||
                        [[currentToken tagName] isEqualToString:@"style"]))
            {
                [self insertElementForToken:currentToken];
                _tokenizer.state = HTMLTokenizerRAWTEXTState;
                _originalInsertionMode = _insertionMode;
                [self switchInsertionMode:HTMLTextInsertionMode];
            } else if ([currentToken isKindOfClass:[HTMLStartTagToken class]] &&
                       [[currentToken tagName] isEqualToString:@"noscript"])
            {
                [self insertElementForToken:currentToken];
                [self switchInsertionMode:HTMLInHeadNoscriptInsertionMode];
            } else if ([currentToken isKindOfClass:[HTMLStartTagToken class]] &&
                       [[currentToken tagName] isEqualToString:@"script"])
            {
                id adjustedInsertionLocation = [self appropriatePlaceForInsertingANode];
                HTMLElementNode *script = [self createElementForToken:currentToken];
                [adjustedInsertionLocation addChildNode:script];
                [_stackOfOpenElements addObject:script];
                _tokenizer.state = HTMLTokenizerScriptDataState;
                _originalInsertionMode = _insertionMode;
                [self switchInsertionMode:HTMLTextInsertionMode];
            } else if ([currentToken isKindOfClass:[HTMLEndTagToken class]] &&
                       [[currentToken tagName] isEqualToString:@"head"])
            {
                [_stackOfOpenElements removeLastObject];
                [self switchInsertionMode:HTMLAfterHeadInsertionMode];
            } else if ([currentToken isKindOfClass:[HTMLStartTagToken class]] &&
                       [[currentToken tagName] isEqualToString:@"head"])
            {
                [self addParseError];
                return;
            } else if ([currentToken isKindOfClass:[HTMLEndTagToken class]] &&
                       !([[currentToken tagName] isEqualToString:@"body"] ||
                         [[currentToken tagName] isEqualToString:@"html"] ||
                         [[currentToken tagName] isEqualToString:@"br"]))
            {
                [self addParseError];
                return;
            } else {
                [_stackOfOpenElements removeLastObject];
                [self switchInsertionMode:HTMLAfterHeadInsertionMode];
                [self resume:currentToken];
            }
            break;
            
        case HTMLInHeadNoscriptInsertionMode:
        case HTMLAfterHeadInsertionMode:
        case HTMLInBodyInsertionMode:
        case HTMLTextInsertionMode:
        case HTMLInTableInsertionMode:
        case HTMLInTableTextInsertionMode:
        case HTMLInCaptionInsertionMode:
        case HTMLInColumnGroupInsertionMode:
        case HTMLInTableBodyInsertionMode:
        case HTMLInRowInsertionMode:
        case HTMLInCellInsertionMode:
        case HTMLInSelectInsertionMode:
        case HTMLInSelectInTableInsertionMode:
        case HTMLInTemplateInsertionMode:
        case HTMLAfterBodyInsertionMode:
        case HTMLInFramesetInsertionMode:
        case HTMLAfterFramesetInsertionMode:
        case HTMLAfterAfterBodyInsertionMode:
        case HTMLAfterAfterFramesetInsertionMode:
            // TODO
            break;
    }
}

- (void)insertComment:(NSString *)data inNode:(id)node
{
    if (!node) node = [self appropriatePlaceForInsertingANode];
    [node addChildNode:[[HTMLCommentNode alloc] initWithData:data]];
}

- (id)appropriatePlaceForInsertingANode
{
    return _stackOfOpenElements.lastObject;
}

- (void)switchInsertionMode:(HTMLInsertionMode)insertionMode
{
    _insertionMode = insertionMode;
}

- (id)createElementForToken:(id)token
{
    HTMLElementNode *element = [[HTMLElementNode alloc] initWithTagName:[token tagName]];
    for (HTMLAttribute *attribute in [token attributes]) {
        [element addAttribute:attribute];
    }
    return element;
}

- (id)insertElementForToken:(id)token
{
    id adjustedInsertionLocation = [self appropriatePlaceForInsertingANode];
    HTMLElementNode *element = [self createElementForToken:token];
    [adjustedInsertionLocation addChildNode:element];
    [_stackOfOpenElements addObject:element];
    return element;
}

- (void)insertCharacter:(UTF32Char)character
{
    id adjustedInsertionLocation = [self appropriatePlaceForInsertingANode];
    if ([adjustedInsertionLocation isKindOfClass:[HTMLDocument class]]) return;
    HTMLTextNode *textNode;
    if ([[[adjustedInsertionLocation childNodes] lastObject] isKindOfClass:[HTMLTextNode class]]) {
        textNode = [[adjustedInsertionLocation childNodes] lastObject];
    } else {
        textNode = [HTMLTextNode new];
        [adjustedInsertionLocation addChildNode:textNode];
    }
    [textNode appendLongCharacter:character];
}

- (void)processToken:(id)token usingRulesForInsertionMode:(HTMLInsertionMode)insertionMode
{
    HTMLInsertionMode oldMode = _insertionMode;
    _insertionMode = insertionMode;
    [self resume:token];
    if (_insertionMode == insertionMode) {
        _insertionMode = oldMode;
    }
}

static BOOL DOCTYPEIsParseError(HTMLDOCTYPEToken *t)
{
    NSString *name = t.name, *public = t.publicIdentifier, *system = t.systemIdentifier;
    if (![name isEqualToString:@"html"]) return YES;
    if ([public isEqualToString:@"-//W3C//DTD HTML 4.0//EN"] &&
        (!system || [system isEqualToString:@"http://www.w3.org/TR/REC-html40/strict.dtd"]))
    {
        return NO;
    }
    if ([public isEqualToString:@"-//W3C//DTD HTML 4.01//EN"] &&
        (!system || [system isEqualToString:@"http://www.w3.org/TR/html4/strict.dtd"]))
    {
        return NO;
    }
    if ([public isEqualToString:@"-//W3C//DTD XHTML 1.0 Strict//EN"] &&
        [system isEqualToString:@"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"])
    {
        return NO;
    }
    if ([public isEqualToString:@"-//W3C//DTD XHTML 1.1//EN"] &&
        [system isEqualToString:@"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"])
    {
        return NO;
    }
    if (public) return YES;
    if (system && ![system isEqualToString:@"about:legacy-compat"]) return YES;
    return NO;
}

static HTMLDocumentQuirksMode QuirksModeForDOCTYPE(HTMLDOCTYPEToken *t)
{
    if (t.forceQuirks) return HTMLQuirksMode;
    if (![t.name isEqualToString:@"html"]) return HTMLQuirksMode;
    static NSString * Prefixes[] = {
        @"+//Silmaril//dtd html Pro v0r11 19970101//",
        @"-//AdvaSoft Ltd//DTD HTML 3.0 asWedit + extensions//",
        @"-//AS//DTD HTML 3.0 asWedit + extensions//",
        @"-//IETF//DTD HTML 2.0 Level 1//",
        @"-//IETF//DTD HTML 2.0 Level 2//",
        @"-//IETF//DTD HTML 2.0 Strict Level 1//",
        @"-//IETF//DTD HTML 2.0 Strict Level 2//",
        @"-//IETF//DTD HTML 2.0 Strict//",
        @"-//IETF//DTD HTML 2.0//",
        @"-//IETF//DTD HTML 2.1E//",
        @"-//IETF//DTD HTML 3.0//",
        @"-//IETF//DTD HTML 3.2 Final//",
        @"-//IETF//DTD HTML 3.2//",
        @"-//IETF//DTD HTML 3//",
        @"-//IETF//DTD HTML Level 0//",
        @"-//IETF//DTD HTML Level 1//",
        @"-//IETF//DTD HTML Level 2//",
        @"-//IETF//DTD HTML Level 3//",
        @"-//IETF//DTD HTML Strict Level 0//",
        @"-//IETF//DTD HTML Strict Level 1//",
        @"-//IETF//DTD HTML Strict Level 2//",
        @"-//IETF//DTD HTML Strict Level 3//",
        @"-//IETF//DTD HTML Strict//",
        @"-//IETF//DTD HTML//",
        @"-//Metrius//DTD Metrius Presentational//",
        @"-//Microsoft//DTD Internet Explorer 2.0 HTML Strict//",
        @"-//Microsoft//DTD Internet Explorer 2.0 HTML//",
        @"-//Microsoft//DTD Internet Explorer 2.0 Tables//",
        @"-//Microsoft//DTD Internet Explorer 3.0 HTML Strict//",
        @"-//Microsoft//DTD Internet Explorer 3.0 HTML//",
        @"-//Microsoft//DTD Internet Explorer 3.0 Tables//",
        @"-//Netscape Comm. Corp.//DTD HTML//",
        @"-//Netscape Comm. Corp.//DTD Strict HTML//",
        @"-//O'Reilly and Associates//DTD HTML 2.0//",
        @"-//O'Reilly and Associates//DTD HTML Extended 1.0//",
        @"-//O'Reilly and Associates//DTD HTML Extended Relaxed 1.0//",
        @"-//SoftQuad Software//DTD HoTMetaL PRO 6.0::19990601::extensions to HTML 4.0//",
        @"-//SoftQuad//DTD HoTMetaL PRO 4.0::19971010::extensions to HTML 4.0//",
        @"-//Spyglass//DTD HTML 2.0 Extended//",
        @"-//SQ//DTD HTML 2.0 HoTMetaL + extensions//",
        @"-//Sun Microsystems Corp.//DTD HotJava HTML//",
        @"-//Sun Microsystems Corp.//DTD HotJava Strict HTML//",
        @"-//W3C//DTD HTML 3 1995-03-24//",
        @"-//W3C//DTD HTML 3.2 Draft//",
        @"-//W3C//DTD HTML 3.2 Final//",
        @"-//W3C//DTD HTML 3.2//",
        @"-//W3C//DTD HTML 3.2S Draft//",
        @"-//W3C//DTD HTML 4.0 Frameset//",
        @"-//W3C//DTD HTML 4.0 Transitional//",
        @"-//W3C//DTD HTML Experimental 19960712//",
        @"-//W3C//DTD HTML Experimental 970421//",
        @"-//W3C//DTD W3 HTML//",
        @"-//W3O//DTD W3 HTML 3.0//",
        @"-//WebTechs//DTD Mozilla HTML 2.0//",
        @"-//WebTechs//DTD Mozilla HTML//",
    };
    for (size_t i = 0; i < sizeof(Prefixes) / sizeof(Prefixes[0]); i++) {
        if ([t.publicIdentifier hasPrefix:Prefixes[i]]) {
            return HTMLQuirksMode;
        }
    }
    if ([t.publicIdentifier isEqualToString:@"-//W3O//DTD W3 HTML Strict 3.0//EN//"] ||
        [t.publicIdentifier isEqualToString:@"-/W3C/DTD HTML 4.0 Transitional/EN"] ||
        [t.publicIdentifier isEqualToString:@"HTML"])
    {
        return HTMLQuirksMode;
    }
    if ([t.systemIdentifier isEqualToString:@"http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd"]) {
        return HTMLQuirksMode;
    }
    if (!t.systemIdentifier) {
        if ([t.publicIdentifier hasPrefix:@"-//W3C//DTD HTML 4.01 Frameset//"] ||
            [t.publicIdentifier hasPrefix:@"-//W3C//DTD HTML 4.01 Transitional//"])
        {
            return HTMLQuirksMode;
        }
    }
    if ([t.publicIdentifier hasPrefix:@"-//W3C//DTD XHTML 1.0 Frameset//"] ||
        [t.publicIdentifier hasPrefix:@"-//W3C//DTD XHTML 1.0 Transitional//"])
    {
        return HTMLLimitedQuirksMode;
    }
    if (t.systemIdentifier) {
        if ([t.publicIdentifier hasPrefix:@"-//W3C//DTD HTML 4.01 Frameset//"] ||
            [t.publicIdentifier hasPrefix:@"-//W3C//DTD HTML 4.01 Transitional//"])
        {
            return HTMLLimitedQuirksMode;
        }
    }
    return HTMLNoQuirksMode;
}

- (void)addParseError
{
    [_errors addObject:[NSNull null]];
}

@end