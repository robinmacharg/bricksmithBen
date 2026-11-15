//==============================================================================
//
// File:		LDrawMPDModel.h
//
// Purpose:		Represents a model which can be used as a submodel within a file.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "LDrawDirective.h"
#import "LDrawModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface LDrawMPDModel : LDrawModel <NSCoding>
{
	@private
	//MPD submodels have a name to identify them.
	// it gets written out as 0 FILE modelName at the beginning.
	NSString		*modelName;
	
}

+ (null_unspecified id) model NS_SWIFT_NAME(model());	// factory: keep distinct from -init (LEARNINGS L40)

// Directives
- (null_unspecified NSString *) writeModel;

// Accessors
- (null_unspecified NSString *) modelDisplayName;
- (null_unspecified NSString *)modelName;
- (void) setModelDisplayName:(null_unspecified NSString *)newDisplayName;
- (void) setModelName:(null_unspecified NSString *)newModelName;

// Utilities
+ (null_unspecified NSString *) ldrawCompliantNameForName:(null_unspecified NSString *)newDisplayName;
+ (BOOL) lineIsMPDModelStart:(null_unspecified NSString*)line modelName:(NSString * _Null_unspecified * _Null_unspecified)modelNamePtr;
+ (BOOL) lineIsMPDModelEnd:(null_unspecified NSString*)line;

@end

NS_ASSUME_NONNULL_END
