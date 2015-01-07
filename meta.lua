--ÑÑÑÑ
-- meta compiler
meta  = {}             -- table of meta compiler definitions
stack = {sp = 0,}      -- the parameter stack
macro = {}             -- table contining all macro definitions
img   = {}             -- table containing binary image
mem   = {}             -- table for storing integers
meta.heap = 0          -- variable holding reference to heap
-- start lua definition
meta[":L"]       = function() wordParser = parseLua     luaWord = "" end

BIN_OPS          = "+-*/%"
function genBinOp(op)
	meta[op] = loadstring("local t = pop() local n = pop() push(n ".. op .. " t)")
end
BIN_OPS:gsub("(.)",genBinOp)

-- start variable definition
meta["variable"] = function()
	wordParser = parseVarName    -- redirect word parser to retrieve wariable name
	varName    = ""
end

meta["."] = function() print(pop()) end
meta["!"] = function() local a = pop() meta[a] = pop() end
meta["@"] = function() push(meta[pop()]) end
meta[":"] = function() wordParser = compCreateToken end

macro.immediate = function()
		macro[meta.currentWord] = meta[meta.currentWord]
		meta[meta.currentWord]  = nil
		meta.currentWord        = nil
	end
macro["if"] = function()
		meta[meta.currentWord] = meta[meta.currentWord] .. " meta.bool() if pop() then "
	end
--- create new variable on heap
-- @param word the name of variable
-- @param ws not used
function parseVarName(word,ws)
	local adr  = meta.heap                  -- get current heap adress
	meta.heap  = meta.heap + 1              -- increment heap adress
	meta[word] = function() push(adr) end   -- create function for placing heap adress of variable on stack
	wordParser = parseWord                  -- restore default word parser
end

--- put a new value onto stack
-- @param n the item to be placed on stack.
function push(n)                         
	stack.sp        = stack.sp + 1       -- increment stack pointer     
	stack[stack.sp] = n                  -- put item onto stack
end

function parseLua(word,ws)
	if word == "L;" then
		luaFunc,err = loadstring(luaWord)
		if(luaFunc == nil) then
			print("Error ",err)
		end
		luaFunc()
		wordParser = parseWord
	else
		luaWord    = luaWord .. word .. ws
	end
end

function pop()
	assert(stack.sp > 0,"stack underflow")
	local n         = stack[stack.sp]
	stack[stack.sp] = nil
	stack.sp        = stack.sp - 1
	return n
end

function pushNumber(n)
	if n < -32768 or n > 32767 then
		push(math.floor(n/65536))
	end
	push(math.floor(n % 65536))
end

function pushNumber(n)
	push(n)
end


function parseWord(word,ws)
	if macro[word] then
		macro[word]()
	elseif(meta[word]) then
		meta[word]()
	elseif tonumber(word) ~= nil then
		pushNumber(tonumber(word))
	else
		print("\nword unknown", word)
		assert(false,word)
	end
end

-- create new HLL definition word
function compCreateToken(word,ws)
	meta.currentWord = word
	meta[word]=" "
	wordParser = compCompileWords
end

-- end high level definition colon 
macro[";"] = function()
	wordParser = parseWord
	local cw   = meta.currentWord
	meta[cw]   = meta[cw] .. " "
	local cf,e = loadstring(meta[cw])
	if e then
		print("error:",e)
		meta[cw] = nil
	else
		meta[cw] = cf
	end
end

-- assemble a string and put it to stack
function stringBuilder(word,ws)
	local s = string.match(word, "([^\"]*)")
	-- print("sb match:",s)
	if s == word then
		currentString = currentString .. word .. ws
	else
		currentString = currentString .. ( s or "" )
		-- print("string compiled:",currentString)
		push(currentString)
		wordParser = stringBuilderOrgParser
	end
end

-- compile string object to stack
macro['"'] = function()
	stringBuilderOrgParser = wordParser
	wordParser = stringBuilder
	currentString = ""
end

-- skip comment line
function skipLine(word, ws)
	if ws == "\n" then
		wordParser = skipLineOrgParser
	end
end

-- skip block comment
function skipComment(word,ws)
	print(" comment skip ")
	if word == ")" then
		wordParser = skipCommentOrgParser
	end
end

macro["\\"] = function() skipLineOrgParser = wordParser wordParser = skipLine end
macro["("]  = function() skipCommentOrgParser = wordParser wordParser = skipComment end

--- high level compiler.
-- a word parser class function
-- assemble the function definition as lua sequence of function invocations.
-- words found in macro dictionary are invoked directly
-- meta words assembled into function invocations
-- numbers / literals assembled as invocation to pushNumber
-- @param word the current word to be compiled or executed 
function compCompileWords(word,ws)
	if macro[word] then
		macro[word]()
	elseif(meta[word]) then
		meta[meta.currentWord] = meta[meta.currentWord] .. " meta['" .. word.."']() "
	elseif tonumber(word) ~= nil then
		meta[meta.currentWord] = meta[meta.currentWord] .. " pushNumber(tonumber(" .. word ..")) "
	else
		print("\nword unknown", word)
		assert(false,word)
	end
end

--- convert value on stack to boolean.
function meta.bool()
	local v = pop()
	if type(v)=="boolean" then
		push(v)
	elseif type(v) == "number" then
		push(v~=0)
	else
		push(v~=nil)
	end
end

--- Redirection to invoke current word parser.
-- @param w the current word string
-- @param ws the white spaces following the current word
function wordParserImpl(w,ws)
	wordParser(w,ws)
end

--- Default line parser.
-- splits line into words and white spaces and handover the words to word parser
-- white spaces might be required to reassemble strings and comments
-- @param l the current line to be parsed
function parseLine(l)
	lineNumber = lineNumber + 1                -- increment line number
	io.write(string.format("%5d ",lineNumber)) -- output debug info line number
	io.write(l)                                -- output current line
	l:gsub("([%S]+)([%s]*)", wordParserImpl)   -- split line into words and whitespaces
end

-- invoke redirector for line parser 
-- line parser can be redirected by application
function lineParserImpl(l, le)
	lineParser(l,le)              -- redirect lineParser for later
end

-- parse the string source as lines 
function parseSource(source)
	source:gsub("([^\r\n]*\n)",lineParserImpl)  -- parse all lines
end


wordParser = parseWord --- reference to current word parser
lineNumber = 0         --- counter for source line numbers
lineParser = parseLine --- reference to current line parser


source = [[
:L A = 1 + 1 print(A) L;
:L meta["."] = function() print(pop()) end L;
:L meta["!"] = function() local a = pop() meta[a] = pop() end L;
:L meta["@"] = function() push(meta[pop()]) end L;
:L meta[":"] = function() wordParser = compCreateToken end L;
:L macro.immediate = function()
		macro[meta.currentWord] = meta[meta.currentWord]
		meta[meta.currentWord]  = nil
		meta.currentWord        = nil
	end	L;
:L macro["if"] = function()
	meta[meta.currentWord] = meta[meta.currentWord] .. " meta.bool() if pop() then "
	end L;
:L macro["else"] = function()
	meta[meta.currentWord] = meta[meta.currentWord] .. " else "
	end L;
:L macro["then"] = function()
	meta[meta.currentWord] = meta[meta.currentWord] .. " end "
	end L;

variable c
variable last-word
: p13 1 3 . . ;
p13
15 c !
c @ .
15 .
: test if 17 else 18 then . ;
1 test
0 test
3 4 + .
3 4 * .
3 4 - .
3 4 / .
3 4 % .
0xff 4 % .
\ ( klkj sdlk lfd slkj gfsd )
\ das ist ein comment
100 .
( klj ÅÅÅ îîîî  alkdk lkj )
" Hallo Leute" 2 !
2 @ .
]]

parseSource(source)
for k,v in pairs(meta) do print(k,v) end

