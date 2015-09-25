hs._asm.serial
==============

Basic serial port support for Hammerspoon

A module to facilitate serial port communications within Hammerspoon.  The motivation behind this module is to facilitate communications with Arduino devices communicating via a USB or Bluetooth Serial Port adapter but should work with any device which shows up under OS X as a serial port device.

This module is largely based on code found at http://playground.arduino.cc/Interfacing/Cocoa and https://github.com/armadsen/ORSSerialPort.

#### Motivation
The intent is provide a means for communicating between Hammerspoon and remote devices which primarily communicate over "serial like" links.  As mentioned above, my most immediate plans are to utilize Bluetooth and USB links with Arduino and Raspberry Pi devices, which appear as serial port devices to the host machine.  They are not fully functional RS232 ports or true modems/terminals, so the features I'll be mostly testing will be somewhat limited, at least for now.  I will try to add what support I can for the various means of handshaking or flow control as I find good examples or descriptions, but be warned, these features probably won't be as fully tested.

I am also trying out a couple of things which are new to me here -- running the receivers on a separate thread from the core Hammerspoon application, and serial IO.  Serial IO programming has advanced remarkably little over the years -- it still requires a lot of low level consideration and manipulation, and there are many more ways to do it wrong (which I probably have in some respects) than right.  I suppose it makes a kind of sense since the existing infrastructure works and supports a staggeringly huge number of devices both old and new, but it's frusting compared to how easy some newer technologies are!

For these and other reasons, I am not planning for this to be included in the Hammerspoon core at present.  Maybe if it gets a lot more testing and review by people more familiar with the concepts new to me.

That said, it is basically working for me now, and I intend to keep tweaking it as I can, so you are more than welcome to use it out as well and let me know what works, what doesn't, post suggestions or patches, etc.

#### Installation
This relies on some features not yet in the released version of Hammerspoon.  They should be included in Hammerspoon 0.9.41, at which time I will try and include a binary which can be downloaded and installed.  In the mean time, if you are running a current development build of Hammerspoon, you can opt for the manual method:

To install this manually, do the following (or if you want the latest and greatest):

~~~sh
$ git clone https://www.github.com/asmagill/hammerspoon_serial.git serial
$ cd serial
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If Hammerspoon.app is in your /Applications folder, you may leave `HS_APPLICATION=/Applications` out and if you are fine with the module being installed in your Hammerspoon configuration directory, you may leave `PREFIX=~/.hammerspoon` out as well.  For most people, it will probably be sufficient to just type `make install`.

I hope to include instructions later for incorporating the documentation into the Hammerspoon help system -- for now, use this document.

#### Usage

~~~lua
serial = require("hs._asm.serial")
~~~

#### Functions

~~~lua
serial.listPorts() -> array
~~~
* List the available serial ports for the system

 Parameters:
 * None

 Returns:
 * an array of available serial ports where each entry in the array is a table describing a serial port.  The table for each index will contain the following keys:
   * baseName   - the name of the serial port
   * calloutDevice - the path to the callout or "active" device for the serial port
   * dialinDevice  - the path to the dialin or "listening" device for the serial port
   * bsdType       - the type of serial port device
   * ttyDevice
   * ttySuffix

 Notes:
 * For most purposes, you should probably use the calloutDevice when performing serial communications.  By convention, the callout device is expected to block other listeners, which `hs._asm.serial:open` does, while the dialin device is intended to be left non-blocking until something actually occurs (this allows Unix like systems to allow you to use a serial port even if a getty process is listening for an incoming login, for example)

~~~lua
serial.port(path) -> serialPortObject
~~~
* Create a Hammerspoon reference to the selected serial port and sets the initial attributes to raw (no control character interpretation, 8 data bits, no parity, 1 stop bit) at 9600 baud.

 Parameters:
 * path - the bsd style path to the device node which represents the serial device you wish to use.

 Returns:
 * the serial port object

 Notes:
 * This constructor does not open the serial port for communications.  It momentarily opens the port in a non-blocking manner just long enough to aquire the serial ports current/default attributes, but then closes it and creates a reference to the serial port for use within Hammerspoon.  This behavior may change, as I suspect it may cause problems with some Arduino devices with auto-reset enabled.
 * In most cases, you will want to use the calloutDevice for the serial port (see `hs._asm.serial.listPorts`)

#### Port Methods

~~~lua
serial:open() -> serialPortObject
~~~
* Open the serial port for communication and apply the most recently provided settings and baud rate.

 Parameters:
 * None

 Returns:
 * the serial port object

 Notes:
 * If the serial port is already open, this method does nothing.

~~~lua
serial:close() -> serialPortObject
~~~
* Close and release the serial port

 Parameters:
 * None

 Returns:
 * None

 Notes:
 * If the port is already closed, this method does nothing.
 * This method is automatically called during garbage collection (most notably when your Hammerspoon configuration is reloaded or Hammerspoon is quit.)

~~~lua
serial:isOpen() -> boolean
~~~
* Returns a boolean value indicating whether or not the serial port is currently open

 Parameters:
 * None

 Returns:
 * True if the serial port is currently open or false if it is not.

~~~lua
serial:lostPortCallback(fn) -> serialPortObject
~~~
* Set or clear a callback function for a lost serial port connection

 Parameters:
 * fn - a function to callback when the serial port is unexpectedly lost.  If an explicit nil value is given, remove any existing callback function.  The function should expect two parameters, the serialPortObject and a string containing the error message (if any). The function should not return a value.

 Returns:
 * the serial port object

 Notes:
 * This function will not be called if the port exits normally; for example because of calling `hs._asm.serial:close` or due to garbage collection (Hammerspoon reloading or termination)

#### Basic Configuration Methods

~~~lua
serial:baud(rate) -> serialPortObject
~~~
* Change the current baud rate for the serial port

 Parameters:
 * rate - the new baud rate to set for the serial port

 Returns:
 * the serial port object

 Notes:
 * if the serial port is currently open, this method attempts to change the baud rate immediately; otherwise the change will be applied when the serial port is opened with `hs._asm.serial:open`.
 * need to find out if this resets the serial port on error like the example suggests but I can't find documented anywhere

~~~lua
serial:dataBits([bits]) -> serialPortObject | integer
~~~
* Get or set the serial port's character data size in bits.

 Parameters:
  * bits - an optional integer between 5 and 8 inclusive specifying the serial port's character data size in bits.

 Returns:
  * the serial port object if a bit size is specified, otherwise, the current setting

 Notes:
  * the data bit size does not include any parity (if any) or stop bits.

~~~lua
serial:stopBits([bits]) -> serialPortObject | integer
~~~
* Get or set the serial port's number of stop bits.

 Parameters:
  * bits - an optional integer between 1 and 2 inclusive specifying the serial port's number of stop bits.

 Returns:
  * the serial port object if a bit size is specified, otherwise, the current setting

~~~lua
serial:parity([type]) -> serialPortObject | integer
~~~
* Get or set the serial port's parity type.

 Parameters:
  * type - an optional string indicating the type of parity to use for error detection.  Recognized values are:
    * N or None - No parity: do not use parity for error detection
    * E or Even - Use even parity
    * O or Odd  - Use odd parity

 Returns:
  * the serial port object if a parity setting is specified, otherwise, the current setting

~~~lua
serial:softwareFlowControl([state]) -> serialPortObject | boolean
~~~
* Get or set whether or not software flow control is enable for the serial port

 Parameters:
 * an optional boolean parameter indicating if software flow control should be enabled for the serial port

 Returns:
 * if a value was provided, then the serial port object is returned; otherwise the current value is returned

 Notes:
 * This method turns software flow control fully on or fully off (i.e. bi-directional).  If you have manipulated the serial port attributes directly, it is possible that software flow control may be only partially enabled - using this method to check on flow control status (i.e. without providing a boolean parameter) will report this condition as false since at least one direction of communication doesn not have software flow control enabled.

~~~lua
serial:hardwareFlowControl([state]) -> serialPortObject | boolean
~~~
* Get or set whether or not hardware (RTSCTS) flow control is enable for the serial port

 Parameters:
 * an optional boolean parameter indicating if hardware flow control should be enabled for the serial port

 Returns:
 * if a value was provided, then the serial port object is returned; otherwise the current value is returned

 Notes:
 * This method only manages RTSCTS hardware flow control as this is the most commonly supported.  By adjusting the serial port attributes directly, DTRDSR hardware flow control and DCDOutputFlowControl may also be available if your device or driver support them.
 * This method turns hardware flow control fully on or fully off (i.e. bi-directional).  If you have manipulated the serial port attributes directly, it is possible that hardware flow control may be only partially enabled - using this method to check on flow control status (i.e. without providing a boolean parameter) will report this condition as false since at least one direction of communication doesn not have hardware flow control enabled.

#### Input and Output Methods

~~~lua
serial:flushBuffer() -> serialPortObject
~~~
* Dumps all data currently waiting in the incoming data buffer.

 Parameters:
 * None

 Returns:
 * the serial port object

~~~lua
serial:bufferSize() -> integer
~~~
* Returns the number of bytes currently in the serial port's receive buffer.

 Parameters:
 * None

 Returns:
 * the number of bytes currently in the receive buffer

~~~lua
serial:write(data) -> serialPortObject
~~~
* Write the specified data to the serial port.

 Parameters:
 * data - the data to send to the serial port.

 Returns:
 * the serial port object

 Notes:
* A number is treated as a string (i.e. 123 will be sent as "123").  To send an actual byte value of 123, use `string.char(123)` as the data.

~~~lua
serial:readBuffer([bytes]) -> string
~~~
* Reads the incoming serial buffer.  If bytes is specified, only read up to that many bytes; otherwise everything currently in the incoming buffer is read.

 Parameters:
 * bytes - an optional integer defining how many bytes to read.  If it is not present, the entire buffer is returned.

 Returns:
 * a string containing the specified contents of the read buffer

 Notes:
 * Data returned by this method is not guaranteed to be valid UTF8 or even complete.  You may need to perform additional reads or cache data for a later check to get full results.  See also `hs._asm.serial:bufferSize`.

 * This method will clear the current incoming buffer of the data it returns.  Cache the data if you need to keep a record.
 * This method will return nil if the buffer is currently empty.

 * This method can be called even if the serial port is closed (even if closed unexpectedly), though no new data will arrive unless the port is re-opened.

~~~lua
serial:incomingDataCallback(fn) -> serialPortObject
~~~
* Set or clear a callback function for incoming data

 Parameters:
 * fn - a function to callback when incoming data is detected.  If an explicit nil value is given, remove any existing callback function.  The function should expect two parameters, the serialPortObject and the incoming buffer contents as a lua string, and return one result: True if the callback should remain active for additional incoming data or false if it should not.

 Returns:
 * the serial port object

 Notes:
 * Data passed to the callback function is not guaranteed to be valid UTF8 or even complete.  You may need to perform additional reads with `hs._asm.serial:readBuffer` or cache data for an additional callback to get the full results.  See also `hs._asm.serial:bufferSize`.

 * This does not enable the callback function, it merely attaches it to this serial port.  See `hs._asm.serial:enableCallback` for more information.
 * If the callback function is currently enabled and this method is used to assign a new callback function, there is a small window where data may be buffered, but will not invoke a callback.  This buffered data will be included in the next callback invocation or can be manually retrieved with `hs._asm.serial:readBuffer`.
 * If the callback function is currently enabled and this method is used to remove the existing callback, the enable state will be set to false.

~~~lua
serial:enableCallback([flag]) -> serialPortObject | state
~~~
* Get or set whether or not a callback should occur when incoming data is detected from the serial port

 Parameters:
 * flag - an optional boolean flag indicating whether or not incoming data should trigger the registered callback function.

 Returns:
 * If a value is specified, then this method returns the serial port object.  Otherwise this method returns the current value.

#### Arduino Motivated Methods

~~~lua
serial:DTR(state) -> serialPortObject
~~~
* Set the DTR high or low

 Parameters:
 * state - a boolean indicating if the DTR should be set high (true) or low (false)

 Returns:
 * the serial port object

~~~lua
serial:unoReset([delay]) -> serialPortObject
~~~
* Triggers the reset process for an Arduino UNO (and similar) by setting the DTR high for `delay` microseconds and then pulling it low.

 Parameters:
 * delay - an optional parameter indicating how long in microseconds the DTR should be held high.  Defaults to 100000 microseconds (1/10 of a second).

 Returns:
 * the serial port object

 Notes:
 * the delay is performed via `hs.timer.usleep` and is blocking, so it should be kept as short as necessary.  My experience is that 100000 microseconds is sufficient, but the parameter is provided if circumstances require another value.

#### Advanced Configuration Methods

These methods allow direct manipualtion of the serial port's attributes for more advanced requirements.  It is my intention that the most common scenarios are covered with wrapper methods included above, but you can use these if you need more direct control.  If you find that there is a common scenario that should be provided for, please feel free to submit a suggestion.

~~~lua
serial:getAttributes() -> termiosTable
~~~
* Get the serial port's termios structure and return it in table form.  This is used internally and provided for advanced serial port manipulation.  It is not expected that you will require this method for most serial port usage requirements.

 Parameters:
 * None

 Returns:
 * a table containing the following keys:
   * iflag  - bit flag representing the input modes for the termios structure
   * oflag  - bit flag representing the output modes for the termios structure
   * cflag  - bit flag representing the control modes for the termios structure
   * lflag  - bit flag representing the local modes for the termios structure
   * ispeed - input speed
   * ospeed - output speed
   * cc     - array of control characters which have special meaning under certain conditions

 Notes:
 * If the serial port is currently open, this method will query the port for its current settings; otherwise, the settings which are to be applied when the port is opened with `hs._asm.serial:open` are provided.
 * The baud rate for the serial port is set via ioctl with the IOSSIOSPEED request to allow a wider range of values than termios directly supports.  `ispeed` and `ospeed` may not be an accurate measure of the actual baud rate currently in effect.

~~~lua
serial:setAttributes(termiosTable, action) -> serialPortObject
~~~
* Set the serial port's termios structure To the values specified in the provided table.  This is used internally and provided for advanced serial port manipulation.  It is not expected that you will require this method for most serial port usage requirements.

 Parameters:
 * termiosTable - a table containing the following keys:
   * iflag  - bit flag representing the input modes for the termios structure
   * oflag  - bit flag representing the output modes for the termios structure
   * cflag  - bit flag representing the control modes for the termios structure
   * lflag  - bit flag representing the local modes for the termios structure
   * ispeed - input speed
   * ospeed - output speed
   * cc     - array of control characters which have special meaning under certain conditions
 * action - an action flag from `hs._asm.serial.attributeFlags.action` specifying when to apply the new termios values

 Returns:
 * the serial port object

 Notes:
 * If the serial port is currently open, this method will try to apply the settings immediately; otherwise the settings will be saved until the serial port is opened with `hs._asm.serial:open`.
 * Not all possible modes in iflag, oflag, cflag, and lflag are valid for all serial devices or drivers.
 * The ispeed and ospeed values should not be adjusted -- use the `hs._asm.serial:baud` method to set the serial port baud rate as it allows for a wider range of speeds than termios directly supports.
 * It is expected that this method will be called after making changes to the results provided by `hs._asm.serial:getAttributes`.

~~~lua
serial:expandIflag() -> string
~~~
* Returns which input mode flags are set for the serial port.

 Parameters:
   * None

 Returns:
   * a string with the names of the input mode flags which are set for the serial port

 Notes:
   * The names are consistent with those found in `hs._asm.serial.attributeFlags`

~~~lua
serial:expandOflag() -> string
~~~
* Returns which output mode flags are set for the serial port.

 Parameters:
   * None

 Returns:
   * a string with the names of the output mode flags which are set for the serial port

 Notes:
   * The names are consistent with those found in `hs._asm.serial.attributeFlags`

~~~lua
serial:expandCflag() -> string
~~~
* Returns which control mode flags are set for the serial port.

 Parameters:
   * None

 Returns:
   * a string with the names of the control mode flags which are set for the serial port

 Notes:
   * The names are consistent with those found in `hs._asm.serial.attributeFlags`

~~~lua
serial:expandLflag() -> string
~~~
* Returns which local mode flags are set for the serial port.

 Parameters:
   * None

 Returns:
   * a string with the names of the local mode flags which are set for the serial port

 Notes:
   * The names are consistent with those found in `hs._asm.serial.attributeFlags`

#### Constants

~~~lua
serial.attributeFlags
~~~
* A table containing TERMIOS flags for advanced serial control.  This is provided for internal use and for reference if you need to manipulate the serial attributes directly with `hs._asm.serial:getAttributes` and `hs._asm.serial:setAttributes`.  This should not be required for most serial port requirements.

 Contents:
 * iflag  - constants which apply to termios input modes
 * oflag  - constants which apply to termios output modes
 * cflag  - constants which apply to termios control modes
 * lflag  - constants which apply to termios local modes
 * cc     - index labels for the `cc` array in the termios control character structure
 * action - flags indicating when changes to the termios structure provided to `hs._asm.serial:setAttributes` should be applied.
 * baud   - predefined baud rate labels

 Notes:
 * Not all defined modes in iflag, oflag, cflag, and lflag are valid for all serial devices or drivers.
 * Lua tables start at index 1 rather than 0; the index labels in cc reflect this (i.e. they are each 1 greater than the value defined in /usr/include/sys/termios.h).
 * The list of baud rates is provided as a reference.  The baud rate is actually set via ioctl with the IOSSIOSPEED request to allow a wider range of values than termios directly supports.  Note that not all baud rates are valid for all serial devices or drivers.

#### License

> The MIT License (MIT)
>
> Copyright (c) 2015 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy this software and associated documentation files (the "Software"), to deal the Software without restriction, including without limitation the rights use, copy, modify, merge, publish, distribute, sublicense, and/or sell of the Software, and to permit persons to whom the Software is to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR , INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER , WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN SOFTWARE.
