//==============================================================================
//
// File:		ArchiveSupport.h
//
// Purpose:		Objective-C helpers that must stay in Objective-C because the
//				calls they wrap can raise NSExceptions, which may not unwind
//				through Swift frames (swift-port-plan §4.4 rule 3).
//
//==============================================================================
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// The object unarchived from non-keyed NSArchiver (typedstream) data, or nil if the data can't be unarchived.
// NSUnarchiver raises NSArchiverArchiveInconsistency on truncated or corrupt data; that is caught here and
// reported as nil (BUG-035, fixed by maintainer decision in P5).
FOUNDATION_EXPORT id _Nullable BricksmithUnarchiveObject(NSData * _Nullable data);

NS_ASSUME_NONNULL_END
