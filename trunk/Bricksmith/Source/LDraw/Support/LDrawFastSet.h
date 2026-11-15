/*
 *  LDrawFastSet.h
 *  Bricksmith
 *
 *  Created by bsupnik on 9/15/12.
 *  Copyright 2012 __MyCompanyName__. All rights reserved.
 *
 */

/*
	LDrawFastSet - THEORY OF OPERATION
	
	Here's the problem: the overhead of NS collections is relatively high, and attaching a 
	mutable set to each directive to keep track of who is observing it basically doubles
	the number of NS containers and load time.
	
	Buuuuut - in nearly every important case, the nubmer of objects in a container is 1.
	So the fast set structure optimizes away the NS mutable set for the simple cases where
	we don't need a real set.
	
	ENCODING
	
	The fast set is a pair of pointers with the following encoding rules:
	
	p1		p2		meaning
	NULL	NULL	The set is empty.
	id1		NULL	The set contains one object, refered to via id1.
	id1		id2		The set contains two objects, referred to via id1 and id2.
	NULL	id2		The set contains at least 3 objects, contained in an NSMutableSet stored in id2.
	
*/

// P3 (ARC): every pointer in the struct is a plain void *. Observers are deliberately NOT retained (as under
// MRC); the overflow NSMutableSet is owned through CFBridgingRetain/CFBridgingRelease. Only LDrawDirective.m
// expands these macros.
typedef struct {
	union {
		struct {			
			void *			p1;
			void *			p2;
		} ptr;
		struct {
			void *			flag;
			void *			mutable_set;	// owned: NSMutableSet *, +1 via CFBridgingRetain
		} obj;
	};
} LDrawFastSet;

#define LDrawFastSetMutableSet(this) ((__bridge NSMutableSet *)this.obj.mutable_set)

#define MESSAGE_FOR_SET(this,ns_type,__msg) \
	do {																					\
		if(this.ptr.p1)																		\
		{																					\
			id<ns_type> p1 = (__bridge id<ns_type>)this.ptr.p1;								\
			id<ns_type> p2 = (__bridge id<ns_type>)this.ptr.p2;								\
			if(p1)	[p1 __msg];																\
			if(p2 && LDrawFastSetContains(this, (__bridge void *)p2))						\
				[p2 __msg];																	\
		}																					\
		else																				\
		{																					\
			if(this.ptr.p2)																	\
			{																				\
				NSSet * orig = [NSSet setWithSet:LDrawFastSetMutableSet(this)];				\
				for (NSValue * o in orig)													\
				{																			\
					id<ns_type> oo = (__bridge id<ns_type>)[o pointerValue];				\
					if(LDrawFastSetContains(this,(__bridge void *)oo))						\
					{																		\
						[oo __msg];															\
					}																		\
				}																			\
			}																				\
		}																					\
	} while(0)

#define LDrawFastSetContains(this, p) \
	((this.obj.flag == NULL && this.obj.mutable_set != NULL) ?								\
		([LDrawFastSetMutableSet(this) containsObject:[NSValue valueWithPointer:(p)]] ? 1 : 0) :	\
		((this.ptr.p1 == (p) || this.ptr.p2 == (p)) ? 1 : 0))

#define LDrawFastSetInit(this) \
	do {																					\
		this.ptr.p1 = this.ptr.p2 = NULL;													\
	} while(0)

#define LDrawFastSetDealloc(this) \
	do {\
		if(this.obj.flag == NULL && this.obj.mutable_set != NULL)							\
		{																					\
			CFBridgingRelease(this.obj.mutable_set);										\
			this.obj.mutable_set = NULL;													\
		}																					\
	} while(0) 

// p is a void * (bridge an object with (__bridge void *)).
#define LDrawFastSetInsert(this,p) \
	do {\
		if(this.ptr.p1)																		\
		{																					\
			if(this.ptr.p2)																	\
			{																				\
				if((p) != this.ptr.p1 && (p) != this.ptr.p2)								\
				{																			\
					NSMutableSet * new_set = [[NSMutableSet alloc] initWithCapacity:3];		\
					[new_set addObject:[NSValue valueWithPointer:this.ptr.p1]];				\
					[new_set addObject:[NSValue valueWithPointer:this.ptr.p2]];				\
					[new_set addObject:[NSValue valueWithPointer:(p)]];						\
					this.obj.flag = NULL;													\
					this.obj.mutable_set = (void *)CFBridgingRetain(new_set);				\
				}																			\
			}																				\
			else																			\
			{																				\
				if((p) != this.ptr.p1)														\
					this.ptr.p2 = (p);														\
			}																				\
		}																					\
		else																				\
		{																					\
			if(this.ptr.p2)																	\
			{																				\
				[LDrawFastSetMutableSet(this) addObject:[NSValue valueWithPointer:(p)]];	\
			}																				\
			else																			\
			{																				\
				this.ptr.p1 = (p);															\
			}																				\
		}																					\
	} while(0)

// p is a void * (bridge an object with (__bridge void *)).
#define LDrawFastSetRemove(this, p) \
	do {																					\
		if(this.obj.flag == NULL && this.obj.mutable_set != NULL)							\
		{																					\
			NSValue * me = [NSValue valueWithPointer:(p)];									\
			assert([LDrawFastSetMutableSet(this) containsObject:me]);						\
			[LDrawFastSetMutableSet(this) removeObject:me];									\
			assert([LDrawFastSetMutableSet(this) count] >= 2);								\
			if([LDrawFastSetMutableSet(this) count] == 2)									\
			{																				\
				NSMutableSet * dead = CFBridgingRelease(this.obj.mutable_set);				\
				void ** ptr = &this.ptr.p1;													\
				for(NSValue * o in dead)													\
				{																			\
					*ptr = [o pointerValue];												\
					++ptr;																	\
				}																			\
			}																				\
		}																					\
		else																				\
		{																					\
			if(this.ptr.p1 == (p))															\
			{																				\
				this.ptr.p1 = this.ptr.p2;													\
				this.ptr.p2 = NULL;															\
			}																				\
			else if(this.ptr.p2 == (p))														\
			{																				\
				this.ptr.p2 = NULL;															\
			}																				\
			else {																			\
				assert(!"Removal of an unknown object.");									\
			}																				\
		}																					\
	} while(0)




