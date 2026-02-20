--!strict
-- Test Runner Bootstrap
-- Studio Run (F5) 시 TestEZ로 .spec 파일 수집 및 실행

local TestService = game:GetService("TestService")

local TestEZ = require(TestService.TestEZ)

-- .spec 모듈 수집
local testModules = {}
for _, descendant in TestService.Tests:GetDescendants() do
	if descendant:IsA("ModuleScript") and descendant.Name:match("%.spec$") then
		table.insert(testModules, descendant)
	end
end

print("[TestRunner] Found " .. #testModules .. " spec modules")

-- TestEZ 실행
TestEZ.TestBootstrap:run(testModules)
