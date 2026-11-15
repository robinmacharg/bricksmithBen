//==============================================================================
//
//  RelatedParts.h
//  Bricksmith
//
//  Created by bsupnik on 2/24/13.
//  Copyright 2013. All rights reserved.
//
//==============================================================================

#if WANT_RELATED_PARTS

#import <Cocoa/Cocoa.h>
#import "MatrixMath.h"

////////////////////////////////////////////////////////////////////////////////
//
// class RelatedPart
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface RelatedPart : NSObject
{
	NSString		*parent;
	NSString		*child;
	NSString		*childName;
	NSString		*role;
	GLfloat			transform[16];
}

- (null_unspecified id)			initWithParent:(null_unspecified NSString *) parentName
						offset:(null_unspecified GLfloat *) offset
					  relation:(null_unspecified NSString *) relation
					 childLine:(null_unspecified NSString *) line;
					 
- (void)		dump;

- (null_unspecified NSString*)	parent;
- (null_unspecified NSString*)	child;
- (null_unspecified NSString*)	childName;
- (null_unspecified NSString*)	role;
- (TransformComponents)	calcChildPosition:(TransformComponents)parentPosition;

@end

////////////////////////////////////////////////////////////////////////////////
//
// class RelatedParts
//
////////////////////////////////////////////////////////////////////////////////
@interface RelatedParts : NSObject 
{
	NSArray *		relatedParts;

}

+ (null_unspecified RelatedParts*)sharedRelatedParts;
- (null_unspecified id)			initWithFilePath:(null_unspecified NSString *)filePath;
- (void)		dump;

// First level search: given a parent, these return an array of strings
// all valid roles or children.
- (null_unspecified NSArray*)	getChildPartList:(null_unspecified NSString *)parent;
- (null_unspecified NSArray*)	getChildRoleList:(null_unspecified NSString *)parent;

// Second level search: given the parent and one of the role or child,
// get the completions.  (There can be more than one, e.g. for a red wheels and "left tire"
// we expect to get the big and small tires).  
// The array is na array of complete RelatedPart objects.
- (null_unspecified NSArray*)	getRelatedPartList:(null_unspecified NSString*) parent withRole:(null_unspecified NSString*) role;
- (null_unspecified NSArray*)	getRelatedPartList:(null_unspecified NSString*) parent withChild:(null_unspecified NSString*) role;

@end

NS_ASSUME_NONNULL_END

#endif /* WANT_RELATED_PARTS */
