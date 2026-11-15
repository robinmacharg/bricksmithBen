//==============================================================================
//
// File:		LDrawPaths.h
//
// Purpose:		Looks up LDraw-related file locations.
//
// Modified:	05/03/2011 Allen Smith. Creation Date.
//
//==============================================================================
#import <Foundation/Foundation.h>

typedef NS_ENUM(int, LDrawDomain)
{
	LDrawUserOfficial		= 0,
	LDrawUserUnofficial		= 1,
	LDrawInternalOfficial	= 2,
	LDrawInternalUnofficial	= 3,
};


////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface LDrawPaths : NSObject
{
	NSString	*preferredLDrawPath;
}

+ (LDrawPaths *) sharedPaths;

// Accessors
- (nullable NSString *) preferredLDrawPath;					// nil until a folder is chosen
- (void) setPreferredLDrawPath:(nullable NSString *)pathIn;

// Standard paths
- (nullable NSString *) partsPathForDomain:(LDrawDomain)domain;		// nil for User domains when no folder is set
- (nullable NSString *) primitivesPathForDomain:(LDrawDomain)domain;
- (nullable NSString *) primitives48PathForDomain:(LDrawDomain)domain;
- (nullable NSString *) ldconfigPath;
- (nullable NSString *) MLCadIniPath;
- (nullable NSString *) partCatalogPath;
- (nullable NSString *) subpartsPathForDomain:(LDrawDomain)domain;

// Utilities
- (nullable NSString *) findLDrawPath;
- (nullable NSString *) pathForPartName:(NSString *)partName;		// nil if not found
- (nullable NSString *) pathForTextureName:(NSString *)imageName;	// nil if not found
- (BOOL) validateLDrawFolder:(nullable NSString *)folderPath;

// Test support (do not call from app code)
+ (void) resetForTesting;

@end

NS_ASSUME_NONNULL_END
