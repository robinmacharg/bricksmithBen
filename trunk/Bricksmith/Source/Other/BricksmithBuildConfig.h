//==============================================================================
//
// File:		BricksmithBuildConfig.h
//
// Purpose:		Build-wide macros and C-level imports that used to live only in
//				the prefix header. Self-contained, so any header (including ones
//				imported by the Swift bridging header, which never sees the
//				prefix header) can import it and see exactly the same types and
//				flags the Objective-C code was compiled with.
//
// Notes:		USE_BLOCKS 0 redefines dispatch_queue_t/dispatch_group_t as
//				void *. That hack is removed in P4 (see docs/swift-port-plan.md);
//				until then every header that uses those types must import this.
//
//==============================================================================
#ifndef BRICKSMITH_BUILD_CONFIG_H
#define BRICKSMITH_BUILD_CONFIG_H

// C (and ObjC) sources rely on the prefix header for the standard C library and CoreServices.
// This used to come via <Carbon/Carbon.h>; Carbon was removed with 3Dconnexion support (P0).
// P1 makes headers self-contained so this implicit dependency can go.
#import <ApplicationServices/ApplicationServices.h>


//#define USE_BLOCKS				NS_BLOCKS_AVAILABLE
#define USE_BLOCKS				0

// P3: only for files still built without ARC. Under ARC, dispatch objects are managed ObjC objects and must
// keep their real types (P4 removes USE_BLOCKS and this hack).
#if !USE_BLOCKS && !__has_feature(objc_arc)
	#define dispatch_queue_t    void *
	#define dispatch_group_t    void *
#endif


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Build Flags
//					Special options to configure the program behavior.
//
////////////////////////////////////////////////////////////////////////////////

// This stores quads as pairs of triangles in the VBO - 50% more vertex count but fewer draw calls.
// Mixed results in perf tests.
#define TESSELATE_QUADS								0

// This draws wire frames by setting the polygon fill mode instead of generating separate meshes.
#define USE_AUTOMATIC_WIREFRAMES					1

// This enables the "related parts" UI - define to 0 to hide it for now.
#define WANT_RELATED_PARTS							1

#endif // BRICKSMITH_BUILD_CONFIG_H
