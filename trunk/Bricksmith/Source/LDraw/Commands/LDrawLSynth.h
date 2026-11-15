//
//  LDrawLSynth.h
//  Bricksmith
//
//  Created by Robin Macharg on 16/11/2012.
//
//

#import <Foundation/Foundation.h>
#import "LDrawContainer.h"
#import "LDrawDrawableElement.h"
#import "ColorLibrary.h"
#import "LDrawMovableDirective.h"
#import "LSynthConfiguration.h"

// The LSynth LDraw format extensions have several mandatory and several optional directives.
// The following state diagram illustrates the order that directives could occur.
// The initWithLines: parser in this class implements this state machine.

// TODO: need a transition between PARSER_PARSING_BEGUN and PARSER_FINISHED on 0 SYNTH END

//
//     State                                         Transitions
//     ---------------------------------------------------------------------------------------
//
//     PARSER_READY_TO_PARSE                         o
//                                                   |
//                                                   |    0 SYNTH BEGIN X X
//                                                   V
//     PARSER_PARSING_BEGUN                          o
//                                                   |    0 SYNTH SHOW or
//                                                   |    1 X X X ...
//                                                   V
//     PARSER_PARSING_CONSTRAINTS                  /\o
//                                    1 X X X ... |_/|
//                                                   |    0 SYNTH SYNTHESIZED BEGIN
//                                                   V
//     PARSER_PARSING_SYNTHESIZED                  /\o
//                                    1 X X X ... |_/|
//                                                   |    0 SYNTH SYNTHESIZED END
//                                                   V
//     PARSER_SYNTHESIZED_FINISHED                   o
//                                                   |    0 SYNTH END
//                                                   |
//                                                   V
//     PARSER_FINISHED                               o
//

// Lsynth block parser states
typedef NS_ENUM(int, LSynthParserStateT)
{
    PARSER_READY_TO_PARSE       = 1, // Idle state - we've not found a SYNTH BEGIN <TYPE> <COLOR> line
    PARSER_PARSING_BEGUN        = 2, // SYNTH BEGIN has been found
    PARSER_PARSING_CONSTRAINTS  = 3, // Parsing constraints
    PARSER_PARSING_SYNTHESIZED  = 4, // Parsing synthesized parts
    PARSER_SYNTHESIZED_FINISHED = 5, // Looking for SYNTH END
    PARSER_FINISHED             = 6, // All finished.
    PARSER_STATE_COUNT
};

NS_ASSUME_NONNULL_BEGIN

@interface LDrawLSynth : LDrawContainer <LDrawColorable, LDrawMovableDirective>
{
    NSMutableArray  *synthesizedParts;
    NSString        *synthType;
    int              lsynthClass;
    LDrawColor      *color;
    GLfloat			 glTransformation[16];
    BOOL             hidden;
    BOOL             subdirectiveSelected;
    Box3			 cachedBounds;		// cached bounds of the enclosed directives
}

// Accessors
- (void) setLsynthClass:(int)lsynthClass;
- (int) lsynthClass;
- (void) setLsynthType:(null_unspecified NSString *)lsynthType;
- (null_unspecified NSString *) lsynthType;
- (void) setHidden:(BOOL)flag;
- (BOOL) isHidden;
- (void) setLDrawColor:(null_unspecified LDrawColor *)color;

- (TransformComponents) transformComponents;
- (Matrix4) transformationMatrix;


// Utilities
- (void) synthesize;
- (void)colorSelectedSynthesizedParts:(BOOL)yesNo;
- (null_unspecified NSString *)determineIconName:(null_unspecified LDrawDirective *)directive;
- (null_unspecified NSMutableArray *)prepareAutoHullData;
-(int)synthesizedPartsCount;


+ (BOOL) lineIsLSynthBeginning:(null_unspecified NSString*)line;
+ (BOOL) lineIsLSynthTerminator:(null_unspecified NSString*)line;

@end

NS_ASSUME_NONNULL_END
