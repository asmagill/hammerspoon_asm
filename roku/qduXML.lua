-- Quick, Dirty, & Ugly XML parser
--
--  I like JSON. It's well understood, has a simple layout, maps nicely to lua data types...
--  XML doesn't. But some web enabled devices still use XML though its probably bloated
--  overkill for what they really need (<cough>Roku</cough>)... so I'm stuck with using it...
--
-- Based on XML specifications as described at https://www.w3schools.com/xml/xml_syntax.asp
-- and to a lesser extent https://www.w3.org/TR/REC-xml/

local usage = [[
xmlObj = qduXML.parseXML(xmlString)
xmlObj:tag() -> string           tag this object represents
xmlObj:value() -> string | nil   if the entity contains text, returns the text
xmlObj:children() -> table       returns a table of the child entities (may be empty)
xmlObj:asTable() -> table        returns a table describing the xml tree

xmlObj[i] -> xmlObj | nil        returns xmlObj:children()[i]
xmlObj["attr"] -> string | nil   returns string for value of attribute or nil
xmlObj("tag") -> table | nil     returns a table of all children of type "tag" or nil

for i, v in ipairs(xmlObj) do ... end    enumerate children
for k, v in pairs(xmlObj) do ... end     enumerate attributes

qduXML.entityValue(obj, [idx])
      Used to simplify code logic from:
             a = xmlObj and xmlObj[idx] and xmlObj[idx]:value() or nil
      Or if idx not provided (i.e. nil):
             a = xmlObj and xmlObj:value() or nil
      To just:
             a = xml.entityValue(xmlObj, [idx])

Known limitations
     minimally tested -- works for Roku ECP as of Apr 2021, but not tested elsewhere
     no mixed-content -- an entity contains *either* text *or* zero or more child entities, not both
     all values returned as strings

     will probably barf on multi-byte UTF-8 sequences in tag and attribute names
         attribute and entity values should be ok, though
     has never heard of CDATA
     just parses tags, attributes, and entity values... no validation, no DTDs no nutten but the
         bare minimum
     probably more...

     when it fails, it does not fail gracefully (e.g. bad XML, mixed-content, etc.)
]]

local module = {}
module._version = "0.0.2"

local NAME_PATTERN = "[%a_][%a%d%-%._:]*"

local decodeEntities = function(val)
    return (val:gsub("&(%w+);", {
        lt   = "<",
        gt   = ">",
        amp  = "&",
        apos = "'",
        quot = '"',
    }))
end

local elementMetatable = {
    tag   = function(self) return getmetatable(self)._tag end,
    value = function(self)
        local v = getmetatable(self)._value
        return type(v) == "string" and v or nil
    end,
    children = function(self)
        local v = getmetatable(self)._value
        return type(v) == "table" and v or {}
    end,
    asTable = function(self)
        local buildTable
        buildTable = function(entity)
            local results = {}
            if #entity == 0 then
                results = entity:value()
            else
                for _, vEntity in ipairs(entity) do
                    local tag, value = vEntity:tag(), buildTable(vEntity)
                    if results[tag] then
                        if type(results[tag]) ~= "table" then
                            results[tag] = { results[tag] }
                        end
                        table.insert(results[tag], value)
                    else
                        results[tag] = value
                    end
                end
            end

            local xml_attributes = {}
            for attr, vValue in pairs(entity) do xml_attributes[attr] = vValue end
            if next(xml_attributes) then
                if type(results) ~= "table" then
                    results = { results }
                end
                results.xml_attributes = xml_attributes
            end

            return results
        end

        return setmetatable({ [self:tag()] = buildTable(self) }, { __tostring = inspect })
    end,
}

local elementCall = function(self, key)
    if type(key) == "number" and math.type(key) == "integer" then
        return self:children()[key]
    elseif type(key) == "string" then
        local results = {}
        for _,v in ipairs(self:children()) do
            if v:tag() == key then
                table.insert(results, v)
            end
        end
        return #results > 0 and results or nil
    else
        return nil
    end
end

local elementIndex = function(self, key)
    if elementMetatable[key] then
        return elementMetatable[key]
    elseif type(key) == "number" and math.type(key) == "integer" then
        return elementCall(self, key)
    else
        return nil
    end
end

local parseSegment
parseSegment = function(xmlString)
    if not xmlString:match("<") then
        return decodeEntities(xmlString)
    end

-- print("{{" .. xmlString .. "}}")
    local result = {}

    local pos = 1
    while (pos < #xmlString) do
        local workingString = xmlString:sub(pos)

        if workingString:match("^%s*$") then break end

        local tag, attrs, closing = workingString:match("^%s*<(" .. NAME_PATTERN .. ")%s*([^/>]-)%s*(/?>)")
        if not tag then
            error("tag malformed in " .. workingString)
        elseif tag:match("^[xX][mM][lL]") then
            error("tag cannot start with the letters 'xml': " .. tag)
        end

        local entity = {}

        local aPos = 1
        while (aPos < #attrs) do
            local s, e = attrs:find(NAME_PATTERN, aPos)
            local a = attrs:sub(s, e)
            aPos = e + 1
            s, e = attrs:find("['\"]", aPos)
            local q = attrs:sub(s, e)
            aPos = e + 1
            s, e = attrs:find(q, aPos)
            local v = attrs:sub(aPos, e - 1)
            aPos = e + 1
            entity[a] = decodeEntities(v)
        end

        local s, e = workingString:find(closing)

        local value

        if closing ~= "/>" then
            local start = e + 1
            s, e = workingString:find("<%s*/" .. tag:gsub("%-", "%%-") .. "%s*>", start)
-- print(workingString:sub(s, e), #workingString, pos, s, e, workingString:sub(start, s - 1))
            pos = pos + e
            if start < s then
                value = parseSegment(workingString:sub(start, s - 1))
            end
        else
            pos = pos + e
        end

        table.insert(result, setmetatable(entity, {
            _tag       = tag,
            _value     = value,
            __index    = elementIndex,
            __call     = elementCall,
            __tostring = function(self) return "xmlNode: " .. self:tag() .. " (" .. tostring(#self) .. ")" end,
            __len      = function(self) return #self:children() end,
        }))
    end

    return result
end

module._help = function() return usage end

module.parseXML = function(xmlString)
    assert(type(xmlString) == "string", "input must be a string")

    if xmlString:match("^[\r\n]*<%?xml") then -- purge prolog if present
        xmlString = xmlString:match("^[\r\n]*<%?xml.-%?>[\r\n]*(.*)$")
    end
    xmlString = xmlString:gsub("<!%-%-.-%-%->", "") -- purge comments

    return parseSegment(xmlString)[1]
end

module.entityValue = function(entity, idx)
    if entity then
        if idx then
            return entity[idx] and entity[idx]:value() or nil
        elseif (getmetatable(entity) or {}).__index == elementIndex then
            return entity:value()
        end
    end
    return nil
end

return module
