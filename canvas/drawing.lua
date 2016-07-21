-- DO NOT USE YET

--- === hs._asm.canvas.drawing ===
---
--- An experimental wrapper, still in very early stages, to replace `hs.drawing` with `hs._asm.canvas`.
---
--- This submodule is not loaded as part of the `hs._asm.canvas` module and has to be loaded explicitly. You can test the use of this wrapper with your Hammerspoon configuration by adding the following to the ***top*** of `~/.hammerspoon/init.lua` -- this needs to be executed before any other code has a chance to load `hs.drawing` first.
---
--- ~~~lua
--- local R, M = pcall(require,"hs._asm.canvas.drawing")
--- if R then
---    print()
---    print("**** Replacing internal hs.drawing with experimental wrapper.")
---    print()
---    hs.drawing = M
---    package.loaded["hs.drawing"] = M   -- make sure require("hs.drawing") returns us
---    package.loaded["hs/drawing"] = M   -- make sure require("hs/drawing") returns us
--- else
---    print()
---    print("**** Error with experimental hs.drawing wrapper: "..tostring(M))
---    print()
--- end
--- ~~~
---
--- The intention is for this wrapper to provide all of the same functionality that `hs.drawing` does without requiring any additional changes to your currently existing code.
---
--- To return to using the officially included version of `hs.drawing`, remove or comment out the code that was added to your `init.lua` file.

local USERDATA_TAG = "hs._asm.canvas.drawing"
local canvas       = require(USERDATA_TAG:match("^(.*)%.drawing$"))
local canvasMT     = hs.getObjectMetatable(USERDATA_TAG:match("^(.*)%.drawing$"))

local styledtext   = require("hs.styledtext")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- functions/tables
--   _image = <function 1>,
--   appImage = <function 2>,
--   arc = <function 3>,
--   circle = <function 4>,
--   ellipticalArc = <function 7>,
--   image = <function 12>,
--   line = <function 13>,
--   rectangle = <function 14>,
--   text = <function 15>,

module.color                = require("hs.drawing.color")
module.defaultTextStyle     = canvas.defaultTextStyle
module.disableScreenUpdates = canvas.disableScreenUpdates
module.enableScreenUpdates  = canvas.enableScreenUpdates
module.fontNames            = styledtext.fontNames
module.fontNamesWithTraits  = styledtext.fontNamesWithTraits
module.fontTraits           = styledtext.fontTraits
--   getTextDrawingSize = <function 11>,
module.windowBehaviors      = canvas.windowBehaviors
module.windowLevels         = canvas.windowLevels



-- methods
--   alpha = <function 3>,
--   behavior = <function 4>,
--   behaviorAsLabels = <function 5>,
--   bringToFront = <function 6>,
--   clickCallbackActivating = <function 7>,
--   clippingRectangle = <function 8>,
--   delete = <function 1>,
--   frame = <function 9>,
--   getStyledText = <function 10>,
--   hide = <function 11>,
--   imageAlignment = <function 12>,
--   imageAnimates = <function 13>,
--   imageFrame = <function 14>,
--   imageScaling = <function 15>,
--   orderAbove = <function 16>,
--   orderBelow = <function 17>,
--   rotateImage = <function 18>,
--   sendToBack = <function 19>,
--   setAlpha = <function 20>,
--   setArcAngles = <function 21>,
--   setBehavior = <function 22>,
--   setBehaviorByLabels = <function 23>,
--   setClickCallback = <function 24>,
--   setFill = <function 25>,
--   setFillColor = <function 26>,
--   setFillGradient = <function 27>,
--   setFrame = <function 28>,
--   setImage = <function 29>,
--   setImageFromASCII = <function 30>,
--   setImageFromPath = <function 31>,
--   setImagePath = <function 31>,
--   setLevel = <function 32>,
--   setRoundedRectRadii = <function 33>,
--   setSize = <function 34>,
--   setStroke = <function 35>,
--   setStrokeColor = <function 36>,
--   setStrokeWidth = <function 37>,
--   setStyledText = <function 38>,
--   setText = <function 39>,
--   setTextColor = <function 40>,
--   setTextFont = <function 41>,
--   setTextSize = <function 42>,
--   setTextStyle = <function 43>,
--   setTopLeft = <function 44>,
--   show = <function 45>,
--   wantsLayer = <function 46>

-- Return Module Object --------------------------------------------------

return module
