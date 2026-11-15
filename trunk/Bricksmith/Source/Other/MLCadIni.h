//==============================================================================
//
// File:		MLCadIni.h
//
// Purpose:		Parses the contents of LDraw/MLCad.ini, the file which defines 
//				settings for the minifigure generator.
//
//  Created by Allen Smith on 7/2/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>


NS_ASSUME_NONNULL_BEGIN

@interface MLCadIni : NSObject
{
	NSArray				*lsynthVisibleTypes;
	
	//Minifigure Generator
	NSMutableArray		*minifigureHats;
	NSMutableArray		*minifigureHeads;
	NSMutableArray		*minifigureNecks;
	NSMutableArray		*minifigureTorsos;
	NSMutableArray		*minifigureHips;
	NSMutableArray		*minifigureArmsLeft;
	NSMutableArray		*minifigureArmsRight;
	NSMutableArray		*minifigureHandsLeft;
	NSMutableArray		*minifigureHandsLeftAccessories;
	NSMutableArray		*minifigureHandsRight;
	NSMutableArray		*minifigureHandsRightAccessories;
	NSMutableArray		*minifigureLegsLeft;
	NSMutableArray		*minifigureLegsLeftAcessories;
	NSMutableArray		*minifigureLegsRight;
	NSMutableArray		*minifigureLegsRightAccessories;
}

//Initialization
+ (null_unspecified MLCadIni *) iniFile;

//Accessors
- (null_unspecified NSArray *) lsynthVisibleTypes;
- (null_unspecified NSArray *) minifigureHats;
- (null_unspecified NSArray *) minifigureHeads;
- (null_unspecified NSArray *) minifigureNecks;
- (null_unspecified NSArray *) minifigureTorsos;
- (null_unspecified NSArray *) minifigureHips;
- (null_unspecified NSArray *) minifigureArmsLeft;
- (null_unspecified NSArray *) minifigureArmsRight;
- (null_unspecified NSArray *) minifigureHandsLeft;
- (null_unspecified NSArray *) minifigureHandsLeftAccessories;
- (null_unspecified NSArray *) minifigureHandsRight;
- (null_unspecified NSArray *) minifigureHandsRightAccessories;
- (null_unspecified NSArray *) minifigureLegsLeft;
- (null_unspecified NSArray *) minifigureLegsLeftAcessories;
- (null_unspecified NSArray *) minifigureLegsRight;
- (null_unspecified NSArray *) minifigureLegsRightAccessories;

- (float) armAngleForTorsoName:(null_unspecified NSString *)torsoName;

//Parsing
- (void) parseFromPath:(null_unspecified NSString *) path;

// Test support (do not call from app code)
+ (void) resetForTesting;

@end

NS_ASSUME_NONNULL_END
