hs._asm.btle
============

Hammerspoon module for Core Bluetooth Objects.

This module provides an interface to the Core Bluetooth OS X Object classes for accessing BTLE devices.

Currently this module only supports Hammerspoon as a BTLE Manager, not as a BTLE Peripheral.

### Status

This code is still very experimental and expected to change (including the module name since BLE seems to be the preferred acronym); documentation is preliminary and incomplete.  The API is basically a mirror of the OS X BLE objects and is not really intuitive to use at present.  The `init.lua` file contains an early attempt at a wrapper to make access easier, but is still in preliminary stages and is expected to change a lot.

Unless you like experimenting and tweaking things yourself (and then hopefully sharing your experiences as issues/pull requests to this repository!), I do not recommend using this module at present.

This module has been tested against the following with mixed results as described here:

* Arduino 101 (Intel Curie) -- except for limitations of the CurieBLE library itself (seems to have a memory limit of around 5 or 6 characteristics, locks up if IMU accessed too quickly while updating BLE characteristics, etc.), seems to work well -- can read, write, and watch characteristics successfully.

* DFRobot Bluno -- can connect and discover services and characteristics.  Can write to DF01 serial characteristic but attempts to read or watch (receive notifications or indications) fail.  Not sure why, and their documentation only says that it works with iOS, Android, and their own devices -- Mac, Linux, and Windows are specifically noted as "not working" and no explanation or detail is given.

* Fitbit Blaze and Surge -- can discover services and advertised characteristics.  Can connect but connection will eventually be terminated.  Can read some characteristics, but not all; from Google searches about the Fitbit devices, I suspect authentication or encryption is involved and without more information this may not be something that can be fixed.

I hope to test this with some of Adafruit's BLE units over the next few months and will update this list as I do.

### Installation

A precompiled version of this module can be found in this directory with a name along the lines of `btle-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/btle-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to download `init.lua`, `internal.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make docs install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make docs install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
btle = require("hs._asm.btle")
~~~

### Contents


- - -

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.btle.characteristic
===========================

Provides support for objects which represent the characteristics of a remote BTLE peripheral’s service.

A characteristic contains a single value and any number of descriptors describing that value. The properties of a characteristic determine how the value of the characteristic can be used and how the descriptors can be accessed.


### Installation

A precompiled version of this module can be found in this directory with a name along the lines of `characteristic-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/characteristic-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to download `init.lua`, `internal.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make docs install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make docs install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
characteristic = require("hs._asm.btle.characteristic")
~~~

### Contents


- - -

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.btle.descriptor
=======================

Provides support for objects which represent the descriptors of a remote BTLE peripheral’s characteristic.

 Descriptors provide further information about a characteristic’s value. For example, they may describe the value in human-readable form and describe how the value should be formatted for presentation purposes. Characteristic descriptors also indicate whether a characteristic’s value is configured on a server (a peripheral) to indicate or notify a client (a central) when the value of the characteristic changes.


### Installation

A precompiled version of this module can be found in this directory with a name along the lines of `descriptor-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/descriptor-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to download `init.lua`, `internal.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make docs install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make docs install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
descriptor = require("hs._asm.btle.descriptor")
~~~

### Contents


- - -

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.btle.manager
====================

Provides support for managing the discovery of and connections to remote BTLE peripheral devices.

This submodule handles scanning for, discovering, and connecting to advertising BTLE peripherals.


### Installation

A precompiled version of this module can be found in this directory with a name along the lines of `manager-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/manager-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to download `init.lua`, `internal.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make docs install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make docs install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
manager = require("hs._asm.btle.manager")
~~~

### Contents


##### Module Constructors
* <a href="#create">manager.create() -> btleObject</a>

##### Module Methods
* <a href="#state">manager:state() -> string</a>

- - -

### Module Constructors

<a name="create"></a>
~~~lua
manager.create() -> btleObject
~~~
Creates a BTLE Central Manager object to manage the discovery of and connections to remote BTLE peripheral objects.

Parameters:
 * None

Returns:
 * a new btleObject

### Module Methods

<a name="state"></a>
~~~lua
manager:state() -> string
~~~
Returns a string indicating the current state of the BTLE manager object.

Parameters:
 * None

Returns:
 * a string matching one of the following:
   * "unknown"      - The current state of the central manager is unknown; an update is imminent.
   * "resetting"    - The connection with the system service was momentarily lost; an update is imminent.
   * "unsupported"  - The machine does not support Bluetooth low energy. BTLE requires a mac which supports Bluetooth 4.
   * "unauthorized" - Hammerspoon is not authorized to use Bluetooth low energy.
   * "poweredOff"   - Bluetooth is currently powered off.
   * "poweredOn"    - Bluetooth is currently powered on and available to use.

Notes:
 * If you have set a callback with [hs._asm.btle.manager:setCallback](#setCallback), a state change will generate a callback with the "didUpdateState" message.

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.btle.peripheral
=======================

Provides support for objects which represent remote BTLE peripheral devices that have been discovered or can be connected to.

 Peripherals are identified by universally unique identifiers (UUIDs) and may contain one or more services or provide useful information about their connected signal strength.


### Installation

A precompiled version of this module can be found in this directory with a name along the lines of `peripheral-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/peripheral-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to download `init.lua`, `internal.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make docs install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make docs install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
peripheral = require("hs._asm.btle.peripheral")
~~~

### Contents


##### Module Methods
* <a href="#maximumWriteSize">peripheral:maximumWriteSize([withResponse]) -> integer</a>

- - -

### Module Methods

<a name="maximumWriteSize"></a>
~~~lua
peripheral:maximumWriteSize([withResponse]) -> integer
~~~
Returns the maximum amount of data, in bytes, that can be sent to a characteristic in a single write. (Only valid in macOS 10.12 and later)

Parameters:
 * withResponse - an optional boolean, default false, indicating whether or not the write will be performed as expecting a response (true) or without expecting a response (false).

Returns:
 * an integer specifying the maximum byte size for the data to be written.

Notes:
 * this method is only supported for macOS 10.12 and later; for earlier macOS versions, this method will return -1.

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

hs._asm.btle.service
====================

Provides support for objects which represent a BTLE peripheral’s service — a collection of data and associated behaviors for accomplishing a function or feature of a device (or portions of that device).

Services are either primary or secondary and may contain a number of characteristics or included services (references to other services).


### Installation

A precompiled version of this module can be found in this directory with a name along the lines of `service-v0.x.tar.gz`. This can be installed by downloading the file and then expanding it as follows:

~~~sh
$ cd ~/.hammerspoon # or wherever your Hammerspoon init.lua file is located
$ tar -xzf ~/Downloads/service-v0.x.tar.gz # or wherever your downloads are located
~~~

If you wish to build this module yourself, and have XCode installed on your Mac, the best way (you are welcome to clone the entire repository if you like, but no promises on the current state of anything else) is to download `init.lua`, `internal.m`, and `Makefile` (at present, nothing else is required) into a directory of your choice and then do the following:

~~~sh
$ cd wherever-you-downloaded-the-files
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make docs install
~~~

If your Hammerspoon application is located in `/Applications`, you can leave out the `HS_APPLICATION` environment variable, and if your Hammerspoon files are located in their default location, you can leave out the `PREFIX` environment variable.  For most people it will be sufficient to just type `make docs install`.

As always, whichever method you chose, if you are updating from an earlier version it is recommended to fully quit and restart Hammerspoon after installing this module to ensure that the latest version of the module is loaded into memory.

### Usage
~~~lua
service = require("hs._asm.btle.service")
~~~

### Contents


- - -

- - -

### License

>     The MIT License (MIT)
>
> Copyright (c) 2017 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>


