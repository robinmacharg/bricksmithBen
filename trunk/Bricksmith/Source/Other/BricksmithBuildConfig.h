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
//==============================================================================
#ifndef BRICKSMITH_BUILD_CONFIG_H
#define BRICKSMITH_BUILD_CONFIG_H

// C (and ObjC) sources rely on the prefix header for the standard C library and CoreServices.
// This used to come via <Carbon/Carbon.h>; Carbon was removed with 3Dconnexion support (P0).
// P1 makes headers self-contained so this implicit dependency can go.
#import <ApplicationServices/ApplicationServices.h>


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
