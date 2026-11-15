//
//  LSynthConfiguration.h
//  Bricksmith
//
//  Created by Robin Macharg on 24/09/2012.
//
//

#import <Foundation/Foundation.h>

@class LDrawPart;
@class LDrawLSynth;

// The class of a synthesis object
typedef NS_ENUM(int, LSynthClassT)
{
    LSYNTH_PART = 1,
    LSYNTH_HOSE = 2,
    LSYNTH_BAND = 3,
    LSYNTH_CLASSES_COUNT
};

NS_ASSUME_NONNULL_BEGIN

@interface LSynthConfiguration : NSObject
{
    NSMutableArray *parts;
    NSMutableArray *hose_constraints;
    NSMutableArray *band_constraints;
    NSMutableArray *hose_types;
    NSMutableArray *band_types;

    NSMutableArray *quickRefHoses;
    NSMutableArray *quickRefBands;
    NSMutableArray *quickRefParts;
    NSMutableArray *quickRefHoseConstraints;
    NSMutableArray *quickRefBandConstraints;
}

#pragma mark -
#pragma mark Class Methods
#pragma mark -

+(null_unspecified LSynthConfiguration*) sharedInstance;

#pragma mark -
#pragma mark Instance Methods
#pragma mark -

-(null_unspecified NSString *)defaultConfigPath;
-(void) parseLsynthConfig:(null_unspecified NSString *)lsynthConfigurationPath;
-(BOOL) isLSynthConstraint:(null_unspecified LDrawPart *)part;

#pragma mark -
#pragma mark CONSTANT ACCESSORS
#pragma mark -

+(null_unspecified NSString *) defaultHoseConstraint;
+(null_unspecified NSString *) defaultBandConstraint;
+(null_unspecified NSString *) defaultHoseType;
+(null_unspecified NSString *) defaultBandType;

#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

-(null_unspecified NSMutableArray *) getParts;
-(null_unspecified NSMutableArray *) getHoseTypes;
-(null_unspecified NSMutableArray *) getBandTypes;
-(null_unspecified NSMutableArray *) getHoseConstraints;
-(null_unspecified NSMutableArray *) getBandConstraints;
-(null_unspecified NSMutableArray *) getQuickRefBands;
-(null_unspecified NSMutableArray *) getQuickRefHoses;
-(null_unspecified NSMutableArray *) getQuickRefParts;
-(null_unspecified NSMutableArray *) getQuickRefBandContstraints;
-(null_unspecified NSMutableArray *) getQuickRefHoseConstraints;
-(null_unspecified NSDictionary *)   constraintDefinitionForPart:(null_unspecified LDrawPart *)directive;
-(null_unspecified NSDictionary *)   typeForTypeName:(null_unspecified NSString *)typeName;

-(void) setLSynthClassForDirective:(null_unspecified LDrawLSynth *)directive withType:(null_unspecified NSString *)type;

@end

NS_ASSUME_NONNULL_END
