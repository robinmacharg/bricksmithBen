//==============================================================================
//
// File:		LDrawPart.swift
//
// Purpose:		Part command.
//				Inserts a part defined in another LDraw file.
//
//				Line format:
//				1 colour x y z a b c d e f g h i part.dat
//
//				where
//
//				* colour is a colour code: 0-15, 16, 24, 32-47, 256-511
//				* x, y, z is the position of the part
//				* a - i are orientation & scaling parameters
//				* part.dat is the filename of the included file
//
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//
//  Ported to Swift in P6b. The superclass (LDrawDrawableElement) is Swift since
//  P6c; its colour and hidden flag are read through -isHidden, -LDrawColor and
//  collectorColor(_:_:). PartTypeT stays in LDrawPart.h.
//
//  Threads: every part is parsed, resolved and drawn on the thread that opened
//  the document (all parse groups are NULL since P4; PartLibrary runs its
//  single-threaded path). The ObjC took no locks (drawLock was never created),
//  so there is none here.
//==============================================================================

import Foundation
import OpenGL.GL

// This is experimental for now: one way to draw the gaps between lego bricks
// without using lines is to simply shrink the entire brick by a tiny amount,
// leaving a small gap between bricks.  (This is based on the seam-shrink code
// in Travis' LDView.) SHRINK_SEAMS was 0 for production use; the experiment
// was not carried over.

/// 16 GLfloats: the part's transformation, as a flat column-major OpenGL matrix.
typealias GLMatrix16 = (GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat,
						GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat)

/// Coder keys over 15 bytes bridge to a new NSString on every call (L102).
private let glTransformationKey = NSString(string: "glTransformation") as String

/// -[LDrawUtilities readNextField:remainder:], keeping the fields as NSString.
private func readNextField(_ line: inout NSString?) -> NSString? {
	return LDrawUtilities.readNextField(line as String?, remainder: &line) as NSString?
}


//========== floatNearGrid =====================================================
//
// Purpose:		Returns true if the value v is within 'epsi' of a grid with
//				'grid' spacing going through the origin.  Used to detect
//				nudges at standard displacements.
//
//==============================================================================
private func floatNearGrid(_ v: Float, _ grid: Float, _ epsi: Float) -> Bool {
	let hgrid: Float = grid * 0.5
	return fabsf(fmodf(v+hgrid, grid)-hgrid) < epsi
}//end floatNearGrid


@objc(LDrawPart)
final class LDrawPart: LDrawDrawableElement, LDrawObserver {

	// Storage. Named apart from the accessor methods, which keep their selectors
	// (-displayName is also read by KVC: LDrawDocument+FileIO's missing-parts list).
	@exclusivity(unchecked) private var displayNameStorage: String?		= nil
	@exclusivity(unchecked) private var referenceNameStorage: String?	= nil //lower-case version of display name

	@exclusivity(unchecked) private var glTransformation: GLMatrix16 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

	// The drawable is the model we link to OR a VBO that represents it from the
	// part library -- a drawable proxy. Both unretained, as under MRC: the part
	// observes the model (L77).
	@exclusivity(unchecked) private unowned(unsafe) var cacheDrawable: LDrawDirective? = nil
	// The model is the real model we link to.
	@exclusivity(unchecked) private unowned(unsafe) var cacheModel: LDrawModel? = nil
	@exclusivity(unchecked) private var cacheType: PartTypeT = .unresolved

	// Cached bounding box of resolved parts, in part's coordinate (that is, _not_
	// in the coordinates of the underlying model). Zeros until first computed,
	// as the ObjC ivar was.
	@exclusivity(unchecked) private var cacheBounds: Box3 = Box3()


	//========== defaultIconName ===============================================
	//
	// Purpose:		The default icon name for this class.
	//
	//==========================================================================
	@objc(defaultIconName)
	override class func defaultIconName() -> String! {
		return "Brick"
	}


	// MARK: - INITIALIZATION

	//========== init ==========================================================
	//
	// Purpose:		Creates an empty part.
	//
	//				(Copying uses [[[self class] alloc] init], and LDrawDirective's
	//				parse initializer calls [self init].)
	//
	//==========================================================================
	@objc(init)
	override init() {
		super.init()

		self.setDisplayName("")
		self.setIconName("Brick")
		self.setTransformComponents(IdentityComponents)
	}


	//========== initWithLines:inRange:parentGroup: ============================
	//
	// Purpose:		Returns the LDraw directive based on lineFromFile, a single
	//				line of LDraw code from a file.
	//
	//				Line format:
	//				1 colour x y z a b c d e f g h i part.dat
	//
	//				Matrix format:
	//				+-       -+
	//				| a d g 0 |
	//				| b e h 0 |
	//				| c f i 0 |
	//				| x y z 1 |
	//				+-       -+
	//
	// Notes:		The ObjC wrapped the parse in a catch-all @try ("A malformed
	//				part could easily cause a string indexing error"). Nothing in
	//				it raises on any input that reaches it: -readNextField: never
	//				indexes out of range and only returns nil for a nil line;
	//				-parseColorFromField:, -floatValue, -integerValue and the
	//				matrix setter take any string; and the library file is parsed
	//				by the (Swift) LDrawFile, which reports a malformed file through
	//				-loadModelForName:inGroup: returning NO (BUG-007). The @catch is
	//				therefore gone; the two explicit failures below are the ones
	//				the ObjC already had.
	//
	//==========================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override init?(lines: [NSObject]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		// No lines: the ObjC messaged nil all the way to its "not a type-1 line"
		// failure.
		guard let lines else {
			NSLog("the part %@ was fatally invalid", "(null)")
			NSLog(" raised exception %@", "BricksmithParseException")
			return nil
		}
		// P6b: ObjC raised here (-objectAtIndex: past the end of the lines,
		// outside the @try); see KNOWN-BUGS BUG-046
		guard range.location < lines.count else {
			return nil
		}

		var workingLine: NSString?		= lines[range.location] as? NSString
		var parsedField: NSString?		= nil
		var transformation: Matrix4		= IdentityMatrix4

		super.init(lines: lines, in: range, parentGroup: parentGroup)

		/// -floatValue of the next field (0 for a missing field, as messaging nil).
		func nextFloat() -> Float {
			return readNextField(&workingLine)?.floatValue ?? 0
		}

		//Read in the line code and advance past it.
		parsedField = readNextField(&workingLine)
		//Only attempt to create the part if this is a valid line.
		if (parsedField?.integerValue ?? 0) == 1 {
			//Read in the color code.
			// (color)
			parsedField = readNextField(&workingLine)
			let parsedColor = LDrawUtilities.parseColor(fromField: parsedField as String?)
			self.setLDrawColor(parsedColor)

			//Read position.
			transformation.element.3.0 = nextFloat()	// (x)
			transformation.element.3.1 = nextFloat()	// (y)
			transformation.element.3.2 = nextFloat()	// (z)

			//Read Transformation X.
			transformation.element.0.0 = nextFloat()	// (a)
			transformation.element.1.0 = nextFloat()	// (b)
			transformation.element.2.0 = nextFloat()	// (c)

			//Read Transformation Y.
			transformation.element.0.1 = nextFloat()	// (d)
			transformation.element.1.1 = nextFloat()	// (e)
			transformation.element.2.1 = nextFloat()	// (f)

			//Read Transformation Z.
			transformation.element.0.2 = nextFloat()	// (g)
			transformation.element.1.2 = nextFloat()	// (h)
			transformation.element.2.2 = nextFloat()	// (i)

			//finish off the corner of the matrix.
			transformation.element.3.3 = 1

			self.setTransformationMatrix(&transformation)

			//Read Part Name
			// (part.dat) -- It can have spaces (for MPD models), so we just use the whole
			// rest of the line.
			// (This is -setDisplayName:parse:YES inGroup:, split so that a library
			// part that fails to parse fails this part, as when that parse threw.)
			self.setDisplayName(workingLine?.trimmingCharacters(in: .whitespaces),
								parse: false,
								in: parentGroup)
			if		((self.displayNameStorage as NSString?)?.length ?? 0) > 0
				&&	PartLibrary.shared().loadModel(forName: self.referenceNameStorage, in: nil) == false {
				NSLog("the part %@ was fatally invalid", String(describing: lines[range.location]))
				NSLog(" raised exception %@", "BricksmithParseException")
				return nil
			}

			// Debug check: full part resolution isn't thread-safe so make sure we haven't run it by accident here!
			assert(self.cacheType == .unresolved)
		}
		else {
			// Not a type-1 line. (This used to throw to the @catch; it cannot
			// happen from a file, because the line type chose this class.)
			NSLog("the part %@ was fatally invalid", String(describing: lines[range.location]))
			NSLog(" raised exception %@", "BricksmithParseException")
			return nil
		}
	}


	//========== initWithLines:inRange: ========================================
	//
	// Purpose:		LDrawDirective's blocking-parse convenience; calls the
	//				parse initializer above, as the ObjC one does.
	//
	//==========================================================================
	@objc(initWithLines:inRange:)
	override convenience init?(lines: [NSObject]!, in range: NSRange) {
		self.init(lines: lines, in: range, parentGroup: nil)
	}


	//========== initWithCoder: ================================================
	//
	// Purpose:		Reads a representation of this object from the given coder,
	//				which is assumed to always be a keyed decoder. This allows us
	//				to read and write LDraw objects as NSData.
	//
	//==========================================================================
	@objc(initWithCoder:)
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)

		self.setDisplayName(decoder.decodeObject(forKey: "displayName") as? String)

		// Parts may have icons other than the standard "Brick", i.e. LSynth constraints
		self.setIconName(decoder.decodeObject(forKey: "iconName") as? String)

		//Decoding structures is a bit messy. memcpy: the bytes have no alignment promise.
		memcpy(&self.glTransformation, decoder.decodeBytes(forKey: glTransformationKey, returnedLength: nil),
			   MemoryLayout<GLMatrix16>.size)
	}


	//========== encodeWithCoder: ==============================================
	//
	// Purpose:		Writes a representation of this object to the given coder,
	//				which is assumed to always be a keyed decoder. This allows us
	//				to read and write LDraw objects as NSData.
	//
	//==========================================================================
	@objc(encodeWithCoder:)
	override func encode(with encoder: NSCoder) {
		super.encode(with: encoder)

		encoder.encode(self.displayNameStorage, forKey: "displayName")

		// Parts may have icons other than the standard "Brick", i.e. LSynth constraints
		encoder.encode(self.iconName(), forKey: "iconName")
		withUnsafeBytes(of: self.glTransformation) {
			encoder.encodeBytes($0.bindMemory(to: UInt8.self).baseAddress, length: MemoryLayout<GLMatrix16>.size,
								forKey: glTransformationKey)
		}
	}


	//========== copyWithZone: =================================================
	//
	// Purpose:		Returns a duplicate of this file.
	//
	//==========================================================================
	@objc(copyWithZone:)
	override func copy(with zone: NSZone? = nil) -> Any {
		let copied			= (super.copy(with: zone) as AnyObject) as! LDrawPart	// (a class cast: `as!` from Any is a slow existential cast)
		var transformation	= self.transformationMatrix()

		// As -setDisplayName:, with the reference name carried over rather than
		// lowercased again: it is always -lowercaseString of the display name
		// (both are only set together, here and in the redirect migration), and
		// this skips bridging both names through NSString per copied part.
		copied.setDisplayName(self.displayNameStorage, referenceName: self.referenceNameStorage, parse: true, in: nil)
		copied.setTransformationMatrix(&transformation)

		return copied
	}


	// MARK: - DIRECTIVES

	//========== drawSelf: =====================================================
	//
	// Purpose:		Draw this directive and its subdirectives by calling APIs on
	//				the passed in renderer, then calling drawSelf on children.
	//
	// Notes:		Parts draw by pushing the matrix and color instancing info
	//				they contain into the renderer, then passing drawSelf to the
	//				model backing the part, if it exists.
	//
	//==========================================================================
	@objc(drawSelf:)
	override func drawSelf(_ renderer: (any LDrawRenderer)!) {
		// One direct call (collectorColor, P6c) reads `hidden` and `color` (no
		// getter sends or retains per part per frame), choosing the colour as the
		// ObjC did: current colour (16) -> no push (LDrawRenderCurrentColor is
		// NULL), edge colour (24) -> LDrawRenderComplimentColor, else the RGBA.
		// (Reading the colour before -resolvePart is the same: resolving doesn't
		// touch it.)
		var rgba: (GLfloat, GLfloat, GLfloat, GLfloat) = (0, 0, 0, 0)
		withUnsafeMutablePointer(to: &rgba) { rp in
			rp.withMemoryRebound(to: GLfloat.self, capacity: 4) { scratch in
				var color: UnsafeMutablePointer<GLfloat>? = nil
				guard self.collectorColor(scratch, &color) else { return }

				self.resolve()

				guard let cacheModel = self.cacheModel else { return }

				// Old rendering code did not actually support
				// pushing the edge color as the new current
				// color - and it's probably against spec.  But
				// it's not really the place of drawSelf to go
				// slappign wrists, so pass it to the render,
				// which actually DOES know how to get this case
				// right.
				let pushesColor = (color != nil)
				if pushesColor {
					renderer.pushColor(color)
				}

				if self.isSelected() == true {
					renderer.pushWireFrame()
				}

				// The renderer copies the matrix (-pushMatrix: multiplies it into
				// its stack), so a stack copy will do.
				var matrix = self.glTransformation
				withUnsafeMutablePointer(to: &matrix) {
					$0.withMemoryRebound(to: GLfloat.self, capacity: 16) { renderer.pushMatrix($0) }
				}

				cacheModel.drawSelf(renderer)

				renderer.popMatrix()
				if pushesColor {
					renderer.popColor()
				}

				if self.isSelected() == true {
					renderer.popWireFrame()
				}
			}
		}
	}


	//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =====
	//
	// Purpose:		Hit-test the geometry.
	//
	//==========================================================================
	@objc(hitTest:transform:viewScale:boundsOnly:creditObject:hits:)
	override func hitTest(_ pickRay: Ray3, transform: Matrix4, viewScale scaleFactor: Float, boundsOnly: Bool,
						  creditObject: Any!, hits: NSMutableDictionary!) {
		assertionFailure("Deprecated.")
	}


	//========== boxTest:transform:boundsOnly:creditObject:hits: ===============
	//
	// Purpose:		Check for intersections with screen-space geometry.
	//
	//==========================================================================
	@objc(boxTest:transform:boundsOnly:creditObject:hits:)
	override func boxTest(_ bounds: Box2, transform: Matrix4, boundsOnly: Bool, creditObject: Any!, hits: NSMutableSet!) -> Bool {
		if self.isHidden() == false {
			if VolumeCanIntersectBox(self.boundingBox3(), transform, bounds) == false {
				return false
			}

			let partTransform		= self.transformationMatrix()
			let combinedTransform	= Matrix4Multiply(partTransform, transform)
			var creditObject		= creditObject

			// Credit all subgeometry to ourselves (unless we are already a child part)
			if creditObject == nil {
				creditObject = self
			}

			self.resolve()
			let modelToDraw: LDrawDirective? = self.cacheModel

			assert(boundsOnly == false)
			if boundsOnly == false {
				// (Messaging a nil model answered NO.)
				if modelToDraw?.boxTest(bounds, transform: combinedTransform, boundsOnly: false, creditObject: creditObject, hits: hits) == true {
					if creditObject != nil {
						return true
					}
				}
			}
		}
		return false
	}


	//========== depthTest:inBox:transform:creditObject:bestObject:bestDepth: ==
	//
	// Purpose:		depthTest finds the closest primitive (in screen space)
	//				overlapping a given point, as well as its device coordinate
	//				depth.
	//
	//==========================================================================
	@objc(depthTest:inBox:transform:creditObject:bestObject:bestDepth:)
	override func depthTest(_ pt: Point2, inBox bounds: Box2, transform: Matrix4, creditObject: Any!,
							bestObject: AutoreleasingUnsafeMutablePointer<AnyObject?>!,
							bestDepth: UnsafeMutablePointer<Float>!) {
		if self.isHidden() == false {
			if VolumeCanIntersectPoint(self.boundingBox3(), transform, bounds, bestDepth.pointee) == false {
				return
			}

			let partTransform		= self.transformationMatrix()
			let combinedTransform	= Matrix4Multiply(partTransform, transform)
			var creditObject		= creditObject

			// Credit all subgeometry to ourselves (unless we are already a child part)
			if creditObject == nil {
				creditObject = self
			}

			self.resolve()
			let modelToDraw: LDrawDirective? = self.cacheModel

			modelToDraw?.depthTest(pt, inBox: bounds, transform: combinedTransform, creditObject: creditObject,
								   bestObject: bestObject, bestDepth: bestDepth)
		}
	}


	//========== write =========================================================
	//
	// Purpose:		Returns a line that can be written out to a file.
	//
	//				Line format:
	//				1 colour x y z a b c d e f g h i part.dat
	//
	//				Matrix format:
	//				+-       -+
	//				| a d g 0 |
	//				| b e h 0 |
	//				| c f i 0 |
	//				| x y z 1 |
	//				+-       -+
	//
	//==========================================================================
	@objc(write)
	override func write() -> String! {
		// Same bytes as stringWithFormat:@"1 %@ ..." ("%@" of nil printed "(null)").
		let t = self.transformationMatrix().element
		func f(_ number: Float) -> String { LDrawUtilities.outputString(for: number) ?? "(null)" }
		let color = LDrawUtilities.outputString(for: self.lDrawColor()) ?? "(null)"

		let name	= self.displayNameStorage ?? "(null)"

		// position (x y z), then transformation X (a b c), Y (d e f) and Z (g h i), then the name.
		return "1 \(color) \(f(t.3.0)) \(f(t.3.1)) \(f(t.3.2)) \(f(t.0.0)) \(f(t.1.0)) \(f(t.2.0)) \(f(t.0.1)) \(f(t.1.1)) \(f(t.2.1)) \(f(t.0.2)) \(f(t.1.2)) \(f(t.2.2)) \(name)"
	}


	// MARK: - DISPLAY

	//========== browsingDescription ===========================================
	//
	// Purpose:		Returns a representation of the directive as a short string
	//				which can be presented to the user.
	//
	//				Here we want the part name displayed.
	//
	//==========================================================================
	@objc(browsingDescription)
	override func browsingDescription() -> String! {
		return PartLibrary.shared().description(for: self)
	}


	//========== inspectorClassName ============================================
	//
	// Purpose:		Returns the name of the class used to inspect this one.
	//
	//==========================================================================
	@objc(inspectorClassName)
	override func inspectorClassName() -> String! {
		return "InspectionPart"
	}


	// MARK: - ACCESSORS

	//========== boundingBox3 ==================================================
	//
	// Purpose:		Returns the minimum and maximum points of the box which
	//				perfectly contains this object. Returns InvalidBox if the part
	//				cannot be found.
	//
	//==========================================================================
	@objc(boundingBox3)
	override func boundingBox3() -> Box3 {
		if self.revalCache(.CacheFlagBounds) == .CacheFlagBounds {
			self.resolve()
			let modelToDraw		= self.cacheModel

			var bounds			= InvalidBox
			self.cacheBounds	= InvalidBox
			let transformation	= self.transformationMatrix()

			// We need to have an actual model here. Blithely calling boundingBox3 will
			// result in most of our Box3 structure being garbage data!
			if let modelToDraw, self.isHidden() == false {
				bounds = modelToDraw.boundingBox3()

				if V3EqualBoxes(bounds, InvalidBox) == 0 {
					// Transform all the points of the bounding box to find the new
					// minimum and maximum. (In the ObjC's order, without an array.)
					func add(_ x: Float, _ y: Float, _ z: Float) {
						let vertex = V3MulPointByProjMatrix(V3Make(x, y, z), transformation)
						self.cacheBounds = V3UnionBoxAndPoint(self.cacheBounds, vertex)
					}
					add(bounds.min.x, bounds.min.y, bounds.min.z)
					add(bounds.min.x, bounds.min.y, bounds.max.z)
					add(bounds.min.x, bounds.max.y, bounds.max.z)
					add(bounds.min.x, bounds.max.y, bounds.min.z)

					add(bounds.max.x, bounds.min.y, bounds.min.z)
					add(bounds.max.x, bounds.min.y, bounds.max.z)
					add(bounds.max.x, bounds.max.y, bounds.max.z)
					add(bounds.max.x, bounds.max.y, bounds.min.z)
				}
			}
		}

		return self.cacheBounds
	}


	//========== displayName ===================================================
	//
	// Purpose:		Returns the name of the part as the user typed it. This
	//				maintains the user's upper- and lower-case usage.
	//
	//==========================================================================
	@objc(displayName)
	func displayName() -> String! {
		return self.displayNameStorage
	}


	//========== position ======================================================
	//
	// Purpose:		Returns the coordinates at which the part is drawn.
	//
	// Notes:		This is purely a convenience method. The actual position is
	//				encoded in the transformation matrix. If you wish to set the
	//				position, you should set either the matrix or the
	//				Transformation Components.
	//
	//==========================================================================
	@objc(position)
	override func position() -> Point3 {
		let components	= self.transformComponents()
		let position	= components.translate

		return position
	}


	//========== referenceName =================================================
	//
	// Purpose:		Returns the name of the part. This is the filename where the
	//				part is found. Since Macintosh computers are case-insensitive,
	//				I have adopted lower-case as the standard for names.
	//
	//==========================================================================
	@objc(referenceName)
	func referenceName() -> String! {
		return self.referenceNameStorage
	}


	//========== referencedMPDSubmodel =========================================
	//
	// Purpose:		Returns the MPD model to which this part refers, or nil if
	//				there is no submodel in this part's file which has the name
	//				this part specifies.
	//
	// Note:		This method is ONLY intended to be used for resolving MPD
	//				references. If you want to resolve the general reference, you
	//				should call -modelForPart: in the PartLibrary!
	//
	//==========================================================================
	@objc(referencedMPDSubmodel)
	func referencedMPDSubmodel() -> LDrawModel! {
		var model: LDrawModel?	= nil
		let enclosingFile		= self.enclosingFile()

		if let enclosingFile {
			model = enclosingFile.model(withName: self.referenceNameStorage)
		}

		//No can do if we get a reference back to ourselves. That would be
		// an infinitely-recursing reference, which is bad!
		if model === self.enclosingStep()?.enclosingModel() {
			model = nil
		}

		return model
	}


	//========== referencedPeerFile ============================================
	//
	// Purpose:		Returns the primary model for a peer file to which this part
	//				refers, or nil if this part is not resolved/resolvable to a
	//				peer file.
	//
	// Note:		This method is ONLY intended to be used for resolving peer
	//				file references. If you want to resolve the general reference,
	//				you should call -modelForPart: in the PartLibrary!
	//
	//				referencedPeerFile will attempt re-resolution for unresolved
	//				parts.
	//
	//==========================================================================
	@objc(referencedPeerFile)
	func referencedPeerFile() -> LDrawModel! {
		if self.cacheType == .unresolved {
			self.resolve()
		}
		if self.cacheType != .peerFile {
			return nil
		}
		return self.cacheModel
	}


	//========== transformComponents ===========================================
	//
	// Purpose:		Returns the individual components of the transformation
	//				matrix applied to this part.
	//
	//==========================================================================
	@objc(transformComponents)
	func transformComponents() -> TransformComponents {
		let transformation	= self.transformationMatrix()
		var components		= IdentityComponents

		//This is a pretty darn neat little function. I wish I could say I wrote it.
		// It will extract all the user-friendly components out of this nasty matrix.
		Matrix4DecomposeTransformation(transformation, &components)

		return components
	}


	//========== transformationMatrix ==========================================
	//
	// Purpose:		Returns a two-dimensional (row matrix) representation of the
	//				part's transformation matrix.
	//
	//																+-       -+
	//				+-                           -+        +-     -+| a d g 0 |
	//				|a d g 0 b e h c f i 0 x y z 1|  -->   |x y z 1|| b e h 0 |
	//				+-                           -+        +-     -+| c f i 0 |
	//																| x y z 1 |
	//																+-       -+
	//					  OpenGL Matrix Format                 LDraw Matrix
	//				(flat column-major of transpose)              Format
	//
	//==========================================================================
	@objc(transformationMatrix)
	func transformationMatrix() -> Matrix4 {
		return withUnsafePointer(to: self.glTransformation) {
			$0.withMemoryRebound(to: GLfloat.self, capacity: 16) { Matrix4CreateFromGLMatrix4($0) }
		}
	}


	//========== setEnclosingDirective: ========================================
	@objc(setEnclosingDirective:)
	override func setEnclosing(_ newParent: LDrawContainer!) {
		self.unresolvePart()
		super.setEnclosing(newParent)
	}


	//========== setLDrawColor: ================================================
	//
	// Purpose:		Sets the color of this element.
	//
	//==========================================================================
	@objc(setLDrawColor:)
	override func setLDrawColor(_ newColor: LDrawColor!) {
		super.setLDrawColor(newColor)

		self.unresolvePart()
		self.invalCache(.CacheFlagBounds)
	}


	//========== setDisplayName: ===============================================
	//
	// Purpose:		Updates the name of the part and attempts to load it into
	//				the part library.
	//
	//==========================================================================
	@objc(setDisplayName:)
	func setDisplayName(_ newPartName: String!) {
		self.setDisplayName(newPartName, parse: true, in: nil)
	}


	//========== setDisplayName:parse:inGroup: =================================
	//
	// Purpose:		Updates the name of the part. This is the filename where the
	//				part is found.
	//
	//				If shouldParse is YES, pre-loads the referenced part if
	//				possible. Pre-loading is very import in initial model loading,
	//				because it enables structual optimizations to be performed
	//				prior to OpenGL optimizations. It also results in a more
	//				honest load progress bar.
	//
	// Notes:		References to LDraw/parts and LDraw/p are simply encoded as the
	//				file name. However, references to LDraw/parts/s are encoded as
	//				"s\partname.dat". The part library, meanwhile, must properly
	//				handle the s\ prefix.
	//
	//				The reference name is NSString's -lowercaseString (it maps a
	//				final sigma differently from Swift's lowercased()).
	//
	//==========================================================================
	@objc(setDisplayName:parse:inGroup:)
	func setDisplayName(_ newPartName: String!, parse shouldParse: Bool, in parentGroup: dispatch_group_t!) {
		let newReferenceName			= (newPartName as NSString?)?.lowercased

		setDisplayName(newPartName, referenceName: newReferenceName, parse: shouldParse, in: parentGroup)
	}


	//---------- setDisplayName(_:referenceName:parse:in:) ---------------------
	//
	// Purpose:		The body of -setDisplayName:parse:inGroup:, given the
	//				reference name (the display name's -lowercaseString).
	//
	//--------------------------------------------------------------------------
	private func setDisplayName(_ newPartName: String!, referenceName newReferenceName: String?, parse shouldParse: Bool, in parentGroup: dispatch_group_t!) {
		let parseGroup: dispatch_group_t? = nil

		self.displayNameStorage = newPartName

		self.referenceNameStorage = newReferenceName

		assert(parentGroup == nil || self.cacheType == .unresolved)

		self.unresolvePart()

		// Force the part library to parse the model this part will display. This
		// pushes all parsing into the same operation, which improves loading time
		// predictability and allows better potential threading optimization.
		//
		// Ben says: we _have_ to call this, even on MPD and peer models.  Since
		// we don't know what kind of thing we are, checking the cache type will
		// always return unresolved.  But I don't think I want to force-resolve
		// here - resolving later prevents thrash.
		if shouldParse == true, let newPartName, (newPartName as NSString).length > 0 {
			PartLibrary.shared().loadModel(forName: self.referenceNameStorage, in: parseGroup)
		}
	}


	//========== setTransformComponents: =======================================
	//
	// Purpose:		Converts the given componets (rotation, scaling, etc.) into
	//				an internal transformation matrix represenation.
	//
	//==========================================================================
	@objc(setTransformComponents:)
	func setTransformComponents(_ newComponents: TransformComponents) {
		var newComponents	= newComponents
		var transformation	= Matrix4CreateTransformation(&newComponents)

		self.setTransformationMatrix(&transformation)
	}


	//========== setTransformationMatrix: ======================================
	//
	// Purpose:		Converts the row-major row-vector matrix into a flat column-
	//				major column-vector matrix understood by OpenGL.
	//
	//
	//			 +-       -+     +-       -++- -+
	//	+-     -+| a d g 0 |     | a b c x || x |
	//	|x y z 1|| b e h 0 |     | d e f y || y |     +-                           -+
	//	+-     -+| c f i 0 | --> | g h i z || z | --> |a d g 0 b e h c f i 0 x y z 1|
	//			 | x y z 1 |     | 0 0 0 1 || 1 |     +-                           -+
	//			 +-       -+     +-       -++- -+
	//		LDraw Matrix            Transpose               OpenGL Matrix Format
	//		   Format                                 (flat column-major of transpose)
	//  (also Matrix4 format)
	//
	//==========================================================================
	@objc(setTransformationMatrix:)
	func setTransformationMatrix(_ newMatrix: UnsafeMutablePointer<Matrix4>!) {
		self.invalCache(.CacheFlagBounds)
		self.storeGLMatrix(newMatrix.pointee)
	}

	/// Matrix4GetGLMatrix4(matrix, self->glTransformation)
	private func storeGLMatrix(_ matrix: Matrix4) {
		withUnsafeMutablePointer(to: &self.glTransformation) {
			$0.withMemoryRebound(to: GLfloat.self, capacity: 16) { Matrix4GetGLMatrix4(matrix, $0) }
		}
	}


	//========== setSelected: ==================================================
	//
	// Purpose:		Somebody make this a protocol method.
	//
	//==========================================================================
	@objc(setSelected:)
	override func setSelected(_ flag: Bool) {
		super.setSelected(flag)

		// would like LDrawContainer to be a protocol.  In its absence, respondsToSelector: works
		// (A nil parent answered NO in ObjC.)
		if let parent = self.enclosingDirective(),
		   parent.responds(to: #selector(LDrawContainer.setSubdirectiveSelected(_:))) {
			parent.setSubdirectiveSelected(flag)
		}
	}


	// MARK: - MOVEMENT

	//========== displacementForNudge: =========================================
	//
	// Purpose:		Returns the amount by which the element wants to move, given
	//				a "nudge" in the specified direction. A "nudge" is generated
	//				by pressing the arrow keys. We scale this value so as to make
	//				nudging go by plate-heights vertically and brick widths
	//				horizontally.
	//
	//==========================================================================
	@objc(displacementForNudge:)
	override func displacement(forNudge nudgeVector: Vector3) -> Vector3 {
		var nudgeVector				= nudgeVector
		var transformationMatrix	= IdentityMatrix4
		var inverseMatrix			= IdentityMatrix4
		var worldNudge				= V4Make(0, 0, 0, 1)
		var brickNudge				= V4Make(0, 0, 0, 0)

		//convert incoming 3D vector to 4D for our math:
		worldNudge.x = nudgeVector.x
		worldNudge.y = nudgeVector.y
		worldNudge.z = nudgeVector.z

		//Figure out which direction we're asking to move the part itself.
		transformationMatrix	= self.transformationMatrix()
		inverseMatrix			= Matrix4Invert( transformationMatrix )
		inverseMatrix.element.3.0 = 0 //zero out the translation part, leaving only rotation etc.
		inverseMatrix.element.3.1 = 0
		inverseMatrix.element.3.2 = 0

		//See if this is a nudge along the brick's "up" direction.
		// If so, the nudge needs to be a different magnitude, to compensate
		// for the fact that Lego bricks are not square!
		brickNudge = V4MulPointByMatrix(worldNudge, inverseMatrix)
		if		abs(brickNudge.y) > abs(brickNudge.x)
			&&	abs(brickNudge.y) > abs(brickNudge.z) {
			//The trouble is, we need to do different things for different
			// scales. For instance, in medium mode, we probably want to
			// move 1/2 stud horizontally but 1/3 stud vertically.
			//
			// But in coarse mode, we want to move 1 stud horizontally and
			// vertically. These are different ratios! So I test for known
			// numbers, and only apply modifications if they are recognized.

			let nudgeDistance: Float = V3Length(nudgeVector)

			let k_small_nudge: Float = 0.0001

			// (24.0 / 20.0 and 8.0 / 10.0 are doubles in C, rounded to the float parameter.)
			if floatNearGrid(nudgeDistance, 20, k_small_nudge) {
				nudgeVector = V3MulScalar(nudgeVector, Float(24.0 / 20.0 as Double))
			}
			else if floatNearGrid(nudgeDistance, 10, k_small_nudge) {
				nudgeVector = V3MulScalar(nudgeVector, Float(8.0 / 10.0 as Double))
			}
		}

		//we now have a nudge based on the correct size: plates or bricks.
		return nudgeVector
	}


	//========== componentsSnappedToGrid:minimumAngle: =========================
	//
	// Purpose:		Returns a copy of the part's current components, but snapped
	//				to the grid. Kinda a weird legacy API.
	//
	//==========================================================================
	@objc(componentsSnappedToGrid:minimumAngle:)
	func componentsSnapped(toGrid gridSpacing: Float, minimumAngle degrees: Float) -> TransformComponents {
		let components = self.transformComponents()

		return self.components(components, snappedToGrid: gridSpacing, minimumAngle: degrees)
	}


	//========== components:snappedToGrid:minimumAngle: ========================
	//
	// Purpose:		Aligns the given components to an imaginary grid along lines
	//				separated by a distance of gridSpacing. This is done
	//				intelligently based on the current orientation of the
	//				receiver: if gridSpacing == 20, that is assumed to mean "1
	//				stud," so the y-axis (up) of the part will be aligned along a
	//				grid spacing of 24 (1 stud vertically).
	//
	//				The part's rotation angles will be adjusted to multiples of the
	//				minimum angle specified.
	//
	// Parameters:	components	- transform to adjust.
	//				gridSpacing	- the grid line interval along stud widths.
	//				degrees		- angle granularity. Pass 0 to leave angle
	//							  unchanged.
	//
	// Notes:		C promoted the float arithmetic with double constants to
	//				double (radians(), fmod, `*= 24.0 / 20.0`); kept explicitly.
	//
	//==========================================================================
	@objc(components:snappedToGrid:minimumAngle:)
	func components(_ components: TransformComponents, snappedToGrid gridSpacing: Float, minimumAngle degrees: Float) -> TransformComponents {
		var components					= components
		let rotationRadians: Float		= Float(Double(degrees) * Double.pi / 180)	// radians(degrees)

		var transformationMatrix		= IdentityMatrix4
		let yAxisOfPart					= V4Make(0, 1, 0, 1)
		var worldY						= V4Make(0, 0, 0, 1) //yAxisOfPart converted to world coordinates
		var worldY3						= V3Make(0, 0, 0)
		var gridSpacingYAxis: Float		= 0.0
		var gridX: Float				= 0.0
		var gridY: Float				= 0.0
		var gridZ: Float				= 0.0

		//---------- Adjust position to grid -----------------------------------

		//Figure out which direction the y-axis is facing in world coordinates:
		transformationMatrix = self.transformationMatrix()
		transformationMatrix.element.3.0 = 0 //zero out the translation part, leaving only rotation etc.
		transformationMatrix.element.3.1 = 0
		transformationMatrix.element.3.2 = 0
		worldY	= V4MulPointByMatrix(yAxisOfPart, transformationMatrix)

		worldY3	= V3FromV4(worldY)
		worldY3 = V3IsolateGreatestComponent(worldY3)
		worldY3	= V3Normalize(worldY3)

		//Get the adjusted grid spacing along the y direction. Remember that Lego
		// bricks are not cubical, so the grid along the brick's y-axis should be
		// spaced differently from the grid along its other sides.
		gridSpacingYAxis = gridSpacing

		if fmod(Double(gridSpacing), 20) == 0 {
			gridSpacingYAxis = Float(Double(gridSpacingYAxis) * (24.0 / 20.0))
		}
		else if fmod(Double(gridSpacing), 10) == 0 {
			gridSpacingYAxis = Float(Double(gridSpacingYAxis) * (8.0 / 10.0))
		}

		//The actual grid spacing, in world coordinates. We will adjust the approrpiate
		// x, y, or z based on which one the part's y-axis is aligned.
		gridX = gridSpacing
		gridY = gridSpacing
		gridZ = gridSpacing

		//Find the direction of the part's Y-axis, and change its grid.
		if worldY3.x != 0 {
			gridX = gridSpacingYAxis
		}

		if worldY3.y != 0 {
			gridY = gridSpacingYAxis
		}

		if worldY3.z != 0 {
			gridZ = gridSpacingYAxis
		}

		// Snap to the Grid!
		// Figure the closest grid line and bump the part to it.
		// Logically, this is a rounding operation with a granularity of the grid
		// size. So all we need to do is normalize, round, then expand back to the
		// original size.

		components.translate.x = roundf(components.translate.x/gridX) * gridX
		components.translate.y = roundf(components.translate.y/gridY) * gridY
		components.translate.z = roundf(components.translate.z/gridZ) * gridZ


		//---------- Snap angles -----------------------------------------------

		if rotationRadians != 0 {
			components.rotate.x = roundf(components.rotate.x/rotationRadians) * rotationRadians
			components.rotate.y = roundf(components.rotate.y/rotationRadians) * rotationRadians
			components.rotate.z = roundf(components.rotate.z/rotationRadians) * rotationRadians
		}

		//round-off errors here? Potential for trouble.
		return components
	}


	//========== moveBy: =======================================================
	//
	// Purpose:		Moves the receiver in the specified direction.
	//
	//==========================================================================
	@objc(moveBy:)
	override func move(by moveVector: Vector3) {
		var transformationMatrix = self.transformationMatrix()

		//I NEED to modify the matrix itself here. Some parts have funky, fragile
		// rotation values, and getting the components really badly botches them up.
		transformationMatrix = Matrix4Translate(transformationMatrix, moveVector)

		self.setTransformationMatrix(&transformationMatrix)
		self.sendMessage(toObservers: .observedChanged)
	}


	//========== position:snappedToGrid: =======================================
	//
	// Purpose:		Orients position at discrete points separated by the given
	//				grid spacing.
	//
	// Notes:		This method may be overridden by subclasses to provide more
	//				intelligent grid alignment.
	//
	//				This method is provided mainly as a service to drag-and-drop.
	//				In the case of LDrawParts, you should generally avoid this
	//				method in favor of
	//				-[LDrawPart components:snappedToGrid:minimumAngle:].
	//
	//==========================================================================
	@objc(position:snappedToGrid:)
	override func position(_ position: Point3, snappedToGrid gridSpacing: Float) -> Point3 {
		var components = IdentityComponents

		// copy the position into a transform
		components.translate = position

		// Snap to grid using intelligent LDrawPart logic
		components = self.components(components, snappedToGrid: gridSpacing, minimumAngle: 0)

		// copy the new position back out of the components
		return components.translate
	}


	//========== rotateByDegrees: ==============================================
	//
	// Purpose:		Rotates the part by the specified angles around its
	//				centerpoint.
	//
	//==========================================================================
	@objc(rotateByDegrees:)
	func rotate(byDegrees degreesToRotate: Tuple3) {
		let partCenter = self.position()

		//Rotate!
		self.rotate(byDegrees: degreesToRotate, centerPoint: partCenter)
	}


	//========== rotateByDegrees:centerPoint: ==================================
	//
	// Purpose:		Performs an additive rotation on the part, rotating by the
	//				specified number of degress around each axis. The part will be
	//				rotated around the specified centerpoint.
	//
	// Notes:		This gets a little tricky because there is more than one way
	//				to represent a single rotation when using three rotation
	//				angles. Since we don't really know which one was intended, we
	//				can't just blithely manipulate the rotation components.
	//
	//				Instead, we must generate a new transformation matrix that
	//				rotates by degreesToRotate in the desired direction. Then we
	//				multiply that matrix by the part's current transformation.
	//				This way, we can rest assured that we rotated the part exactly
	//				the direction the user intended, no matter what goofy
	//				representation the components came up with.
	//
	//				Caveat: We have to do some translations to take into account
	//				the centerpoint.
	//
	//==========================================================================
	@objc(rotateByDegrees:centerPoint:)
	func rotate(byDegrees degreesToRotate: Tuple3, centerPoint rotationCenter: Point3) {
		var transform				= self.transformationMatrix()
		let displacement			= rotationCenter
		let negativeDisplacement	= V3Negate(rotationCenter)

		//Do the rotation around the specified centerpoint.
		transform = Matrix4Translate(transform, negativeDisplacement) //translate to rotationCenter
		transform = Matrix4Rotate(transform, degreesToRotate) //rotate at rotationCenter
		transform = Matrix4Translate(transform, displacement) //translate back to original position

		self.setTransformationMatrix(&transform)
		self.sendMessage(toObservers: .observedChanged)
	}


	// MARK: - OBSERVER

	//========== observableSaysGoodbyeCruelWorld: ==============================
	//
	// Purpose:		Our cached model is going away (it is in its -dealloc).
	//
	// Notes:		Pointer comparison only: no retain of the dying model.
	//
	//==========================================================================
	@objc(observableSaysGoodbyeCruelWorld:)
	func observableSaysGoodbyeCruelWorld(_ doomedObservable: (any LDrawObservable)!) {
		if self.cacheType == .unresolved || self.cacheType == .notFound {
			NSLog("WARNING: LDraw part is receiving a notification that its observer is dying but it thinks it should have no observer.\n")
		}
		if !self.isCacheModel(doomedObservable) {
			NSLog("WARNING: LDraw part is receiving a notification from an observer that is not its cached drawable.\n")
		}

		self.unresolvePart()
	}

	/// doomedObservable == cacheModel, as pointers.
	private func isCacheModel(_ observable: (any LDrawObservable)?) -> Bool {
		let cached: UnsafeMutableRawPointer? = self.cacheModel.map { Unmanaged.passUnretained($0).toOpaque() }
		let other: UnsafeMutableRawPointer? = observable.map { Unmanaged.passUnretained($0 as AnyObject).toOpaque() }
		return cached == other
	}


	//========== statusInvalidated:who: ========================================
	//
	// Purpose:		This message is sent to us when a directive we are observing
	//				is invalidated.  We invalidate ourselves.  This is what makes
	//				our bbox need recalculating when a sub-model changes.
	//
	//==========================================================================
	@objc(statusInvalidated:who:)
	func statusInvalidated(_ flags: CacheFlagsT, who observable: (any LDrawObservable)!) {
		self.invalCache(flags.intersection(.CacheFlagBounds))
	}


	//========== receiveMessage:who: ===========================================
	//
	// Purpose:		The model we observe was renamed or moved to another scope:
	//				find it again on the next query.
	//
	//==========================================================================
	@objc(receiveMessage:who:)
	func receiveMessage(_ msg: MessageT, who observable: (any LDrawObservable)!) {
		if msg == .nameChanged {
			self.unresolvePart()
		}
		if msg == .scopeChanged {
			self.unresolvePart()
		}
	}


	// MARK: - UTILITIES

	//========== containsReferenceTo: ==========================================
	//
	// Purpose:		Returns if the part references a model with the given name.
	//				This is used by containers to detect circular references.
	//
	// Notes:		-isEqualToString: compares UTF-16 literally (no Unicode
	//				normalisation, unlike Swift's ==); nil on either side is NO.
	//
	//==========================================================================
	@objc(containsReferenceTo:)
	override func containsReference(to name: String!) -> Bool {
		guard let referenceName = self.referenceNameStorage, let name else {
			return false
		}
		let isMatch = (referenceName as NSString).isEqual(to: name)
		return isMatch
	}


	//========== partIsMissing =================================================
	//
	// Purpose:		Identifies whether the part cannot be found in any known
	//				places to look for it.
	//
	//==========================================================================
	@objc(partIsMissing)
	func partIsMissing() -> Bool {
		self.resolve()
		return self.cacheType == .notFound
	}


	//========== flattenIntoLines:triangles:quadrilaterals:other:currentColor: =
	//
	// Purpose:		Appends the directive into the appropriate container.
	//
	//==========================================================================
	@objc(flattenIntoLines:triangles:quadrilaterals:other:currentColor:currentTransform:normalTransform:recursive:)
	override func flatten(intoLines lines: NSMutableArray!, triangles: NSMutableArray!, quadrilaterals: NSMutableArray!,
						  other everythingElse: NSMutableArray!, currentColor parentColor: LDrawColor!,
						  currentTransform transform: Matrix4, normalTransform: Matrix3, recursive: Bool) {
		var modelToDraw: LDrawModel?	= nil
		var flatCopy: LDrawModel?		= nil
		let partTransform				= self.transformationMatrix()
		var combinedTransform			= IdentityMatrix4
		var normalTransform				= normalTransform

		// Nonrecursive flattenings are just trying to collect the primitives. Parts
		// should be completely ignored.
		if recursive == true {
			super.flatten(intoLines: lines,
						  triangles: triangles,
						  quadrilaterals: quadrilaterals,
						  other: everythingElse,
						  currentColor: parentColor,
						  currentTransform: transform,
						  normalTransform: normalTransform,
						  recursive: recursive)

			// Flattening involves applying the part's transform to copies of all
			// referenced vertices. (We are forced to make copies because you can't call
			// glMultMatrix inside a glBegin; the only way to draw all like geometry at
			// once is to have a flat, transformed copy of it.)

			// Do not go through the regular part resolution scheme - it is not thread safe.
			// Look up sub-model first, to avoid taking a lock on the shared library catalog ONLY
			// to discover that we aren't in there.

			modelToDraw = self.referencedMPDSubmodel()

			if modelToDraw == nil {
				modelToDraw = PartLibrary.shared().model(forName_threadSafe: self.referenceNameStorage)
			}

			flatCopy = modelToDraw?.copy() as? LDrawModel

			// concatenate the transform and pass it down
			combinedTransform	= Matrix4Multiply(partTransform, transform)

			// Normals are actually transformed by a different matrix.
			normalTransform		= Matrix3MakeNormalTransformFromProjMatrix(combinedTransform)

			flatCopy?.flatten(intoLines: lines,
							  triangles: triangles,
							  quadrilaterals: quadrilaterals,
							  other: everythingElse,
							  currentColor: self.lDrawColor(),
							  currentTransform: combinedTransform,
							  normalTransform: normalTransform,
							  recursive: recursive)
		}
	}


	//========== collectPartReport: ============================================
	//
	// Purpose:		Collects a report on this part. If this is really an MPD
	//				reference, we want to get a report on the submodel and not
	//				this actual part.
	//
	//==========================================================================
	@objc(collectPartReport:)
	func collect(_ report: PartReport!) {
		self.resolve()
		if self.cacheType == .submodel || self.cacheType == .peerFile {
			self.cacheModel?.collect(report)
		}
		else if self.cacheType == .library {
			// P6b: ObjC raised here (-[PartReport registerPart:] ends with
			// -setObject:forKey: keyed by the part's colour, nil for a part that
			// never had one, after counting the part); see KNOWN-BUGS
			// BUG-048
			guard self.lDrawColor() != nil else {
				return
			}
			report.register(self)
		}

		//There's a bug here: -referencedMPDSubmodel doesn't necessarily tell you if
		// this actually *is* a submodel reference. It may actually resolve to
		// something in the part library. In this case, we would draw the library
		// part, but report the submodel! I'm going to let this ride, because the
		// specification explicitly says the behavior in such a case is undefined.
	}


	//========== applyToAllParts: ==============================================
	//
	// Purpose:		This is part of a visitor API that applies a block to all
	//				parts. Since we are a part, we simply call it on ourselves.
	//
	//==========================================================================
	@objc(applyToAllParts:)
	func apply(toAllParts visitor: LDrawPartVisitor!) {
		visitor(self)
	}


	//========== registerUndoActions ===========================================
	//
	// Purpose:		Registers the undo actions that are unique to this subclass,
	//				not to any superclass.
	//
	// Notes:		The undo proxy is messaged dynamically, as in ObjC. Never ask
	//				it respondsToSelector: (that is recorded as the action) and
	//				never cast it to this final class (static dispatch; L103).
	//
	//==========================================================================
	@objc(registerUndoActions:)
	override func registerUndoActions(_ undoManager: UndoManager!) {
		super.registerUndoActions(undoManager)

		(undoManager.prepare(withInvocationTarget: self) as AnyObject).setTransformComponents(self.transformComponents())
		(undoManager.prepare(withInvocationTarget: self) as AnyObject).setDisplayName(self.displayName())

		undoManager.setActionName(NSLocalizedString("UndoAttributesPart", comment: ""))
	}


	//========== addedMPDModel =================================================
	//
	// Purpose:		This message is sent when a model is added to a MPD file; if
	//				we aren't fonud, we unresolve so that we can get a shot at
	//				re-resolving to the newly added part.
	//
	//==========================================================================
	@objc(addedMPDModel:)
	func addedMPDModel(_ notification: Notification!) {
		if self.cacheType == .notFound {
			self.unresolvePart()
		}
	}


	//========== resolvePart ===================================================
	//
	// Purpose:		Find the object this part references and record the way in
	//				which it was found.
	//
	//==========================================================================
	@objc(resolvePart)
	func resolve() {
		if self.cacheType == .unresolved {
			if let mdpModel = self.referencedMPDSubmodel() {
				self.cacheModel		= mdpModel
				self.cacheDrawable	= mdpModel
				self.cacheType		= .submodel

				self.invalCache(.CacheFlagBounds)
				mdpModel.add(self as LDrawObserver)
			}
			else {
				// P6b: ObjC raised here (-[LDrawPaths pathForPartName:nil], via
				// -[PartLibrary modelForName:], for a part with no name); see
				// KNOWN-BUGS BUG-047
				guard let referenceName = self.referenceNameStorage else {
					return
				}

				// Try the part library first for speed - sub-paths will thrash the modelmanager.
				self.cacheModel = PartLibrary.shared().model(forName: referenceName)
				if self.cacheModel != nil {
					// Intentional: do not observe library parts - they are immutable so
					// we don't need observations, and messing with the lib parts set is expensive.
					// [cacheModel addObserver:self];

					// WE DO NOT LOOK UP THE DRAWABLE VBO HERE!!!  Do that in -optimizeOpenGL
					// instead.
					self.cacheDrawable	= nil
					self.invalCache(.CacheFlagBounds)
					self.cacheType		= .library
				}
				else {
					let peerModel = ModelManager.shared().requestModel(referenceName, withDocument: self.enclosingFile())
					self.cacheModel = peerModel
					if let peerModel {
						self.cacheType		= .peerFile
						self.cacheDrawable	= peerModel
						self.invalCache(.CacheFlagBounds)
						peerModel.add(self as LDrawObserver)
					}
					else {
						self.cacheType		= .notFound
						self.cacheDrawable	= nil
						self.cacheModel		= nil
						self.invalCache(.CacheFlagBounds)
						// If we are not found, listen to the "sub-model-added" notification; ideally this would be on our enclosing LDrawFile but for
						// now listen to all instances.
						NotificationCenter.default.addObserver(self, selector: #selector(addedMPDModel(_:)),
															   name: NSNotification.Name(LDrawMPDSubModelAdded), object: nil)
					}
				}
			}
		}
	}


	//========== unresolvePart =================================================
	//
	// Purpose:		This method is called when something potentially breaks the
	//				link between a part and the underlying model that represents
	//				it. Typical events include: renaming the part (new name, new
	//				model), putting the part in a new container (new container,
	//				new MPD peers) or deallocing a directive tree in use by the
	//				observer (since parts have weak references to their models,
	//				this can in theory happen).
	//
	//==========================================================================
	@objc(unresolvePart)
	func unresolvePart() {
		if self.cacheType != .unresolved {
			if self.cacheType == .submodel || self.cacheType == .peerFile, let cacheModel = self.cacheModel {
				//printf("Part %p telling observer/cache %p to forget us.\n",self,cacheModel);
				cacheModel.remove(self as LDrawObserver)
			}

			if self.cacheType == .notFound {
				NotificationCenter.default.removeObserver(self, name: NSNotification.Name(LDrawMPDSubModelAdded), object: nil)
			}

			self.cacheType		= .unresolved
			self.cacheDrawable	= nil
			self.cacheModel		= nil
		}
	}


	//========== unresolvePartIfPartLibrary ====================================
	//
	// Purpose:		Unresolve a part only if it is a library part.  There are two
	//				cases: actual library parts and parts that were not found (and
	//				thus maybe they should be library parts but the library that
	//				was loaded was incomplete.
	//
	//				This is used by unresolveLibraryParts to reload the library.
	//
	//==========================================================================
	@objc(unresolvePartIfPartLibrary)
	func unresolvePartIfPartLibrary() {
		if self.cacheType == .library || self.cacheType == .notFound {
			self.unresolvePart()
		}
	}


	//========== followRedirectionAndUpdate ====================================
	//
	// Purpose:		For a part whose definition is the inclusion of a single
	//				other part (e.g. a short-cut or redirect), we find that actual
	//				part and swap us to use that part, taking into account the
	//				relative transform offset and "baking" it into our pose.
	//
	// Notes:		Previous versions of Bricksmith simply used a file name
	//				substitution; when ~Moved directives include a change of
	//				origin that is not enough, and this method is better.
	//
	//				This method will fail if we can't find exactly one part usage
	//				directive, because it is ambiguous what the move is.
	//
	//				Every step below messaged nil in ObjC when the file had gone
	//				(no path, no contents, no lines, no file): optional chaining.
	//
	//==========================================================================
	@objc(followRedirectionAndUpdate)
	func followRedirectionAndUpdate() {
		self.resolve()	// We need this to have a valid cache type and make sure we are
						// a library part.
		if self.cacheType == .library, let referenceName = self.referenceNameStorage {
			// This is a little gross, but: the library doesn't have the definition of our
			// part - it has a completely flattened soup of triangles, so that we
			// don't have to walk a giant part tree to draw using the library.  So we
			// can't use our cacheModel or drawable to figure out what the substitution is.

			// Instead we do it the low level way: we directly go load the original part
			// from disk so we can see its direct contents.  We keep the part manager out
			// of this - this is just a one-time look at a file for a one-time migration
			// operation.
			let partPath		= LDrawPaths.shared().path(forPartName: referenceName)
			let fileContents	= LDrawUtilities.string(fromFile: partPath)
			let lines			= (fileContents as NSString?)?.separateByLine()

			let parseGroup		= DispatchGroup()
			let parsedFile		= LDrawFile(lines: lines, in: NSMakeRange(0, lines?.count ?? 0), parentGroup: parseGroup) as LDrawFile?

			// The part parser is insanely dangerous: it parses on a dispatch group and fills in your
			// NS containers in the background later, with no locks. We use a dispatch group to
			// wait until the entire mess of loading is done, synchronously, so the part is safe to look at.
			parseGroup.wait()

			// We're going to go get all of the directives and try to find EXACTLY one LDrawPart.
			let directives		= parsedFile?.allEnclosedElements() ?? []
			var redirect: LDrawPart? = nil
			for directive in directives {
				if let part = directive as? LDrawPart {
					// If we find TWO LDrawParts, just bail out - it's not clear which one
					// is the redirect.  If anyone sees this fail in production with the real
					// LDraw library, we need to look at whawt on earth is going on with the
					// redirect part.
					if redirect == nil {
						redirect = part
					}
					else {
						return
					}
				}
			}

			if let redirect {
				// We found exactly one part.  Unresolve and copy out its names for future use.
				self.unresolvePart()
				self.referenceNameStorage	= redirect.referenceName()
				self.displayNameStorage		= redirect.displayName()

				// Our new location is our old location with the relative transform of that part applied.
				let new_loc = Matrix4Multiply(redirect.transformationMatrix(), self.transformationMatrix())
				self.storeGLMatrix(new_loc)
			}
		}
	}


	// MARK: - DESTRUCTOR

	//========== dealloc =======================================================
	//
	// Purpose:		It's time to go home to that great Lego room in the sky--where
	//				all teeth marks on secondhand bricks are healed, where the gold
	//				print never rubs off the classic spacemen, and where the white
	//				bricks never discolor.
	//
	//==========================================================================
	deinit {
		self.unresolvePart()
	}
}
