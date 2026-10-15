-- fanyi_core.lua —— 译词功能的共享核心（配置、词典、查询、comment 改写）
-- 供 fanyi.lua（filter）与 fanyi_commit.lua（processor）复用。

local M = {}

-- ------------------------- 全局状态 -------------------------
local dict = nil            -- 主译词表: { [中文] = 译词字符串 }
local overrides = nil       -- 覆盖表: 优先于主词典
local loaded_name = nil     -- 当前已加载的词典名
local failed_name = nil     -- 加载失败过的词典名
local overrides_loaded = false
local cfg = {}

local CFG_DEFAULT = {
  enabled = true,
  mode = "replace",
  separator = " · ",
  dictionary = "cn2en",
  overrides = "cn_overrides",
  commit_key = "Control+Return",
  commit_enabled = true,
}

-- ------------------------- 日志 -------------------------
local function log_info(msg)
  if log and log.info then log.info("[fanyi] " .. tostring(msg)) end
end
local function log_error(msg)
  if log and log.error then
    log.error("[fanyi] " .. tostring(msg))
  elseif log and log.info then
    log.info("[fanyi][error] " .. tostring(msg))
  end
end
M.log_info = log_info
M.log_error = log_error

-- ------------------------- 配置 -------------------------
local function has_key(c, key)
  local ok, item = pcall(function() return c:get_item(key) end)
  if not ok or item == nil then return false end
  return item.type ~= nil and item.type ~= "kNull"
end

function M.load_config(env)
  cfg.enabled = CFG_DEFAULT.enabled
  cfg.mode = CFG_DEFAULT.mode
  cfg.separator = CFG_DEFAULT.separator
  cfg.dictionary = CFG_DEFAULT.dictionary
  cfg.overrides = CFG_DEFAULT.overrides
  cfg.commit_key = CFG_DEFAULT.commit_key
  cfg.commit_enabled = CFG_DEFAULT.commit_enabled

  local ok, c = pcall(function() return env.engine.schema.config end)
  if not ok or c == nil then return end

  if has_key(c, "fanyi/enabled") then cfg.enabled = c:get_bool("fanyi/enabled") end
  if has_key(c, "fanyi/commit_enabled") then cfg.commit_enabled = c:get_bool("fanyi/commit_enabled") end

  local mode = c:get_string("fanyi/mode")
  if mode ~= nil and mode ~= "" then cfg.mode = mode end
  local sep = c:get_string("fanyi/separator")
  if sep ~= nil and sep ~= "" then cfg.separator = sep end
  local dn = c:get_string("fanyi/dictionary")
  if dn ~= nil and dn ~= "" then cfg.dictionary = dn end
  local ov = c:get_string("fanyi/overrides")
  if ov ~= nil and ov ~= "" then cfg.overrides = ov end
  local ck = c:get_string("fanyi/commit_key")
  if ck ~= nil and ck ~= "" then cfg.commit_key = ck end
end

function M.get_cfg() return cfg end

-- ------------------------- 词典加载 -------------------------
local function load_dict_from(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local t = {}
  for line in f:lines() do
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local zh, en = line:match("^([^\t]+)\t(.+)$")
      if zh and en then
        zh = zh:gsub("%s+$", "")
        en = en:gsub("^%s+", ""):gsub("%s+$", "")
        if zh ~= "" and en ~= "" then t[zh] = en end
      end
    end
  end
  f:close()
  return t
end

local function user_dir()
  local ok, dir = pcall(function() return rime_api.get_user_data_dir() end)
  if ok and dir then return dir end
  return nil
end

local function ensure_overrides(ud)
  if overrides_loaded then return end
  overrides_loaded = true
  overrides = {}
  if not ud then return end
  local name = cfg.overrides or "cn_overrides"
  for _, p in ipairs({ ud .. "/" .. name .. ".tsv", ud .. "/fanyi/" .. name .. ".tsv" }) do
    local t = load_dict_from(p)
    if t then
      overrides = t
      local n = 0; for _ in pairs(t) do n = n + 1 end
      log_info(string.format("覆盖表已加载: %s（%d 条）", p, n))
      return
    end
  end
end

function M.ensure_dict(env)
  local dname = cfg.dictionary or "cn2en"
  local ud = user_dir()
  ensure_overrides(ud)

  if loaded_name == dname then return end
  if failed_name == dname then return end

  local candidates = {}
  if ud then
    candidates[#candidates + 1] = ud .. "/" .. dname .. ".tsv"
    candidates[#candidates + 1] = ud .. "/fanyi/" .. dname .. ".tsv"
  end
  for _, p in ipairs(candidates) do
    local t = load_dict_from(p)
    if t then
      dict = t
      loaded_name = dname
      failed_name = nil
      local n = 0; for _ in pairs(t) do n = n + 1 end
      log_info(string.format("词典已加载: %s（%d 条）", p, n))
      return
    end
  end
  dict = {}
  failed_name = dname
  log_info("未找到词典文件 '" .. dname .. ".tsv'，译词功能将不显示内容")
end

-- ------------------------- 查询 -------------------------
function M.lookup(text)
  if not text or text == "" then return nil end
  if overrides and overrides[text] then return overrides[text] end
  if dict then return dict[text] end
  return nil
end

-- ------------------------- comment 改写 -------------------------
function M.process_candidate(cand)
  local trans = M.lookup(cand.text)
  if not trans then return end
  local cfgv = cfg
  local target = cand
  local ok, g = pcall(function() return cand:get_genuine() end)
  if ok and g ~= nil then target = g end
  local old = target.comment or ""
  if cfgv.mode == "replace" then
    target.comment = trans
  else
    if old ~= "" then
      target.comment = old .. cfgv.separator .. trans
    else
      target.comment = trans
    end
  end
end

return M
