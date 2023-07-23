-- Izak's Lua utils
-- Last updated 6:06 PM 7/13/2023


function keyCount(table)
  local n = 0
  for _, _ in pairs(table) do
    n = n + 1
  end
  return n
end


-- Return the number "x" clamped between the given minimum and maximum values
function clamp(x, minX, maxX)
	if x > maxX then
		return maxX
	elseif x < minX then
		return minX
	else
		return x
	end
end


-- Linear interpolation from value "a" to value "b" specified by "t".
-- Usually, "t" should be between 0 and 1.
function mix(a, b, t)
	return a*(1 - t) + b*t
end


-- Re-mix `x` from an input range of `in1` to `in2` to an output range of `out1` to `out2`.
-- For example: remix(0, 1, 3, 8, x) will map `x`
--   from between 0 and 1 to be proportionally somewhere between 3 and 8.
-- Note: This function may return values outside of the output range
--   if `x` is already outside of the input range.
-- This function copies the functionality of Processing's `map` function
-- [https://processing.org/reference/map_.html]
function remix(in1, in2, out1, out2, x)
	return out1 + ((x - in1) * (out2 - out1) / (in2 - in1))
end


-- Note: Equivalent to `remix`, except that `x` will be kept inside the output range.
function remixClamped(in1, in2, out1, out2, x)
	local x = remix(in1, in2, out2, out2, x)
	if out1 < out2 then
		return clamp(x, out1, out2)
	else
		return clamp(x, out2, out1)
	end
end


-- Ease with cubic smooth interpolation from value "a" to value "b"
-- Usually, "t" should be between 0 and 1.
function ease(a, b, t)
	return mix(a, b, cubicUnit(clamp(t, 0, 1)))
end


-- Cubic function that forms a sort of sigmoid in the unit square.
-- Such that: f(0) = 0, f(0.5) = 0.5, and f(1) = 1, and f'(0) = 0, and f'(1) = 0.
-- The solution is: f(x) = (x^2)*(3 - 2*x) = 3(x^2) - 2(x^3)
function cubicUnit(x)
	return x*x*(3 - 2*x)
end


-- GLSL smoothstep function of "x" between "edge1" and "edge2"
-- https://docs.gl/sl4/smoothstep
function smoothstep(edge1, edge2, x)
	if edge1 >= edge2 then
		error("function `smoothstep`: result is undefined if `edge1` >= `edge2`", 2)
	end
	local t = clamp((x - edge1) / (edge2 - edge1), 0, 1)
	return cubicUnit(t)
end


-- Treat "b" as a boolean value and convert it to 1 for true and 0 for false.
function boolToInt(b)
	if b then return 1
	else return 0 end
end


-- Generates a step function, by comparing "x" to "edge".
-- Parameters "edge" and "x" can either be tables or numbers, but must both be the same type.
-- Returns either a single number or an array of numbers.
function step(edge, x)
	-- helper function 
	local function step_1(edge_1, x_1) return boolToInt(x_1 < edge_1) end

	if type(edge) ~= type(x) then
		error("function `step`: `edge` and `x` should be the same type", 2)
	elseif type(edge) == "number" then
		return step1(edge, x)
	elseif type(edge) == "table" then
		if #edge ~= #x then
			error("function `step`: parameters should have the same length", 2)
		end
		local result = {}
		for i = 1, #edge do
			result[i] = step_1(edge[i], x[i])
		end
		return result
	else
		error("function `step`: `edge` and `x` should both be numbers or tables")
	end
end


-- Escape special characters in a string
function escape(s)
	return string.format("%q", s)
	--[[
	if type(s) ~= "string" then
		error("function `escape` is only defined for strings")
	end
	
	local t = {}
	for c in s:gmatch"." do
		if c == "\n" then t[1 + #t] = "\\n"      -- literal \n
		elseif c == "\r" then t[1 + #t] = "\\r"  -- literal \r
		elseif c == "\t" then t[1 + #t] = "\\t"  -- literal \t
		elseif c == "\"" then t[1 + #t] = "\\\"" -- literal \"
		elseif c == "\\" then t[1 + #t] = "\\\\" -- literal \\
		elseif c == "\'" then t[1 + #t] = "\\\'" -- literal \'
		else t[1 + #t] = c
		end
	end
	return table.concat(t)
	--]]
end


-- See a string representation of "x".
-- Level is the number of levels of recursion to allow when presenting a table
function quote(x, level)
	local next_level = level
	if next_level then
		next_level = level - 1
	end	
	
	if type(x) == "string" then
		-- Make strings appear the same as in literal form
		return escape(x)
	elseif type(x) == "table" then
		local m = getmetatable(x)
		if (level and level <= 0) or (m and m.__tostring) then
			-- End of recursion, or the table has a custom tostring()
			return tostring(x)
		else
			-- Recursively print a whole table
			local t = {}
			for k, v in pairs(x) do
				if type(k) == "string" and k:match("^%w+$") then
					-- Key can be unquoted because it is a valid identifier word
					t[1 + #t] = k .. " = " .. quote(v, next_level)
				else
					t[1 + #t] = "[" .. quote(k, next_level) .. "] = " .. quote(v, next_level)
				end
			end
			return table.concat({"{", table.concat(t, ", "), "}"})
		end
	else
		return tostring(x)
	end
end


-- Queue object
Queue = {}
Queue.mt = {}

function Queue.new()
  local obj = {first = 0, last = -1}
  return setmetatable(obj, Queue.mt)
end

function Queue:isEmpty()
    return self.last < self.first
end

function Queue:put(value)
  local last = self.last + 1
  self.last = last
  self[last] = value
end

function Queue:pop()
  local first = self.first
  if first > self.last then
      --error("Queue is empty")
      return nil
  end
  local value = self[first]
  self[first] = nil        -- to allow garbage collection
  self.first = first + 1
  
  -- Indices can reset if empty
  if Queue.isEmpty(self) then
    self.first = 0
    self.last = -1
  end
  
  return value
end


-- Sparse 2D grid
Sparse2D = {}
Sparse2D.mt = {}

function Sparse2D.new()
  return setmetatable({}, Sparse2D.mt)
end


-- Lookup table with a keys being defined as equal if the 2 elements are equal
-- If the key is not present, fall back on rawget()
Sparse2D.mt.__index = function(table, key)
	if type(key) == 'table' then
    if #key == 2 then
      local a, b = unpack(key)
      for k, v in pairs(table) do
        if k[1] == a and k[2] == b then
          return v
        end
      end
    end
    return nil
  end
  return rawget(table, key)
end


Sparse2D.mt.__newindex = function(table, key, val)
	if type(key) == 'table' then
    if #key == 2 then
      local a, b = unpack(key)
      for k, v in pairs(table) do
        if k[1] == a and k[2] == b then
          rawset(table, k, val)
          return
        end
      end
    end
  end
  return rawset(table, key, val)
end


-- Check if a table contains a value as a member.
function member(item, table)
  for _, val in pairs(table) do
    if item == val then
      return true
    end
  end
  return false
end
