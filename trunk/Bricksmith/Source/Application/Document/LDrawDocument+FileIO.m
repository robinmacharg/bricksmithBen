//==============================================================================
//
// File:		LDrawDocument+FileIO.m
//
// Purpose:		Reading and writing the document, the open-time checks (missing
//				pieces, moved pieces, model name extensions) and the File menu.
//
//				A category of LDrawDocument, split out of LDrawDocument.m (P4) so
//				that P10 can port it on its own. Shared declarations and the
//				instance variables are in LDrawDocument+Private.h.
//
//  Created by Allen Smith on 2/14/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawDocument+Private.h"
#import "Bricksmith-Swift.h"

@implementation LDrawDocument (FileIO)

#pragma mark -
#pragma mark Reading

//========== readFromURL:ofType:error: =========================================
//
// Purpose:		Reads the file off of disk. We are overriding this NSDocument 
//				method to grab the path; the actual data-collection is done 
//				elsewhere.
//
//==============================================================================
- (BOOL) readFromURL:(NSURL *)absoluteURL
			  ofType:(NSString *)typeName
			   error:(NSError **)outError
{
	AMSProgressPanel    *progressPanel  = [AMSProgressPanel progressPanel];
	NSString            *openMessage    = nil;
	BOOL                success         = NO;
	
	openMessage = [NSString stringWithFormat:	NSLocalizedString(@"OpeningFileX", nil), 
		[self displayName] ];
	
	//This might take a while. Show that we're doing something!
	[progressPanel setMessage:openMessage];
	[progressPanel setIndeterminate:YES];
	[progressPanel showProgressPanel];

	//do the actual loading.
	success = [super readFromURL:absoluteURL ofType:typeName error:outError];
	
	[progressPanel close];
	
	if(success == YES)
	{
		// Track the path. I'm not sure what a non-file URL means, and I'm basically 
		// hoping we never encounter one. 
		if([absoluteURL isFileURL] == YES)
		{
			[[self documentContents] setPath:[absoluteURL path]];
			[[ModelManager sharedModelManager] documentSignIn:[absoluteURL path] withFile:documentContents];
		}
		else
			[[self documentContents] setPath:nil];

		//Postflight: find missing and moved parts.
		[self doMissingPiecesCheck:self];
		[self doMovedPiecesCheck:self];
		[self doMissingModelnameExtensionCheck:self];
		
		// Now that all the parts are at their final name, we can optimize.
//		[[LDrawApplication sharedOpenGLContext] makeCurrentContext];
	}
	
	return success;
	
}//end readFromFile:ofType:


//========== showWindows =======================================================
//
// Purpose:		Overrides NSDocument method to fix a bug whereby the window is 
//				not main once opened. This bug is some sort of odd interplay 
//				with the progress panel; if you don't show the progress panel, 
//				the bug goes away. 
//
//==============================================================================
- (void) showWindows
{
	[super showWindows];
	[[self windowForSheet] makeKeyAndOrderFront:self]; // manually force what is normally automatic behavior.
}


//========== revertToContentsOfURL:ofType:error: ===============================
//
// Purpose:		Called by NSDocument when it reverts the document to its most 
//				recently saved state.
//
//==============================================================================
- (BOOL) revertToContentsOfURL:(NSURL *)absoluteURL
						ofType:(NSString *)typeName
						 error:(NSError **)outError
{
	BOOL success = NO;
	
	//Causes loadDataRepresentation:ofType: to be invoked.
	success = [super revertToContentsOfURL:absoluteURL ofType:typeName error:outError];
	if(success == YES)
	{
		//Display the new document contents. 
		//		(Alas. This doesn't happen automatically.)
		[self loadDataIntoDocumentUI];
	}
	
	return success;
	
}//end revertToSavedFromFile:ofType:


//========== readFromData:ofType:error: ========================================
//
// Purpose:		Read a logical document structure from data. This is the "open" 
//				method.
//
//==============================================================================
- (BOOL) readFromData:(NSData *)data
			   ofType:(NSString *)typeName
				error:(NSError **)outError
{
	NSString    *fileContents   = [LDrawUtilities stringFromFileData:data];
	LDrawFile   *newFile        = nil;
	BOOL        success         = NO;
	
	//Parse the model.
	// - optimizing models can result in OpenGL calls, so to be ultra-safe we 
	//   set a context and lock on it. We can't use any of the documents GL 
	//   views because the Nib may not have been loaded yet.
	CGLLockContext([[LDrawApplication sharedOpenGLContext] CGLContextObj]);
	{
		[[LDrawApplication sharedOpenGLContext] makeCurrentContext];
		
		@try
		{
			CFAbsoluteTime  startTime   = CFAbsoluteTimeGetCurrent();
			CFTimeInterval  parseTime   = 0;
			
			BOOL			parseFailed	= NO;
			
			newFile     = [LDrawFile parseFromFileContents:fileContents parseFailed:&parseFailed];
			parseTime   = CFAbsoluteTimeGetCurrent() - startTime;
			
			// What the @catch below wrote when the parse threw (BUG-007), still 
			// without checking outError for NULL (S9). 
			if(parseFailed)
			{
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain
												code:NSFileReadCorruptFileError
											userInfo:nil];
			}
			
#if DEBUG
			NSLog(@"parse time = %f", parseTime);
#endif
			
			if(newFile != nil)
			{
				[self setDocumentContents:newFile];
				success = YES;
			}
		}
		@catch(NSException * e)
		{
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
											code:NSFileReadCorruptFileError
										userInfo:nil];
		}
	}
	CGLUnlockContext([[LDrawApplication sharedOpenGLContext] CGLContextObj]);
	
    return success;
	
}//end loadDataRepresentation:ofType:


#pragma mark -
#pragma mark Writing


//========== saveToURL:ofType:forSaveOperation:delegate:didSaveSelector:contextInfo:
//
// Purpose:		Saves the file out. We are overriding this NSDocument method to 
//				grab the path; the actual data-collection is done elsewhere.
//
//==============================================================================
- (void)saveToURL:(NSURL *)absoluteURL 
		   ofType:(NSString *)typeName 
 forSaveOperation:(NSSaveOperationType)saveOperation 
		 delegate:(id)delegate 
  didSaveSelector:(SEL)didSaveSelector 
	  contextInfo:(void *)contextInfo
{
	[super saveToURL:absoluteURL 
			  ofType:typeName 
	forSaveOperation:saveOperation 
			delegate:delegate 
	 didSaveSelector:didSaveSelector 
		 contextInfo:contextInfo];

	//track the path.
	if([absoluteURL isFileURL] == YES)
	{
		[[self documentContents] setPath:[absoluteURL path]];
		[[ModelManager sharedModelManager] documentSignIn:[absoluteURL path] withFile:documentContents];
	}
	else
		[[self documentContents] setPath:nil];
}//end saveToURL:ofType:forSaveOperation:delegate:didSaveSelector:contextInfo:


//========== dataOfType:error: =================================================
//
// Purpose:		Converts this document into a data object that can be written 
//				to disk. This is where a document gets saved.
//
//==============================================================================
- (NSData *)dataOfType:(NSString *)typeName
				 error:(NSError **)outError
{
    NSString *modelOutput = [[self documentContents] write];
	
	return [modelOutput dataUsingEncoding:NSUTF8StringEncoding];
	
}//end dataOfType:error:


#pragma mark -

//========== doMissingModelnameExtensionCheck: =================================
//
// Purpose:		Ensures that the names of all submodels in the current model end 
//				in a recognized LDraw extension (.ldr, .dat), renaming models 
//				and updating references as needed. 
//
// Notes:		Previous versions of Bricksmith did not force submodel names to 
//				end in a file extension, and this was a seemingly sensible, 
//				Maclike thing to do. Alas, MLCad will NOT RECOGNIZE submodels 
//				whose names do not have an extension. (Why...?!) Furthermore, 
//				according to the LDraw File Specification, a type 1 MUST point 
//				ot a "valid LDraw filename," which MUST include the extension. 
//				http://www.ldraw.org/Article218.html#lt1 Sigh...
//
//				This action is not undoable. Why would you want to?
//
//==============================================================================
- (void) doMissingModelnameExtensionCheck:(id)sender
{
	NSArray         *submodels          = [[self documentContents] submodels];
	LDrawMPDModel   *currentSubmodel    = nil;
	NSString        *currentName        = nil;
	NSString        *acceptableName     = nil;
	NSInteger       counter             = 0;
	
	// Find submodels with bad names.
	for(counter = 0; counter < [submodels count]; counter++)
	{
		currentSubmodel	= [submodels objectAtIndex:counter];
		currentName		= [currentSubmodel modelName];
		acceptableName	= [LDrawMPDModel ldrawCompliantNameForName:currentName];
		
		// If the model name does not have a valid LDraw file extension, the 
		// LDraw spec says we must give it one. Ugh. 
		if( [acceptableName isEqualToString:currentName] == NO )
		{
			// For files with only one model, we synthesize a name based on the 
			// model description. We can safely do a direct rename of these 
			// files. This also means LDrawMPDModel doesn't have to clean up 
			// every official part we parse from the LDraw folder. 
			if([submodels count] == 1)
			{
				[currentSubmodel setModelName:acceptableName];
			}
			else
			{
				// For MPD documents, we need to do a complex rename.
				[[self documentContents] renameModel:currentSubmodel toName:acceptableName];
			
				// Mark document as modified.
				[self updateChangeCount:NSChangeDone];
			}
		}
	}
	
}//end doMissingModelnameExtensionCheck:


//========== doMissingPiecesCheck: =============================================
//
// Purpose:		Searches the current model for any missing parts, and displays a 
//				warning if there are some.
//
//==============================================================================
- (void) doMissingPiecesCheck:(id)sender
{
	CFAbsoluteTime  startTime       = CFAbsoluteTimeGetCurrent();
	CFTimeInterval  partReportTime    = 0;
	
	// Until we load neighbor files as part of the async-GCD-friendly file load, neighboring files show
	// up here - the part report is the first thing that triggers the lazy load.  So until we fix this,
	// "resolve" time contains the time to figure out what each part points to, and the dominant cost 
	// is loading neighbor files when they are in use.
				
	PartReport		*partReport			= [PartReport partReportForContainer:[self documentContents]];
	NSArray			*missingParts		= [partReport missingParts];

	partReportTime = CFAbsoluteTimeGetCurrent() - startTime;
#if DEBUG
	NSLog(@"resolve time = %f", partReportTime);
#endif

	NSArray			*missingNames		= nil;
	NSMutableString	*informativeString	= nil;
	
	if([missingParts count] > 0)
	{
		//Build a string listing all the missing parts.
		missingNames = [missingParts valueForKey:@"displayName"]; // I love Cocoa.
		
		informativeString = [NSMutableString stringWithString:NSLocalizedString(@"MissingPiecesInformative", nil)];
		[informativeString appendString:@"\n\n"];
		[informativeString appendString:[missingNames componentsJoinedByString:@"\n"]];
		
		//Alert! Alert!
		NSAlert *alert = [[NSAlert alloc] init];
		
		[alert     setMessageText:NSLocalizedString(@"MissingPiecesMessage", nil)];
		[alert setInformativeText:informativeString];
		[alert addButtonWithTitle:NSLocalizedString(@"OKButtonName", nil)];
		
		[alert runModal];
		
	}
	
}//end doMissingPiecesCheck:


//========== doMovedPiecesCheck: ===============================================
//
// Purpose:		Searches the current model for any ~Moved parts, and displays a 
//				warning if there are some.
//
//==============================================================================
- (void) doMovedPiecesCheck:(id)sender
{
	PartReport	*partReport     = [PartReport partReportForContainer:[self documentContents]];
	NSArray     *movedParts     = [partReport movedParts];
	NSInteger   buttonReturned  = 0;
	NSInteger   counter         = 0;
	
	if([movedParts count] > 0)
	{
		//Alert! Alert! What should we do?
		NSAlert *alert = [[NSAlert alloc] init];
		
		[alert     setMessageText:NSLocalizedString(@"MovedPiecesMessage", nil)];
		[alert setInformativeText:NSLocalizedString(@"MovedPiecesInformative", nil)];
		[alert addButtonWithTitle:NSLocalizedString(@"OKButtonName", nil)];
		[alert addButtonWithTitle:NSLocalizedString(@"CancelButtonName", nil)];
		
		buttonReturned = [alert runModal];
		
		//They want us to update the ~Moved parts.
		if(buttonReturned == NSAlertFirstButtonReturn)
		{
			for(counter = 0; counter < [movedParts count]; counter++)
			{
				[LDrawUtilities updateNameForMovedPart:[movedParts objectAtIndex:counter]];
			}
			
			//mark document as modified.
			[self updateChangeCount:NSChangeDone];
		}
		
	}
	
}//end doMovedPiecesCheck:


#pragma mark -
#pragma mark File Menu

//========== exportSteps: ======================================================
//
// Purpose:		Presents a save dialog allowing the user to export his model 
//				as a series of files, one for each progressive step.
//
//==============================================================================
- (IBAction) exportSteps:(id)sender
{
	NSSavePanel *exportPanel	= [NSSavePanel savePanel];
	NSString	*activeName		= [[[self documentContents] activeModel] modelName];
	NSString	*nameFormat		= NSLocalizedString(@"ExportedStepsFolderFormat", nil);
	
	[exportPanel setDirectoryURL:nil];
	[exportPanel setNameFieldStringValue:[NSString stringWithFormat:nameFormat, activeName]];
	
	[exportPanel beginSheetModalForWindow:[self windowForSheet]
						completionHandler:
	 ^(NSInteger returnCode)
	 {
		 if(returnCode == NSModalResponseOK)
			 [self exportStepsToURL:[exportPanel URL]];
	 }];

}//end exportSteps:


//========== exportStepsToURL: =================================================
//
// Purpose:		Writes the model as a series of files, one for each progressive
//				step, into a folder at saveURL (replacing anything already
//				there): one subfolder per submodel, holding one file per step.
//				This is the work of Export Steps once the save panel is accepted.
//
//==============================================================================
- (void) exportStepsToURL:(NSURL *)saveURL
{
	NSFileManager	 *fileManager		 = [[NSFileManager alloc] init];
	NSString		 *saveName			 = nil;
	NSString		 *modelName 		 = nil;
	NSString		 *folderName		 = nil;
	NSString		 *modelnameFormat	 = NSLocalizedString(@"ExportedStepsFolderFormat", nil);
	NSString		 *filenameFormat	 = NSLocalizedString(@"ExportedStepsFileFormat", nil);
	NSString		 *fileString		 = nil;
	NSData 		 *fileOutputData	 = nil;
	NSString		 *outputName		 = nil;
	NSString		 *outputPath		 = nil;
	
	LDrawFile		 *fileCopy			 = nil;
	
	NSInteger		 modelCounter		 = 0;
	NSInteger		 counter			 = 0;
	
	saveName	= ([saveURL isFileURL] ? [saveURL path] : nil);
	
	// If we got this far, we need to replace any prexisting file.
	if([fileManager fileExistsAtPath:saveName isDirectory:NULL])
		[fileManager removeItemAtPath:saveName error:NULL];
	
	[fileManager createDirectoryAtPath:saveName withIntermediateDirectories:YES attributes:nil error:NULL];
	
	//Output all the steps for all the submodels.
	for(modelCounter = 0; modelCounter < [[[self documentContents] submodels] count]; modelCounter++)
	{
		fileCopy = [[self documentContents] copy];
		
		//Move the target model to the top of the file. That way L3P will know to
		// render it!
		LDrawMPDModel *currentModel = [[fileCopy submodels] objectAtIndex:modelCounter];
		[fileCopy removeDirective:currentModel];
		[fileCopy insertDirective:currentModel atIndex:0];
		[fileCopy setActiveModel:currentModel];
		
		//Make a new folder for the model's steps.
		modelName	= [NSString stringWithFormat:modelnameFormat, [currentModel modelName]];
		folderName	= [saveName stringByAppendingPathComponent:modelName];
		
		[fileManager createDirectoryAtPath:folderName withIntermediateDirectories:YES attributes:nil error:NULL];
		
		//Write out each step!
		for(counter = [[currentModel steps] count]-1; counter >= 0; counter--)
		{
			fileString		= [fileCopy write];
			fileOutputData	= [fileString dataUsingEncoding:NSUTF8StringEncoding];
			
			outputName = [NSString stringWithFormat: filenameFormat,
							[currentModel modelName],
							(long)counter+1 ];
			outputPath = [folderName stringByAppendingPathComponent:outputName];
			[fileManager createFileAtPath:outputPath
								 contents:fileOutputData
							   attributes:nil ];
			
			//Remove the step we just wrote, so that the next cycle won't
			// include it. We can safely do this because we are working with
			// a copy of the file!
			[currentModel removeDirectiveAtIndex:counter];
		}
		
		
		
	}
	
}//end exportStepsToURL:


//========== revealInFinder: ===================================================
//
// Purpose:             Open a Finder window with the current file selected.
//
//==============================================================================
- (IBAction) revealInFinder:(id)sender
{
    // Cribbed directly from
    // http://stackoverflow.com/questions/7652928/launch-osx-finder-window-with-specific-files-selected
    NSArray *fileURLs = [NSArray arrayWithObjects:[self fileURL], nil];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
    
}//end revealInFinder:

@end
