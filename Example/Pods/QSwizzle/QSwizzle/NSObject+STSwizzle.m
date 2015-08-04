//
//  NSObject+STSwizzle.m
//  STSwizzle
//
//  Created by Thomas Dupont on 22/08/13.

/***********************************************************************************
 *
 * Copyright (c) 2013 Thomas Dupont
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NON INFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 ***********************************************************************************/

#import "NSObject+STSwizzle.h"

#import <objc/runtime.h>

@implementation NSObject (STSwizzle)

static char isSwizzledKey;

+ (void)swizzleMethod:(Method)firstMethod withMethod:(Method)secondMethod inClass:(Class)secondClass
{
	if (firstMethod == NULL || secondMethod == NULL)
	{
		//At least one method is missing
		[NSException raise:@"STSwizzleException" format:@"Attempting to swizzle an inexistant method."];
		return;
	}
	
	SEL firstSelector = method_getName(firstMethod);
	SEL secondSelector = method_getName(secondMethod);
    
	BOOL firstWasInChild = !class_addMethod(self, firstSelector, method_getImplementation(secondMethod), method_getTypeEncoding(secondMethod));
	BOOL secondWasInChild = !class_addMethod(secondClass, secondSelector, method_getImplementation(firstMethod), method_getTypeEncoding(firstMethod));
	
	if (secondWasInChild && !firstWasInChild)
	{
		//Only new method was in child
		class_replaceMethod(secondClass, secondSelector, method_getImplementation(firstMethod), method_getTypeEncoding(firstMethod));
	}
	else if (!secondWasInChild && firstWasInChild)
	{
		//Only old method was in child
		class_replaceMethod(self, firstSelector, method_getImplementation(secondMethod), method_getTypeEncoding(secondMethod));
	}
	else if (secondWasInChild && firstWasInChild)
	{
		//both methods were present in child
		method_exchangeImplementations(firstMethod, secondMethod);
	}
}

+ (void)swizzleInstanceMethod:(SEL)firstSelector withMethod:(SEL)secondSelector
{
	[self swizzleInstanceMethod:firstSelector withMethod:secondSelector inClass:self];
}

+ (void)swizzleInstanceMethod:(SEL)firstSelector withMethod:(SEL)secondSelector inClass:(Class)c
{
	Method firstMethod = class_getInstanceMethod(self, firstSelector);
    Method secondMethod = class_getInstanceMethod(c, secondSelector);
	
	[self swizzleMethod:firstMethod withMethod:secondMethod inClass:c];
}

+ (void)swizzleClassMethod:(SEL)firstSelector withMethod:(SEL)secondSelector
{
	[self swizzleClassMethod:firstSelector withMethod:secondSelector inClass:self];
}

+ (void)swizzleClassMethod:(SEL)firstSelector withMethod:(SEL)secondSelector inClass:(Class)c
{
	Method firstMethod = class_getClassMethod(self, firstSelector);
    Method secondMethod = class_getClassMethod(c, secondSelector);
	
	[self swizzleMethod:firstMethod withMethod:secondMethod inClass:c];
}

- (BOOL)setHackClass
{
	NSString* newSelectorName = [NSString stringWithFormat:@"%@-%p", NSStringFromClass([self class]), self];
	
	NSNumber* isSwizzled = (NSNumber*)objc_getAssociatedObject(self, &isSwizzledKey);
	
	if (!isSwizzled || ![isSwizzled boolValue])
	{
		Class hackClass = objc_allocateClassPair([self class], [newSelectorName UTF8String], 0);
		if (hackClass)
		{
			objc_registerClassPair(hackClass);
		}
		else
		{
			hackClass = objc_getClass([newSelectorName UTF8String]);
		}
		
		if (hackClass)
		{
			object_setClass(self, hackClass);
			objc_setAssociatedObject(self, &isSwizzledKey, (id)[NSNumber numberWithBool:YES], OBJC_ASSOCIATION_ASSIGN);
			
			return YES;
		}
		
		return NO;
	}
	
	return YES;
}

- (void)addMethodForSelector:(SEL)selector types:(char*)types implementation:(implementation_block)impl
{
	BOOL hacked = [self setHackClass];
	if (hacked)
	{
		Class hackClass = [self class];
		class_addMethod(hackClass, selector, imp_implementationWithBlock(impl), types);
	}
}

- (void)replaceMethodForSelector:(SEL)selector implementation:(implementation_block)impl
{
	Method origMethod = class_getInstanceMethod([self class], selector);
	
	if (origMethod)
    {
		BOOL hacked = [self setHackClass];
		
		if (hacked)
		{
			Class hackClass = [self class];
			
			const char* types = method_getTypeEncoding(origMethod);
			IMP blockImpl = imp_implementationWithBlock(impl);
			
			BOOL added = class_addMethod(hackClass, selector, blockImpl, types);
			if (!added)
			{
				Method hackMethod = class_getInstanceMethod(hackClass, selector);
				method_setImplementation(hackMethod, blockImpl);
			}
		}
	}
}

- (void)replaceMethodForSelector:(SEL)selector orAddWithTypes:(char*)types implementation:(implementation_block)impl {
  Method origMethod = class_getInstanceMethod([self class], selector);

  if (origMethod) {
    [self replaceMethodForSelector:selector implementation: impl];
  }
  else {
    [self addMethodForSelector:(SEL)selector types:types implementation: impl];
  }
}

- (void)callOnSuper:(dispatch_block_t)block
{
	Class cls = [self class];
	object_setClass(self, [self superclass]);
	block();
	object_setClass(self, cls);
}

- (void)rollbackMethodReplacements
{
	NSNumber* isSwizzled = (NSNumber*)objc_getAssociatedObject(self, &isSwizzledKey);
	
	if (isSwizzled && [isSwizzled boolValue])
    {
		object_setClass(self, [self superclass]);
		objc_setAssociatedObject(self, &isSwizzledKey, (id)[NSNumber numberWithBool:NO], OBJC_ASSOCIATION_ASSIGN);
	}
}

+(void)swizzleSelector: (SEL)orig
             fromClass:(Class)source
            toSelector: (SEL)repl
               toClass:(Class)target {
    
    Method origMethod = class_getInstanceMethod(source, orig);
    Method newMethod = class_getInstanceMethod(target, repl);
    
    if (origMethod) {
        class_addMethod(source, repl, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
        method_exchangeImplementations(origMethod, newMethod);
    }
    else {
        class_addMethod(source, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
    }
}

+(void)swizzleSelector:(SEL)orig
            toSelector:(SEL)repl
              forClass:(Class)cls {
    
    Method origMethod = class_getInstanceMethod(cls, orig);
    Method newMethod = class_getInstanceMethod(cls, repl);
    
    // swizzle one-way
    if(class_addMethod(cls, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(cls, repl, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    }
    else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}
@end
