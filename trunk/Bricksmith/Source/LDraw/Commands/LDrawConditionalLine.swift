//==============================================================================
//
// File:		LDrawConditionalLine.swift
//
// Purpose:		Conditional-Line command.
//				Draws a line between the first two points, if the projections
//				of the last two points onto the screen are on the same side of
//				an imaginary line through the projections of the first two
//				points onto the screen.
//
//				Line format:
//				5 colour x1 y1 z1 x2 y2 z2 x3 y3 z3 x4 y4 z4
//
//				where
//
//				* colour is a colour code: 0-15, 16, 24, 32-47, 256-511
//				* x1, y1, z1 is the position of the first point
//				* x2, y2, z2 is the position of the second point
//				* x3, y3, z3 is the position of the third point
//				* x4, y4, z4 is the position of the fourth point
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//
//  Ported to Swift in P6a. The superclass (LDrawLine) is still ObjC, so its
//  ivars are read through -vertex1, -vertex2 and -LDrawColor.
//==============================================================================

import Foundation

/// -[LDrawUtilities readNextField:remainder:], keeping the fields as NSString.
private func readNextField(_ line: inout NSString?) -> NSString? {
	return LDrawUtilities.readNextField(line as String?, remainder: &line) as NSString?
}

/// Reads three fields as a point, with -floatValue (0 for a missing field, as messaging nil).
private func readVertex(_ line: inout NSString?) -> Point3 {
	var vertex = ZeroPoint3
	vertex.x = readNextField(&line)?.floatValue ?? 0
	vertex.y = readNextField(&line)?.floatValue ?? 0
	vertex.z = readNextField(&line)?.floatValue ?? 0
	return vertex
}


@objc(LDrawConditionalLine)
final class LDrawConditionalLine: LDrawLine {

	// Storage. Named apart from the accessor methods, which keep their selectors.
	@exclusivity(unchecked) private var control1: Point3 = ZeroPoint3
	@exclusivity(unchecked) private var control2: Point3 = ZeroPoint3


	// MARK: - INITIALIZATION

	//========== init ==========================================================
	//
	// Purpose:		Plain initializer: copying uses [[[self class] alloc] init].
	//
	//==========================================================================
	@objc(init)
	override init() {
		super.init()
	}


	//========== initWithLines:inRange:parentGroup: ============================
	//
	// Purpose:		Returns the LDraw directive based on lineFromFile, a single
	//				line of LDraw code from a file.
	//
	//				directive should have the format:
	//
	//				5 colour x1 y1 z1 x2 y2 z2 x3 y3 z3 x4 y4 z4
	//
	//==========================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override init?(lines: [NSObject]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		var workingLine: NSString?	= lines[range.location] as? NSString
		var parsedField: NSString?	= nil

		// Our superclass is LDrawLine, which has its own unique syntax, so we can't
		// call -[super initWithLines:inRange:]. The ObjC called [self init]; this
		// class's -init is super's.
		super.init()

		//Read in the line code and advance past it.
		parsedField = readNextField(&workingLine)
		//Only attempt to create the part if this is a valid line.
		if (parsedField?.integerValue ?? 0) == 5 {
			//Read in the color code.
			// (color)
			parsedField = readNextField(&workingLine)
			let parsedColor = LDrawUtilities.parseColor(fromField: parsedField as String?)
			self.setLDrawColor(parsedColor)

			//Read Vertex 1 and 2.
			self.setVertex1(readVertex(&workingLine))
			self.setVertex2(readVertex(&workingLine))

			//Read Conditonal Vertex 1 and 2.
			self.setConditionalVertex1(readVertex(&workingLine))
			self.setConditionalVertex2(readVertex(&workingLine))
		}
		else {
			NSLog("the conditional line primitive %@ was fatally invalid", String(describing: lines[range.location]))
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

		//Decoding structures is a bit messy. memcpy: the bytes have no alignment promise.
		memcpy(&self.control1, decoder.decodeBytes(forKey: "conditionalVertex1", returnedLength: nil), MemoryLayout<Point3>.size)
		memcpy(&self.control2, decoder.decodeBytes(forKey: "conditionalVertex2", returnedLength: nil), MemoryLayout<Point3>.size)
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

		encodeBytes(of: self.control1, encoder, "conditionalVertex1")
		encodeBytes(of: self.control2, encoder, "conditionalVertex2")
	}

	/// [encoder encodeBytes:&value length:sizeof(Point3) forKey:key]
	private func encodeBytes(of value: Point3, _ encoder: NSCoder, _ key: String) {
		withUnsafeBytes(of: value) {
			encoder.encodeBytes($0.bindMemory(to: UInt8.self).baseAddress, length: MemoryLayout<Point3>.size, forKey: key)
		}
	}


	//========== copyWithZone: =================================================
	//
	// Purpose:		Returns a duplicate of this file.
	//
	//==========================================================================
	@objc(copyWithZone:)
	override func copy(with zone: NSZone? = nil) -> Any {
		let copied = super.copy(with: zone) as! LDrawConditionalLine

		copied.setConditionalVertex1(self.conditionalVertex1())
		copied.setConditionalVertex2(self.conditionalVertex2())

		return copied
	}


	// MARK: - DIRECTIVES

	//========== write =========================================================
	//
	// Purpose:		Returns a line that can be written out to a file.
	//				Line format:
	//				5 colour x1 y1 z1 x2 y2 z2 x3 y3 z3 x4 y4 z4
	//
	//==========================================================================
	@objc(write)
	override func write() -> String! {
		// Same bytes as stringWithFormat:@"5 %@ ..." ("%@" of nil printed "(null)").
		let (v1, v2, c1, c2) = (self.vertex1(), self.vertex2(), self.control1, self.control2)
		func f(_ number: Float) -> String { LDrawUtilities.outputString(for: number) ?? "(null)" }
		let color = LDrawUtilities.outputString(for: self.lDrawColor()) ?? "(null)"

		return "5 \(color) \(f(v1.x)) \(f(v1.y)) \(f(v1.z)) \(f(v2.x)) \(f(v2.y)) \(f(v2.z))"
			+ " \(f(c1.x)) \(f(c1.y)) \(f(c1.z)) \(f(c2.x)) \(f(c2.y)) \(f(c2.z))"
	}


	//========== writeElementToVertexBuffer:withColor:wireframe: ===============
	//
	// Purpose:		Writes this object into the specified vertex buffer, which is
	//				a pointer to the offset into which the first vertex point's
	//				data is to be stored. Store subsequent vertexs after the
	//				first.
	//
	//==========================================================================
	@objc(writeElementToVertexBuffer:withColor:wireframe:)
	override func write(toVertexBuffer vertexBuffer: UnsafeMutablePointer<VBOVertexData>!, with drawingColor: LDrawColor!,
						wireframe: Bool) -> UnsafeMutablePointer<VBOVertexData>! {
		// This should never be called, but just in case...
		return nil
	}


	// MARK: - DISPLAY

	//========== browsingDescription ===========================================
	//
	// Purpose:		Returns a representation of the directive as a short string
	//				which can be presented to the user.
	//
	//==========================================================================
	@objc(browsingDescription)
	override func browsingDescription() -> String! {
		return NSLocalizedString("ConditionalLine", comment: "")
	}


	//========== iconName ======================================================
	//
	// Purpose:		Returns the name of image file used to display this kind of
	//				object, or nil if there is no icon.
	//
	//==========================================================================
	@objc(iconName)
	override func iconName() -> String! {
		return "ConditionalLinePrimitive"
	}


	//========== inspectorClassName ============================================
	//
	// Purpose:		Returns the name of the class used to inspect this one.
	//
	//==========================================================================
	@objc(inspectorClassName)
	override func inspectorClassName() -> String! {
		return "InspectionConditionalLine"
	}


	// MARK: - ACCESSORS

	//========== conditionalVertex1 ============================================
	@objc(conditionalVertex1)
	func conditionalVertex1() -> Point3 {
		return self.control1
	}


	//========== conditionalVertex2 ============================================
	@objc(conditionalVertex2)
	func conditionalVertex2() -> Point3 {
		return self.control2
	}


	//========== setConditionalVertex1: ========================================
	@objc(setConditionalVertex1:)
	func setConditionalVertex1(_ newVertex: Point3) {
		self.control1 = newVertex
	}


	//========== setConditionalVertex2: ========================================
	@objc(setConditionalVertex2:)
	func setConditionalVertex2(_ newVertex: Point3) {
		self.control2 = newVertex
	}


	// MARK: - ACTIONS

	//========== moveBy: =======================================================
	//
	// Purpose:		Moves the receiver in the specified direction.
	//
	// Notes:		Doesn't call super, so the end points stay put (BUG-018,
	//				kept as a known issue until P12).
	//
	//==========================================================================
	@objc(moveBy:)
	override func move(by moveVector: Vector3) {
		//I don't know if this makes any sense.
		self.control1.x += moveVector.x
		self.control1.y += moveVector.y
		self.control1.z += moveVector.z

		self.control2.x += moveVector.x
		self.control2.y += moveVector.y
		self.control2.z += moveVector.z
	}


	// MARK: - UTILITIES

	//========== flattenIntoLines:triangles:quadrilaterals:other:currentColor: =
	//
	// Purpose:		Appends the directive into the appropriate container.
	//
	//==========================================================================
	@objc(flattenIntoLines:triangles:quadrilaterals:other:currentColor:currentTransform:normalTransform:recursive:)
	override func flatten(intoLines lines: NSMutableArray!, triangles: NSMutableArray!, quadrilaterals: NSMutableArray!,
						  other everythingElse: NSMutableArray!, currentColor parentColor: LDrawColor!,
						  currentTransform transform: Matrix4, normalTransform: Matrix3, recursive: Bool) {
		// Do nothing. Prevent LDrawLine (the superclass) from adding this object to
		// the list!

		// Conditional lines are not really my friend, so I'm dumping them all.
	}


	//========== registerUndoActions ===========================================
	//
	// Purpose:		Registers the undo actions that are unique to this subclass,
	//				not to any superclass.
	//
	// Notes:		The undo proxy is messaged dynamically, as in ObjC. Never ask
	//				it respondsToSelector: (that is recorded as the action) and
	//				never cast it to this final class (static dispatch).
	//
	//==========================================================================
	@objc(registerUndoActions:)
	override func registerUndoActions(_ undoManager: UndoManager!) {
		super.registerUndoActions(undoManager)

		(undoManager.prepare(withInvocationTarget: self) as AnyObject).setConditionalVertex2(self.conditionalVertex2())
		(undoManager.prepare(withInvocationTarget: self) as AnyObject).setConditionalVertex1(self.conditionalVertex1())

		undoManager.setActionName(NSLocalizedString("UndoAttributesConditionalLine", comment: ""))
	}
}
