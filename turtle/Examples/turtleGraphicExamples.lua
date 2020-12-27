-- Note: I need to break these out into explicit examples.
--
-- Right now its more of a dumping ground for things I'm using to test various aspects.
-- But since the module isn't even really "released" yet and is more for my amusement than
-- anything else, doing so is a low priority ATM.

-- TO fern :size :sign
--   if :size < 1 [ stop ]
--   fd :size
--   rt 70 * :sign fern :size * 0.5 :sign * -1 lt 70 * :sign
--   fd :size
--   lt 70 * :sign fern :size * 0.5 :sign rt 70 * :sign
--   rt 7 * :sign fern :size - 1 :sign lt 7 * :sign
--   bk :size * 2
-- END
-- window clearscreen pu bk 150 pd
-- fern 25 1

tgFern = function(cv, size, sign)
    local tgFern2
    tgFern2 = function(cv, size, sign)
        if size < 1 then return end
        cv:forward(size)
        cv:right(70 * sign)
        tgFern2(cv, size * .5, -sign)
        cv:left(70 * sign)

        cv:forward(size)
        cv:left(70 * sign)
        tgFern2(cv, size * .5, sign)
        cv:right(70 * sign)

        cv:right(7 * sign)
        tgFern2(cv, size -1, sign)
        cv:left(7 * sign)

        cv:back(size * 2)
    end

    cv:penup():back(150):pendown()
    tgFern2(cv, size, sign)
end

fern2 = function(i, s, yr)
    i = i or 10

    coroutine.wrap(function()
        tg = require("hs.canvas.turtle")
        cv = tg.turtleCanvas()

        if yr == false then
            cv:_neverYield(true)
        elseif yr then
            cv:_yieldRatio(yr)
        else
            cv:_yieldRatio(1000)
        end

        local t = os.time()
        tgFern(cv, i, s or 1)
        print(os.time() - t)
    end)()
end

-- to tree :size
--    if :size < 5 [forward :size back :size stop]
--    forward :size/3
--    left 30 tree :size*2/3 right 30
--    forward :size/6
--    right 25 tree :size/2 left 25
--    forward :size/3
--    right 25 tree :size/2 left 25
--    forward :size/6
--    back :size
-- end
-- clearscreen
-- tree 150

tgTree = function(cv, size)
    if size < 5 then
        cv:forward(size):back(size)
        return
    end
    cv:forward(size / 3)
    cv:left(30)
    tgTree(cv, size * 2/3)
    cv:right(30)

    cv:forward(size / 6)
    cv:right(25)
    tgTree(cv, size / 2)
    cv:left(25)

    cv:forward(size / 3)
    cv:right(25)
    tgTree(cv, size / 2)
    cv:left(25)

    cv:forward(size / 6)
    cv:back(size)
end

tree2 = function(i, yr)
    i = i or 50

    coroutine.wrap(function()
        tg = require("hs.canvas.turtle")
        cv = tg.turtleCanvas()

        if yr == false then
            cv:_neverYield(true)
        elseif yr then
            cv:_yieldRatio(yr)
        else
            cv:_yieldRatio(1000)
        end

        local t = os.time()
        tgTree(cv, i)
        print(os.time() - t)
    end)()
end





tc = require("hs.canvas.turtle")

fern = function(self, size, sign)
    if (size >= 1) then
        self:forward(size):right(70 * sign)
        fern(self, size * 0.5, sign * -1)
        self:left(70 * sign):forward(size):left(70 * sign)
        fern(self, size * 0.5, sign)
        self:right(70 * sign):right(7 * sign)
        fern(self, size - 1, sign)
        self:left(7 * sign):back(size * 2)
    end
end

t = os.time()
tc1 = tc.turtleCanvas()
tc1:penup():back(150):pendown()
fern(tc1, 25, 1)
fern(tc1, 25, -1)
print("Blocked for", os.time() - t)

t = os.time()
tc2 = tc.turtleCanvas()
tc2:penup():back(150):pendown():_background(fern, 25, 1):_background(fern, 25, -1):_background(function(self) self:show() ; print("Completed in", os.time() - t) end)
print("Blocked for", os.time() - t)





tc = require("hs.canvas.turtle")

fern = function(self, size, sign)
    if (size >= 1) then
        self:forward(size):right(70 * sign)
        fern(self, size * 0.5, sign * -1)
        self:left(70 * sign):forward(size):left(70 * sign)
        fern(self, size * 0.5, sign)
        self:right(70 * sign):right(7 * sign)
        fern(self, size - 1, sign)
        self:left(7 * sign):back(size * 2)
    end
end

wheel = function(self, _step)
    local t = os.time()
    for i = 0, 359, (_step or 90) do
        self:penup():home():setheading(i):back(150):pendown()
        fern(self, 25, 1)
        fern(self, 25, -1)
    end
    self:show()
    print("Completed in", os.time() - t)
end

-- Blocks Hammerspoon (and possibly makes other apps less responsive as well), but is
-- the fastest. I've seen this as high as 7 in my tests, but it's usually around 5.
-- Completed in	5
-- Blocked for	5
local t = os.time()
tc1 = tc.turtleCanvas()
wheel(tc1, _step)
print("Blocked for", os.time() - t)


-- Hammerspoon remains responsive, but does take longer (I've seen as low as 9 in my
-- tests, but 12 is about average -- other HS and macOS applications *will* affect
-- this, but if you know it's going to noticeably block HS or slow other apps down,
-- it's probably worth it and is considered "good application behavior".)
-- Blocked for	0
-- Completed in	12
local t = os.time()
tc2 = tc.turtleCanvas():_background(wheel, _step):hide()
print("Blocked for", os.time() - t)

-- Even slower, but visually like what you may remember if you had a Logo class at
-- some point in your past. Ah memories...
-- Blocked for	0
-- Completed in	24
local t = os.time()
tc3 = tc.turtleCanvas():_background(wheel, _step)
print("Blocked for", os.time() - t)

