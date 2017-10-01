hs._asm.guitk.manager
=====================

This submodule provides a content manager for an `hs._asm.guitk` window that allows the placement and managerment of multiple gui elements.

A manager can also act as an element to another manager -- this allows for the grouping of elements as single units for display or other purposes. See `hs._asm.guitk.element.button` for a further discussion of this when using the radio button style.

Elements can be added and managed through the methods of this module.  There are also metamethods which allow you to manipulate the elements in an array like fashion. Each element is represented as a table and can be accessed from the manager as if it were an array. Valid index numbers range from 1 to `#hs._asm.guitk.manager:elements()` when getting an element or its attributes, or 1 to `#hs._asm.guitk.manager:elements() + 1` when replacing or assigning a new element. To access the userdata representing a specific element you can use the following syntax: `hs._asm.guitk.manager[#]._element` or `hs._asm.guitk.manager(#)` where # is the index number or the string `id` specified in the `frameDetails` attribute described below.

The specific attributes of each element will depend upon the type of element (see `hs._asm.guitk.element`) and the following manager specific attributes:

* `_element`     - A read-only attribute whos value is the userdata representing the gui element itself.
* `_fittingSize` - A read-only size-table specifying the default height and width for the element. Not all elements have a default height or width and the value for one or more of these keys may be 0.
* `_type`        - A read-only string indicating the userdata name for the element.
* `frameDetails` - A table containing positioning and identification information about the element.  All of it's keys are optional and are as follows:
  * `x`  - The horizontal position of the elements top-left corner. Only one of `x` and `cX` can be set; setting one will clear the other.
  * `y`  - The vertical position of the elements top-left corner. Only one of `y` and `cY` can be set; setting one will clear the other.
  * `cX` - The horizontal position of the elements center point. Only one of `x` and `cX` can be set; setting one will clear the other.
  * `cY` - The vertical position of the elements center point. Only one of `y` and `cY` can be set; setting one will clear the other.
  * `h`  - The element's height. If this is set, it will be used instead of the default height as returned by the `_fittingSize` attribute. If the default height is 0, then this *must* be set or the element will be effectively invisible.
  * `w`  - The element's width. If this is set, it will be used instead of the default width as returned by the `_fittingSize` attribute. If the default width is 0, then this *must* be set or the element will be effectively invisible.
  * `id` - A string specifying an identifier which can be used to reference this element through the manager's metamethods without requiring knowledge of the element's index position.

  * Note that `x`, `cX`, `y`, `cY`, `h`, and `w` may be specified as numbers or as strings representing percentages of the element's parent width (for `x`, `cX`, and `w`) or height (for `y`, `cY`, and `h`). Percentages should specified in the string as defined for your locale or in the `en_US` locale (as a fallback) which is either a number followed by a % sign or a decimal number.

* When assigning a new element to the manager through the metamethods, you can assign the userdata directly or by using the table format described above. For example:

~~~lua
manager = hs._asm.guitk.manager.new()
manager[1] = hs._asm.guitk.element.button.new(...)  -- direct assignment of the element
manager[2] = {                                      -- as a table
  _element = hs._asm.guitk.element.button.new(...), -- the only time that `_element` can be assigned a value
  frameDetails = { cX = "50%", cY = "50%" },
  id = "secondButton", -- the only time that `id` can be set outside of the `frameDetails` table
  -- other button specific attributes as defined in `hs._asm.guitk.element.button`
}
~~~

You can remove an existing element by setting its value to nil, e.g. `manager[1] = nil`.


### Installation

This module is still undergoing structural and documentation changes, so no precompiled version is presently available; it is hoped that this will change soon.

This module manages content only and requires its parent [hs._asm.guitk](..) for proper use. See the instructions for compiling the parent module for current installation instructions.

### Usage
~~~lua
manager = require("hs._asm.guitk").manager
~~~

### Contents


##### Module Constructors
* <a href="#new">manager.new([frame]) -> managerObject | nil</a>

##### Module Methods
* <a href="#_debugFrames">manager:_debugFrames([color]) -> managerObject | table/nil</a>
* <a href="#_nextResponder">manager:_nextResponder() -> userdata</a>
* <a href="#autoPosition">manager:autoPosition() -> managerObject</a>
* <a href="#element">manager:element([id]) -> elementUserdata | nil</a>
* <a href="#elementAutoPosition">manager:elementAutoPosition(element) -> managerObject</a>
* <a href="#elementFittingSize">manager:elementFittingSize(element) -> size-table</a>
* <a href="#elementFrameDetails">manager:elementFrameDetails(element, [details]) -> managerObject | table</a>
* <a href="#elementId">manager:elementId(element, [id]) -> managerObject | string</a>
* <a href="#elementMoveAbove">manager:elementMoveAbove(element1, element2, [offset], [relationship]) -> managerObject</a>
* <a href="#elementMoveBelow">manager:elementMoveBelow(element1, element2, [offset], [relationship]) -> managerObject</a>
* <a href="#elementMoveLeftOf">manager:elementMoveLeftOf(element1, element2, [offset], [relationship]) -> managerObject</a>
* <a href="#elementMoveRightOf">manager:elementMoveRightOf(element1, element2, [offset], [relationship]) -> managerObject</a>
* <a href="#elementPropertyList">manager:elementPropertyList(element) -> managerObject</a>
* <a href="#elementRemoveFromManager">manager:elementRemoveFromManager(element) -> managerObject</a>
* <a href="#elements">manager:elements() -> table</a>
* <a href="#insertElement">manager:insertElement(element, [pos]) -> managerObject</a>
* <a href="#passthroughCallback">manager:passthroughCallback([fn | nil]) -> managerObject | fn/nil</a>
* <a href="#removeElement">manager:removeElement([pos]) -> managerObject</a>
* <a href="#sizeToFit">manager:sizeToFit([hPad], [vPad]) -> managerObject</a>
* <a href="#tooltip">manager:tooltip([tooltip]) -> managerObject | string</a>

- - -

### Module Constructors

<a name="new"></a>
~~~lua
manager.new([frame]) -> managerObject | nil
~~~
Create a new manager object for use with a `hs._asm.guitk` window or another manager.

Parameters:
 * `frame` - an optional frame table specifying the initial position and size of the manager.

Returns:
 * the manager object or nil if there was an error creating the manager.

Notes:
 * In most cases, setting the frame is not necessary and will be overridden when the manager is assigned to a `hs._asm.guitk` window or another manager. It may be useful, however, when assigning elements to an unattached manager so that proper positioning can be worked out before final assignment of the new manager to it's parent object.

### Module Methods

<a name="_debugFrames"></a>
~~~lua
manager:_debugFrames([color]) -> managerObject | table/nil
~~~
Enable or disable visual rectangles around element frames in the content manager which can aid in identifying frame or positioning bugs.

Parameters:
 * `color` - a color table (as defined in `hs.drawing.color`, boolean, or nil, specifying whether debugging frames should be displayed and if so in what color.

Returns:
 * If an argument is provided, the manager object; otherwise the current value.

Notes:
 * Specifying `true` will enable the debugging frames with the current system color that represents the keyboard focus ring around controls.
 * Specifying `false` or `nil` will disable the debugging frames (default).
 * Specifying a color as defined by `hs.drawing.color` will display the debugging frames in the specified color.

 * Element frames which contain a height or width which is less than .5 points (effectively invisible) will draw an X at the center of the elements position instead of a rectangle.

- - -

<a name="_nextResponder"></a>
~~~lua
manager:_nextResponder() -> userdata
~~~
Returns the parent object of the manager as a userdata object.

Parameters:
 * None

Returns:
 * the userdata object representing the managers parent, usually a `hs._asm.guitk` window, or nil if the manager has no parent or its parent is not controllable through Hammerspoon.

Notes:
 * This method can be used to access the parent object of the manager. Usually this will be a `hs._asm.guitk` window object, but since a manager may also be an element of another manager, this method may return a `hs._asm.guitk.manager` object in these cases.
 * The metamethods for this module are designed so that you usually shouldn't need to access this method directly.
 * The name "nextResponder" comes from the macOS user interface internal organization and refers to the object which is further up the responder chain when determining the target for user activity.

- - -

<a name="autoPosition"></a>
~~~lua
manager:autoPosition() -> managerObject
~~~
Recalculate the position of all elements in the manager and update them if necessary.

Parameters:
 * None

Returns:
 * the manager object

Notes:
 * This method recalculates the position of elements whose position in `frameDetails` is specified by the element center or whose position or size are specified by percentages. See [hs._asm.guitk.manager:elementFrameDetails](#elementFrameDetails) for more information.
 * This method is invoked automatically anytime the managers parent (usually a `hs._asm.guitk` window) is resized and you shouldn't need to invoke it manually very often. If you find that you are needing to invoke it manually on a regular basis, try to determine what the specific circumstances are and submit an issue so that it can be evaluated to determine if the situation can be detected and trigger an update automatically.

* See also [hs._asm.guitk.manager:elementAutoPosition](#elementAutoPosition).

- - -

<a name="element"></a>
~~~lua
manager:element([id]) -> elementUserdata | nil
~~~
Returns the element userdata for the element specified.

Parameters:
 * `id` - a string or integer specifying which element to return.  If `id` is an integer, returns the element at the specified index position; if `id` is a string, returns the element with the specified identifier string.

Returns:
 * the element userdata, or nil if no element exists in the manager at the specified index position or with the specified identifier.

Notes:
 * See [hs._asm.guitk.manager:elementFrameDetails](#elementFrameDetails) for more information on setting an element's identifier string.

- - -

<a name="elementAutoPosition"></a>
~~~lua
manager:elementAutoPosition(element) -> managerObject
~~~
Recalculate the position of the specified element in the manager and update it if necessary.

Parameters:
 * `element` - the element userdata to recalculate the size and position for.

Returns:
 * the manager object

Notes:
 * This method recalculates the position of the element if it is defined in `framedDetails` as a percentage or by the elements center and it's size if the element size is specified as a percentage or inherits its size from the element's fitting size (see [hs._asm.guitk.manager:elementFittingSize](#elementFittingSize).

 * See also [hs._asm.guitk.manager:autoPosition](#autoPosition).
 * This method is wrapped so that elements which are assigned to a manager can access this method as `hs._asm.guitk.element:autoPosition()`

- - -

<a name="elementFittingSize"></a>
~~~lua
manager:elementFittingSize(element) -> size-table
~~~
Returns a table with `h` and `w` keys specifying the element's fitting size as defined by macOS and the element's current properties.

Parameters:
 * `element` - the element userdata to get the fitting size for.

Returns:
 * a table with `h` and `w` keys specifying the elements fitting size

Notes:
 * The dimensions provided can be used to determine a minimum size for the element to display fully based on its current properties and may change as these change.
 * Not all elements provide one or both of these fields; in such a case, the value for the missing or unspecified field will be 0.
 * If you do not specify an elements height or width with [hs._asm.guitk.manager:elementFrameDetails](#elementFrameDetails), the value returned by this method will be used instead; in cases where a specific dimension is not defined by this method, you should make sure to specify it or the element may not be visible.

- - -

<a name="elementFrameDetails"></a>
~~~lua
manager:elementFrameDetails(element, [details]) -> managerObject | table
~~~
Get or set the frame details in the manager for the specified element.

Parameters:
 * `element` - the element to get or set the frame details for
 * `details` - an optional table specifying the details to change or set for this element. The valid key-value pairs for the table are as follows:
   * `x`  - The horizontal position of the elements top-left corner. Only one of `x` and `cX` can be set; setting one will clear the other.
   * `y`  - The vertical position of the elements top-left corner. Only one of `y` and `cY` can be set; setting one will clear the other.
   * `cX` - The horizontal position of the elements center point. Only one of `x` and `cX` can be set; setting one will clear the other.
   * `cY` - The vertical position of the elements center point. Only one of `y` and `cY` can be set; setting one will clear the other.
   * `h`  - The element's height. If this is set, it will be used instead of the default height as returned by [hs._asm.guitk.manager:elementFittingSize](#elementFittingSize). If the default height is 0, then this *must* be set or the element will be effectively invisible. Set to false to clear a defined height and return the the default behavior.
   * `w`  - The element's width. If this is set, it will be used instead of the default width as returned by [hs._asm.guitk.manager:elementFittingSize](#elementFittingSize). If the default width is 0, then this *must* be set or the element will be effectively invisible. Set to false to clear a defined width and return the the default behavior.
   * `id` - A string specifying an identifier which can be used to reference this element with [hs._asm.guitk.manager:element](#element) without requiring knowledge of the element's index position. Specify the value as false to clear the identifier and set it to nil.

Returns:
 * If an argument is provided, the manager object; otherwise the current value.

Notes:
 * When setting the frame details, only those fields provided will be adjusted; other fields will remain unaffected (except as noted above). The values for keys `x`, `cX`, `y`, `cY`, `h`, and `w` may be specified as numbers or as strings representing percentages of the element's parent width (for `x`, `cX`, and `w`) or height (for `y`, `cY`, and `h`). Percentages should specified in the string as defined for your locale or in the `en_US` locale (as a fallback) which is either a number followed by a % sign or a decimal number.

 * When returning the current frame details table, an additional key-value pair is included: `_effective` will be a table specifying the elements actual frame-table (a table specifying the elements position as key-value pairs specifying the top-left position with `x` and `y`, and the element size with `h` and `w`).  This is provided for reference only: if this key-value pair is included when setting the frame details with this method, it will be ignored.

 * This method is wrapped so that elements which are assigned to a manager can access this method as `hs._asm.guitk.element:frameDetails([details])`

- - -

<a name="elementId"></a>
~~~lua
manager:elementId(element, [id]) -> managerObject | string
~~~
Get or set the string identifier for the specified element.

Parameters:
 * `element` - the element userdata to get or set the id of.
 * `id`      - an optional string, or explicit nil to remove, to change the element's identifier to

Returns:
 * If an argument is provided, the manager object; otherwise the current value.

Notes:
 * This method is wrapped so that elements which are assigned to a manager can access this method as `hs._asm.guitk.element:id([id])`

- - -

<a name="elementMoveAbove"></a>
~~~lua
manager:elementMoveAbove(element1, element2, [offset], [relationship]) -> managerObject
~~~
Moves element1 above element2 in the manager.

Parameters:
 * `element1`     - the element userdata to adjust the `x` and `y` coordinates of
 * `element2`     - the element userdata to anchor element1 to
 * `offset`       - a number, default 0.0, specifying the space between element1 and element2 in their new relationship
 * `relationship` - a string, default "flushLeft", specifying the horizontal relationship between `element1` and `element2`.  May be one of the following:
   * "flushLeft"  - element1 will be positioned above element2 with its left side at the same `x` position of the left side of element2.
   * "centered"   - element1 will be centered horizontally above element2.
   * "flushRight" - element1 will be positioned above element2 with its right side at the same `x` position of the right side of element2.

Returns:
 * the manager object

Notes:
 * This method will set the `x` and `y` fields of `frameDetails` for the element.  See [hs._asm.guitk.manager:elementFrameDetails](#elementFrameDetails) for the effect of this on other frame details.
 * This method is wrapped so that elements which are assigned to a manager can access this method as `hs._asm.guitk.element:moveAbove(element2, [offset], [relationship])`

 * this method moves element1 in relation to element2's current position -- moving element2 at a later point will not cause element1 to follow
 * this method will not adjust the postion of any other element which may already be at the new position for element1
 * an extension to `hs._asm.guitk.manager` which may support these limitations is under consideration but is currently not in the works.

- - -

<a name="elementMoveBelow"></a>
~~~lua
manager:elementMoveBelow(element1, element2, [offset], [relationship]) -> managerObject
~~~
Moves element1 below element2 in the manager.

Parameters:
 * `element1`     - the element userdata to adjust the `x` and `y` coordinates of
 * `element2`     - the element userdata to anchor element1 to
 * `offset`       - a number, default 0.0, specifying the space between element1 and element2 in their new relationship
 * `relationship` - a string, default "flushLeft", specifying the horizontal relationship between `element1` and `element2`.  May be one of the following:
   * "flushLeft"  - element1 will be positioned below element2 with its left side at the same `x` position of the left side of element2.
   * "centered"   - element1 will be centered horizontally below element2.
   * "flushRight" - element1 will be positioned below element2 with its right side at the same `x` position of the right side of element2.

Returns:
 * the manager object

Notes:
 * This method will set the `x` and `y` fields of `frameDetails` for the element.  See [hs._asm.guitk.manager:elementFrameDetails](#elementFrameDetails) for the effect of this on other frame details.
 * This method is wrapped so that elements which are assigned to a manager can access this method as `hs._asm.guitk.element:moveBelow(element2, [offset], [relationship])`

 * this method moves element1 in relation to element2's current position -- moving element2 at a later point will not cause element1 to follow
 * this method will not adjust the postion of any other element which may already be at the new position for element1
 * an extension to `hs._asm.guitk.manager` which may support these limitations is under consideration but is currently not in the works.

- - -

<a name="elementMoveLeftOf"></a>
~~~lua
manager:elementMoveLeftOf(element1, element2, [offset], [relationship]) -> managerObject
~~~
Moves element1 to the left of element2 in the manager.

Parameters:
 * `element1`     - the element userdata to adjust the `x` and `y` coordinates of
 * `element2`     - the element userdata to anchor element1 to
 * `offset`       - a number, default 0.0, specifying the space between element1 and element2 in their new relationship
 * `relationship` - a string, default "flushTop", specifying the vertical relationship between `element1` and `element2`.  May be one of the following:
   * "flushBottom" - element1 will be positioned to the left of element2 with its top at the same `y` position of the top of element2.
   * "centered"    - element1 will be centered vertically to the left of element2.
   * "flushTop"    - element1 will be positioned to the left of element2 with its bottom at the same `y` position of the bottom of element2.

Returns:
 * the manager object

Notes:
 * This method will set the `x` and `y` fields of `frameDetails` for the element.  See [hs._asm.guitk.manager:elementFrameDetails](#elementFrameDetails) for the effect of this on other frame details.
 * This method is wrapped so that elements which are assigned to a manager can access this method as `hs._asm.guitk.element:moveLeftOf(element2, [offset], [relationship])`

 * this method moves element1 in relation to element2's current position -- moving element2 at a later point will not cause element1 to follow
 * this method will not adjust the postion of any other element which may already be at the new position for element1
 * an extension to `hs._asm.guitk.manager` which may support these limitations is under consideration but is currently not in the works.

- - -

<a name="elementMoveRightOf"></a>
~~~lua
manager:elementMoveRightOf(element1, element2, [offset], [relationship]) -> managerObject
~~~
Moves element1 to the right of element2 in the manager.

Parameters:
 * `element1`     - the element userdata to adjust the `x` and `y` coordinates of
 * `element2`     - the element userdata to anchor element1 to
 * `offset`       - a number, default 0.0, specifying the space between element1 and element2 in their new relationship
 * `relationship` - a string, default "flushTop", specifying the vertical relationship between `element1` and `element2`.  May be one of the following:
   * "flushBottom" - element1 will be positioned to the right of element2 with its top at the same `y` position of the top of element2.
   * "centered"    - element1 will be centered vertically to the right of element2.
   * "flushTop"    - element1 will be positioned to the right of element2 with its bottom at the same `y` position of the bottom of element2.

Returns:
 * the manager object

Notes:
 * This method will set the `x` and `y` fields of `frameDetails` for the element.  See [hs._asm.guitk.manager:elementFrameDetails](#elementFrameDetails) for the effect of this on other frame details.
 * This method is wrapped so that elements which are assigned to a manager can access this method as `hs._asm.guitk.element:moveRightOf(element2, [offset], [relationship])`

 * this method moves element1 in relation to element2's current position -- moving element2 at a later point will not cause element1 to follow
 * this method will not adjust the postion of any other element which may already be at the new position for element1
 * an extension to `hs._asm.guitk.manager` which may support these limitations is under consideration but is currently not in the works.

- - -

<a name="elementPropertyList"></a>
~~~lua
manager:elementPropertyList(element) -> managerObject
~~~
Return a table of key-value pairs containing the properties for the specified element

Parameters:
 * `element` - the element userdata to create the property list for

Returns:
 * a table containing key-value pairs describing the properties of the element.

Notes:
 * The table returned by this method does not support modifying the property values as can be done through the `hs._asm.guitk.manager` metamethods (see the top-level documentation for `hs._asm.guitk.manager`).

 * This method is wrapped so that elements which are assigned to a manager can access this method as `hs._asm.guitk.element:propertyList()`

- - -

<a name="elementRemoveFromManager"></a>
~~~lua
manager:elementRemoveFromManager(element) -> managerObject
~~~
Remove the specified element from the manager

Parameters:
 * `element` - the element userdata to remove from this manager

Returns:
 * the manager object

Notes:
 * This method is wrapped so that elements which are assigned to a manager can access this method as `hs._asm.guitk.element:removeFromManager()`

 * See also [hs._asm.guitk.manager:removeElement](#removeElement)

- - -

<a name="elements"></a>
~~~lua
manager:elements() -> table
~~~
Returns an array containing the elements in index order currently managed by this manager.

Parameters:
 * None

Returns:
 * a table containing the elements in index order currently managed by this manager

- - -

<a name="insertElement"></a>
~~~lua
manager:insertElement(element, [pos]) -> managerObject
~~~
Inserts a new element for the manager to manage.

Parameters:
 * `element` - the element userdata to insert into the manager
 * `pos`     - the index position in the list of elements specifying where to insert the element.  Defaults to `#hs._asm.guitk.manager:elements() + 1`, which will insert the element at the end.

Returns:
 * the manager object

- - -

<a name="passthroughCallback"></a>
~~~lua
manager:passthroughCallback([fn | nil]) -> managerObject | fn/nil
~~~
Get or set the pass through callback for the manager.

Parameters:
 * `fn` - a function, or an explicit nil to remove, specifying the callback to invoke for elements which do not have their own callbacks assigned.

Returns:
 * If an argument is provided, the manager object; otherwise the current value.

Notes:
 * The pass through callback should expect one or two arguments and return none.

 * The pass through callback is designed so that elements which trigger a callback based on user interaction which do not have a specifically assigned callback can still report user interaction through a common fallback.
 * The arguments received by the pass through callback will be organized as follows:
   * the manager userdata object
   * a table containing the arguments provided by the elements callback itself, usually the element userdata followed by any additional arguments as defined for the element's callback function.

 * Note that elements which have a callback that returns a response cannot use this common pass through callback method; in such cases a specific callback must be assigned to the element directly as described in the element's documentation.

- - -

<a name="removeElement"></a>
~~~lua
manager:removeElement([pos]) -> managerObject
~~~
Remove an element from the manager as specified by its index position.

Parameters:
 * `pos`     - the index position in the list of elements specifying the element to remove.  Defaults to `#hs._asm.guitk.manager:elements()` (the last element)

Returns:
 * the manager object

Notes:
 * See also [hs._asm.guitk.manager:elementRemoveFromManager](#elementRemoveFromManager)

- - -

<a name="sizeToFit"></a>
~~~lua
manager:sizeToFit([hPad], [vPad]) -> managerObject
~~~
Adjusts the size of the manager so that it is the minimum size necessary to contain all of its elements.

Parameters:
 * `hPad` - an optional number specifying the horizontal padding to include between the elements and the left and right of the manager's new borders. Defaults to 0.0.
 * `vPad` - an optional number specifying the vertical padding to include between the elements and the top and bottom of the manager's new borders.  Defaults to the value of `hPad`.

Returns:
 * the manager object

Notes:
 * If the manager is the member of another manager, this manager's size (but not top-left corner) is adjusted within its parent.
 * If the manager is assigned to a `hs._asm.guitk` window, the window's size (but not top-left corner) will be adjusted to the calculated size.

- - -

<a name="tooltip"></a>
~~~lua
manager:tooltip([tooltip]) -> managerObject | string
~~~
Get or set the tooltip for the manager

Parameters:
 * `tooltip` - a string, or nil to remove, specifying the tooltip to display when the mouse pointer hovers over the content manager

Returns:
 * If an argument is provided, the manager object; otherwise the current value.

Notes:
 * Tooltips are displayed when the window is active and the mouse pointer hovers over the content manager and no other element at the current mouse position has a defined tooltip.

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


