// Ported to LDrawPart.swift (P6b).
// Types-only header: PartTypeT stays here for the Swift class (through the bridging header).
#import <Foundation/Foundation.h>

typedef NS_ENUM(int, PartTypeT) {
	PartTypeUnresolved = 0,	// We have not yet tried to figure out what we have.
	PartTypeNotFound,		// We went looking and the part is missing.  This keeps us from retrying on every query until someone tells us to try again.
	PartTypeLibrary,		// Part is in the library.
	PartTypeSubmodel,		// Part is an MPD submodel from our parent LDrawFile
	PartTypePeerFile		// Part is the first model in another file in the same directory as us.
};

@class LDrawPart;
