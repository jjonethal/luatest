-- Encoding:UTF-8 "ä" == "&auml;"
-- meta compiler
-- on windows os.execute("chcp 65001")
-- os.execute("chcp 65001")
meta  = {}             -- table of meta compiler definitions
stack = {sp = 0,}      -- the parameter stack
macro = {}             -- table contining all macro definitions
img   = {}             -- table containing binary image
mem   = {}             -- table for storing integers
meta.heap = 0          -- variable holding reference to heap
-- start lua definition
meta[":L"]       = function() wordParser = parseLua     luaWord = "" end

-- debugging stuff
function printf(fmt,...) io.write(fmt:format(...)) end
function debug(...)  print(...)  end
function debugf(...) printf(...) end
----------------- stack operations -----------------------------
--- put a new value onto stack
-- @param n the item to be placed on parameter stack.
function push(n)                         
	stack.sp        = stack.sp + 1       -- increment stack pointer     
	stack[stack.sp] = n                  -- put item onto stack
end

--- get item from parameter stack
function pop()
	assert(stack.sp > 0,"stack underflow")
	local n         = stack[stack.sp]
	stack[stack.sp] = nil
	stack.sp        = stack.sp - 1
	return n
end

--- generate replacement for binary operations
BIN_OPS          = "+-*/%"
function genBinOp(op)
	meta[op] = loadstring("local t = pop() local n = pop() push(n ".. op .. " t)")
end
BIN_OPS:gsub("(.)",genBinOp)

-- start variable definition
function meta.variable()
	wordParser = createVar    -- redirect word parser to retrieve wariable name
	varName    = ""
end

--- create new variable on heap
-- @param word the name of variable
-- @param ws not used
function createVar(word,ws)
	local adr  = meta.heap                  -- get current heap adress
	meta.heap  = meta.heap + 1              -- increment heap adress
	meta[word] = function() push(adr) end   -- create function for placing heap adress of variable on stack
	wordParser = interpret                  -- restore default word parser
end

--- print top of stack
meta["."]  = function() print(pop())                         end
--- store to variable
meta["!"]  = function() local a = pop() meta[a] = pop()      end
--- fetch variable from index on stack
meta["@"]  = function() push(meta[pop()])                    end
--- start high level definition
meta[":"]  = function() wordParser = createHll               end
--- open file on file system
meta.open  = function()  -- open file ( "filename" "mode" -- )
	local m   = pop()
	local n   = pop()
	meta.file = io.open(n,m)
	end
--- write data to file
meta.write  = function() meta.file:write(pop())              end -- write string ( s -- )
--- close file
meta.close  = function() meta.file:close() meta.file = nil   end -- close file
--- write a byte to file
meta.bwrite = function() meta.file:write(string.char(pop())) end -- write binary byte
--- move command as immediate
macro.immediate = function()
		macro[meta.currentWord] = meta[meta.currentWord]
		meta[meta.currentWord]  = nil
		meta.currentWord        = nil
	end
macro["if"] = function()
		meta[meta.currentWord] = meta[meta.currentWord] .. " meta.bool() if pop() then "
	end

function create_constant(word, ws)
	local v = pop()
	meta[word] = function() push(v) end
	wordParser = interpret
end

function macro.constant() wordParser = create_constant end

--- assemble lua definition
function parseLua(word,ws)
	if word == "L;" then
		luaFunc,err = loadstring(luaWord)
		if(luaFunc == nil) then
			print("Error ",err)
		end
		luaFunc()
		wordParser = interpret
	else
		luaWord    = luaWord .. word .. ( ws or "" )
	end
end

function interpret(word,ws)
	if macro[word] then
		macro[word]()
	elseif(meta[word]) then
		meta[word]()
	elseif tonumber(word) ~= nil then
		push(tonumber(word))
	else
		print("\nword unknown", word)
		assert(false,word)
	end
end

-- create new HLL definition word
function createHll(word,ws)
	meta.currentWord = word
	meta[word]=" "
	wordParser = compCompileWords
end

-- end high level definition colon 
macro[";"] = function()
	wordParser = interpret
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
		currentString = currentString .. word .. (ws or "")
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
function skipCommentLine(word, ws)
	if ws == "\n" then
		wordParser = skipLineOrgParser
	end
end

-- skip block comment
function skipCommentBlock(word,ws)
	-- print(" comment skip ")
	if word == ")" then
		wordParser = skipCommentOrgParser
	end
end

macro["\\"] = function() skipLineOrgParser    = wordParser wordParser = skipCommentLine  end
macro["("]  = function() skipCommentOrgParser = wordParser wordParser = skipCommentBlock end

--- high level compiler.
-- a word parser class function
-- assemble the function definition as lua sequence of function invocations.
-- words found in macro dictionary are invoked directly
-- meta words assembled into function invocations
-- numbers / literals assembled as invocation to push
-- @param word the current word to be compiled or executed 
function compCompileWords(word,ws)
	if macro[word] then
		macro[word]()
	elseif(meta[word]) then
		meta[meta.currentWord] = meta[meta.currentWord] .. " meta['" .. word.."']() "
	elseif tonumber(word) ~= nil then
		meta[meta.currentWord] = meta[meta.currentWord] .. " push(tonumber(" .. word ..")) "
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

--- Variable / state initialization
wordParser = interpret --- reference to current word parser
lineNumber = 0         --- counter for source line numbers
lineParser = parseLine --- reference to current line parser

source = [[
:L A = 1 + 1 print(A) L;
:L meta["."] = function() print(pop()) end L;
:L meta["!"] = function() local a = pop() meta[a] = pop() end L;
:L meta["@"] = function() push(meta[pop()]) end L;
:L meta[":"] = function() wordParser = createHll end L;
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

	
\ this is a line comment
( this is a block comment )

: p13 1 3 . . ;                 \ test word creation and stack print
p13
variable c                      \ test variable creation
15 c !
c @ .
15 .
: test if 17 else 18 then . ;   \ create definition test
1 test                          \ 1 is boolean true
0 test                          \ 0 is boolean false
3 4 + .                         \ test add
3 4 * .                         \ test multiply
3 4 - .                         \ test substract
3 4 / .                         \ test division
3 4 % .                         \ test modulo
0xff 4 % .                      \ test modulo
100 .                           \ print 100
" Hello World" 2 !              \ put string on index 2
2 @ .                           \ print item at index 2
: true  1 bool ;
: false 0 bool ;
true  .
false .
]]

parseSource(source)
for k,v in pairs(meta) do print(k,v) end

