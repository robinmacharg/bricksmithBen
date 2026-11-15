//==============================================================================
//
// File:		PartReport.h
//
// Purpose:		Holds the data necessary to generate a report of the parts in a 
//				model. We are interested in the quantities and colors of each 
//				type of part included.
//
//  Created by Allen Smith on 9/10/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

@class LDrawPart;
@class LDrawContainer;


extern NSString * _Null_unspecified PART_REPORT_NUMBER_KEY;
extern NSString * _Null_unspecified PART_REPORT_NAME_KEY;
extern NSString * _Null_unspecified PART_REPORT_LDRAW_COLOR;	// LDrawColor object
extern NSString * _Null_unspecified PART_REPORT_COLOR_NAME;	// NSString representing localized name
extern NSString * _Null_unspecified PART_REPORT_PART_QUANTITY;	// NSNumber of how many of this part there are


////////////////////////////////////////////////////////////////////////////////
//
// class PartReport
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface PartReport : NSObject
{
	LDrawContainer		*reportedObject;
	NSMutableDictionary	*partsReport;			//see -registerPart: for a description of this data
	NSMutableArray		*missingParts;
	NSMutableArray		*movedParts;
	NSUInteger			 totalNumberOfParts;	//how many parts are in the model.
}

//Initialization
+ (null_unspecified PartReport *) partReportForContainer:(null_unspecified LDrawContainer *)container;

//Collecting Information
- (void) setLDrawContainer:(null_unspecified LDrawContainer *)newContainer;
- (void) getPieceCountReport;
- (void) registerPart:(null_unspecified LDrawPart *)part;

//Accessing Information
- (null_unspecified NSArray *) allParts;
- (null_unspecified NSArray *) flattenedReport;
- (null_unspecified NSArray *) missingParts;
- (null_unspecified NSArray *) movedParts;
- (NSUInteger) numberOfParts;
- (null_unspecified NSString *) textualRepresentationWithSortDescriptors:(null_unspecified NSArray *)sortDescriptors;

@end

NS_ASSUME_NONNULL_END
