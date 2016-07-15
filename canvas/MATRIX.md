hs._asm.canvas.matrix
=====================

A sub module to `hs._asm.canvas` which provides support for basic matrix manipulations which can be used as the values for `transformation` attributes in the `hs._asm.canvas` module.

For mathematical reasons that are beyond the scope of this document, a 3x3 matrix can be used to represent a series of manipulations to be applied to the coordinates of a 2 dimensional drawing object.  These manipulations can include one or more of a combination of translations, rotations, shearing and scaling. Within the 3x3 matrix, only 6 numbers are actually required, and this module represents them as the following keys in a Lua table: `m11`, `m12`, `m21`, `m22`, `tX`, and `tY`. For those of a mathematical bent, the 3x3 matrix used within this module can be visualized as follows:

    [  m11,  m12,  0  ]
    [  m21,  m22,  0  ]
    [  tX,   tY,   1  ]

This module allows you to generate the table which can represent one or more of the recognized transformations without having to understand the math behind the manipulations or specify the matrix values directly.

Many of the methods defined in this module can be used both as constructors and as methods chained to a previous method or constructor. Chaining the methods in this manner allows you to combine multiple transformations into one combined table which can then be assigned to an element in your canvas.
.

For more information on the mathematics behind these, you can check the web.  One site I used for reference (but there are many more which go into much more detail) can be found at http://www.cs.trinity.edu/~jhowland/cs2322/2d/2d/.

### Usage
~~~lua
matrix = require("hs._asm.canvas.matrix")
~~~

### Contents


##### Module Constructors
* <a href="#identity">matrix.identity() -> matrixObject</a>

##### Module Methods
* <a href="#append">matrix:append(matrix) -> matrixObject</a>
* <a href="#invert">matrix:invert() -> matrixObject</a>
* <a href="#prepend">matrix:prepend(matrix) -> matrixObject</a>
* <a href="#rotate">matrix:rotate(angle) -> matrixObject</a>
* <a href="#scale">matrix:scale(xFactor, [yFactor]) -> matrixObject</a>
* <a href="#shear">matrix:shear(xFactor, [yFactor]) -> matrixObject</a>
* <a href="#translate">matrix:translate(x, y) -> matrixObject</a>

- - -

### Module Constructors

<a name="identity"></a>
~~~lua
matrix.identity() -> matrixObject
~~~
Specifies the identity matrix.  Resets all existing transformations when applied as a method to an existing matrixObject.

Parameters:
 * None

Returns:
 * the identity matrix.

Notes:
 * The identity matrix can be thought of as "apply no transformations at all" or "render as specified".
 * Mathematically this is represented as:
~~~
[ 1,  0,  0 ]
[ 0,  1,  0 ]
[ 0,  0,  1 ]
~~~

### Module Methods

<a name="append"></a>
~~~lua
matrix:append(matrix) -> matrixObject
~~~
Appends the specified matrix transformations to the matrix and returns the new matrix.  This method cannot be used as a constructor.

Parameters:
 * `matrix` - the table to append to the current matrix.

Returns:
 * the new matrix

Notes:
 * Mathematically this method multiples the original matrix by the new one and returns the result of the multiplication.
 * You can use this method to "stack" additional transformations on top of existing transformations, without having to know what the existing transformations in effect for the canvas element are.

- - -

<a name="invert"></a>
~~~lua
matrix:invert() -> matrixObject
~~~
Generates the mathematical inverse of the matrix.  This method cannot be used as a constructor.

Parameters:
 * None

Returns:
 * the inverted matrix.

Notes:
 * Inverting a matrix which represents a series of transformations has the effect of reversing or undoing the original transformations.
 * This is useful when used with [hs._asm.canvas.matrix.append](#append) to undo a previously applied transformation without actually replacing all of the transformations which may have been applied to a canvas element.

- - -

<a name="prepend"></a>
~~~lua
matrix:prepend(matrix) -> matrixObject
~~~
Prepends the specified matrix transformations to the matrix and returns the new matrix.  This method cannot be used as a constructor.

Parameters:
 * `matrix` - the table to append to the current matrix.

Returns:
 * the new matrix

Notes:
 * Mathematically this method multiples the new matrix by the original one and returns the result of the multiplication.

- - -

<a name="rotate"></a>
~~~lua
matrix:rotate(angle) -> matrixObject
~~~
Applies a rotation of the specified number of degrees to the transformation matrix.  This method can be used as a constructor or a method.

Parameters:
 * `angle` - the number of degrees to rotate in a clockwise direction.

Returns:
 * the new matrix

Notes:
 * The rotation of an element this matrix is applied to will be rotated about the origin (zero point).  To rotate an object about another point (its center for example), prepend a translation to the point to rotate about, and append a translation reversing the initial translation.
   * e.g. `hs.canvas.matrix.translate(x, y):rotate(angle):translate(-x, -y)`

- - -

<a name="scale"></a>
~~~lua
matrix:scale(xFactor, [yFactor]) -> matrixObject
~~~
Applies a scaling transformation to the matrix.  This method can be used as a constructor or a method.

Parameters:
 * `xFactor` - the scaling factor to apply to the object in the horizontal orientation.
 * `yFactor` - an optional argument specifying a different scaling factor in the vertical orientation.  If this argument is not provided, the `xFactor` argument will be used for both orientations.

Returns:
 * the new matrix

- - -

<a name="shear"></a>
~~~lua
matrix:shear(xFactor, [yFactor]) -> matrixObject
~~~
Applies a shearing transformation to the matrix.  This method can be used as a constructor or a method.

Parameters:
 * `xFactor` - the shearing factor to apply to the object in the horizontal orientation.
 * `yFactor` - an optional argument specifying a different shearing factor in the vertical orientation.  If this argument is not provided, the `xFactor` argument will be used for both orientations.

Returns:
 * the new matrix

- - -

<a name="translate"></a>
~~~lua
matrix:translate(x, y) -> matrixObject
~~~
Applies a translation transformation to the matrix.  This method can be used as a constructor or a method.

Parameters:
 * `x` - the distance to translate the object in the horizontal direction.
 * `y` - the distance to translate the object in the vertical direction.

Returns:
 * the new matrix

- - -

### License

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
