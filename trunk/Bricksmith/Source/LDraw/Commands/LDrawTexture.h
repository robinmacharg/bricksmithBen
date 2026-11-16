//==============================================================================
//
// File:		LDrawTexture.h
//
// Purpose:		Support for projecting images onto LDraw geometry.
//
// Modified:	04/10/2012 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>
#import "BricksmithBuildConfig.h"

#import "LDrawContainer.h"

NS_ASSUME_NONNULL_BEGIN

@interface LDrawTexture : LDrawContainer
{
	NSArray 		*fallback;
	NSString		*imageDisplayName;
	NSString		*imageReferenceName;
	NSString		*glossmapName;
	
	Point3			planePoint1;
	Point3			planePoint2;
	Point3			planePoint3;
	
	NSArray			*dragHandles;
	Box3			cachedBounds;		// cached bounds of the enclosed directives
	
	GLuint			textureTag;
}

// Accessors
- (null_unspecified NSString *) glossmapName;
- (null_unspecified NSString *) imageDisplayName;
- (null_unspecified NSString *) imageReferenceName;

- (void) setGlossmapName:(null_unspecified NSString *)newName;
- (void) setImageDisplayName:(null_unspecified NSString *)newName;
- (void) setImageDisplayName:(null_unspecified NSString *)newName parse:(BOOL)shouldParse inGroup:(null_unspecified dispatch_group_t)parentGroup;

// Utilities
+ (BOOL) lineIsTextureBeginning:(null_unspecified NSString*)line;
+ (BOOL) lineIsTextureFallback:(null_unspecified NSString*)line;
+ (BOOL) lineIsTextureTerminator:(null_unspecified NSString*)line;
- (BOOL) parsePlanarTextureFromLine:(null_unspecified NSString *)line parentGroup:(null_unspecified dispatch_group_t)parentGroup;

@end

NS_ASSUME_NONNULL_END
