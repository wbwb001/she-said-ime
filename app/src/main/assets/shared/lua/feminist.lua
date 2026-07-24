-- feminist.lua
-- 女性主义输入法 · 候选过滤插件 v2
-- 功能：
--   1. 辱女词检测 -> 候选标🔴/🟠/🟢 + 平替直接插入候选栏（可以选）
--   2. 可替换词   -> 候选后加 →平替
--   3. 保留词     -> 候选后加 💪
--   4. 性别反转   -> 打"父母"时，紧跟着多出一个"母父"候选

local data = require("feminist_data")

-- 按 "/" 拆分平替词，返回列表
local function split_alt(alt_str)
  local result = {}
  if not alt_str or alt_str == "" then return result end
  -- 按 "/" 或 " / " 拆分
  for part in string.gmatch(alt_str, "([^/]+)") do
    local t = part:match("^%s*(.-)%s*$")  -- trim
    if t and t ~= "" then
      table.insert(result, t)
    end
  end
  return result
end

local function filter(input, env)
  for cand in input:iter() do
    local txt = cand.text

    -- 1. 警告词：标级别 + 平替直接插进候选栏
    local w = data.warn[txt]
    if w then
      local mark = "⚠"
      if w.level == "severe" then mark = "🔴"
      elseif w.level == "mild" then mark = "🟠"
      elseif w.level == "implicit" then mark = "🟢" end
      
      -- 在候选上加级别标记
      cand:get_genuine().comment = mark
      yield(cand)

      -- 把平替词作为可选候选插入
      if w.alt and w.alt ~= "" then
        local alts = split_alt(w.alt)
        for _, alt_word in ipairs(alts) do
          if alt_word and alt_word ~= "" and alt_word ~= "（直接禁用）" and alt_word ~= "（禁用）" then
            local c = Candidate("feminist", cand.start, cand._end, alt_word, "← 平替")
            yield(c)
          end
        end
      end
    else
      -- 2. 可替换词：候选后面加 "→平替"
      local rep = data.replace[txt]
      if rep and rep ~= "" then
        cand:get_genuine().comment = "→ " .. rep
        yield(cand)
        
        -- 也把替换词插入候选栏
        local alts = split_alt(rep)
        for _, alt_word in ipairs(alts) do
          if alt_word and alt_word ~= "" then
            local c = Candidate("feminist", cand.start, cand._end, alt_word, "← 替代方案")
            yield(c)
          end
        end
      else
        -- 3. 保留词
        local rc = data.reclaim[txt]
        if rc then
          cand:get_genuine().comment = "💪"
          yield(cand)
        else
          yield(cand)
        end
      end
    end
  end
end

return filter
