//==============================================================================
//
// File:		LDrawPathNames.h
//
// Purpose:		Constant names of standard LDraw files or folders.
//
// Modified:	05/03/2011 Allen Smith. Creation Date.
//
//==============================================================================
#ifndef LDrawPathNames_h
#define LDrawPathNames_h


#import <Foundation/Foundation.h>

////////////////////////////////////////////////////////////////////////////////
//
// Folder Names
//
////////////////////////////////////////////////////////////////////////////////
FOUNDATION_EXPORT NSString * const LDRAW_DIRECTORY_NAME; // @"LDraw"

FOUNDATION_EXPORT NSString * const PRIMITIVES_DIRECTORY_NAME; // @"p"
	FOUNDATION_EXPORT NSString * const PRIMITIVES_48_DIRECTORY_NAME; // @"48"

FOUNDATION_EXPORT NSString * const PARTS_DIRECTORY_NAME; // @"parts"  //match case of LDraw.org complete distribution zip package.
	FOUNDATION_EXPORT NSString * const SUBPARTS_DIRECTORY_NAME; // @"s"
	
FOUNDATION_EXPORT NSString * const TEXTURES_DIRECTORY_NAME; // @"textures"

FOUNDATION_EXPORT NSString * const UNOFFICIAL_DIRECTORY_NAME; // @"Unofficial"


////////////////////////////////////////////////////////////////////////////////
//
// File Names
//
////////////////////////////////////////////////////////////////////////////////

FOUNDATION_EXPORT NSString * const LDCONFIG; // @"LDConfig"
FOUNDATION_EXPORT NSString * const LDCONFIG_EXTENSION; // @"ldr"
FOUNDATION_EXPORT NSString * const LDCONFIG_FILE_NAME; // LDCONFIG "." LDCONFIG_EXTENSION = @"LDConfig.ldr"

FOUNDATION_EXPORT NSString * const MLCAD; // @"MLCad"
FOUNDATION_EXPORT NSString * const MLCAD_EXTENSION; // @"ini"
FOUNDATION_EXPORT NSString * const MLCAD_INI_FILE_NAME; // MLCAD "." MLCAD_EXTENSION = @"MLCad.ini"

FOUNDATION_EXPORT NSString * const PART_CATALOG_NAME; // @"Bricksmith Parts.plist"

#endif