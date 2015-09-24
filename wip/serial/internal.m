// Largely based on code from http://playground.arduino.cc/Interfacing/Cocoa and https://github.com/armadsen/ORSSerialPort

// TODO:
//  * add support for setting bits, stop bits, parity, and flow control
//    do i still have devices to test this with?
//   add class and selectors for actual reading
//   best way to let lua know data is waiting?
//   test with reseting uno and leonardo

#import <Cocoa/Cocoa.h>
// #import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

// import IOKit headers
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>
#include <IOKit/serial/ioss.h>
#include <sys/ioctl.h>

#define USERDATA_TAG        "hs._asm.serial"
int refTable ;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))

@interface HSSerialPort : NSObject
@property (readonly) int            serialFileDescriptor;
@property (readonly) NSString       *path ;
@property            speed_t        baud ;
@property            struct termios portAttributes ;
@property (readonly) struct termios gOriginalTTYAttrs;
@property (readonly) BOOL           readThreadRunning ;
@property (readonly) NSMutableData  *incomingData ;
@property            BOOL           notifyMainThread ;
@property            int            selfRef ;
@property            int            callbackFunction ;
@property            int            lostPortFunction ;
@property (readonly) BOOL           bufferChanging ;
@end


@implementation HSSerialPort

- (id)initWithPort:(const char *)portPath {
    self = [super init] ;
    if (self) {
        _serialFileDescriptor = -1 ;
        _path                 = [[NSString alloc] initWithCString:portPath encoding:NSUTF8StringEncoding] ;
        _baud                 = B9600 ;
        _readThreadRunning    = NO ;
        _notifyMainThread     = NO ;
        _bufferChanging       = NO ;
        _incomingData         = [[NSMutableData alloc] init] ;
        _selfRef              = LUA_NOREF ;
        _callbackFunction     = LUA_NOREF ;
        _lostPortFunction     = LUA_NOREF ;

        NSString *errorMessage = nil ;

        // We just open it enough to get the current attributes

        _serialFileDescriptor = open([_path UTF8String], O_RDWR | O_NOCTTY | O_NONBLOCK );

        if (_serialFileDescriptor == -1) {
            errorMessage = @"unable to open serial port";
        } else {
            // Get the current options and save them so we can restore the default settings later.
            if (tcgetattr(_serialFileDescriptor, &_gOriginalTTYAttrs) == -1) {
                errorMessage = @"unable to get serial attributes";
            } else {
                // copy the old termios settings into the current
                //   you want to do this so that you get all the control characters assigned
                _portAttributes = _gOriginalTTYAttrs;

                /*
                 cfmakeraw(&options) is equivilent to:
                 options.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
                 options.c_oflag &= ~OPOST;
                 options.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
                 options.c_cflag &= ~(CSIZE | PARENB);
                 options.c_cflag |= CS8;
                 */
                cfmakeraw(&_portAttributes);

                // set VMIN and VTIME so read in monitor thread isn't blocking
                _portAttributes.c_cc[VMIN]  = 0 ;
                _portAttributes.c_cc[VTIME] = 10 ;

                close(_serialFileDescriptor);
                _serialFileDescriptor = -1 ;
            }
        }

        if (errorMessage) {
            NSString *fullErrorMessage = [NSString stringWithFormat:@"%s: new: %@ for %@: %s", USERDATA_TAG, errorMessage, _path, strerror(errno)] ;
            if (_serialFileDescriptor != -1) close(_serialFileDescriptor);
            _serialFileDescriptor = -1;
            luaL_error([[LuaSkin shared] L], (char *)[fullErrorMessage UTF8String]) ;
            return nil ;
        }
    }
    return self ;
}

- (void)openPort {
    if (_serialFileDescriptor == -1) {

        NSString   *errorMessage = nil ;
        unsigned long  mics = 3;  // receive latency ( in microseconds )

        // open the port
        //     O_NONBLOCK causes the port to open without any delay (we'll block with another call)
        _serialFileDescriptor = open([_path UTF8String], O_RDWR | O_NOCTTY | O_NONBLOCK );

        if (_serialFileDescriptor == -1) {
            // check if the port opened correctly
            errorMessage = @"unable to open serial port";
        } else {
            // TIOCEXCL causes blocking of non-root processes on this serial-port
            if (ioctl(_serialFileDescriptor, TIOCEXCL) == -1) {
                errorMessage = @"unable to obtain lock on serial port";
            } else {
                // clear the O_NONBLOCK flag; all calls from here on out are blocking for non-root processes
                if (fcntl(_serialFileDescriptor, F_SETFL, 0) == -1) {
                    errorMessage = @"unable to obtain lock on serial port";
                } else {
                    // set tty attributes
                    if (tcsetattr(_serialFileDescriptor, TCSANOW, &_portAttributes) == -1) {
                        errorMessage = @"unable to set serial attributes";
                    } else {
                        // Set baud rate (any arbitrary baud rate can be set this way)
                        if (ioctl(_serialFileDescriptor, IOSSIOSPEED, &_baud) == -1) {
                            errorMessage = @"baud rate out of bounds";
                        } else {
                            // Set the receive latency (a.k.a. don't wait to buffer data)
                            if (ioctl(_serialFileDescriptor, IOSSDATALAT, &mics) == -1) {
                                errorMessage = @"unable to set serial latency";
                            }
                        }
                    }
                }
            }
        }

        if (errorMessage) {
            NSString *fullErrorMessage = [NSString stringWithFormat:@"%s: open: %@ for %@: %s", USERDATA_TAG, errorMessage, _path, strerror(errno)] ;

            if (_serialFileDescriptor != -1) close(_serialFileDescriptor);
            _serialFileDescriptor = -1 ;
            luaL_error([[LuaSkin shared] L], (char *)[fullErrorMessage UTF8String]) ;
            return ;
        }
    }

    [self performSelectorInBackground:@selector(monitorIncomingDataThread:) withObject:[NSThread currentThread]];
}

- (void)closePort {
    if (_serialFileDescriptor != -1) {
       // The next tcsetattr() call can fail if the port is waiting to send data. This is likely to happen
        // e.g. if flow control is on and the CTS line is low. So, turn off flow control before proceeding
        struct termios options;

        tcgetattr(_serialFileDescriptor, &options);
        options.c_cflag &= ~(unsigned long)CRTSCTS; // RTS/CTS Flow Control
        options.c_cflag &= ~(unsigned long)(CDTR_IFLOW | CDSR_OFLOW); // DTR/DSR Flow Control
        options.c_cflag &= ~(unsigned long)CCAR_OFLOW; // DCD Flow Control
        // set VMIN and VTIME so read in monitor thread isn't blocking
        options.c_cc[VMIN]  = 0 ;
        options.c_cc[VTIME] = 10 ;

        tcsetattr(_serialFileDescriptor, TCSANOW, &options);

        int theDescriptor = _serialFileDescriptor ;
        _serialFileDescriptor = -1 ;
        while(_readThreadRunning) {} ;


        // return the serial port to its normal upright position...
        tcsetattr(theDescriptor, TCSADRAIN, &_gOriginalTTYAttrs);


        if (close(theDescriptor) == -1) {
            luaL_error([[LuaSkin shared] L], "%s: error closing serial port %@: %s", USERDATA_TAG, _path, strerror(errno)) ;
            return ;
        }

        // re-opening the same port REALLY fast will fail spectacularly... better to sleep a bit
        usleep(500000);
    }
}

- (NSData *)getBytesFromBuffer:(NSUInteger)chunkSize {
    NSData *bufferCopy ;

    if (chunkSize < 1) {
        luaL_error([[LuaSkin shared] L], "%s: cannot read less than 1 byte from buffer") ;
        return nil ;
    }

    while(_bufferChanging) {} ; _bufferChanging = YES ;
        if ([_incomingData length] > 0) {
            bufferCopy = [_incomingData subdataWithRange:NSMakeRange(0,MIN(chunkSize, [_incomingData length]))] ;
            if (chunkSize < [_incomingData length]) {
                NSData *remainingData = [_incomingData subdataWithRange:NSMakeRange(chunkSize,[_incomingData length] - chunkSize)] ;
                _incomingData = [remainingData mutableCopy] ;
            } else {
                _incomingData = [[NSMutableData alloc] init] ;
            }
        } else {
            bufferCopy = nil ;
        }
    _bufferChanging = NO ;
    return bufferCopy ;
}

- (NSData *)getDataFromBuffer {
    NSData *bufferCopy ;
    while(_bufferChanging) {} ; _bufferChanging = YES ;
        if ([_incomingData length] > 0) {
            bufferCopy    = [_incomingData copy] ;
            _incomingData = [[NSMutableData alloc] init] ;
        } else {
            bufferCopy    = nil ;
        }
    _bufferChanging = NO ;
    return bufferCopy ;
}

- (void)flushBuffer {
    while(_bufferChanging) {} ; _bufferChanging = YES ;
        _incomingData = [[NSMutableData alloc] init] ;
    _bufferChanging = NO ;
}

- (size_t)bufferSize {
    size_t bufferSize = 0 ;

    while(_bufferChanging) {} ; _bufferChanging = YES ;
        bufferSize = [_incomingData length] ;
    _bufferChanging = NO ;

    return bufferSize ;
}

- (void)lostPortNotification:(NSNumber *)errorNumber {
    if (_callbackFunction != LUA_NOREF) {
        [[LuaSkin shared] pushLuaRef:refTable ref:_lostPortFunction];
        [[LuaSkin shared] pushLuaRef:refTable ref:_selfRef];
        lua_pushstring([[LuaSkin shared] L], strerror([errorNumber intValue])) ;

        if (![[LuaSkin shared]  protectedCallAndTraceback:2 nresults:1]) {
            const char *errorMsg = lua_tostring([[LuaSkin shared] L], -1);
            lua_pop([[LuaSkin shared] L], 1) ;
            showError([[LuaSkin shared] L], (char *)[[NSString stringWithFormat:@"%s: lost port %@: %s, callback error: %s", USERDATA_TAG, _path, strerror([errorNumber intValue]), errorMsg] UTF8String]);
        }
    } else {
        showError([[LuaSkin shared] L], (char *)[[NSString stringWithFormat:@"%s: lost port %@: %s", USERDATA_TAG, _path, strerror([errorNumber intValue])] UTF8String]);
    }
}

- (void)serialInputNotification:(__unused id)object {
    if (_callbackFunction != LUA_NOREF) {
        NSData *theData = [self getDataFromBuffer] ;
        [[LuaSkin shared] pushLuaRef:refTable ref:_callbackFunction];
        [[LuaSkin shared] pushLuaRef:refTable ref:_selfRef];
        [[LuaSkin shared] pushNSObject:theData] ;

        if (![[LuaSkin shared]  protectedCallAndTraceback:2 nresults:1]) {
            const char *errorMsg = lua_tostring([[LuaSkin shared] L], -1);
            showError([[LuaSkin shared] L], (char *)[[NSString stringWithFormat:@"%s: callback error for port %@: %s", USERDATA_TAG, _path, errorMsg] UTF8String]);
        } else {
            _notifyMainThread = (BOOL)lua_toboolean([[LuaSkin shared] L], -1) ;
        }

         lua_pop([[LuaSkin shared] L], 1) ;
    }
}

// This selector/function will be called as another thread...
//  this thread will read from the serial port and exits when the port is closed
- (void)monitorIncomingDataThread:(__unused id)object {
    @autoreleasepool {
        // mark that the thread is running
        _readThreadRunning = YES;

        const int     BUFFER_SIZE = 512;
        unsigned char byte_buffer[BUFFER_SIZE]; // buffer for holding incoming data
        ssize_t       numBytes=0; // number of bytes read during read

        // assign a high priority to this thread
        [NSThread setThreadPriority:1.0];

        while(TRUE) {
            // read() blocks until some data is available or the port is closed
            if (_serialFileDescriptor == -1) break ;

            numBytes = read(_serialFileDescriptor, byte_buffer, BUFFER_SIZE); // read up to the size of the buffer
            if(numBytes>0) {
                while(_bufferChanging) {} ; _bufferChanging = YES ;
                    [_incomingData appendData:[NSData dataWithBytes:byte_buffer length:(NSUInteger)numBytes]] ;
                _bufferChanging = NO ;
                if (_notifyMainThread) {
                    _notifyMainThread = NO ;
                    [self performSelectorOnMainThread:@selector(serialInputNotification:)
                                           withObject:self
                                        waitUntilDone:NO];
                }
            } else if (numBytes < 0) {
                if (_serialFileDescriptor != -1) {
                    // It wasn't because of an actual close...
                    close(_serialFileDescriptor);
                    _serialFileDescriptor = -1;

                    CLS_NSLOG(@"%s: port %@ unexpectedly died: %s", USERDATA_TAG, _path, strerror(errno)) ;
                    [self performSelectorOnMainThread:@selector(lostPortNotification:)
                                           withObject:[NSNumber numberWithInt:errno]
                                        waitUntilDone:NO];
                }
                break; // Stop the thread if there is an error
            }
        }

        // mark that the thread has quit
        _readThreadRunning = NO;
    }
}

@end

/// hs._asm.serial.listPorts() -> array
/// Function
/// List the available serial ports for the system
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array of available serial ports where each entry in the array is a table describing a serial port.  The table for each index will contain the following keys:
///    * baseName   - the name of the serial port
///    * calloutDevice - the path to the callout or "active" device for the serial port
///    * dialinDevice  - the path to the dialin or "listening" device for the serial port
///    * bsdType       - the type of serial port device
///    * ttyDevice
///    * ttySuffix
///
/// Notes:
///  * For most purposes, it is most likely that you want to use the calloutDevice when performing serial communications as it blocks other processes (other than root) from using the serial device while Hammerspoon is using it.
static int serial_listPorts(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;

    io_object_t serialPort;
    io_iterator_t serialPortIterator;

    // ask for all the serial ports
    IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(kIOSerialBSDServiceValue), &serialPortIterator);

    lua_newtable(L) ;

    // loop through all the serial ports and add them to the array
    while ((serialPort = IOIteratorNext(serialPortIterator))) {
        lua_newtable(L) ;
            lua_pushstring(L, [(__bridge_transfer NSString *)IORegistryEntryCreateCFProperty(serialPort, CFSTR(kIOTTYBaseNameKey),  kCFAllocatorDefault, 0) UTF8String]) ;
            lua_setfield(L, -2, "baseName") ;
            lua_pushstring(L, [(__bridge_transfer NSString *)IORegistryEntryCreateCFProperty(serialPort, CFSTR(kIOCalloutDeviceKey),  kCFAllocatorDefault, 0) UTF8String]) ;
            lua_setfield(L, -2, "calloutDevice") ;
            lua_pushstring(L, [(__bridge_transfer NSString *)IORegistryEntryCreateCFProperty(serialPort, CFSTR(kIOSerialBSDTypeKey),  kCFAllocatorDefault, 0) UTF8String]) ;
            lua_setfield(L, -2, "bsdType") ;
            lua_pushstring(L, [(__bridge_transfer NSString *)IORegistryEntryCreateCFProperty(serialPort, CFSTR(kIOTTYDeviceKey),  kCFAllocatorDefault, 0) UTF8String]) ;
            lua_setfield(L, -2, "ttyDevice") ;
            lua_pushstring(L, [(__bridge_transfer NSString *)IORegistryEntryCreateCFProperty(serialPort, CFSTR(kIOTTYSuffixKey),  kCFAllocatorDefault, 0) UTF8String]) ;
            lua_setfield(L, -2, "ttySuffix") ;
            lua_pushstring(L, [(__bridge_transfer NSString *)IORegistryEntryCreateCFProperty(serialPort, CFSTR(kIODialinDeviceKey),  kCFAllocatorDefault, 0) UTF8String]) ;
            lua_setfield(L, -2, "dialinDevice") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;

        IOObjectRelease(serialPort);
    }

    IOObjectRelease(serialPortIterator);

    return 1 ;
}

/// hs._asm.serial.port(path) -> serialPortObject
/// Constructor
/// Create a Hammerspoon reference to the selected serial port and sets the initial attributes to raw at 9600 baud.
///
/// Parameters:
///  * path - the bsd style path to the device node which represents the serial device you wish to use.
///
/// Returns:
///  * the serial port object
///
/// Notes:
///  * This constructor does not open the serial port.  It just creates a reference to the serial port for use within Hammerspoon.
///  * In most cases, you will want to use the calloutDevice for the serial port (see `hs._asm.serial.listPorts`)
static int serial_port(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TSTRING, LS_TBREAK] ;

    size_t     pathLen ;
    const char *bsdPath = lua_tolstring(L, 1, &pathLen) ;

    HSSerialPort *port = [[HSSerialPort alloc] initWithPort:bsdPath] ;

    if (port) {
        void** portPtr = lua_newuserdata(L, sizeof(HSSerialPort *)) ;
        *portPtr = (__bridge_retained void *)port ;
        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
        lua_pushvalue(L, -1) ;
        port.selfRef = [[LuaSkin shared] luaRef:refTable] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

/// hs._asm.serial:open() -> serialPortObject
/// Constructor
/// Open the serial port for communication and apply the most recently provided settings and baud rate.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the serial port object
///
/// Notes:
///  * If the serial port is already open, this method does nothing.
static int serial_open(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    [port openPort] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs._asm.serial:close() -> nil
/// Method
/// Close and release the serial port
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * If the port is already closed, this method does nothing.
///  * This method is automatically called during garbage collection (most notably when your Hammerspoon configuration is reloaded or Hammerspoon is quit.)
static int serial_close(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    [port closePort] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs._asm.serial:isOpen() -> boolean
/// Method
/// Returns a boolean value indicating whether or not the serial port is currently open
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the serial port is currently open or false if it is not.
static int serial_isOpen(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    lua_pushboolean(L, (port.serialFileDescriptor != -1)) ;
    return 1 ;
}

/// hs._asm.serial:incomingDataCallback(fn) -> serialPortObject
/// Method
/// Set or clear a callback function for incoming data
///
/// Parameters:
///  * fn - a function to callback when incoming data is detected.  If an explicit nil value is given, remove any existing callback function.  The function should expect two parameters, the serialPortObject and the incoming buffer contents as a lua string, and return one result: True if the callback should remain active for additional incoming data or false if it should not.
///
/// Returns:
///  * the serial port object
///
/// Notes:
///  * Data passed to the callback function is not guaranteed to be valid UTF8 or even complete.  You may need to perform additional reads with `hs._asm.serial:readBuffer` or cache data for an additional callback to get the full results.  See also `hs._asm.serial:bufferSize`.
///
///  * This does not enable the callback function, it merely attaches it to this serial port.  See `hs._asm.serial:enableCallback` for more information.
///  * If the callback function is currently enabled and this method is used to assign a new callback function, there is a small window where data may be buffered, but will not invoke a callback.  This buffered data will be included in the next callback invocation or can be manually retrieved with `hs._asm.serial:readBuffer`.
///  * If the callback function is currently enabled and this method is used to remove the existing callback, the enable state will be set to false.
static int serial_incomingDataCallback(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    // either way, we need to set the existing callback to nil, so...
    BOOL currentState = port.notifyMainThread ;
    port.notifyMainThread = NO ;
    port.callbackFunction = [[LuaSkin shared] luaUnref:refTable ref:port.callbackFunction] ;

    if (lua_type(L, 2) != LUA_TNIL) {
        lua_pushvalue(L, 2);
        port.callbackFunction = [[LuaSkin shared] luaRef:refTable] ;

        port.notifyMainThread = currentState ;
    }

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs._asm.serial:lostPortCallback(fn) -> serialPortObject
/// Method
/// Set or clear a callback function for a lost serial port connection
///
/// Parameters:
///  * fn - a function to callback when the serial port is unexpectedly lost.  If an explicit nil value is given, remove any existing callback function.  The function should expect two parameters, the serialPortObject and a string containing the error message (if any). The function should not return a value.
///
/// Returns:
///  * the serial port object
///
/// Notes:
///  * This function will not be called if the port exits normally; for example because of calling `hs._asm.serial:close` or due to garbage collection (Hammerspoon reloading or termination)
static int serial_lostPortCallback(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    // either way, we need to set the existing callback to nil, so...
    port.lostPortFunction = [[LuaSkin shared] luaUnref:refTable ref:port.lostPortFunction] ;

    if (lua_type(L, 2) != LUA_TNIL) {
        lua_pushvalue(L, 2);
        port.lostPortFunction = [[LuaSkin shared] luaRef:refTable] ;
    }

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs._asm.serial:enableCallback([flag]) -> serialPortObject | state
/// Method
/// Get or set whether or not a callback should occur when incoming data is detected from the serial port
///
/// Parameters:
///  * flag - an optional boolean flag indicating whether or not incoming data should trigger the registered callback function.
///
/// Returns:
///  * If a value is specified, then this method returns the serial port object.  Otherwise this method returns the current value.
static int serial_enableCallback(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    if (lua_isnone(L, 2)) {
        lua_pushboolean(L, port.notifyMainThread) ;
    } else {
        port.notifyMainThread = (BOOL)lua_toboolean(L, 2) ;
        lua_settop(L, 1) ;
    }

    return 1 ;
}

/// hs._asm.serial:flushBuffer() -> serialPortObject
/// Method
/// Dumps all data currently waiting in the incoming data buffer.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the serial port object
static int serial_flushBuffer(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    if (port.serialFileDescriptor != -1) {
        [port flushBuffer] ;

        lua_settop(L, 1) ;
        return 1 ;
    } else {
        return luaL_error(L, "%s: serial port %s is not currently open", USERDATA_TAG, [port.path UTF8String]) ;
    }
}

/// hs._asm.serial:bufferSize() -> integer
/// Method
/// Returns the number of bytes currently in the serial port's receive buffer.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the number of bytes currently in the receive buffer
static int serial_bufferSize(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    if (port.serialFileDescriptor != -1) {
        lua_pushinteger(L, (lua_Integer)[port bufferSize]) ;
        return 1 ;
    } else {
        return luaL_error(L, "%s: serial port %s is not currently open", USERDATA_TAG, [port.path UTF8String]) ;
    }
}

/// hs._asm.serial:write(data) -> serialPortObject
/// Method
/// Write the specified data to the serial port.
///
/// Parameters:
///  * data - the data to send to the serial port.
///
/// Returns:
///  * the serial port object
///
/// Notes:
/// * A number is treated as a string (i.e. 123 will be sent as "123").  To send an actual byte value of 123, use `string.char(123)` as the data.
static int serial_write(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    if (port.serialFileDescriptor != -1) {
        size_t     length ;
        const char *theData = lua_tolstring(L, 2, &length) ;

        ssize_t result = write(port.serialFileDescriptor, theData, length);

        if (result == -1) {
            return luaL_error(L, "%s: error writing to %s", USERDATA_TAG, [port.path UTF8String], strerror(errno)) ;
        }

        if (result != (ssize_t)length) {
            return luaL_error(L, "%s: incomplete write to %s", USERDATA_TAG, [port.path UTF8String]) ;
        }

        lua_settop(L, 1) ;
        return 1 ;
    } else {
        return luaL_error(L, "%s: serial port %s is not currently open", USERDATA_TAG, [port.path UTF8String]) ;
    }
}

/// hs._asm.serial:readBuffer([bytes]) -> string
/// Method
/// Reads the incoming serial buffer.  If bytes is specified, only read up to that many bytes; otherwise everything currently in the incoming buffer is read.
///
/// Parameters:
///  * bytes - an optional integer defining how many bytes to read.  If it is not present, the entire buffer is returned.
///
/// Returns:
///  * a string containing the specified contents of the read buffer
///
/// Notes:
///  * Data returned by this method is not guaranteed to be valid UTF8 or even complete.  You may need to perform additional reads or cache data for a later check to get full results.  See also `hs._asm.serial:bufferSize`.
///
///  * This method will clear the current incoming buffer of the data it returns.  Cache the data if you need to keep a record.
///  * This method will return nil if the buffer is currently empty.
///
///  * This method can be called even if the serial port is closed (even if closed unexpectedly), though no new data will arrive unless the port is re-opened.
static int serial_readBuffer(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    lua_Integer chunkSize ;
    if (lua_isnone(L, 2)) chunkSize = 0 ;
    else {
        chunkSize = lua_tointeger(L, 2) ;
        if (chunkSize < 1)
            return luaL_error(L, "%s: readBuffer byte parameter must be a positive integer if specified", USERDATA_TAG) ;
    }

    if (chunkSize == 0)
        [[LuaSkin shared] pushNSObject:[port getDataFromBuffer]] ;
    else
        [[LuaSkin shared] pushNSObject:[port getBytesFromBuffer:(NSUInteger)chunkSize]] ;

    return 1 ;
}

/// hs._asm.serial:DTR(state) -> serialPortObject
/// Method
/// Set the DTR high or low
///
/// Parameters:
///  * state - a boolean indicating if the DTR should be set high (true) or low (false)
///
/// Returns:
///  * the serial port object
static int serial_DTR(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    if (port.serialFileDescriptor != -1) {
        if (lua_toboolean(L, 2)) {
            ioctl(port.serialFileDescriptor, TIOCSDTR);
        } else {
            ioctl(port.serialFileDescriptor, TIOCCDTR);
        }

        lua_settop(L, 1) ;
        return 1 ;
    } else {
        return luaL_error(L, "%s: serial port %s is not currently open", USERDATA_TAG, [port.path UTF8String]) ;
    }
}

/// hs._asm.serial:baud(rate) -> serialPortObject
/// Method
/// Change the current baud rate for the serial port
///
/// Parameters:
///  * rate - the new baud rate to set for the serial port
///
/// Returns:
///  * the serial port object
///
/// Notes:
///  * if the serial port is currently open, this method attempts to change the baud rate immediately; otherwise the change will be applied when the serial port is opened with `hs._asm.serial:open`.
///  * need to find out if this resets the serial port on error like the example suggests but I can't find documented anywhere
static int serial_baud(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    port.baud = (speed_t)lua_tointeger(L, 2) ;

    if (port.serialFileDescriptor != -1) {
        speed_t baudRate = port.baud ;
        if (ioctl(port.serialFileDescriptor, IOSSIOSPEED, &baudRate) == -1) {
            return luaL_error(L, "%s: baud rate out of bounds for %s: %s", USERDATA_TAG, [port.path UTF8String], strerror(errno)) ;
        }
    }

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs._asm.serial:getAttributes() -> termiosTable
/// Method
/// Get the serial port's termios structure and return it in table form.  This is used internally and provided for advanced serial port manipulation.  It is not expected that you will require this method for most serial port usage requirements.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the following keys:
///    * iflag  - bit flag representing the input modes for the termios structure
///    * oflag  - bit flag representing the output modes for the termios structure
///    * cflag  - bit flag representing the control modes for the termios structure
///    * lflag  - bit flag representing the local modes for the termios structure
///    * ispeed - input speed
///    * ospeed - output speed
///    * cc     - array of control characters which have special meaning under certain conditions
///
/// Notes:
///  * If the serial port is currently open, this method will query the port for its current settings; otherwise, the settings which are to be applied when the port is opened with `hs._asm.serial:open` are provided.
///  * The baud rate for the serial port is set via ioctl with the IOSSIOSPEED request to allow a wider range of values than termios directly supports.  `ispeed` and `ospeed` may not be an accurate measure of the actual baud rate currently in effect.
static int serial_getAttributes(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    // just to make sure they're current, if port currently open, copy them
    if (port.serialFileDescriptor != -1) {
        struct termios options = port.portAttributes ;
        if (tcgetattr(port.serialFileDescriptor, &options) == -1) {
            return luaL_error(L, "%s: unable to get serial attributes for %s: %s", USERDATA_TAG, [port.path UTF8String], strerror(errno)) ;
        } else {
            port.portAttributes = options ;
        }
    }

    lua_newtable(L) ;
        lua_pushinteger(L, (lua_Integer)(port.portAttributes).c_iflag) ;  lua_setfield(L, -2, "iflag") ;
        lua_pushinteger(L, (lua_Integer)(port.portAttributes).c_oflag) ;  lua_setfield(L, -2, "oflag") ;
        lua_pushinteger(L, (lua_Integer)(port.portAttributes).c_cflag) ;  lua_setfield(L, -2, "cflag") ;
        lua_pushinteger(L, (lua_Integer)(port.portAttributes).c_lflag) ;  lua_setfield(L, -2, "lflag") ;
        lua_pushinteger(L, (lua_Integer)(port.portAttributes).c_ispeed) ; lua_setfield(L, -2, "ispeed") ;
        lua_pushinteger(L, (lua_Integer)(port.portAttributes).c_ospeed) ; lua_setfield(L, -2, "ospeed") ;
        lua_newtable(L) ;
            for(int i = 0 ; i < NCCS ; i++) {
                lua_pushinteger(L, (port.portAttributes).c_cc[i]) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1 ) ;
            }
            lua_setfield(L, -2, "cc") ;

    return 1 ;
}

/// hs._asm.serial:setAttributes(termiosTable, action) -> serialPortObject
/// Method
/// Set the serial port's termios structure To the values specified in the provided table.  This is used internally and provided for advanced serial port manipulation.  It is not expected that you will require this method for most serial port usage requirements.
///
/// Parameters:
///  * termiosTable - a table containing the following keys:
///    * iflag  - bit flag representing the input modes for the termios structure
///    * oflag  - bit flag representing the output modes for the termios structure
///    * cflag  - bit flag representing the control modes for the termios structure
///    * lflag  - bit flag representing the local modes for the termios structure
///    * ispeed - input speed
///    * ospeed - output speed
///    * cc     - array of control characters which have special meaning under certain conditions
///  * action - an action flag from `hs._asm.serial.attributeFlags.action` specifying when to apply the new termios values
///
/// Returns:
///  * the serial port object
///
/// Notes:
///  * If the serial port is currently open, this method will try to apply the settings immediately; otherwise the settings will be saved until the serial port is opened with `hs._asm.serial:open`.
///  * Not all possible modes in iflag, oflag, cflag, and lflag are valid for all serial devices or drivers.
///  * The ispeed and ospeed values should not be adjusted -- use the `hs._asm.serial:baud` method to set the serial port baud rate as it allows for a wider range of speeds than termios directly supports.
///  * It is expected that this method will be called after making changes to the results provided by `hs._asm.serial:getAttributes`.
static int serial_setAttributes(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;

    struct termios options ;

    if (lua_getfield(L, 2, "iflag") != LUA_TNUMBER || !lua_isinteger(L, -1)) {
        lua_pop(L, 1) ;
        return luaL_error(L, "%s:setAttributes - integer expected for required field iflag", USERDATA_TAG) ;
    } else {
        options.c_iflag = (tcflag_t)luaL_checkinteger(L, -1) ;
        lua_pop(L, 1) ;
    }
    if (lua_getfield(L, 2, "oflag") != LUA_TNUMBER || !lua_isinteger(L, -1)) {
        lua_pop(L, 1) ;
        return luaL_error(L, "%s:setAttributes - integer expected for required field oflag", USERDATA_TAG) ;
    } else {
        options.c_oflag = (tcflag_t)luaL_checkinteger(L, -1) ;
        lua_pop(L, 1) ;
    }
    if (lua_getfield(L, 2, "cflag") != LUA_TNUMBER || !lua_isinteger(L, -1)) {
        lua_pop(L, 1) ;
        return luaL_error(L, "%s:setAttributes - integer expected for required field cflag", USERDATA_TAG) ;
    } else {
        options.c_cflag = (tcflag_t)luaL_checkinteger(L, -1) ;
        lua_pop(L, 1) ;
    }
    if (lua_getfield(L, 2, "lflag") != LUA_TNUMBER || !lua_isinteger(L, -1)) {
        lua_pop(L, 1) ;
        return luaL_error(L, "%s:setAttributes - integer expected for required field lflag", USERDATA_TAG) ;
    } else {
        options.c_lflag = (tcflag_t)luaL_checkinteger(L, -1) ;
        lua_pop(L, 1) ;
    }
    if (lua_getfield(L, 2, "ispeed") != LUA_TNUMBER || !lua_isinteger(L, -1)) {
        lua_pop(L, 1) ;
        return luaL_error(L, "%s:setAttributes - integer expected for required field ispeed", USERDATA_TAG) ;
    } else {
        options.c_ispeed = (speed_t)luaL_checkinteger(L, -1) ;
        lua_pop(L, 1) ;
    }
    if (lua_getfield(L, 2, "ospeed") != LUA_TNUMBER || !lua_isinteger(L, -1)) {
        lua_pop(L, 1) ;
        return luaL_error(L, "%s:setAttributes - integer expected for required field ospeed", USERDATA_TAG) ;
    } else {
        options.c_ospeed = (speed_t)luaL_checkinteger(L, -1) ;
        lua_pop(L, 1) ;
    }
    if (lua_getfield(L, 2, "cc") != LUA_TTABLE) {
        lua_pop(L, 1) ;
        return luaL_error(L, "%s:setAttributes - table expected for required field cc", USERDATA_TAG) ;
    } else {
        if (luaL_len(L, -1) != NCCS) {
            lua_pop(L, 1) ;
            return luaL_error(L, "%s:setAttributes - cc table must contain %d entries", USERDATA_TAG, NCCS) ;
        }
        int realPos = lua_absindex(L, -1) ;
        for (int i = 0 ; i < NCCS ; i++) {
            lua_rawgeti(L, realPos, i + 1) ;
            if (lua_type(L, -1) != LUA_TNUMBER || !lua_isinteger(L, -1)) {
                lua_pop(L, 2) ;
                return luaL_error(L, "%s:setAttributes - integer expected for cc table entry %d", USERDATA_TAG, i + 1) ;
            } else {
                options.c_cc[i] = (unsigned char)luaL_checkinteger(L, -1) ;
                lua_pop(L, 1) ;
            }
        }
        lua_pop(L, 1) ;
    }

    port.portAttributes = options ;

    if (port.serialFileDescriptor != -1) {
        int action = TCSANOW ;
        if (lua_type(L, 3) == LUA_TNUMBER) {
            action = (int)luaL_checkinteger(L, 3) ;
        }

        if (tcsetattr(port.serialFileDescriptor, action, &options) == -1) {
            return luaL_error(L, "%s: unable to set serial attributes for %s: %s", USERDATA_TAG, [port.path UTF8String], strerror(errno)) ;
        }
    }

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs._asm.serial.attributeFlags
/// Constant
/// A table containing TERMIOS flags for advanced serial control.  This is provided for internal use and for reference if you need to manipulate the serial attributes directly with `hs._asm.serial:getAttributes` and `hs._asm.serial:setAttributes`.  This should not be required for most serial port requirements.
///
/// Contents:
///  * iflag  - constants which apply to termios input modes
///  * oflag  - constants which apply to termios output modes
///  * cflag  - constants which apply to termios control modes
///  * lflag  - constants which apply to termios local modes
///  * cc     - index labels for the `cc` array in the termios control character structure
///  * action - flags indicating when changes to the termios structure provided to `hs._asm.serial:setAttributes` should be applied.
///  * baud   - predefined baud rate labels
///
/// Notes:
///  * Not all defined modes in iflag, oflag, cflag, and lflag are valid for all serial devices or drivers.
///  * Lua tables start at index 1 rather than 0; the index labels in cc reflect this (i.e. they are each 1 greater than the value defined in /usr/include/sys/termios.h).
///  * The list of baud rates is provided as a reference.  The baud rate is actually set via ioctl with the IOSSIOSPEED request to allow a wider range of values than termios directly supports.  Note that not all baud rates are valid for all serial devices or drivers.
static int serial_pushConstants(lua_State *L) {
    lua_newtable(L) ;
      lua_newtable(L) ;
        lua_pushinteger(L, IGNBRK) ;  lua_setfield(L, -2, "IGNBRK") ;  /* ignore BREAK condition */
        lua_pushinteger(L, BRKINT) ;  lua_setfield(L, -2, "BRKINT") ;  /* map BREAK to SIGINTR */
        lua_pushinteger(L, IGNPAR) ;  lua_setfield(L, -2, "IGNPAR") ;  /* ignore (discard) parity errors */
        lua_pushinteger(L, PARMRK) ;  lua_setfield(L, -2, "PARMRK") ;  /* mark parity and framing errors */
        lua_pushinteger(L, INPCK) ;   lua_setfield(L, -2, "INPCK") ;   /* enable checking of parity errors */
        lua_pushinteger(L, ISTRIP) ;  lua_setfield(L, -2, "ISTRIP") ;  /* strip 8th bit off chars */
        lua_pushinteger(L, INLCR) ;   lua_setfield(L, -2, "INLCR") ;   /* map NL into CR */
        lua_pushinteger(L, IGNCR) ;   lua_setfield(L, -2, "IGNCR") ;   /* ignore CR */
        lua_pushinteger(L, ICRNL) ;   lua_setfield(L, -2, "ICRNL") ;   /* map CR to NL (ala CRMOD) */
        lua_pushinteger(L, IXON) ;    lua_setfield(L, -2, "IXON") ;    /* enable output flow control */
        lua_pushinteger(L, IXOFF) ;   lua_setfield(L, -2, "IXOFF") ;   /* enable input flow control */
        lua_pushinteger(L, IXANY) ;   lua_setfield(L, -2, "IXANY") ;   /* any char will restart after stop */
        lua_pushinteger(L, IMAXBEL) ; lua_setfield(L, -2, "IMAXBEL") ; /* ring bell on input queue full */
        lua_pushinteger(L, IUTF8) ;   lua_setfield(L, -2, "IUTF8") ;   /* maintain state for UTF-8 VERASE */
      lua_setfield(L, -2, "iflag") ;
      lua_newtable(L) ;
        lua_pushinteger(L, OPOST) ;  lua_setfield(L, -2, "OPOST") ;  /* enable following output processing */
        lua_pushinteger(L, ONLCR) ;  lua_setfield(L, -2, "ONLCR") ;  /* map NL to CR-NL (ala CRMOD) */
        lua_pushinteger(L, OXTABS) ; lua_setfield(L, -2, "OXTABS") ; /* expand tabs to spaces */
        lua_pushinteger(L, ONOEOT) ; lua_setfield(L, -2, "ONOEOT") ; /* discard EOT's `^D' on output) */
        lua_pushinteger(L, OCRNL) ;  lua_setfield(L, -2, "OCRNL") ;  /* map CR to NL */
        lua_pushinteger(L, ONOCR) ;  lua_setfield(L, -2, "ONOCR") ;  /* No CR output at column 0 */
        lua_pushinteger(L, ONLRET) ; lua_setfield(L, -2, "ONLRET") ; /* NL performs CR function */
        lua_pushinteger(L, OFILL) ;  lua_setfield(L, -2, "OFILL") ;  /* use fill characters for delay */
        lua_pushinteger(L, NLDLY) ;  lua_setfield(L, -2, "NLDLY") ;  /* \n delay */
        lua_pushinteger(L, TABDLY) ; lua_setfield(L, -2, "TABDLY") ; /* horizontal tab delay */
        lua_pushinteger(L, CRDLY) ;  lua_setfield(L, -2, "CRDLY") ;  /* \r delay */
        lua_pushinteger(L, FFDLY) ;  lua_setfield(L, -2, "FFDLY") ;  /* form feed delay */
        lua_pushinteger(L, BSDLY) ;  lua_setfield(L, -2, "BSDLY") ;  /* \b delay */
        lua_pushinteger(L, VTDLY) ;  lua_setfield(L, -2, "VTDLY") ;  /* vertical tab delay */
        lua_pushinteger(L, OFDEL) ;  lua_setfield(L, -2, "OFDEL") ;  /* fill is DEL, else NUL */
      lua_setfield(L, -2, "oflag") ;
      lua_newtable(L) ;
        lua_pushinteger(L, CIGNORE) ;    lua_setfield(L, -2, "CIGNORE") ;    /* ignore control flags */
        lua_pushinteger(L, CSIZE) ;      lua_setfield(L, -2, "CSIZE") ;      /* character size mask */
        lua_pushinteger(L, CS5) ;        lua_setfield(L, -2, "CS5") ;        /* 5 bits (pseudo) */
        lua_pushinteger(L, CS6) ;        lua_setfield(L, -2, "CS6") ;        /* 6 bits */
        lua_pushinteger(L, CS7) ;        lua_setfield(L, -2, "CS7") ;        /* 7 bits */
        lua_pushinteger(L, CS8) ;        lua_setfield(L, -2, "CS8") ;        /* 8 bits */
        lua_pushinteger(L, CSTOPB) ;     lua_setfield(L, -2, "CSTOPB") ;     /* send 2 stop bits */
        lua_pushinteger(L, CREAD) ;      lua_setfield(L, -2, "CREAD") ;      /* enable receiver */
        lua_pushinteger(L, PARENB) ;     lua_setfield(L, -2, "PARENB") ;     /* parity enable */
        lua_pushinteger(L, PARODD) ;     lua_setfield(L, -2, "PARODD") ;     /* odd parity, else even */
        lua_pushinteger(L, HUPCL) ;      lua_setfield(L, -2, "HUPCL") ;      /* hang up on last close */
        lua_pushinteger(L, CLOCAL) ;     lua_setfield(L, -2, "CLOCAL") ;     /* ignore modem status lines */
        lua_pushinteger(L, CCTS_OFLOW) ; lua_setfield(L, -2, "CCTS_OFLOW") ; /* CTS flow control of output */
        lua_pushinteger(L, CRTSCTS) ;    lua_setfield(L, -2, "CRTSCTS") ;    /* (CCTS_OFLOW | CRTS_IFLOW) */
        lua_pushinteger(L, CRTS_IFLOW) ; lua_setfield(L, -2, "CRTS_IFLOW") ; /* RTS flow control of input */
        lua_pushinteger(L, CDTR_IFLOW) ; lua_setfield(L, -2, "CDTR_IFLOW") ; /* DTR flow control of input */
        lua_pushinteger(L, CDSR_OFLOW) ; lua_setfield(L, -2, "CDSR_OFLOW") ; /* DSR flow control of output */
        lua_pushinteger(L, CCAR_OFLOW) ; lua_setfield(L, -2, "CCAR_OFLOW") ; /* DCD flow control of output */
        lua_pushinteger(L, MDMBUF) ;     lua_setfield(L, -2, "MDMBUF") ;     /* old name for CCAR_OFLOW */
      lua_setfield(L, -2, "cflag") ;
      lua_newtable(L) ;
        lua_pushinteger(L, ECHOKE) ;     lua_setfield(L, -2, "ECHOKE") ;     /* visual erase for line kill */
        lua_pushinteger(L, ECHOE) ;      lua_setfield(L, -2, "ECHOE") ;      /* visually erase chars */
        lua_pushinteger(L, ECHOK) ;      lua_setfield(L, -2, "ECHOK") ;      /* echo NL after line kill */
        lua_pushinteger(L, ECHO) ;       lua_setfield(L, -2, "ECHO") ;       /* enable echoing */
        lua_pushinteger(L, ECHONL) ;     lua_setfield(L, -2, "ECHONL") ;     /* echo NL even if ECHO is off */
        lua_pushinteger(L, ECHOPRT) ;    lua_setfield(L, -2, "ECHOPRT") ;    /* visual erase mode for hardcopy */
        lua_pushinteger(L, ECHOCTL) ;    lua_setfield(L, -2, "ECHOCTL") ;    /* echo control chars as ^(Char) */
        lua_pushinteger(L, ISIG) ;       lua_setfield(L, -2, "ISIG") ;       /* enable signals INTR, QUIT, [D]SUSP */
        lua_pushinteger(L, ICANON) ;     lua_setfield(L, -2, "ICANON") ;     /* canonicalize input lines */
        lua_pushinteger(L, ALTWERASE) ;  lua_setfield(L, -2, "ALTWERASE") ;  /* use alternate WERASE algorithm */
        lua_pushinteger(L, IEXTEN) ;     lua_setfield(L, -2, "IEXTEN") ;     /* enable DISCARD and LNEXT */
        lua_pushinteger(L, EXTPROC) ;    lua_setfield(L, -2, "EXTPROC") ;    /* external processing */
        lua_pushinteger(L, TOSTOP) ;     lua_setfield(L, -2, "TOSTOP") ;     /* stop background jobs from output */
        lua_pushinteger(L, FLUSHO) ;     lua_setfield(L, -2, "FLUSHO") ;     /* output being flushed (state) */
        lua_pushinteger(L, NOKERNINFO) ; lua_setfield(L, -2, "NOKERNINFO") ; /* no kernel output from VSTATUS */
        lua_pushinteger(L, PENDIN) ;     lua_setfield(L, -2, "PENDIN") ;     /* XXX retype pending input (state) */
        lua_pushinteger(L, NOFLSH) ;     lua_setfield(L, -2, "NOFLSH") ;     /* don't flush after interrupt */
      lua_setfield(L, -2, "lflag") ;
      lua_newtable(L) ;
        lua_pushinteger(L, VEOF + 1) ;     lua_setfield(L, -2, "VEOF") ;
        lua_pushinteger(L, VEOL + 1) ;     lua_setfield(L, -2, "VEOL") ;
        lua_pushinteger(L, VEOL2 + 1) ;    lua_setfield(L, -2, "VEOL2") ;
        lua_pushinteger(L, VERASE + 1) ;   lua_setfield(L, -2, "VERASE") ;
        lua_pushinteger(L, VWERASE + 1) ;  lua_setfield(L, -2, "VWERASE") ;
        lua_pushinteger(L, VKILL + 1) ;    lua_setfield(L, -2, "VKILL") ;
        lua_pushinteger(L, VREPRINT + 1) ; lua_setfield(L, -2, "VREPRINT") ;
        lua_pushinteger(L, VINTR + 1) ;    lua_setfield(L, -2, "VINTR") ;
        lua_pushinteger(L, VQUIT + 1) ;    lua_setfield(L, -2, "VQUIT") ;
        lua_pushinteger(L, VSUSP + 1) ;    lua_setfield(L, -2, "VSUSP") ;
        lua_pushinteger(L, VDSUSP + 1) ;   lua_setfield(L, -2, "VDSUSP") ;
        lua_pushinteger(L, VSTART + 1) ;   lua_setfield(L, -2, "VSTART") ;
        lua_pushinteger(L, VSTOP + 1) ;    lua_setfield(L, -2, "VSTOP") ;
        lua_pushinteger(L, VLNEXT + 1) ;   lua_setfield(L, -2, "VLNEXT") ;
        lua_pushinteger(L, VDISCARD + 1) ; lua_setfield(L, -2, "VDISCARD") ;
        lua_pushinteger(L, VMIN + 1) ;     lua_setfield(L, -2, "VMIN") ;
        lua_pushinteger(L, VTIME + 1) ;    lua_setfield(L, -2, "VTIME") ;
        lua_pushinteger(L, VSTATUS + 1) ;  lua_setfield(L, -2, "VSTATUS") ;
      lua_setfield(L, -2, "cc") ;
      lua_newtable(L) ;
        lua_pushinteger(L, TCSANOW) ;   lua_setfield(L, -2, "TCSANOW") ;
        lua_pushinteger(L, TCSADRAIN) ; lua_setfield(L, -2, "TCSADRAIN") ;
        lua_pushinteger(L, TCSAFLUSH) ; lua_setfield(L, -2, "TCSAFLUSH") ;
        lua_pushinteger(L, TCSASOFT) ;  lua_setfield(L, -2, "TCSASOFT") ;
      lua_setfield(L, -2, "action") ;
      lua_newtable(L) ;
        lua_pushinteger(L, B0) ;      lua_setfield(L, -2, "B0") ;
        lua_pushinteger(L, B50) ;     lua_setfield(L, -2, "B50") ;
        lua_pushinteger(L, B75) ;     lua_setfield(L, -2, "B75") ;
        lua_pushinteger(L, B110) ;    lua_setfield(L, -2, "B110") ;
        lua_pushinteger(L, B134) ;    lua_setfield(L, -2, "B134") ;
        lua_pushinteger(L, B150) ;    lua_setfield(L, -2, "B150") ;
        lua_pushinteger(L, B200) ;    lua_setfield(L, -2, "B200") ;
        lua_pushinteger(L, B300) ;    lua_setfield(L, -2, "B300") ;
        lua_pushinteger(L, B600) ;    lua_setfield(L, -2, "B600") ;
        lua_pushinteger(L, B1200) ;   lua_setfield(L, -2, "B1200") ;
        lua_pushinteger(L, B1800) ;   lua_setfield(L, -2, "B1800") ;
        lua_pushinteger(L, B2400) ;   lua_setfield(L, -2, "B2400") ;
        lua_pushinteger(L, B4800) ;   lua_setfield(L, -2, "B4800") ;
        lua_pushinteger(L, B9600) ;   lua_setfield(L, -2, "B9600") ;
        lua_pushinteger(L, B19200) ;  lua_setfield(L, -2, "B19200") ;
        lua_pushinteger(L, B38400) ;  lua_setfield(L, -2, "B38400") ;
        lua_pushinteger(L, B7200) ;   lua_setfield(L, -2, "B7200") ;
        lua_pushinteger(L, B14400) ;  lua_setfield(L, -2, "B14400") ;
        lua_pushinteger(L, B28800) ;  lua_setfield(L, -2, "B28800") ;
        lua_pushinteger(L, B57600) ;  lua_setfield(L, -2, "B57600") ;
        lua_pushinteger(L, B76800) ;  lua_setfield(L, -2, "B76800") ;
        lua_pushinteger(L, B115200) ; lua_setfield(L, -2, "B115200") ;
        lua_pushinteger(L, B230400) ; lua_setfield(L, -2, "B230400") ;
        lua_pushinteger(L, EXTA) ;    lua_setfield(L, -2, "EXTA") ;
        lua_pushinteger(L, EXTB) ;    lua_setfield(L, -2, "EXTB") ;
      lua_setfield(L, -2, "baud") ;
    return 1 ;
}

static int userdata_tostring(lua_State* L) {
    HSSerialPort *port = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ - %s (%p)", USERDATA_TAG, port.path,
        ((port.serialFileDescriptor == -1) ? "closed" : "open"), lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    HSSerialPort *port1 = get_objectFromUserdata(__bridge HSSerialPort, L, 1) ;
    HSSerialPort *port2 = get_objectFromUserdata(__bridge HSSerialPort, L, 2) ;
    lua_pushboolean(L, port1.selfRef = port2.selfRef) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSSerialPort *port = get_objectFromUserdata(__bridge_transfer HSSerialPort, L, 1) ;

    port.callbackFunction = [[LuaSkin shared] luaUnref:refTable ref:port.callbackFunction] ;
    port.lostPortFunction = [[LuaSkin shared] luaUnref:refTable ref:port.lostPortFunction] ;
    port.selfRef          = [[LuaSkin shared] luaUnref:refTable ref:port.selfRef] ;

    if (port.serialFileDescriptor != -1) {
        lua_pushcfunction(L, serial_close) ;
        lua_pushvalue(L, 1) ;
        lua_pcall(L, 1, 0, 0) ;
        lua_pop(L, 1) ; // userdata or error, either way we no longer care cause we're GCing
    }

    lua_pushnil(L) ;
    lua_setmetatable(L, -2);
    port = nil ;

    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     [hsimageReferences removeAllIndexes];
//     hsimageReferences = nil;
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"DTR",                  serial_DTR},
    {"baud",                 serial_baud},
    {"getAttributes",        serial_getAttributes},
    {"setAttributes",        serial_setAttributes},
    {"open",                 serial_open},
    {"close",                serial_close},
    {"isOpen",               serial_isOpen},
    {"bufferSize",           serial_bufferSize},
    {"flushBuffer",          serial_flushBuffer},
    {"readBuffer",           serial_readBuffer},
    {"write",                serial_write},
    {"enableCallback",       serial_enableCallback},
    {"incomingDataCallback", serial_incomingDataCallback},
    {"lostPortCallback",     serial_lostPortCallback},

    {"__tostring",           userdata_tostring},
    {"__eq",                 userdata_eq},
    {"__gc",                 userdata_gc},
    {NULL,                   NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"listPorts", serial_listPorts},
    {"port",      serial_port},
    {NULL,        NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs__asm_serial_internal(lua_State* __unused L) {
// Use this if your module doesn't have a module specific object that it returns.
//    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
// Use this some of your functions return or act on a specific object unique to this module
    refTable = [[LuaSkin shared] registerLibraryWithObject:USERDATA_TAG
                                                 functions:moduleLib
                                             metaFunctions:nil    // or module_metaLib
                                           objectFunctions:userdata_metaLib];

    serial_pushConstants(L) ; lua_setfield(L, -2, "attributeFlags") ;

    return 1;
}
