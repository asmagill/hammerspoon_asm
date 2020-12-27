hs.canvas.turtle
================

An experimental module to add a turtle graphics module to `hs.canvas` in Hammerspoon.

This module creates a "canvas" that responds to turtle graphics like commands similar to those found in the Logo language, specifically [BERKELEY LOGO 6.1](https://people.eecs.berkeley.edu/~bh/docs/html/usermanual_6.html#GRAPHICS).

This may or may not ever make it into Hammerspoon itself; it was a diversion and an attempt to revisit some algorithms I worked on to explore Sierpiński curves in an old Hypercard stack I created in my teens.

- - -

*December 27, 2020 Update*

Now uses an off screen image for generating display. Shows slight general speedup, but is really noticeable when moving or resizing view for complex renders. (If `hs.canvas` ever gets a rewrite, should consider similar... setting `needsDisplay = YES` causes view (or dirty rect, if you specify one) to be cleared, requiring complete redraw; using an offscreen image allows adding elements in stages and then just one image draw in the view in `drawRect` method. Would require some thought about moving elements, though it may still be worth it because even before I started updating offscreen image incrementally, there was a noticeable (though smaller) speedup just from rendering offscreen outside of NSView's Graphics Context.)

Todo:
* finish documentation -- it's started, but not done yet
* rethink _background
  * does it need a rename?
  * no way to tell if _backup function is active -- subsequent calls to _backup are queued, but other turtle actions aren't
  * queue other actions as well? queries are ok, but anything that changes state isn't safe during run
  * no way to cancel running function or depth of queue
* decide on savepict/loadpict and logo conversion
* revisit fill/filled
