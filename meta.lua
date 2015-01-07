-- meta compiler
meta  = {}
stack = {sp = 0,}
meta  = {}
macro = {}
img   = {}
mem   = {}
meta.heap = 0
meta[":L"]       = function() wordParser = parseLua     luaWord = "" end
meta["variable"] = function() wordParser = parseVarName varName = "" end
BIN_OPS          = "+-*/%"

function genBinOp(op)
	meta[op] = loadstring("local t = pop() local n = pop() push(n ".. op .. " t)")
end

BIN_OPS:gsub("(.)",genBinOp)

function parseVarName(word,ws)
	local adr  = meta.heap
	meta.heap  = meta.heap + 1
	meta[word] = function() push(adr) end
	wordParser = parseWord
end

function push(n)
	stack.sp        = stack.sp + 1
	stack[stack.sp] = n
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

-- high level compiler
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

-- convert value on stack to boolen
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

wordParser = parseWord
lineNumber = 0

function wordParserImpl(w,ws)
	wordParser(w,ws)
end


function parseLine(l)
	lineNumber = lineNumber + 1
	io.write(string.format("%5d ",lineNumber))
	io.write(l)
	l:gsub("([%S]+)([%s]*)", wordParserImpl)
end

lineParser = parseLine

function lineParserImpl(l, le)
	lineParser(l,le)
end

function parseSource(source)
	source:gsub("([^\r\n]*\n)",lineParserImpl)
end

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
\ ( klkj sdl”k ”lfd s”lkj gfsd )
\ das ist ein comment
100 .
( ”klj a”lkd”k ”lkj )
" Hallo Leute" 2 !
2 @ .
]]
parseSource(source)
for k,v in pairs(meta) do print(k,v) end

