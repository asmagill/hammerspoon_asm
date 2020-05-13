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
