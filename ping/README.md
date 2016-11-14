hs.network.ping
===============

This module provides a basic ping function which can test host availability. Ping is a network diagnostic tool commonly found in most operating systems which can be used to test if a route to a specified host exists and if that host is responding to network traffic.

### Installation

A precompiled version of this module can be found in this directory with a name along the lines of `ping-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/ping-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything) is to download `init.lua`, `internal.m`, `SimplePing.h`, `SimplePing.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

- - -

### Usage
~~~lua
ping = require("hs.network.ping")
~~~

### Contents


##### Module Constructors
* <a href="#ping">ping.ping(server, [count], [interval], [timeout], [class], [fn]) -> pingObject</a>

##### Module Methods
* <a href="#address">ping:address() -> string</a>
* <a href="#cancel">ping:cancel() -> none</a>
* <a href="#count">ping:count([count]) -> integer | pingObject | nil</a>
* <a href="#isPaused">ping:isPaused() -> boolean</a>
* <a href="#isRunning">ping:isRunning() -> boolean</a>
* <a href="#packets">ping:packets([sequenceNumber]) -> table</a>
* <a href="#pause">ping:pause() -> pingObject | nil</a>
* <a href="#resume">ping:resume() -> pingObject | nil</a>
* <a href="#sent">ping:sent() -> integer</a>
* <a href="#server">ping:server() -> string</a>
* <a href="#summary">ping:summary() -> string</a>

- - -

### Module Constructors

<a name="ping"></a>
~~~lua
ping.ping(server, [count], [interval], [timeout], [class], [fn]) -> pingObject
~~~
Test server availability by pinging it with ICMP Echo Requests.

Parameters:
 * `server`   - a string containing the hostname or ip address of the server to test. Both IPv4 and IPv6 addresses are supported.
 * `count`    - an optional integer, default 5, specifying the number of ICMP Echo Requests to send to the server.
 * `interval` - an optional number, default 1.0, in seconds specifying the delay between the sending of each echo request. To set this parameter, you must supply `count` as well.
 * `timeout`  - an optional number, default 2.0, in seconds specifying how long before an echo reply is considered to have timed-out. To set this parameter, you must supply `count` and `interval` as well.
 * `class`    - an optional string, default "any", specifying whether IPv4 or IPv6 should be used to send the ICMP packets. The string must be one of the following:
   * `any`  - uses the IP version which corresponds to the first address the `server` resolves to
   * `IPv4` - use IPv4; if `server` cannot resolve to an IPv4 address, or if IPv4 traffic is not supported on the network, the ping will fail with an error.
   * `IPv6` - use IPv6; if `server` cannot resolve to an IPv6 address, or if IPv6 traffic is not supported on the network, the ping will fail with an error.
 * `fn`       - the callback function which receives update messages for the ping process. See the Notes for details regarding the callback function.

Returns:
 * a pingObject

Notes:
 * For convenience, you can call this constructor as `hs.network.ping(server, ...)`
 * the full ping process will take at most `count` * `interval` + `timeout` seconds from `didStart` to `didFinish`.

 * the default callback function, if `fn` is not specified, prints the results of each echo reply as they are received to the Hammerspoon console and a summary once completed. The output should be familiar to anyone who has used `ping` from the command line.

 * If you provide your own callback function, it should expect between 2 and 4 arguments and return none. The possible arguments which are sent will be one of the following:

   * "didStart" - indicates that address resolution has completed and the ping will begin sending ICMP Echo Requests.
     * `object`  - the ping object the callback is for
     * `message` - the message to the callback, in this case "didStart"

   * "didFail" - indicates that the ping process has failed, most likely due to a failure in address resolution or because the network connection has dropped.
     * `object`  - the ping object the callback is for
     * `message` - the message to the callback, in this case "didFail"
     * `error`   - a string containing the error message that has occurred

   * "sendPacketFailed" - indicates that a specific ICMP Echo Request has failed for some reason.
     * `object`         - the ping object the callback is for
     * `message`        - the message to the callback, in this case "sendPacketFailed"
     * `sequenceNumber` - the sequence number of the ICMP packet which has failed to send
     * `error`          - a string containing the error message that has occurred

   * "receivedPacket" - indicates that an ICMP Echo Request has received the expected ICMP Echo Reply
     * `object`         - the ping object the callback is for
     * `message`        - the message to the callback, in this case "receivedPacket"
     * `sequenceNumber` - the sequence number of the ICMP packet received

   * "didFinish" - indicates that the ping has finished sending all ICMP Echo Requests or has been cancelled
     * `object`  - the ping object the callback is for
     * `message` - the message to the callback, in this case "didFinish"

### Module Methods

<a name="address"></a>
~~~lua
ping:address() -> string
~~~
Returns a string containing the resolved IPv4 or IPv6 address this pingObject is sending echo requests to.

Parameters:
 * None

Returns:
 * A string containing the IPv4 or IPv6 address this pingObject is sending echo requests to or "<unresolved address>" if the address cannot be resolved.

- - -

<a name="cancel"></a>
~~~lua
ping:cancel() -> none
~~~
Cancels an in progress ping process, terminating it immediately

Paramters:
 * None

Returns:
 * None

Notes:
 * the `didFinish` message will be sent to the callback function as its final message.

- - -

<a name="count"></a>
~~~lua
ping:count([count]) -> integer | pingObject | nil
~~~
Get or set the number of ICMP Echo Requests that will be sent by the ping process

Parameters:
 * `count` - an optional integer specifying the total number of echo requests that the ping process should send. If specified, this number must be greater than the number of requests already sent.

Returns:
 * if no argument is specified, returns the current number of echo requests the ping process will send; if an argument is specified and the ping process has not completed, returns the pingObject; if the ping process has already completed, then this method returns nil.

- - -

<a name="isPaused"></a>
~~~lua
ping:isPaused() -> boolean
~~~
Returns whether or not the ping process is currently paused.

Parameters:
 * None

Returns:
 * A boolean indicating if the ping process is paused (true) or not (false)

- - -

<a name="isRunning"></a>
~~~lua
ping:isRunning() -> boolean
~~~
Returns whether or not the ping process is currently active.

Parameters:
 * None

Returns:
 * A boolean indicating if the ping process is active (true) or not (false)

Notes:
 * This method will return false only if the ping process has finished sending all echo requests or if it has been cancelled with [hs.network.ping:cancel](#cancel).  To determine if the process is currently sending out echo requests, see [hs.network.ping:isPaused](#isPaused).

- - -

<a name="packets"></a>
~~~lua
ping:packets([sequenceNumber]) -> table
~~~
Returns a table containing information about the ICMP Echo packets sent by this pingObject.

Parameters:
 * `sequenceNumber` - an optional integer specifying the sequence number of the ICMP Echo packet to return information about.

Returns:
 * If `sequenceNumber` is specified, returns a table with key-value pairs containing information about the specific ICMP Echo packet with that sequence number, or an empty table if no packet with that sequence number has been sent yet. If no sequence number is specified, returns an array table of all ICMP Echo packets this object has sent.

Notes:
 * Sequence numbers start at 0 while Lua array tables are indexed starting at 1. If you do not specify a `sequenceNumber` to this method, index 1 of the array table returned will contain a table describing the ICMP Echo packet with sequence number 0, index 2 will describe the ICMP Echo packet with sequence number 1, etc.

 * An ICMP Echo packet table will have the following key-value pairs:
   * `sent`           - a number specifying the time at which the echo request for this packet was sent. This number is the number of seconds since January 1, 1970 at midnight, GMT, and is a floating point number, so you should use `math.floor` on this number before using it as an argument to Lua's `os.date` function.
   * `recv`           - a number specifying the time at which the echo reply for this packet was received. This number is the number of seconds since January 1, 1970 at midnight, GMT, and is a floating point number, so you should use `math.floor` on this number before using it as an argument to Lua's `os.date` function.
   * `icmp`           - a table provided by the `hs.network.ping.echoRequest` object which contains the details about the specific ICMP packet this entry corresponds to. It will contain the following keys:
     * `checksum`       - The ICMP packet checksum used to ensure data integrity.
     * `code`           - ICMP Control Message Code. Should always be 0.
     * `identifier`     - The ICMP Identifier generated internally for matching request and reply packets.
     * `payload`        - A string containing the ICMP payload for this packet. This has been constructed to cause the ICMP packet to be exactly 64 bytes to match the convention for ICMP Echo Requests.
     * `sequenceNumber` - The ICMP Sequence Number for this packet.
     * `type`           - ICMP Control Message Type. For ICMPv4, this will be 0 if a reply has been received or 8 no reply has been received yet. For ICMPv6, this will be 129 if a reply has been received or 128 if no reply has been received yet.
     * `_raw`           - A string containing the ICMP packet as raw data.

- - -

<a name="pause"></a>
~~~lua
ping:pause() -> pingObject | nil
~~~
Pause an in progress ping process.

Parameters:
 * None

Returns:
 * if the ping process is currently active, returns the pingObject; if the process has already completed, returns nil.

- - -

<a name="resume"></a>
~~~lua
ping:resume() -> pingObject | nil
~~~
Resume an in progress ping process, if it has been paused.

Parameters:
 * None

Returns:
 * if the ping process is currently active, returns the pingObject; if the process has already completed, returns nil.

- - -

<a name="sent"></a>
~~~lua
ping:sent() -> integer
~~~
Returns the number of ICMP Echo Requests which have been sent.

Parameters:
 * None

Returns:
 * The number of echo requests which have been sent so far.

- - -

<a name="server"></a>
~~~lua
ping:server() -> string
~~~
Returns the hostname or ip address string given to the [hs.network.ping.ping](#ping) constructor.

Parameters:
 * None

Returns:
 * A string matching the hostname or ip address given to the [hs.network.ping.ping](#ping) constructor for this object.

- - -

<a name="summary"></a>
~~~lua
ping:summary() -> string
~~~
Returns a string containing summary information about the ping process.

Parameters:
 * None

Returns:
 * a summary string for the current state of the ping process

Notes:
 * The summary string will look similar to the following:
~~~
--- hostname ping statistics ---
5 packets transmitted, 5 packets received, 0.0 packet loss
round-trip min/avg/max = 2.282/4.133/4.926 ms
~~~
 * The numer of packets received will match the number that has currently been sent, not necessarily the value returned by [hs.network.ping:count](#count).

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs.network.ping.echoRequest
===========================

Provides lower-level access to the ICMP Echo Request infrastructure used by the hs.network.ping module. In general, you should not need to use this module directly unless you have specific requirements not met by the hs.network.ping module and the `hs.network.ping` object methods.

This module is based heavily on Apple's SimplePing sample project which can be found at https://developer.apple.com/library/content/samplecode/SimplePing/Introduction/Intro.html.

When a callback function argument is specified as an ICMP table, the Lua table returned will contain the following key-value pairs:
 * `checksum`       - The ICMP packet checksum used to ensure data integrity.
 * `code`           - ICMP Control Message Code. This should always be 0 unless the callback has received a "receivedUnexpectedPacket" message.
 * `identifier`     - The ICMP packet identifier.  This should match the results of [hs.network.ping.echoRequest:identifier](#identifier) unless the callback has received a "receivedUnexpectedPacket" message.
 * `payload`        - A string containing the ICMP payload for this packet. The default payload has been constructed to cause the ICMP packet to be exactly 64 bytes to match the convention for ICMP Echo Requests.
 * `sequenceNumber` - The ICMP Sequence Number for this packet.
 * `type`           - ICMP Control Message Type. Unless the callback has received a "receivedUnexpectedPacket" message, this will be 0 (ICMPv4) or 129 (ICMPv6) for packets we receive and 8 (ICMPv4) or 128 (ICMPv6) for packets we send.
     * `_raw`           - A string containing the ICMP packet as raw data.

In cases where the callback receives a "receivedUnexpectedPacket" message because the packet is corrupted or truncated, this table may only contain the `_raw` field.

### Usage
~~~lua
echoRequest = require("hs.network.ping.echoRequest")
~~~

### Contents


##### Module Constructors
* <a href="#echoRequest">echoRequest.echoRequest(server) -> echoRequestObject</a>

##### Module Methods
* <a href="#acceptAddressFamily">echoRequest:acceptAddressFamily([family]) -> echoRequestObject | current value</a>
* <a href="#hostAddress">echoRequest:hostAddress() -> string | false | nil</a>
* <a href="#hostAddressFamily">echoRequest:hostAddressFamily() -> string</a>
* <a href="#hostName">echoRequest:hostName() -> string</a>
* <a href="#identifier">echoRequest:identifier() -> integer</a>
* <a href="#isRunning">echoRequest:isRunning() -> boolean</a>
* <a href="#nextSequenceNumber">echoRequest:nextSequenceNumber() -> integer</a>
* <a href="#sendPayload">echoRequest:sendPayload([payload]) -> echoRequestObject | false | nil</a>
* <a href="#setCallback">echoRequest:setCallback(fn | nil) -> echoRequestObject</a>
* <a href="#start">echoRequest:start() -> echoRequestObject</a>
* <a href="#stop">echoRequest:stop() -> echoRequestObject</a>

- - -

### Module Constructors

<a name="echoRequest"></a>
~~~lua
echoRequest.echoRequest(server) -> echoRequestObject
~~~
Creates a new ICMP Echo Request object for the server specified.

Parameters:
 * `server` - a string containing the hostname or ip address of the server to communicate with. Both IPv4 and IPv6 style addresses are supported.

Returns:
 * an echoRequest object

Notes:
 * This constructor returns a lower-level object than the `hs.network.ping.ping` constructor and is more difficult to use. It is recommended that you use this constructor only if `hs.network.ping.ping` is not sufficient for your needs.

 * For convenience, you can call this constructor as `hs.network.ping.echoRequest(server)`

### Module Methods

<a name="acceptAddressFamily"></a>
~~~lua
echoRequest:acceptAddressFamily([family]) -> echoRequestObject | current value
~~~
Get or set the address family the echoRequestObject should communicate with.

Parameters:
 * `family` - an optional string, default "any", which specifies the address family used by this object.  Valid values are "any", "IPv4", and "IPv6".

Returns:
 * if an argument is provided, returns the echoRequestObject, otherwise returns the current value.

Notes:
 * Setting this value to "IPv6" or "IPv4" will cause the echoRequestObject to attempt to resolve the server's name into an IPv6 address or an IPv4 address and communicate via ICMPv6 or ICMP(v4) when the [hs.network.ping.echoRequest:start](#start) method is invoked.  A callback with the message "didFail" will occur if the server could not be resolved to an address in the specified family.
 * If this value is set to "any", then the first address which is discovered for the server's name will determine whether ICMPv6 or ICMP(v4) is used, based upon the family of the address.

 * Setting a value with this method will have no immediate effect on an echoRequestObject which has already been started with [hs.network.ping.echoRequest:start](#start). You must first stop and then restart the object for any change to have an effect.

- - -

<a name="hostAddress"></a>
~~~lua
echoRequest:hostAddress() -> string | false | nil
~~~
Returns a string representation for the server's IP address, or a boolean if address resolution has not completed yet.

Parameters:
 * None

Returns:
 * If the object has been started and address resolution has completed, then the string representation of the server's IP address is returned.
 * If the object has been started, but resolution is still pending, returns a boolean value of false.
 * If the object has not been started, returns nil.

- - -

<a name="hostAddressFamily"></a>
~~~lua
echoRequest:hostAddressFamily() -> string
~~~
Returns the host address family currently in use by this echoRequestObject.

Parameters:
 * None

Returns:
 * a string indicating the IP address family currently used by this echoRequestObject.  It will be one of the following values:
   * "IPv4"       - indicates that ICMP(v4) packets are being sent and listened for.
   * "IPv6"       - indicates that ICMPv6 packets are being sent and listened for.
   * "unresolved" - indicates that the echoRequestObject has not been started or that address resolution is still in progress.

- - -

<a name="hostName"></a>
~~~lua
echoRequest:hostName() -> string
~~~
Returns the name of the target host as provided to the echoRequestObject's constructor

Parameters:
 * None

Returns:
 * a string containing the hostname as specified when the object was created.

- - -

<a name="identifier"></a>
~~~lua
echoRequest:identifier() -> integer
~~~
Returns the identifier number for the echoRequestObject.

Parameters:
 * None

Returns:
 * an integer specifying the identifier which is embedded in the ICMP packets this object sends.

Notes:
 * ICMP Echo Replies which include this identifier will generate a "receivedPacket" message to the object callback, while replies which include a different identifier will generate a "receivedUnexpectedPacket" message.

- - -

<a name="isRunning"></a>
~~~lua
echoRequest:isRunning() -> boolean
~~~
Returns a boolean indicating whether or not this echoRequestObject is currently listening for ICMP Echo Replies.

Parameters:
 * None

Returns:
 * true if the object is currently listening for ICMP Echo Replies, or false if it is not.

- - -

<a name="nextSequenceNumber"></a>
~~~lua
echoRequest:nextSequenceNumber() -> integer
~~~
The sequence number that will be used for the next ICMP packet sent by this object.

Parameters:
 * None

Returns:
 * an integer specifying the sequence number that will be embedded in the next ICMP message sent by this object when [hs.network.ping.echoRequest:sendPayload](#sendPayload) is invoked.

Notes:
 * ICMP Echo Replies which are expected by this object should always be less than this number, with the caveat that this number is a 16-bit integer which will wrap around to 0 after sending a packet with the sequence number 65535.
 * Because of this wrap around effect, this module will generate a "receivedPacket" message to the object callback whenever the received packet has a sequence number that is within the last 120 sequence numbers we've sent and a "receivedUnexpectedPacket" otherwise.
   * Per the comments in Apple's SimplePing.m file: Why 120?  Well, if we send one ping per second, 120 is 2 minutes, which is the standard "max time a packet can bounce around the Internet" value.

- - -

<a name="sendPayload"></a>
~~~lua
echoRequest:sendPayload([payload]) -> echoRequestObject | false | nil
~~~
Sends a single ICMP Echo Request packet.

Parameters:
 * `payload` - an optional string containing the data to include in the ICMP Echo Request as the packet payload.

Returns:
 * If the object has been started and address resolution has completed, then the ICMP Echo Packet is sent and this method returns the echoRequestObject
 * If the object has been started, but resolution is still pending, the packet is not sent and this method returns a boolean value of false.
 * If the object has not been started, the packet is not sent and this method returns nil.

Notes:
 * By convention, unless you are trying to test for specific network fragmentation or congestion problems, ICMP Echo Requests are generally 64 bytes in length (this includes the 8 byte header, giving 56 bytes of payload data).  If you do not specify a payload, a default payload which will result in a packet size of 64 bytes is constructed.

- - -

<a name="setCallback"></a>
~~~lua
echoRequest:setCallback(fn | nil) -> echoRequestObject
~~~
Set or remove the object callback function

Parameters:
 * `fn` - a function to set as the callback function for this object, or nil if you wish to remove any existing callback function.

Returns:
 * the echoRequestObject

Notes:
 * The callback function should expect between 3 and 5 arguments and return none. The possible arguments which are sent will be one of the following:

   * "didStart" - indicates that the object has resolved the address of the server and is ready to begin sending and receiving ICMP Echo packets.
     * `object`  - the echoRequestObject itself
     * `message` - the message to the callback, in this case "didStart"
     * `address` - a string representation of the IPv4 or IPv6 address of the server specified to the constructor.

   * "didFail" - indicates that the object has failed, either because the address could not be resolved or a network error has occurred.
     * `object`  - the echoRequestObject itself
     * `message` - the message to the callback, in this case "didFail"
     * `error`   - a string describing the error that occurred.
   * Notes:
     * When this message is received, you do not need to call [hs.network.ping.echoRequest:stop](#stop) -- the object will already have been stopped.

   * "sendPacket" - indicates that the object has sent an ICMP Echo Request packet.
     * `object`  - the echoRequestObject itself
     * `message` - the message to the callback, in this case "sendPacket"
     * `icmp`    - an ICMP packet table representing the packet which has been sent as described in the header of this module's documentation.
     * `seq`     - the sequence number for this packet. Sequence numbers always start at 0 and increase by 1 every time the [hs.network.ping.echoRequest:sendPayload](#sendPayload) method is called.

   * "sendPacketFailed" - indicates that the object failed to send the ICMP Echo Request packet.
     * `object`  - the echoRequestObject itself
     * `message` - the message to the callback, in this case "sendPacketFailed"
     * `icmp`    - an ICMP packet table representing the packet which was to be sent.
     * `seq`     - the sequence number for this packet.
     * `error`   - a string describing the error that occurred.
   * Notes:
     * Unlike "didFail", the echoRequestObject is not stopped when this message occurs; you can try to send another payload if you wish without restarting the object first.

   * "receivedPacket" - indicates that an expected ICMP Echo Reply packet has been received by the object.
     * `object`  - the echoRequestObject itself
     * `message` - the message to the callback, in this case "receivedPacket"
     * `icmp`    - an ICMP packet table representing the packet received.
     * `seq`     - the sequence number for this packet.

   * "receivedUnexpectedPacket" - indicates that an unexpected ICMP packet was received
     * `object`  - the echoRequestObject itself
     * `message` - the message to the callback, in this case "receivedUnexpectedPacket"
     * `icmp`    - an ICMP packet table representing the packet received.
   * Notes:
     * This message can occur for a variety of reasons, the most common being:
       * the ICMP packet is corrupt or truncated and cannot be parsed
       * the ICMP Identifier does not match ours and the sequence number is not one we have sent
       * the ICMP type does not match an ICMP Echo Reply
       * When using IPv6, this is especially common because IPv6 uses ICMP for network management functions like Router Advertisement and Neighbor Discovery.
     * In general, it is reasonably safe to ignore these messages, unless you are having problems receiving anything else, in which case it could indicate problems on your network that need addressing.

- - -

<a name="start"></a>
~~~lua
echoRequest:start() -> echoRequestObject
~~~
Start the echoRequestObject by resolving the server's address and start listening for ICMP Echo Reply packets.

Parameters:
 * None

Returns:
 * the echoRequestObject

- - -

<a name="stop"></a>
~~~lua
echoRequest:stop() -> echoRequestObject
~~~
Start listening for ICMP Echo Reply packets with this object.

Parameters:
 * None

Returns:
 * the echoRequestObject

- - -

### Licenses

>     The MIT License (MIT)
>
> Copyright (c) 2016 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>

SimplePing.h and SimplePing.m are part of Apple's sample project SimplePing which can be found at https://developer.apple.com/library/content/samplecode/SimplePing/Introduction/Intro.html. It is licensed by Apple Inc. as follows:

> Sample code project: SimplePing
> Version: 5.0
>
> IMPORTANT:  This Apple software is supplied to you by Apple
> Inc. ("Apple") in consideration of your agreement to the following
> terms, and your use, installation, modification or redistribution of
> this Apple software constitutes acceptance of these terms.  If you do
> not agree with these terms, please do not use, install, modify or
> redistribute this Apple software.
>
> In consideration of your agreement to abide by the following terms, and
> subject to these terms, Apple grants you a personal, non-exclusive
> license, under Apple's copyrights in this original Apple software (the
> "Apple Software"), to use, reproduce, modify and redistribute the Apple
> Software, with or without modifications, in source and/or binary forms;
> provided that if you redistribute the Apple Software in its entirety and
> without modifications, you must retain this notice and the following
> text and disclaimers in all such redistributions of the Apple Software.
> Neither the name, trademarks, service marks or logos of Apple Inc. may
> be used to endorse or promote products derived from the Apple Software
> without specific prior written permission from Apple.  Except as
> expressly stated in this notice, no other rights or licenses, express or
> implied, are granted by Apple herein, including but not limited to any
> patent rights that may be infringed by your derivative works or by other
> works in which the Apple Software may be incorporated.
>
> The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
> MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
> THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
> FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
> OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
>
> IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
> OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
> SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
> INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
> MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
> AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
> STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
> POSSIBILITY OF SUCH DAMAGE.
>
> Copyright (C) 2016 Apple Inc. All Rights Reserved.
>
