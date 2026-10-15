-- test_fanyi.lua —— 脱离 librime 环境验证 fanyi.lua 的核心逻辑
-- 用法：lua test_fanyi.lua

-- ---- mock librime 全局 ----
-- 建立临时用户目录与受控测试词典，避免依赖真实词典内容
local test_dir = os.getenv("TMPDIR") or "/tmp"
test_dir = test_dir .. "/fanyi_unittest"
os.execute("mkdir -p " .. test_dir)

local function write_dict(name, content)
  local f = assert(io.open(test_dir .. "/" .. name, "w"))
  f:write(content)
  f:close()
end

write_dict("testen.tsv", table.concat({
  "# test dict",
  "开发\tdevelop / development",
  "好\tgood / well",
  "女孩子\tgirl",
}, "\n"))
write_dict("testja.tsv", table.concat({
  "开发\t開発（かいはつ）",
  "好\t良い（よい）",
}, "\n"))
-- 覆盖表：把"开发"覆盖为常用义
write_dict("testov.tsv", table.concat({
  "开发\tdevelop / development",
}, "\n"))

local user_dir = test_dir
log = { info = function(s) print("[log] " .. s) end }

rime_api = {
  get_user_data_dir = function() return user_dir end,
}

-- mock Candidate：带 text/comment
local Candidate = {}
Candidate.__index = Candidate
function Candidate.new(text, comment)
  return setmetatable({ text = text, comment = comment or "" }, Candidate)
end
function Candidate:get_genuine()
  return self
end
function Candidate:get_dynamic_type()
  return "Simple"
end

-- mock translation 迭代器
local Translation = {}
Translation.__index = Translation
function Translation.new(list)
  return setmetatable({ _list = list }, Translation)
end
function Translation:iter()
  local i = 0
  local n = #self._list
  return function()
    i = i + 1
    if i <= n then return self._list[i] end
  end
end

-- mock yield 收集器
local yielded = {}
local function reset() yielded = {} end
function yield(c) yielded[#yielded + 1] = c end

-- ---- mock schema config ----
local function make_env(opts)
  opts = opts or {}
  local function present(key)
    if key == "fanyi/enabled" then return opts.enabled ~= nil end
    if key == "fanyi/mode" then return opts.mode ~= nil end
    if key == "fanyi/separator" then return opts.separator ~= nil end
    if key == "fanyi/dictionary" then return opts.dictionary ~= nil end
    if key == "fanyi/overrides" then return opts.overrides ~= nil end
    if key == "fanyi/commit_key" then return opts.commit_key ~= nil end
    if key == "fanyi/commit_enabled" then return opts.commit_enabled ~= nil end
    return false
  end
  local config = {
    get_item = function(self, key)
      if present(key) then return { type = "kScalar" } end
      return { type = "kNull" }
    end,
    get_bool = function(self, key)
      if key == "fanyi/enabled" then return opts.enabled end
      if key == "fanyi/commit_enabled" then return opts.commit_enabled end
      return false
    end,
    get_string = function(self, key)
      if key == "fanyi/mode" then return opts.mode or "" end
      if key == "fanyi/separator" then return opts.separator or "" end
      if key == "fanyi/dictionary" then return opts.dictionary or "" end
      if key == "fanyi/overrides" then return opts.overrides or "" end
      if key == "fanyi/commit_key" then return opts.commit_key or "" end
      return ""
    end,
  }
  return {
    engine = { schema = { config = config } },
    name_space = "fanyi",
  }
end

-- ---- 加载被测模块 ----
-- 便于从任意目录运行：定位到脚本所在目录
local script_dir = (arg and arg[0] and arg[0]:match("^(.*)/[^/]*$")) or "."
package.path = script_dir .. "/lua/?.lua;" .. package.path
local M = dofile(script_dir .. "/lua/fanyi.lua")
assert(type(M.func) == "function", "未导出 M.func")

local function run(env, candidates)
  reset()
  M.func(Translation.new(candidates), env)
  return yielded
end

-- ---- 测试 ----
local pass, fail = 0, 0
local function check(name, got, want)
  if got == want then
    pass = pass + 1
    print(string.format("  ✓ %s", name))
  else
    fail = fail + 1
    print(string.format("  ✗ %s\n      期望: %q\n      实际: %q", name, want, got))
  end
end

print("== 测试 1：append 模式，有码提示 + 无码提示 ==")
local env1 = make_env({ mode = "append", dictionary = "testen" })
local out1 = run(env1, {
  Candidate.new("女孩子", "bbbb"),
  Candidate.new("好", ""),
  Candidate.new("不存在词", "xxxx"),
})
check("有码提示拼接", out1[1].comment, "bbbb · girl")
check("无码提示直接显示", out1[2].comment, "good / well")
check("未收录词不变", out1[3].comment, "xxxx")

print("== 测试 2：replace 模式（默认）==")
local env2 = make_env({ dictionary = "testen" })
local out2 = run(env2, {
  Candidate.new("女孩子", "bbbb"),
  Candidate.new("好", ""),
})
check("默认即 replace，覆盖有码提示", out2[1].comment, "girl")
check("replace 无码提示", out2[2].comment, "good / well")

print("== 测试 3：自定义分隔符 ==")
local env3 = make_env({ mode = "append", separator = " | ", dictionary = "testen" })
local out3 = run(env3, { Candidate.new("开发", "gayt") })
check("自定义分隔符", out3[1].comment, "gayt | develop / development")

print("== 测试 4：enabled=false 时不改动 ==")
local env4 = make_env({ enabled = false, dictionary = "testen" })
local out4 = run(env4, { Candidate.new("好", "h") })
check("关闭时原样输出", out4[1].comment, "h")

print("== 测试 5：切换词典（中→日）==")
local env5 = make_env({ dictionary = "testja" })
local out5 = run(env5, { Candidate.new("开发", ""), Candidate.new("好", "") })
check("日语词典 开发", out5[1].comment, "開発（かいはつ）")
check("日语词典 好", out5[2].comment, "良い（よい）")

print("== 测试 6：覆盖表优先于主词典 ==")
local env6 = make_env({ dictionary = "testen", overrides = "testov" })
local out6 = run(env6, { Candidate.new("开发", "") })
check("覆盖表生效", out6[1].comment, "develop / development")

print(string.format("\n结果：%d 通过, %d 失败", pass, fail))
os.exit(fail == 0 and 0 or 1)
