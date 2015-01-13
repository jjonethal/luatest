-- mini.lua
words = {}
stack = {sp=0}
image = {}
macros= {} --- immediate words
words["."]        = function() print(words.pop()) end
words.wraplv      = function(v) local f=loadstring("return function(v) if v~= nil then "..v.." = v else words.push("..v..") end")() words.push(f) end
words.createConst = function(w,ws) local v = words.pop() words[w] = function() words.push(v) end words.wordParser = words.interpret end
words.constant    = function()  words.wordParser = words.createConst end
words.push        = function(v) stack.sp = stack.sp + 1 stack[stack.sp] = v end
words.pop         = function()	assert(stack.sp > 0) local v,sp = stack[stack.sp],stack.sp-1 stack[stack.sp],stack.sp = nil,sp return v end
words.macro       = function(w) return (macros[w] ~= nil and (macros[w]() or true)) or false end
words.word        = function(w) return (words[w] ~= nil and (words[w]() or true)) or false end
words.number      = function(w) local n = tonumber(w) return (n ~= nil and (words.push(n) or true)) or false end
words.fail        = function()  print("failed") end
words.interpret   = function(w,ws) _ = words.macro(w) or words.word(w) or words.number(w) or words.fail() end
words.wordParser  = words.interpret
words.parseWords  = function(w,ws) words.wordParser(w,ws) end
words.parseLine   = function(l, le) l:gsub("([%S]+)([%s]*)", words.parseWords) end
words.lineParser  = words.parseLine
-- parse the string source as lines 
words.parseSource = function (s) s:gsub("([^\r\n]*[\n]?)",words.lineParser) end
words.variable    = function() words.wordParser = words.createVar end
words.heap        = 1
words.createVar   = function(w,ws) local v = words.heap words.heap=words.heap+1 words[w] = function() words.push(v) end words.wordParser = words.interpret end

source = " 12 constant hallo hallo ."
words.parseSource(source)
