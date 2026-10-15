-- fanyi.lua —— 候选词外语译词滤镜（filter）
-- 挂载：engine/filters: [ lua_filter@*fanyi ]
--
-- 注意：必须把 func 放在模块顶层，挂载写 lua_filter@*fanyi，
--       不能写 lua_filter@*fanyi.filter（librime 会把 ".filter" 当子路径，
--       导致组件解析异常、候选栏变空）。
--       译词上屏的处理器在 fanyi_commit.lua（lua_processor@*fanyi_commit）。

local core = require("fanyi_core")
local M = {}

function M.init(env)
  core.log_info("滤镜已初始化")
end

function M.func(translation, env)
  core.load_config(env)
  local cfg = core.get_cfg()

  local dict_ready = true
  if cfg.enabled then
    local ok, err = pcall(core.ensure_dict, env)
    if not ok then
      core.log_error("加载词典失败: " .. tostring(err))
      dict_ready = false
    end
  end

  for cand in translation:iter() do
    if cfg.enabled and dict_ready then
      local pok, perr = pcall(core.process_candidate, cand)
      if not pok then
        core.log_error("处理候选 '" .. tostring(cand.text) .. "' 失败: " .. tostring(perr))
      end
    end
    yield(cand)
  end
end

function M.fini(env)
  core.log_info("滤镜已卸载")
end

return M
