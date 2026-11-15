//
//  PartCatalogBuilder.h
//  Bricksmith
//
//  Created by Allen Smith on 1/6/22.
//

#import <Foundation/Foundation.h>

//------------------------------------------------------------------------------
///
/// @class		PartCatalogBuilder
///
/// @abstract	Scans the LDraw folder for a list of all available parts and
/// 			categories. 
///
//------------------------------------------------------------------------------
NS_ASSUME_NONNULL_BEGIN

@interface PartCatalogBuilder : NSObject

- (void) makePartCatalogWithMaxLoadCountHandler:(null_unspecified void (^)(NSUInteger maxPartCount))maxLoadCountHandler
					   progressIncrementHandler:(null_unspecified void (^)())progressIncrementHandler
							  completionHandler:(null_unspecified void (^)(NSDictionary<NSString*, id> * _Null_unspecified newCatalog))completionHandler;

@end

NS_ASSUME_NONNULL_END
