//==============================================================================
//
// File:		LDrawFile.h
//
// Purpose:		Represents an LDraw file, composed of one or more models.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "LDrawDirective.h"
#import "LDrawContainer.h"

// forward declarations
@class LDrawMPDModel;


//Active model changed.
// Object is the LDrawFile in which the model resides. No userInfo.
#define LDrawFileActiveModelDidChangeNotification		@"LDrawFileActiveModelDidChangeNotification"


////////////////////////////////////////////////////////////////////////////////
//
// class LDrawFile
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface LDrawFile : LDrawContainer
{
	NSDictionary	*nameModelDict;
	LDrawMPDModel	*activeModel;
	NSString		*filePath;			//where this file came from on disk.
}

// Initialization
+ (null_unspecified LDrawFile *) file NS_SWIFT_NAME(file());	// keep as a factory: imported as init() it would collide with -init (LEARNINGS L40)
+ (null_unspecified LDrawFile *) fileFromContentsAtPath:(null_unspecified NSString *)path;
+ (nullable LDrawFile *) parseFromFileContents:(null_unspecified NSString *) fileContents;
// As above; *parseFailed is YES when the text could not be parsed (a malformed final ROTSTEP), as opposed to nil
// for text with no lines.
+ (nullable LDrawFile *) parseFromFileContents:(null_unspecified NSString *) fileContents parseFailed:(nullable BOOL *)parseFailed;

// Accessors
- (null_unspecified LDrawMPDModel *) activeModel;
- (null_unspecified LDrawMPDModel *) firstModel;							// For using another file, we always refer to the FIRST model even if the doc is open and another model is actively edited!
- (void) addSubmodel:(null_unspecified LDrawMPDModel *)newSubmodel;
- (null_unspecified NSArray *) draggingDirectives;
- (null_unspecified NSArray *) modelNames;
- (null_unspecified LDrawMPDModel *) modelWithName:(null_unspecified NSString *)soughtName;
- (null_unspecified NSString *)path;
- (null_unspecified NSArray *) submodels;

- (void) setActiveModel:(null_unspecified LDrawMPDModel *)newModel;
- (void) setDraggingDirectives:(null_unspecified NSArray *)directives;
- (void) setPath:(null_unspecified NSString *)newPath;

// Utilities
- (void) optimizeStructure;
- (void) renameModel:(null_unspecified LDrawMPDModel *)submodel toName:(null_unspecified NSString *)newName;

@end

NS_ASSUME_NONNULL_END
