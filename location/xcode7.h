//
// Definitions to accept XCode 8 SDK when compiling with XCode 7
//
// Cobbled together by Aaron Magill for Hammerspoon, September 2016
//
// This is in no way complete, it is an ongoing collection of the things I've found
// necessary to wrap or work around.  Use at your own risk.
//
// Include the following in your code to use:
//    #if __clang_major__ < 8
//    #import "xcode7.h"
//    #endif

// The MIT License (MIT)
//
// Copyright (c) 2016 Aaron Magill
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

typedef NSUInteger NSWindowStyleMask ;

#define NSWindowStyleMaskBorderless             NSBorderlessWindowMask
#define NSWindowStyleMaskTitled                 NSTitledWindowMask
#define NSWindowStyleMaskClosable               NSClosableWindowMask
#define NSWindowStyleMaskMiniaturizable         NSMiniaturizableWindowMask
#define NSWindowStyleMaskResizable              NSResizableWindowMask
#define NSWindowStyleMaskTexturedBackground     NSTexturedBackgroundWindowMask
#define NSWindowStyleMaskUnifiedTitleAndToolbar NSUnifiedTitleAndToolbarWindowMask
#define NSWindowStyleMaskFullScreen             NSFullScreenWindowMask
#define NSWindowStyleMaskFullSizeContentView    NSFullSizeContentViewWindowMask
#define NSWindowStyleMaskUtilityWindow          NSUtilityWindowMask
#define NSWindowStyleMaskDocModalWindow         NSDocModalWindowMask
#define NSWindowStyleMaskNonactivatingPanel     NSNonactivatingPanelMask
#define NSWindowStyleMaskHUDWindow              NSHUDWindowMask

#define NSCompositingOperationClear           NSCompositeClear
#define NSCompositingOperationCopy            NSCompositeCopy
#define NSCompositingOperationSourceOver      NSCompositeSourceOver
#define NSCompositingOperationSourceIn        NSCompositeSourceIn
#define NSCompositingOperationSourceOut       NSCompositeSourceOut
#define NSCompositingOperationSourceAtop      NSCompositeSourceAtop
#define NSCompositingOperationDestinationOver NSCompositeDestinationOver
#define NSCompositingOperationDestinationIn   NSCompositeDestinationIn
#define NSCompositingOperationDestinationOut  NSCompositeDestinationOut
#define NSCompositingOperationDestinationAtop NSCompositeDestinationAtop
#define NSCompositingOperationXOR             NSCompositeXOR
#define NSCompositingOperationPlusDarker      NSCompositePlusDarker
#define NSCompositingOperationPlusLighter     NSCompositePlusLighter

#define NSEventTypeLeftMouseDown  NSLeftMouseDown
#define NSEventTypeRightMouseDown NSRightMouseDown
#define NSEventTypeOtherMouseDown NSOtherMouseDown

#define NSEventModifierFlagCapsLock NSAlphaShiftKeyMask
#define NSEventModifierFlagShift    NSShiftKeyMask
#define NSEventModifierFlagControl  NSControlKeyMask
#define NSEventModifierFlagOption   NSAlternateKeyMask
#define NSEventModifierFlagCommand  NSCommandKeyMask
#define NSEventModifierFlagFunction NSFunctionKeyMask

#define NSControlSizeMini    NSMiniControlSize
#define NSControlSizeRegular NSRegularControlSize
#define NSControlSizeSmall   NSSmallControlSize

#define kCLAuthorizationStatusAuthorizedAlways kCLAuthorizationStatusAuthorized

// #define EKWeekdaySunday    EKSunday
// #define EKWeekdayMonday    EKMonday
// #define EKWeekdayTuesday   EKTuesday
// #define EKWeekdayWednesday EKWednesday
// #define EKWeekdayThursday  EKThursday
// #define EKWeekdayFriday    EKFriday
// #define EKWeekdaySaturday  EKSaturday

// #define birthdayContactIdentifier birthdayPersonUniqueID
