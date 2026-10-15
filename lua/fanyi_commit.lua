-- fanyi_commit.lua —— 译词上屏处理器（processor）
-- 挂载："engine/processors/@before 0": lua_processor@*fanyi_commit
--
-- 行为：输入过程中高亮某候选，按 commit_key（默认 Ctrl+Enter），
--       若该候选有译词，则把译词整串上屏并清空当前输入；
--       无译词时不做任何动作（返回 kNoop）。
--
-- 配置：fanyi/commit_enabled（开关）、fanyi/commit_key（快捷键）。
-- 快捷键写法：修饰键用 + 连接，键名取 KeyEvent 的键名，例如
--   "Control+Return"、"Control+Shift+Return"、"Alt+Return"、"Control+space"。

local core = require("fanyi_core")
local M = {}

-- 解析快捷键字符串 → { ctrl=, alt=, super=, shift=, key= }
local function parse_key(s)
  local spec = { ctrl = false, alt = false, super = false, shift = false, key = nil }
  if not s or s == "" then return spec end
  for part in s:gmatch("[^+]+") do
    local d = part:lower()
    if d == "control" or d == "ctrl" then
      spec.ctrl = true
    elseif d == "alt" or d == "option" then
      spec.alt = true
    elseif d == "super" or d == "command" or d == "cmd" then
      spec.super = true
    elseif d == "shift" then
      spec.shift = true
    else
      spec.key = d
    end
  end
  return spec
end

-- key_event 修饰键既可作方法也可作属性，这里统一取值
local function ke_bool(ke, name)
  local v = ke[name]
  if type(v) == "function" then
    local ok, r = pcall(v, ke)
    if ok then return r end
    return false
  end
  return v and true or false
end

local function is_release(ke)
  local v = ke.release
  if type(v) == "function" then
    local ok, r = pcall(v, ke)
    return ok and r or false
  end
  return v and true or false
end

local function key_repr(ke)
  local v = ke.repr
  if type(v) == "function" then
    local ok, r = pcall(v, ke)
    if ok then return r end
  end
  return v
end

local function key_matches(ke, spec)
  if spec.ctrl ~= ke_bool(ke, "ctrl") then return false end
  if spec.alt ~= ke_bool(ke, "alt") then return false end
  if spec.super ~= ke_bool(ke, "super") then return false end
  if spec.shift ~= ke_bool(ke, "shift") then return false end
  local repr = key_repr(ke)
  if not repr then return false end
  local r = tostring(repr):lower()
  local last = r:match("([^+]+)$") or r
  return last == spec.key
end

function M.init(env)
  core.log_info("上屏处理器已初始化")
end

function M.func(key_event, env)
  if is_release(key_event) then return 2 end  -- kNoop

  core.load_config(env)
  local cfg = core.get_cfg()
  if not cfg.enabled or not cfg.commit_enabled then return 2 end

  local spec = parse_key(cfg.commit_key)
  if not key_matches(key_event, spec) then return 2 end

  local ctx = env.engine.context
  local cand = ctx:get_selected_candidate()
  if not cand then return 2 end

  local ok = pcall(core.ensure_dict, env)
  if not ok then return 2 end

  local trans = core.lookup(cand.text)
  if not trans or trans == "" then return 2 end

  local cok, cerr = pcall(function()
    ctx:clear()
    env.engine:commit_text(trans)
  end)
  if not cok then
    core.log_error("上屏失败: " .. tostring(cerr))
    return 2
  end
  core.log_info("译词上屏: " .. trans)
  return 1  -- kAccepted
end

function M.fini(env)
  core.log_info("上屏处理器已卸载")
end

return M
