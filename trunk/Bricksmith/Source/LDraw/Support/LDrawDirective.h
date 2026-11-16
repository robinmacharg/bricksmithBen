// Ported to LDrawDirective.swift (P6c).
//
// Types-only header: the cache flags, messages and observer protocols, the
// notification and drawing macros, LDrawPartVisitor and the imports their
// users relied on, plus the three initializer shims LDrawDirective.swift uses.
#import <Foundation/Foundation.h>
#import "BricksmithBuildConfig.h"

#import "MatrixMath.h"
#import "LDrawRenderer.h"

@class LDrawDirective;
@class LDrawColor;
@class LDrawContainer;
@class LDrawFile;
@class LDrawModel;
@class LDrawStep;
@class LDrawPart;

////////////////////////////////////////////////////////////////////////////////
//
//				OBSERVABLE/OBSERVER PROTOCOLS FOR DIRECTIVES
//
////////////////////////////////////////////////////////////////////////////////

// The observer protocol builds a one-way DAG out of our directives allowing
// directives to note changes in their child directives and manage cached data
// appropriately.  The protocol rules:
//
// 1. An observer/observable relationship is a pair of _weak_ references.  No
//	  retain counts are maintained, and it is always possible that either party
//	  could end the relationship by dying.  Observers who have good reason why
//	  their observables should not go away (or vice versa) should maintain 
//	  retain counts separately as part of a separate parallel structure; this is
//	  only for message flow.
//
// 2. An observer begins observation by requesting that the observable at it to
//	  an internal hypothetical observer list.  Observables do not start the 
//    relationship.
//
//	  Similarly, an observer ends observation by requesting its observable to
//	  remove me from the list.
//
// 3. Death: if the observer dies first, it is responsible for terminating the
//	  relationship in the usual way by calling removeObserver on its observable
//	  with itself as the direct object.
//
//	  But if the observable dies first (while being observed) it sends a 
//	  "goodbye cruel world" message to all observers currently watching it.  
//	  Those observers note that the observable is no longer, um, observable but
//	  they do _not_ need to call back with a removeObservable message.
//
// The method receiveMessage is used to send a set of specific messages to all
// observing.  This is for one-time, relatively rare, non-deallocation events
// that happen.
//
// Observables maintain a bit-field of flags about the status of cachable 
// information; an invalidate cache message is sent to all observers once each
// time cachable info is changed until _any_ external caller reads that property.
// (When a caller reads the property, the cache is rebuilt and a new invalidate
// message will be generated.)
//
// CACHING BEHAVIORS
//
// The idea behind the caching flags is this: an observer that produces the sum
// or union from many observables can benefit from knowing that none of the
// observables has changed.  (E.g. it's nice for a step to know that no bricks
// have moved.)  The correct caching behavior is this:
//
// - Every time the observer reads an observable's property, the observable
//	 clears the flag for that property, because the observer and observable
//	 are now in sync.  If the property requires expensive computation in the
//	 observable, the observable probably updates its own internal cache.
//
// - Every time the observable changes that property, it sends a notification
//	 only IF the cache flag is clear; it then sets the cache flag.
//
// - An observer who receives an invalidate message may in turn invalidate
//	 its own cache (if necessary), causing a cascade up the observation tree.
//
// Thus if the position of an object is changed 8 times between any external
// code reading the object, an inval message is sent to observers only once.
// See invalCache and revalCache for more details.

@protocol LDrawObserver;
@protocol LDrawObservable;

// Cache flags.  For now, we can maintain all cache flags in one place.  In
// theory observable/observer could be used in many places in the app but for
// now since it is just used for directives, maintain all directive-related
// enums and flags here...

typedef NS_OPTIONS(int, CacheFlagsT) {

	// The bounding box of the directive has changed and is no longer valid.
	CacheFlagBounds      = 1,
	DisplayList		     = 2,
    ContainerInvalid     = 4  // Subdirectives have changed in a way that may invalidate the cache
	
	// Ben says: ContainerInvalid is _not_ a good cache flag because it is not truly recursive - it is ONLY
	// invoked on LDrawLSynth directives and should probably be private to that class.
	// The flag "works" because the class maps the MessageObservedChanged message to inval itself, and 
	// MessageObservedChanged has been specifically put into LDrawPart, which is the only thing an LSynth 
	// actually cares about.
};

typedef NS_ENUM(int, MessageT) {

	// The reference name of the MPD model has changed and observers should 
	// update their string references.
	MessageNameChanged = 0,
	
	// The MPD's parent has changed, and thus its scope may have changed
	MessageScopeChanged = 1,

    // The observed have changed in a way that may require the observer to
    // update its representation (e.g. an LSynth constraint has moved and
    // requires resynthesis)
	// Ben says: this is really LSynth specific, e.g. part -> parent synth
    MessageObservedChanged = 2
};

NS_ASSUME_NONNULL_BEGIN

@protocol LDrawObserver
@required
- (void) observableSaysGoodbyeCruelWorld:(null_unspecified id<LDrawObservable>) doomedObservable;
- (void) statusInvalidated:(CacheFlagsT) flags who:(null_unspecified id<LDrawObservable>) observable;
- (void) receiveMessage:(MessageT) msg who:(null_unspecified id<LDrawObservable>) observable;
@end


@protocol LDrawObservable
@required
- (void) addObserver:(null_unspecified id<LDrawObserver>) observer;
- (void) removeObserver:(null_unspecified id<LDrawObserver>) observer;
@end




////////////////////////////////////////////////////////////////////////////////



//A directive was modified, either explicitly by the user or by undo/redo.
// Object is the LDrawDirective that changed. No userInfo.
#define LDrawDirectiveDidChangeNotification				@"LDrawDirectiveDidChangeNotification"
#define LDrawModelRotationCenterDidChangeNotification	@"LDrawModelRotationCenterDidChangeNotification"


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Drawing Mask bits and Constants
//
////////////////////////////////////////////////////////////////////////////////
#define DRAW_NO_OPTIONS							0
#define DRAW_WIREFRAME							1 << 1
#define DRAW_BOUNDS_ONLY						1 << 3

typedef void(^LDrawPartVisitor)(LDrawPart *);	// part is nonnull: only ever invoked as visitor(self) by -[LDrawPart applyToAllParts:] (verified 2026-11-15)

////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Initializer shims (used by LDrawDirective.swift)
//
////////////////////////////////////////////////////////////////////////////////
//
// -[LDrawDirective initWithLines:inRange:parentGroup:] began with [self init],
// and -initWithLines:inRange: sent [self initWithLines:inRange:parentGroup:NULL]:
// both reach the subclass's override on the object being initialized, and the
// subclasses depend on it (LDrawContainer's children array, LDrawModel's colour
// library, LDrawPart's icon and transform). A Swift designated initializer
// can't delegate to self, and Swift can't send an init message to an existing
// object: an @objc protocol method with the selector, sent through a bitcast,
// over-releases (an init consumes self and returns +1, which a plain method
// can't express; the P6c probe crashed with SIGSEGV). So the Swift initializers
// call NSObject's init and then these shims, which ARC compiles with the init
// family's ownership.
//
// +directiveWithLines:inRange:parentGroup: is [[self alloc] initWithLines:...].
// In Swift, self.init(lines:...) on a metatype needs a `required` initializer,
// which forces `required` onto every subclass override and fails for subclasses
// that declare other initializers (P6c probe), so it goes through the third
// shim, keeping ObjC's alloc/init semantics.
//
// NS_RETURNS_RETAINED: Swift takes the result owned, so it never depends on the
// autorelease-return handshake (no directive is left in an autorelease pool).


// The parse initializer's selector, so the shims can send it to an `id`.
@protocol LDrawDirectiveParseInit
- (nullable instancetype) initWithLines:(nullable NSArray<NSObject *> *)lines inRange:(NSRange)range parentGroup:(nullable dispatch_group_t)parentGroup;
@end

// [directive init]: the receiver's (most derived) -init.
static inline NSObject * _Nullable LDrawDirectiveSendInit(NSObject *directive) NS_RETURNS_RETAINED;
static inline NSObject * _Nullable LDrawDirectiveSendInit(NSObject *directive)
{
	return [directive init];
}

// [directive initWithLines:lines inRange:range parentGroup:parentGroup]
static inline NSObject * _Nullable LDrawDirectiveSendInitWithLines(NSObject *directive, NSArray<NSObject *> * _Nullable lines, NSRange range, dispatch_group_t _Nullable parentGroup) NS_RETURNS_RETAINED;
static inline NSObject * _Nullable LDrawDirectiveSendInitWithLines(NSObject *directive, NSArray<NSObject *> * _Nullable lines, NSRange range, dispatch_group_t _Nullable parentGroup)
{
	return [(NSObject<LDrawDirectiveParseInit> *)directive initWithLines:lines inRange:range parentGroup:parentGroup];
}

// [[directiveClass alloc] initWithLines:lines inRange:range parentGroup:parentGroup]
static inline NSObject * _Nullable LDrawDirectiveAllocInitWithLines(Class directiveClass, NSArray<NSObject *> * _Nullable lines, NSRange range, dispatch_group_t _Nullable parentGroup) NS_RETURNS_RETAINED;
static inline NSObject * _Nullable LDrawDirectiveAllocInitWithLines(Class directiveClass, NSArray<NSObject *> * _Nullable lines, NSRange range, dispatch_group_t _Nullable parentGroup)
{
	return [(NSObject<LDrawDirectiveParseInit> *)[directiveClass alloc] initWithLines:lines inRange:range parentGroup:parentGroup];
}

NS_ASSUME_NONNULL_END
