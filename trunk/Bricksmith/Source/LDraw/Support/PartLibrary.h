//==============================================================================
//
// File:		PartLibrary.m
//
// Purpose:		This is the centralized repository for obtaining information 
//				about the contents of the LDraw folder.
//
//  Created by Allen Smith on 3/12/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>
#import "BricksmithBuildConfig.h"

#import "ColorLibrary.h"

@class LDrawDirective;
@class LDrawModel;
@class LDrawPart;
@class LDrawTexture;
@protocol PartLibraryDelegate;

//The part catalog was regenerated from disk.
// Object is the new catalog. No userInfo.
extern NSString * _Null_unspecified LDrawPartLibraryDidChangeNotification;

// Catalog info keys
extern NSString * _Null_unspecified PARTS_CATALOG_KEY;
extern NSString * _Null_unspecified PART_NUMBER_KEY;
extern NSString * _Null_unspecified PART_NAME_KEY;
extern NSString * _Null_unspecified PART_CATEGORY_KEY;
extern NSString * _Null_unspecified PART_KEYWORDS_KEY;
extern NSString * _Null_unspecified PARTS_LIST_KEY;
extern NSString * _Null_unspecified VERSION_KEY;
extern NSString * _Null_unspecified COMPATIBILITY_VERSION_KEY;

extern NSString * _Null_unspecified CategoryNameKey;
extern NSString * _Null_unspecified CategoryDisplayNameKey;
extern NSString * _Null_unspecified CategoryChildrenKey;

extern NSString * _Null_unspecified Category_All;
extern NSString * _Null_unspecified Category_Favorites;
extern NSString * _Null_unspecified Category_Alias;
extern NSString * _Null_unspecified Category_Moved;
extern NSString * _Null_unspecified Category_Primitives;
extern NSString * _Null_unspecified Category_Subparts;


////////////////////////////////////////////////////////////////////////////////
//
// class PartLibrary
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface PartLibrary : NSObject
{
	__weak id<PartLibraryDelegate> delegate;	// unretained under MRC (L77)
	NSDictionary            *partCatalog;
	NSMutableArray          *favorites;					// parts names in the "Favorites" pseduocategory
	NSMutableDictionary     *loadedFiles;				// list of LDrawFiles which have been read off disk.
	NSMutableDictionary		*loadedImages;
	NSMutableDictionary		*optimizedTextures;			// GLuint texture tags
	NSMutableDictionary     *optimizedRepresentations;	// access stored vertex objects by part name, then color.
}

// Initialization
+ (PartLibrary *) sharedPartLibrary;	// nonnull: allocated on first use (verified)

// Accessors
- (null_unspecified NSArray *) allPartCatalogRecords;
- (null_unspecified NSArray *) categories;
- (null_unspecified NSArray *) categoryHierarchy;
- (null_unspecified NSString *) displayNameForCategory:(null_unspecified NSString *)categoryName;
- (null_unspecified NSArray *) favoritePartNames;
- (null_unspecified NSArray *) favoritePartCatalogRecords;
- (null_unspecified NSArray *) partCatalogRecordsInCategory:(null_unspecified NSString *)category;
- (null_unspecified NSString *) categoryForPartName:(null_unspecified NSString *)partName;

- (void) setDelegate:(null_unspecified id<PartLibraryDelegate>)delegateIn;
- (void) setFavorites:(null_unspecified NSArray *)favoritesIn;
- (void) setPartCatalog:(null_unspecified NSDictionary *)newCatalog;

// Actions
- (BOOL) load;
- (void) reloadPartsWithMaxLoadCountHandler:(null_unspecified void (^)(NSUInteger maxPartCount))maxLoadCountHandler
				   progressIncrementHandler:(null_unspecified void (^)())progressIncrementHandler
						  completionHandler:(null_unspecified void (^)(BOOL success))completionHandler;

// Favorites
- (void) addPartNameToFavorites:(null_unspecified NSString *)partName;
- (void) removePartNameFromFavorites:(null_unspecified NSString *)partName;
- (void) saveFavoritesToUserDefaults;

// Finding Parts
- (void) loadImageForName:(null_unspecified NSString *)imageName inGroup:(null_unspecified dispatch_group_t)parentGroup;
- (void) loadModelForName:(null_unspecified NSString *)name inGroup:(null_unspecified dispatch_group_t)parentGroup;
- (null_unspecified CGImageRef) imageForTextureName:(null_unspecified NSString *)imageName;
- (null_unspecified CGImageRef) imageForTexture:(null_unspecified LDrawTexture *)texture;
- (null_unspecified CGImageRef) imageFromNeighboringFileForTexture:(null_unspecified LDrawTexture *)texture;
- (null_unspecified LDrawModel *) modelForName:(null_unspecified NSString *) partName;
- (null_unspecified LDrawModel *) modelForName_threadSafe:(null_unspecified NSString *) partName;

- (null_unspecified LDrawDirective *) optimizedDrawableForPart:(null_unspecified LDrawPart *) part color:(null_unspecified LDrawColor *)color;
- (GLuint) textureTagForTexture:(null_unspecified LDrawTexture*)texture;

// Utilites
- (null_unspecified NSString *)descriptionForPart:(null_unspecified LDrawPart *)part;
- (null_unspecified NSString *)descriptionForPartName:(null_unspecified NSString *)name;
- (null_unspecified CGImageRef) readImageAtPath:(null_unspecified NSString *)imagePath
				asynchronously:(BOOL)asynchronous
			 completionHandler:(null_unspecified void (^)(CGImageRef _Null_unspecified))completionBlock;
- (null_unspecified LDrawModel *) readModelAtPath:(null_unspecified NSString *)partPath
				  asynchronously:(BOOL)asynchronous
			   completionHandler:(null_unspecified void (^)(LDrawModel * _Null_unspecified))completionBlock;


// Test support (do not call from app code)
+ (void) resetForTesting;
@end


////////////////////////////////////////////////////////////////////////////////
//
// delegate PartLibraryReloadPartsDelegate
// (all methods are required)
//
////////////////////////////////////////////////////////////////////////////////
@protocol PartLibraryDelegate

- (void) partLibrary:(null_unspecified PartLibrary *)partLibrary didChangeFavorites:(null_unspecified NSArray *)newFavorites;

@end

NS_ASSUME_NONNULL_END

