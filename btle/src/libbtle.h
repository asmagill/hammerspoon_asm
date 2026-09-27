#pragma once

@import CoreBluetooth ;

@interface CBPeripheral (HammerspoonAdditions)
@property (nonatomic)           int      callbackRef ;
@property (nonatomic, readonly) int      refTable ;
@end

@interface CBCharacteristic (HammerspoonAdditions)
@property (nonatomic)           int      callbackRef ;
@property (nonatomic, readonly) int      refTable ;
@end

@interface CBDescriptor (HammerspoonAdditions)
@property (nonatomic)           int      callbackRef ;
@property (nonatomic, readonly) int      refTable ;
@end

@interface CBService (HammerspoonAdditions)
@property (nonatomic)           int      callbackRef ;
@property (nonatomic, readonly) int      refTable ;
@end

static const char * const USERDATA_TAG          = "hs._asm.btle" ;
static const char * const UD_CHARACTERISTIC_TAG = "hs._asm.btle.characteristic" ;
static const char * const UD_DESCRIPTOR_TAG     = "hs._asm.btle.descriptor" ;
static const char * const UD_PERIPHERAL_TAG     = "hs._asm.btle.peripheral" ;
static const char * const UD_SERVICE_TAG        = "hs._asm.btle.service" ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"
static NSArray *validateAndConvertUUIDs(NSArray *list, BOOL asCBUUID, NSError * __autoreleasing *error) {
    if ([list isKindOfClass:NSString.class]) list = [NSArray arrayWithObject:(NSString *)list] ;
    NSMutableArray *servicesList = [NSMutableArray array] ;

    __block NSString *errorReason = nil ;
    if ([list isKindOfClass:NSArray.class]) {
        [list enumerateObjectsUsingBlock:^(NSString *item, NSUInteger idx, BOOL *stop) {
            if ([item isKindOfClass:NSString.class]) {
                NSObject *uuid ;
                @try {
                    uuid = (asCBUUID) ? (NSObject *)[CBUUID UUIDWithString:item] :
                                        (NSObject *)[[NSUUID alloc] initWithUUIDString:item] ;
                }
                @catch (NSException *exception) {
                    if (exception.name == NSInternalInconsistencyException) {
                        uuid = nil ;
                    } else {
                        @throw ;
                    }
                }
                if (uuid) {
                    [servicesList addObject:uuid] ;
                } else {
                    errorReason = [NSString stringWithFormat:@"string at index %lu does not represent a valid BTLE uuid", idx + 1] ;
                    *stop = YES ;
                }
            } else {
                errorReason = [NSString stringWithFormat:@"string expected at index %lu", idx + 1] ;
                *stop = YES ;
            }
        }] ;
    } else {
        errorReason = @"expected string or list of strings" ;
    }

    if (errorReason) {
        NSString *errDomain = [[NSBundle mainBundle] bundleIdentifier] ;
        if (!errDomain) errDomain = @"<no-bundle-identifier>" ;
        *error = [NSError errorWithDomain:errDomain code:NSKeyValueValidationError
                                                userInfo:@{ NSLocalizedDescriptionKey : errorReason }] ;
        return nil ;
    } else {
        return servicesList.copy ;
    }
}
#pragma clang diagnostic pop
