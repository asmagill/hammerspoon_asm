-- not efficient, in fact painfully inefficient,
-- but seems to work with quad faces in 3d; not as sure about 4 yet...

local module = {}

local dimensional = require("hs._asm.dimensional")

-- points -> p#, { x, y, z, [w] }
-- lines  -> l#, { p1, p2 }
-- faces  -> f#, { l1, l2, l3, l4 }
-- edges  -> l#, { f1, f2 }

-- facePoints -> f#, { x, y, z, [w] }
-- edgePoints -> e#, { x, y, z, [w] }


local tableCopy
tableCopy = function(t)
    if type(t) ~= "table" then return t end

    local nt = {}
    local k, v = next(t)
    while k do
        nt[tableCopy(k)] = tableCopy(v)
        k, v = next(t, k)
    end
    return nt
end

local contains = function(tbl, val)
    local found = false
    local k, v = next(tbl)
    while not found and k do
        found = v == val
        k, v = next(tbl, k)
    end
    return found
end

local alreadySeen = function(a, b, c, d, seen)
    local count, duplicate = 0, false

    while not duplicate and count < #seen do
        count = count + 1
        local knownFace = seen[count]
        duplicate = (
                      contains(knownFace, a) and
                      contains(knownFace, b) and
                      contains(knownFace, c) and
                      contains(knownFace, d)
                    )
    end
    return duplicate
end

-- assumes quad pt faces; should we also allow three point faces? Making it for n
-- results in combinatorial explosion and introduces the need to ensure all points are
-- on same plane
-- local facesFromLines = function(lines)
--     local faces = {}
--
--     for a = 1, #lines, 1 do
--         for b = 1, #lines, 1 do
--             for c = 1, #lines, 1 do
--                 for d = 1, #lines, 1 do
--                     if a ~= b and a ~= c and a ~= d and b ~= c and b ~= d and c ~= d then
--                         if (lines[d][1] == lines[a][1] or lines[d][1] == lines[a][2] or lines[d][2] == lines[a][1] or lines[d][2] == lines[a][2]) and
--                            (lines[a][1] == lines[b][1] or lines[a][1] == lines[b][2] or lines[a][2] == lines[b][1] or lines[a][2] == lines[b][2]) and
--                            (lines[b][1] == lines[c][1] or lines[b][1] == lines[c][2] or lines[b][2] == lines[c][1] or lines[b][2] == lines[c][2]) and
--                            (lines[c][1] == lines[d][1] or lines[c][1] == lines[d][2] or lines[c][2] == lines[d][1] or lines[c][2] == lines[d][2])
--                         then
--                             -- check to make sure it's actually a closed path
--                             local pointCounts, isBad = {}, false
--                             for i = 1, 2, 1 do
--                                 pointCounts[lines[a][i]] = (pointCounts[lines[a][i]] or 0) + 1
--                                 pointCounts[lines[b][i]] = (pointCounts[lines[b][i]] or 0) + 1
--                                 pointCounts[lines[c][i]] = (pointCounts[lines[c][i]] or 0) + 1
--                                 pointCounts[lines[d][i]] = (pointCounts[lines[d][i]] or 0) + 1
--                             end
--                             for pt, number in pairs(pointCounts) do
--                                 isBad = isBad or (number ~= 2)
--                             end
--                             -- culls duplicates
--                             if not isBad and not alreadySeen(a, b, c, d, faces) then
--                                 table.insert(faces, { a, b, c, d })
--                             end
--                         end
--                     end
--                 end
--             end
--         end
--     end
--
--     return faces
-- end
local facesFromLines = dimensional.facesFromLines

module.facesFromLines = facesFromLines

local mapLinesToFaces = function(faces, lines)
    local map = {}
    for i = 1, #lines, 1 do map[i] = {} end

    for i = 1, #faces, 1 do
        for _, v in ipairs(faces[i]) do table.insert(map[v], i) end
    end

    return map
end
module.mapLinesToFaces = mapLinesToFaces

module.refine = function(lines, points)
    local newPoints, newLines = {}, {}

    local faces = facesFromLines(lines)
    local edges = mapLinesToFaces(faces, lines)

    for i = 1, #points, 1 do newPoints[i] = tableCopy(points[i]) end

    local facePoints = {}
    for f = 1, #faces, 1 do
        local np, count = {}, 0
        local face = faces[f]
        local seenP = {}
        for l = 1, #face, 1  do
            local line = lines[face[l]]
            for p = 1, #line, 1 do
                local pt = line[p]
                if not seenP[pt] then
                    seenP[pt] = true
                    local point = points[pt]
                    for c = 1, #point, 1 do np[c] = (np[c] or 0) + point[c] end
                    count = count + 1
                end
            end
        end
        for c = 1, #np, 1 do np[c] = np[c] / count end
        table.insert(facePoints, np)
        table.insert(newPoints, np)
    end

    local edgePoints = {}
    local edgePointPointsMap = {}
    for e = 1, #edges, 1 do
        local edge = edges[e]
        local np = {}
        local p1 = points[lines[e][1]]
        local p2 = points[lines[e][2]]
        for c = 1, #p1, 1 do np[c] = p1[c] + p2[c] end
        for _, v in ipairs(edge) do
            for c = 1, #p1, 1 do np[c] = np[c] + facePoints[v][c] end
        end

        for c = 1, #p1, 1 do np[c] = np[c] / (2 + #edge) end
        table.insert(edgePoints, np)
        table.insert(newPoints, np)
        edgePointPointsMap[#newPoints] = { lines[e][1], lines[e][2] }

        for _, v in ipairs(edge) do
            table.insert(newLines, { #newPoints, #points + v })
        end
    end

    for p = 1, #points, 1 do
        local pInLines, lInFaces = {}, {}
        for i, v in ipairs(lines) do
            if contains(v, p) then table.insert(pInLines, i) end
        end

        for i, v in ipairs(faces) do
            for _, v2 in ipairs(pInLines) do
                if contains(v, v2) and not contains(lInFaces, i) then
                    table.insert(lInFaces, i)
                end
            end
        end

        local n = #lInFaces -- which will be the same as #pInLines

        local F = {}
        for f = 1, n, 1 do
            local fP = facePoints[lInFaces[f]]
            for c = 1, #fP, 1 do F[c] = (F[c] or 0) + fP[c] end
        end
        for c = 1, #F, 1 do F[c] = F[c] / n end

        local R = {}
        for _, v in ipairs(pInLines) do
            for c = 1, #F, 1 do
                R[c] = (R[c] or 0) + (points[lines[v][1]][c] + points[lines[v][2]][c]) / 2
            end
        end
        for c = 1, #F, 1 do R[c] = R[c] / n end

        local P = points[p]
        if n == 3 then
            P = {}
            for c = 1, #F, 1 do P[c] = 0 end
        end

        for c = 1, #newPoints[p], 1 do
            newPoints[p][c] = (F[c] + 2 * R[c] + P[c]) / n
        end

        for k, v in pairs(edgePointPointsMap) do
            if contains(v, p) then table.insert(newLines, { p, k }) end
        end
    end

    return {
--         faces = faces, edges = edges,
--         facePoints = facePoints, edgePoints = edgePoints,
        lines = newLines, points = newPoints,
    }
end

return module
