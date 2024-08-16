// https://blog.timac.org/2016/1124-testing-if-an-arbitrary-pointer-is-a-valid-objective-c-object/
// https://github.com/apple-oss-distributions/objc4/blob/objc4-912.3/runtime/objc-internal.h

// updated (re objc-internal.h), rearranged and cleaned up a little,
// but also still a mess... Heed Apple's warning below.
// ASM 2024-08-16


/*
 * WARNING  DANGER  HAZARD  BEWARE  EEK
 *
 * Everything in this file is for Apple Internal use only.
 * These will change in arbitrary OS updates and in unpredictable ways.
 * When your program breaks, you get to keep both pieces.
 */


//
//  IsObjcObject.c
//  IsObjcObject
//
//  Created by Alexandre Colucci on 19.11.2016.
//  Copyright © 2016 Alexandre Colucci. All rights reserved.
//

// #include "IsObjcObject.h"

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

// For vm_region_64
#include <mach/mach.h>

// Objective-C runtime
#include <objc/runtime.h>

// For dlsym
#include <dlfcn.h>

// For malloc_size
#include <malloc/malloc.h>

#pragma mark - Expose non exported Tagged Pointer functions from objc4-706/runtime/objc-internal.h

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundef"

# if __arm64__

#pragma clang diagnostic pop

#   define ISA_MASK        0x0000000ffffffff8ULL
#   define ISA_MAGIC_MASK  0x000003f000000001ULL
#   define ISA_MAGIC_VALUE 0x000001a000000001ULL

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundef"

# elif __x86_64__

#pragma clang diagnostic pop

#   define ISA_MASK        0x00007ffffffffff8ULL
#   define ISA_MAGIC_MASK  0x001f800000000001ULL
#   define ISA_MAGIC_VALUE 0x001d800000000001ULL

# else
    // Available bits in isa field are architecture-specific.
#   error unknown architecture
# endif

// Tagged pointer layout and usage is subject to change on different OS versions.

// Tag indexes 0..<7 have a 60-bit payload.
// Tag index 7 is reserved.
// Tag indexes 8..<264 have a 52-bit payload.
// Tag index 264 is reserved.

#if __has_feature(objc_fixed_enum)  ||  __cplusplus >= 201103L
enum objc_tag_index_t : uint16_t
#else
typedef uint16_t objc_tag_index_t;
enum
#endif
{
    // 60-bit payloads
    OBJC_TAG_NSAtom            = 0,
    OBJC_TAG_1                 = 1,
    OBJC_TAG_NSString          = 2,
    OBJC_TAG_NSNumber          = 3,
    OBJC_TAG_NSIndexPath       = 4,
    OBJC_TAG_NSManagedObjectID = 5,
    OBJC_TAG_NSDate            = 6,

    // 60-bit reserved
    OBJC_TAG_RESERVED_7        = 7,

    // 52-bit payloads
    OBJC_TAG_Photos_1          = 8,
    OBJC_TAG_Photos_2          = 9,
    OBJC_TAG_Photos_3          = 10,
    OBJC_TAG_Photos_4          = 11,
    OBJC_TAG_XPC_1             = 12,
    OBJC_TAG_XPC_2             = 13,
    OBJC_TAG_XPC_3             = 14,
    OBJC_TAG_XPC_4             = 15,
    OBJC_TAG_NSColor           = 16,
    OBJC_TAG_UIColor           = 17,
    OBJC_TAG_CGColor           = 18,
    OBJC_TAG_NSIndexSet        = 19,
    OBJC_TAG_NSMethodSignature = 20,
    OBJC_TAG_UTTypeRecord      = 21,
    OBJC_TAG_Foundation_1      = 22,
    OBJC_TAG_Foundation_2      = 23,
    OBJC_TAG_Foundation_3      = 24,
    OBJC_TAG_Foundation_4      = 25,
    OBJC_TAG_CGRegion          = 26,

    // When using the split tagged pointer representation
    // (OBJC_SPLIT_TAGGED_POINTERS), this is the first tag where
    // the tag and payload are unobfuscated. All tags from here to
    // OBJC_TAG_Last52BitPayload are unobfuscated. The shared cache
    // builder is able to construct these as long as the low bit is
    // not set (i.e. even-numbered tags).
    OBJC_TAG_FirstUnobfuscatedSplitTag = 136, // 128 + 8, first ext tag with high bit set

    OBJC_TAG_Constant_CFString = 136,

    OBJC_TAG_First60BitPayload = 0,
    OBJC_TAG_Last60BitPayload  = 6,
    OBJC_TAG_First52BitPayload = 8,
    OBJC_TAG_Last52BitPayload  = 263,

    OBJC_TAG_RESERVED_264      = 264
};
#if __has_feature(objc_fixed_enum)  &&  !defined(__cplusplus)
typedef enum objc_tag_index_t objc_tag_index_t;
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundef"

#if __arm64__

#pragma clang diagnostic pop

// ARM64 uses a new tagged pointer scheme where normal tags are in
// the low bits, extended tags are in the high bits, and half of the
// extended tag space is reserved for unobfuscated payloads.
#   define OBJC_SPLIT_TAGGED_POINTERS 1
#else
#   define OBJC_SPLIT_TAGGED_POINTERS 0
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundef"

#if (TARGET_OS_OSX || TARGET_OS_MACCATALYST) && __x86_64__

#pragma clang diagnostic pop

    // 64-bit Mac - tag bit is LSB
#   define OBJC_MSB_TAGGED_POINTERS 0
#else
    // Everything else - tag bit is MSB
#   define OBJC_MSB_TAGGED_POINTERS 1
#endif

#define _OBJC_TAG_INDEX_MASK 0x7UL

#if OBJC_SPLIT_TAGGED_POINTERS
#define _OBJC_TAG_SLOT_COUNT 8
#define _OBJC_TAG_SLOT_MASK 0x7UL
#else
// array slot includes the tag bit itself
#define _OBJC_TAG_SLOT_COUNT 16
#define _OBJC_TAG_SLOT_MASK 0xfUL
#endif

#define _OBJC_TAG_EXT_INDEX_MASK 0xff
// array slot has no extra bits
#define _OBJC_TAG_EXT_SLOT_COUNT 256
#define _OBJC_TAG_EXT_SLOT_MASK 0xff

#if OBJC_SPLIT_TAGGED_POINTERS
#   define _OBJC_TAG_MASK (1UL<<63)
#   define _OBJC_TAG_INDEX_SHIFT 0
#   define _OBJC_TAG_SLOT_SHIFT 0
#   define _OBJC_TAG_PAYLOAD_LSHIFT 1
#   define _OBJC_TAG_PAYLOAD_RSHIFT 4
#   define _OBJC_TAG_EXT_MASK (_OBJC_TAG_MASK | 0x7UL)
#   define _OBJC_TAG_NO_OBFUSCATION_MASK ((1UL<<62) | _OBJC_TAG_EXT_MASK)
#   define _OBJC_TAG_CONSTANT_POINTER_MASK \
        ~(_OBJC_TAG_EXT_MASK | ((uintptr_t)_OBJC_TAG_EXT_SLOT_MASK << _OBJC_TAG_EXT_SLOT_SHIFT))
#   define _OBJC_TAG_EXT_INDEX_SHIFT 55
#   define _OBJC_TAG_EXT_SLOT_SHIFT 55
#   define _OBJC_TAG_EXT_PAYLOAD_LSHIFT 9
#   define _OBJC_TAG_EXT_PAYLOAD_RSHIFT 12
#elif OBJC_MSB_TAGGED_POINTERS
#   define _OBJC_TAG_MASK (1UL<<63)
#   define _OBJC_TAG_INDEX_SHIFT 60
#   define _OBJC_TAG_SLOT_SHIFT 60
#   define _OBJC_TAG_PAYLOAD_LSHIFT 4
#   define _OBJC_TAG_PAYLOAD_RSHIFT 4
#   define _OBJC_TAG_EXT_MASK (0xfUL<<60)
#   define _OBJC_TAG_EXT_INDEX_SHIFT 52
#   define _OBJC_TAG_EXT_SLOT_SHIFT 52
#   define _OBJC_TAG_EXT_PAYLOAD_LSHIFT 12
#   define _OBJC_TAG_EXT_PAYLOAD_RSHIFT 12
#else
#   define _OBJC_TAG_MASK 1UL
#   define _OBJC_TAG_INDEX_SHIFT 1
#   define _OBJC_TAG_SLOT_SHIFT 0
#   define _OBJC_TAG_PAYLOAD_LSHIFT 0
#   define _OBJC_TAG_PAYLOAD_RSHIFT 4
#   define _OBJC_TAG_EXT_MASK 0xfUL
#   define _OBJC_TAG_EXT_INDEX_SHIFT 4
#   define _OBJC_TAG_EXT_SLOT_SHIFT 4
#   define _OBJC_TAG_EXT_PAYLOAD_LSHIFT 0
#   define _OBJC_TAG_EXT_PAYLOAD_RSHIFT 12
#endif

// Map of tags to obfuscated tags.
extern uintptr_t objc_debug_taggedpointer_obfuscator;

#if OBJC_SPLIT_TAGGED_POINTERS
extern uint8_t objc_debug_tag60_permutations[8];

static inline uintptr_t _objc_basicTagToObfuscatedTag(uintptr_t tag) {
    return objc_debug_tag60_permutations[tag];
}

static inline uintptr_t _objc_obfuscatedTagToBasicTag(uintptr_t tag) {
    for (unsigned i = 0; i < 7; i++)
        if (objc_debug_tag60_permutations[i] == tag)
            return i;
    return 7;
}
#endif

static inline void * _Nonnull
_objc_encodeTaggedPointer_withObfuscator(uintptr_t ptr, uintptr_t obfuscator)
{
    uintptr_t value = (obfuscator ^ ptr);
#if OBJC_SPLIT_TAGGED_POINTERS
    if ((value & _OBJC_TAG_NO_OBFUSCATION_MASK) == _OBJC_TAG_NO_OBFUSCATION_MASK)
        return (void *)ptr;
    uintptr_t basicTag = (value >> _OBJC_TAG_INDEX_SHIFT) & _OBJC_TAG_INDEX_MASK;
    uintptr_t permutedTag = _objc_basicTagToObfuscatedTag(basicTag);
    value &= ~(_OBJC_TAG_INDEX_MASK << _OBJC_TAG_INDEX_SHIFT);
    value |= permutedTag << _OBJC_TAG_INDEX_SHIFT;
#endif
    return (void *)value;
}

static inline uintptr_t
_objc_decodeTaggedPointer_noPermute_withObfuscator(const void * _Nullable ptr,
                                                   uintptr_t obfuscator)
{
    uintptr_t value = (uintptr_t)ptr;
#if OBJC_SPLIT_TAGGED_POINTERS
    if ((value & _OBJC_TAG_NO_OBFUSCATION_MASK) == _OBJC_TAG_NO_OBFUSCATION_MASK)
        return value;
#endif
    return value ^ obfuscator;
}

static inline uintptr_t
_objc_decodeTaggedPointer_withObfuscator(const void * _Nullable ptr,
                                         uintptr_t obfuscator)
{
    uintptr_t value
      = _objc_decodeTaggedPointer_noPermute_withObfuscator(ptr, obfuscator);
#if OBJC_SPLIT_TAGGED_POINTERS
    uintptr_t basicTag = (value >> _OBJC_TAG_INDEX_SHIFT) & _OBJC_TAG_INDEX_MASK;

    value &= ~(_OBJC_TAG_INDEX_MASK << _OBJC_TAG_INDEX_SHIFT);
    value |= _objc_obfuscatedTagToBasicTag(basicTag) << _OBJC_TAG_INDEX_SHIFT;
#endif
    return value;
}

static inline void * _Nonnull
_objc_encodeTaggedPointer(uintptr_t ptr)
{
    return _objc_encodeTaggedPointer_withObfuscator(ptr, objc_debug_taggedpointer_obfuscator);
}

static inline uintptr_t
_objc_decodeTaggedPointer_noPermute(const void * _Nullable ptr)
{
    return _objc_decodeTaggedPointer_noPermute_withObfuscator(ptr, objc_debug_taggedpointer_obfuscator);
}

static inline uintptr_t
_objc_decodeTaggedPointer(const void * _Nullable ptr)
{
    return _objc_decodeTaggedPointer_withObfuscator(ptr, objc_debug_taggedpointer_obfuscator);
}

static inline bool
_objc_taggedPointersEnabled(void)
{
    extern uintptr_t objc_debug_taggedpointer_mask;
    return (objc_debug_taggedpointer_mask != 0);
}

__attribute__((no_sanitize("unsigned-shift-base")))
static inline void * _Nonnull
_objc_makeTaggedPointer_withObfuscator(objc_tag_index_t tag, uintptr_t value,
                                       uintptr_t obfuscator)
{
    // PAYLOAD_LSHIFT and PAYLOAD_RSHIFT are the payload extraction shifts.
    // They are reversed here for payload insertion.

    // ASSERT(_objc_taggedPointersEnabled());
    if (tag <= OBJC_TAG_Last60BitPayload) {
        // ASSERT(((value << _OBJC_TAG_PAYLOAD_RSHIFT) >> _OBJC_TAG_PAYLOAD_LSHIFT) == value);
        uintptr_t result =
            (_OBJC_TAG_MASK |
             ((uintptr_t)tag << _OBJC_TAG_INDEX_SHIFT) |
             ((value << _OBJC_TAG_PAYLOAD_RSHIFT) >> _OBJC_TAG_PAYLOAD_LSHIFT));
        return _objc_encodeTaggedPointer_withObfuscator(result, obfuscator);
    } else {
        // ASSERT(tag >= OBJC_TAG_First52BitPayload);
        // ASSERT(tag <= OBJC_TAG_Last52BitPayload);
        // ASSERT(((value << _OBJC_TAG_EXT_PAYLOAD_RSHIFT) >> _OBJC_TAG_EXT_PAYLOAD_LSHIFT) == value);
        uintptr_t result =
            (_OBJC_TAG_EXT_MASK |
             ((uintptr_t)(tag - OBJC_TAG_First52BitPayload) << _OBJC_TAG_EXT_INDEX_SHIFT) |
             ((value << _OBJC_TAG_EXT_PAYLOAD_RSHIFT) >> _OBJC_TAG_EXT_PAYLOAD_LSHIFT));
        return _objc_encodeTaggedPointer_withObfuscator(result, obfuscator);
    }
}

static inline void * _Nonnull
_objc_makeTaggedPointer(objc_tag_index_t tag, uintptr_t value)
{
    return _objc_makeTaggedPointer_withObfuscator(tag, value, objc_debug_taggedpointer_obfuscator);
}

static inline bool
_objc_isTaggedPointer(const void * _Nullable ptr)
{
    return ((uintptr_t)ptr & _OBJC_TAG_MASK) == _OBJC_TAG_MASK;
}

static inline bool
_objc_isTaggedPointerOrNil(const void * _Nullable ptr)
{
    // this function is here so that clang can turn this into
    // a comparison with NULL when this is appropriate
    // it turns out it's not able to in many cases without this
    return !ptr || ((uintptr_t)ptr & _OBJC_TAG_MASK) == _OBJC_TAG_MASK;
}

static inline objc_tag_index_t
_objc_getTaggedPointerTag_withObfuscator(const void * _Nullable ptr,
                                         uintptr_t obfuscator)
{
    // ASSERT(_objc_isTaggedPointer(ptr));
    uintptr_t value = _objc_decodeTaggedPointer_withObfuscator(ptr, obfuscator);
    uintptr_t basicTag = (value >> _OBJC_TAG_INDEX_SHIFT) & _OBJC_TAG_INDEX_MASK;
    uintptr_t extTag =   (value >> _OBJC_TAG_EXT_INDEX_SHIFT) & _OBJC_TAG_EXT_INDEX_MASK;
    if (basicTag == _OBJC_TAG_INDEX_MASK) {
        return (objc_tag_index_t)(extTag + OBJC_TAG_First52BitPayload);
    } else {
        return (objc_tag_index_t)basicTag;
    }
}

__attribute__((no_sanitize("unsigned-shift-base")))
static inline uintptr_t
_objc_getTaggedPointerValue_withObfuscator(const void * _Nullable ptr,
                                           uintptr_t obfuscator)
{
    // ASSERT(_objc_isTaggedPointer(ptr));
    uintptr_t value = _objc_decodeTaggedPointer_noPermute_withObfuscator(ptr, obfuscator);
    uintptr_t basicTag = (value >> _OBJC_TAG_INDEX_SHIFT) & _OBJC_TAG_INDEX_MASK;
    if (basicTag == _OBJC_TAG_INDEX_MASK) {
        return (value << _OBJC_TAG_EXT_PAYLOAD_LSHIFT) >> _OBJC_TAG_EXT_PAYLOAD_RSHIFT;
    } else {
        return (value << _OBJC_TAG_PAYLOAD_LSHIFT) >> _OBJC_TAG_PAYLOAD_RSHIFT;
    }
}

__attribute__((no_sanitize("unsigned-shift-base")))
static inline intptr_t
_objc_getTaggedPointerSignedValue_withObfuscator(const void * _Nullable ptr,
                                                 uintptr_t obfuscator)
{
    // ASSERT(_objc_isTaggedPointer(ptr));
    uintptr_t value = _objc_decodeTaggedPointer_noPermute_withObfuscator(ptr, obfuscator);
    uintptr_t basicTag = (value >> _OBJC_TAG_INDEX_SHIFT) & _OBJC_TAG_INDEX_MASK;
    if (basicTag == _OBJC_TAG_INDEX_MASK) {
        return ((intptr_t)value << _OBJC_TAG_EXT_PAYLOAD_LSHIFT) >> _OBJC_TAG_EXT_PAYLOAD_RSHIFT;
    } else {
        return ((intptr_t)value << _OBJC_TAG_PAYLOAD_LSHIFT) >> _OBJC_TAG_PAYLOAD_RSHIFT;
    }
}

static inline objc_tag_index_t
_objc_getTaggedPointerTag(const void * _Nullable ptr)
{
    return _objc_getTaggedPointerTag_withObfuscator(ptr, objc_debug_taggedpointer_obfuscator);
}

static inline uintptr_t
_objc_getTaggedPointerValue(const void * _Nullable ptr)
{
    return _objc_getTaggedPointerValue_withObfuscator(ptr, objc_debug_taggedpointer_obfuscator);
}

static inline intptr_t
_objc_getTaggedPointerSignedValue(const void * _Nullable ptr)
{
    return _objc_getTaggedPointerSignedValue_withObfuscator(ptr, objc_debug_taggedpointer_obfuscator);
}

#   if OBJC_SPLIT_TAGGED_POINTERS
static inline void * _Nullable
_objc_getTaggedPointerRawPointerValue(const void * _Nullable ptr) {
    return (void *)((uintptr_t)ptr & _OBJC_TAG_CONSTANT_POINTER_MASK);
}
#   endif

/**
 Returns the registered class for the given tag.
 Returns nil if the tag is valid but has no registered class.

 This function searches the exported function: _objc_getClassForTag(objc_tag_index_t tag)
 declared in https://opensource.apple.com/source/objc4/objc4-706/runtime/objc-internal.h
 */
static Class _Nullable _objc_getClassForTag(objc_tag_index_t tag)
{
    static bool _objc_getClassForTag_searched = false;
    static Class (*_objc_getClassForTag_func)(objc_tag_index_t) = NULL;
    if(!_objc_getClassForTag_searched)
    {
        _objc_getClassForTag_func = (Class(*)(objc_tag_index_t))dlsym(RTLD_DEFAULT, "_objc_getClassForTag");
        _objc_getClassForTag_searched = true;
        if(_objc_getClassForTag_func == NULL)
        {
            fprintf(stderr, "*** Could not find _objc_getClassForTag()!\n");
        }
    }

    if(_objc_getClassForTag_func != NULL)
    {
        return _objc_getClassForTag_func(tag);
    }

    return NULL;
}

#pragma mark - Readable and valid memory


/**
 Test if the pointer points to readable and valid memory.

 @param inPtr is the pointer
 @return true if the pointer points to readable and valid memory.
 */
static bool IsValidReadableMemory(const void * _Nonnull inPtr)
{
    kern_return_t error = KERN_SUCCESS;

    // Check for read permissions
    bool hasReadPermissions = false;

    vm_size_t vmsize;
    vm_address_t address = (vm_address_t)inPtr;
    vm_region_basic_info_data_t info;
    mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_64;

    memory_object_name_t object;

    error = vm_region_64(mach_task_self(), &address, &vmsize, VM_REGION_BASIC_INFO, (vm_region_info_t)&info, &info_count, &object);
    if(error != KERN_SUCCESS)
    {
        // vm_region/vm_region_64 returned an error
        hasReadPermissions = false;
    }
    else
    {
        hasReadPermissions = (info.protection & VM_PROT_READ);
    }

    if(!hasReadPermissions)
    {
        return false;
    }

    // Read the memory
    vm_offset_t readMem = 0;
    mach_msg_type_number_t size = 0;
    error = vm_read(mach_task_self(), (vm_address_t)inPtr, sizeof(uintptr_t), &readMem, &size);
    if(error != KERN_SUCCESS)
    {
        // vm_read returned an error
        return false;
    }

    return true;
}

/**
 Test if a pointer is a tagged pointer

 @param inPtr is the pointer to check
 @param outClass returns the registered class for the tagged pointer.
 @return true if the pointer is a tagged pointer.
 */
bool IsObjcTaggedPointer(const void * _Nonnull inPtr, Class _Nullable * _Nullable outClass)
{
    //
    // Check if the memory is valid and readable
    //
    if(!IsValidReadableMemory((const void * _Nonnull)inPtr))
    {
        if(outClass != NULL) *outClass = NULL;
        return false;
    }

    bool isTaggedPointer = _objc_isTaggedPointer(inPtr);
    if(outClass != NULL)
    {
        if(isTaggedPointer)
        {
            objc_tag_index_t tagIndex = _objc_getTaggedPointerTag(inPtr);
            *outClass = _objc_getClassForTag(tagIndex);
        }
        else
        {
            *outClass = NULL;
        }
    }

    return isTaggedPointer;
}

#pragma mark - IsObjcObject

/**
 Test if a pointer is an Objective-C object

 @param inPtr is the pointer to check
 @return true if the pointer is an Objective-C object
 */
bool IsObjcObject(const void * _Nullable inPtr)
{
    //
    // NULL pointer is not an Objective-C object
    //
    if(inPtr == NULL)
    {
        return false;
    }

    //
    // Check if the memory is valid and readable
    //
    if(!IsValidReadableMemory((const void * _Nonnull)inPtr))
    {
        return false;
    }

    //
    // Check for tagged pointers
    //
    if(IsObjcTaggedPointer((const void * _Nonnull)inPtr, NULL))
    {
        return true;
    }

    //
    // Check if the pointer is aligned
    //
    if (((uintptr_t)inPtr % sizeof(uintptr_t)) != 0)
    {
        return false;
    }

    //
    // From LLDB:
    // Objective-C runtime has a rule that pointers in a class_t will only have bits 0 thru 46 set
    // so if any pointer has bits 47 thru 63 high we know that this is not a valid isa
    // See http://llvm.org/svn/llvm-project/lldb/trunk/examples/summaries/cocoa/objc_runtime.py
    //
    if(((uintptr_t)inPtr & 0xFFFF800000000000) != 0)
    {
        return false;
    }

    //
    // Get the Class from the pointer
    // From http://www.sealiesoftware.com/blog/archive/2013/09/24/objc_explain_Non-pointer_isa.html :
    // If you are writing a debugger-like tool, the Objective-C runtime exports some variables
    // to help decode isa fields. objc_debug_isa_class_mask describes which bits are the class pointer:
    // (isa & class_mask) == class pointer.
    // objc_debug_isa_magic_mask and objc_debug_isa_magic_value describe some bits that help
    // distinguish valid isa fields from other invalid values:
    // (isa & magic_mask) == magic_value for isa fields that are not raw class pointers.
    // These variables may change in the future so do not use them in application code.
    //

    uintptr_t isa = (*(uintptr_t *)((void *)(uintptr_t)inPtr));
//     Class ptrClass = NULL;
    void *ptrClass = NULL;

    if ((isa & ~ISA_MASK) == 0)
    {
        ptrClass = (void *)isa;
    }
    else
    {
        if ((isa & ISA_MAGIC_MASK) == ISA_MAGIC_VALUE)
        {
            ptrClass = (void *)(isa & ISA_MASK);
        }
        else
        {
            ptrClass = (void *)isa;
        }
    }

    if(ptrClass == NULL)
    {
        return false;
    }

    //
    // Verifies that the found Class is a known class.
    //
    bool isKnownClass = false;

    unsigned int numClasses = 0;
    Class *classesList = objc_copyClassList(&numClasses);
    for (unsigned int i = 0; i < numClasses; i++)
    {
        if (classesList[i] == ptrClass)
        {
            isKnownClass = true;
            break;
        }
    }
    free(classesList);

    if(!isKnownClass)
    {
        return false;
    }


    //
    // From Greg Parker
    // https://twitter.com/gparker/status/801894068502433792
    // You can filter out some false positives by checking malloc_size(obj) >= class_getInstanceSize(cls).
    //
    size_t pointerSize = malloc_size(inPtr);
    if(pointerSize > 0 && pointerSize < class_getInstanceSize((__bridge Class _Nullable)ptrClass))
    {
        return false;
    }

    return true;
}
