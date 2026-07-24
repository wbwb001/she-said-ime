-- feminist.lua
-- 她说输入法 · 女性主义候选过滤插件 v5
--
-- ⚙️ 模式设置（运行时读 feminist.config 文件，可热更新）：
--   "minimal"  = 温和模式：只标严重辱女词(🔴)，其他不显示
--   "standard" = 标准模式：辱女词分级(🔴🟠🟢)+平替+教育提示(📖) ← 默认
--   "full"     = 全面模式：标准模式 + 新词推荐✨ + 双标对照⚖ + 夸奖陷阱⭐ + 控制语言💬
--
-- 设置方法：
--   1. 在 Rime 用户目录(用户文件夹)的 feminist.config 文件写一行 "full" 即可
--   2. 重新部署 Rime 后生效
--   3. 后续 App 设置页会写这个文件

local function read_mode_from_config()
  -- 默认值
  local mode = "standard"

  -- 尝试读 Rime 配置目录的 feminist.config
  local config_path = rime_api.get_user_data_dir() .. "/feminist.config"
  local f = io.open(config_path, "r")
  if f then
    local content = f:read("*l")  -- 读第一行
    f:close()
    if content then
      content = content:match("^%s*(.-)%s*$")  -- trim
      if content == "minimal" or content == "standard" or content == "full" then
        mode = content
      end
    end
  end

  return mode
end

local MODE = read_mode_from_config()

print("feminist.lua: MODE = " .. MODE)

-- ============================================================

local data = require("feminist_data")

local function split_alt(alt_str)
  local result = {}
  if not alt_str or alt_str == "" then return result end
  for part in string.gmatch(alt_str, "([^/]+)") do
    local t = part:match("^%s*(.-)%s*$")
    if t and t ~= "" then
      table.insert(result, t)
    end
  end
  return result
end

local function filter(input, env)
  for cand in input:iter() do
    local txt = cand.text
    local yielded = false
    local w = data.warn[txt]

    -- ============ 模式判断 ============
    if MODE == "minimal" then
      -- 温和模式：只标 severe 词
      if w and w.level == "severe" then
        cand:get_genuine().comment = "🔴"
        yield(cand)
        yielded = true
      end
      if not yielded then yield(cand) end
      goto continue

    elseif MODE == "full" then
      -- ====== 全面模式：全部功能开启 ======

      -- ① 教育模式
      local edu = data.educate[txt]
      if edu then
        local short = edu:sub(1, 22)
        cand:get_genuine().comment = "📖" .. short
        yield(cand)
        yielded = true
      end

      -- ② 新词推荐
      local nw = data.new_word[txt]
      if nw then
        if not yielded then yield(cand); yielded = true end
        local c = Candidate("feminist", cand.start, cand._end, nw.recommend, "✨ 试试这个词")
        yield(c)
      end

      -- ③ 警告词
      if w and not yielded then
        local mark = "⚠"
        if w.level == "severe" then mark = "🔴"
        elseif w.level == "mild" then mark = "🟠"
        elseif w.level == "implicit" then mark = "🟢" end
        cand:get_genuine().comment = mark
        yield(cand); yielded = true
        if w.alt and w.alt ~= "" then
          for _, a in ipairs(split_alt(w.alt)) do
            if a ~= "（直接禁用）" and a ~= "（禁用）" and a ~= "" then
              yield(Candidate("feminist", cand.start, cand._end, a, "← 平替"))
            end
          end
        end
      end

      -- ④ 双标对照
      if not yielded then
        local ds = data.double_standard[txt]
        if ds then
          cand:get_genuine().comment = "⚖"
          yield(cand); yielded = true
        end
      end

      -- ⑤ 夸奖陷阱
      if not yielded then
        local pt = data.praise_trap[txt]
        if pt then
          cand:get_genuine().comment = "⭐"
          yield(cand); yielded = true
        end
      end

      -- ⑥ 控制性语言
      if not yielded then
        local cl = data.control_lang[txt]
        if cl then
          cand:get_genuine().comment = "💬"
          yield(cand); yielded = true
        end
      end

      -- ⑦ 都没命中
      if not yielded then yield(cand) end

    else
      -- ====== 标准模式（默认）：警告词+教育提示 ======

      -- 教育提示优先（📖）
      local edu = data.educate[txt]
      if edu then
        local short = edu:sub(1, 22)
        cand:get_genuine().comment = "📖" .. short
        yield(cand); yielded = true
      end

      -- 警告词（🔴🟠🟢 + 平替）
      if w and not yielded then
        local mark = "⚠"
        if w.level == "severe" then mark = "🔴"
        elseif w.level == "mild" then mark = "🟠"
        elseif w.level == "implicit" then mark = "🟢" end
        cand:get_genuine().comment = mark
        yield(cand); yielded = true
        if w.alt and w.alt ~= "" then
          for _, a in ipairs(split_alt(w.alt)) do
            if a ~= "（直接禁用）" and a ~= "（禁用）" and a ~= "" then
              yield(Candidate("feminist", cand.start, cand._end, a, "← 平替"))
            end
          end
        end
      end

      if not yielded then yield(cand) end
    end

    ::continue::
  end
end

return filter
