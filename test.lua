-- test.lua

function stack_test()
	local s,t1={},os.clock()
	for i=1,1000000000 do
		s[#s+1] = 1
		s[#s]   = nil
	end 
	print("stack_test",#s,os.clock()-t1)
end

function add_test()
	local s,t1 = 0,os.clock()
	for i=1,1000000000 do
		s = s + 1
		s = s - 1
	end 
	print("add_test",s,os.clock() - t1)
end

function stack_test2()
	local s,sp,t1 = {},0,os.clock()
	for i = 1,1000000000 do
		sp      = sp + 1
		s[sp]   = 1
		s[sp]   = nil
		sp      = sp - 1
	end 
	print("stack_test2",#s,os.clock() - t1)
end


stack_test()
add_test()
stack_test2()

