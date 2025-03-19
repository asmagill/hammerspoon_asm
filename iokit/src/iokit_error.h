static NSDictionary *ioReturnMap ;

static void logError(BOOL debug, const char *func, kern_return_t err, NSString *message) {
    static dispatch_once_t once;
    dispatch_once(&once, ^ {
        // from caffeinate
        ioReturnMap = @{
            @(kIOReturnSuccess)          : @"success",
            @(kIOReturnError)            : @"general error",
            @(kIOReturnNoMemory)         : @"memory allocation error",
            @(kIOReturnNoResources)      : @"resource shortage",
            @(kIOReturnIPCError)         : @"Mach IPC failure",
            @(kIOReturnNoDevice)         : @"no such device",
            @(kIOReturnNotPrivileged)    : @"privilege violation",
            @(kIOReturnBadArgument)      : @"invalid argument",
            @(kIOReturnLockedRead)       : @"device is read locked",
            @(kIOReturnLockedWrite)      : @"device is write locked",
            @(kIOReturnExclusiveAccess)  : @"exclusive access and device already open",
            @(kIOReturnBadMessageID)     : @"IPC message ID mismatch",
            @(kIOReturnUnsupported)      : @"unsupported function",
            @(kIOReturnVMError)          : @"virtual memory error",
            @(kIOReturnInternalError)    : @"internal error",
            @(kIOReturnIOError)          : @"General I/O error",
            @(kIOReturnCannotLock)       : @"can't acquire lock",
            @(kIOReturnNotOpen)          : @"device is not open",
            @(kIOReturnNotReadable)      : @"device is not readable",
            @(kIOReturnNotWritable)      : @"device is not writeable",
            @(kIOReturnNotAligned)       : @"alignment error",
            @(kIOReturnBadMedia)         : @"media error",
            @(kIOReturnStillOpen)        : @"device is still open",
            @(kIOReturnRLDError)         : @"rld failure",
            @(kIOReturnDMAError)         : @"DMA failure",
            @(kIOReturnBusy)             : @"device busy",
            @(kIOReturnTimeout)          : @"I/O Timeout",
            @(kIOReturnOffline)          : @"device is offline",
            @(kIOReturnNotReady)         : @"device is not ready",
            @(kIOReturnNotAttached)      : @"device/channel is not attached",
            @(kIOReturnNoChannels)       : @"no DMA channels available",
            @(kIOReturnNoSpace)          : @"no space for data",
            @(kIOReturnPortExists)       : @"port already exists",
            @(kIOReturnCannotWire)       : @"cannot wire physical memory",
            @(kIOReturnNoInterrupt)      : @"no interrupt attached",
            @(kIOReturnNoFrames)         : @"no DMA frames enqueued",
            @(kIOReturnMessageTooLarge)  : @"oversized msg received on interrupt port",
            @(kIOReturnNotPermitted)     : @"operation is not permitted",
            @(kIOReturnNoPower)          : @"no power to device",
            @(kIOReturnNoMedia)          : @"media is not present",
            @(kIOReturnUnformattedMedia) : @"media is not formatted",
            @(kIOReturnUnsupportedMode)  : @"unsupported mode",
            @(kIOReturnUnderrun)         : @"data underrun",
            @(kIOReturnOverrun)          : @"data overrun",
            @(kIOReturnDeviceError)      : @"device error",
            @(kIOReturnNoCompletion)     : @"no completion routine",
            @(kIOReturnAborted)          : @"operation aborted",
            @(kIOReturnNoBandwidth)      : @"bus bandwidth would be exceeded",
            @(kIOReturnNotResponding)    : @"device not responding",
            @(kIOReturnIsoTooOld)        : @"isochronous I/O request for distant past",
            @(kIOReturnIsoTooNew)        : @"isochronous I/O request for distant future",
            @(kIOReturnNotFound)         : @"data was not found",
            @(kIOReturnInvalid)          : @"unanticipated driver error",
        };
    });

    NSString *errMsg = [ioReturnMap objectForKey:[NSNumber numberWithInt:err]] ;
    if (!errMsg) errMsg = [NSString stringWithFormat:@"unknown kernel error %d", err] ;

    if (debug) {
        [LuaSkin logDebug:@"%s.%s -- %@ (%@)", USERDATA_TAG, func, message, errMsg] ;
    } else {
        [LuaSkin  logWarn:@"%s.%s -- %@ (%@)", USERDATA_TAG, func, message, errMsg] ;
    }
}
