//  HTMLTreeEnumeratorTests.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <XCTest/XCTest.h>
#import "HTMLParser.h"

@interface HTMLTreeEnumeratorTests : XCTestCase

@end

@implementation HTMLTreeEnumeratorTests

- (void)testSingleNode
{
    HTMLNode *root = [self rootNodeWithString:@"<a>"];
    XCTAssertEqualObjects([root.treeEnumerator allObjects], @[ root ]);
}

- (void)testBalancedThreeNodes
{
    HTMLNode *parent = [self rootNodeWithString:@"<parent><child1></child1><child2>"];
    NSArray *nodes = [parent.treeEnumerator allObjects];
    NSArray *expectedOrder = @[ @"parent", @"child1", @"child2" ];
    XCTAssertEqualObjects([nodes valueForKey:@"tagName"], expectedOrder);
}

- (void)testBalancedThreeNodesReversed
{
    HTMLNode *parent = [self rootNodeWithString:@"<parent><child1></child1><child2>"];
    NSArray *nodes = [parent.reversedTreeEnumerator allObjects];
    NSArray *expectedOrder = @[ @"parent", @"child2", @"child1" ];
    XCTAssertEqualObjects([nodes valueForKey:@"tagName"], expectedOrder);
}

- (void)testChristmasTree
{
    HTMLNode *root = [self rootNodeWithString:@"<a><b><c></c></b><b><c><d></d></c><c></c></b>"];
    NSArray *nodes = [root.treeEnumerator allObjects];
    NSArray *expectedOrder = @[ @"a", @"b", @"c", @"b", @"c", @"d", @"c" ];
    XCTAssertEqualObjects([nodes valueForKey:@"tagName"], expectedOrder);
}

- (HTMLNode *)rootNodeWithString:(NSString *)string
{
    HTMLDocument *document = [[HTMLParser alloc] initWithString:string context:nil].document;
    HTMLElement *body = document.rootElement.children.lastObject;
    return body.children[0];
}

@end