-- feminist.lua
-- 她说输入法 · 女性主义候选过滤插件 v3
-- 功能：
--   1. 辱女词检测 -> 候选标🔴/🟠/🟢 + 平替直接插入候选栏（可点选）
--   2. 可替换词   -> 候选后加 →平替
--   3. 保留词     -> 候选后加 💪
--   4. 教育模式   -> 检测到历史污名化字时，候选后加 📖原意说明
--   5. 新词推荐   -> 检测到旧词时，推荐女本位新造词

local data = require("feminist_data")

-- 按 "/" 拆分平替词，返回列表
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

    -- ========== 1. 教育模式：历史提示 ==========
    local edu = data.educate[txt]
    if edu then
      cand:get_genuine().comment = "📖"
      yield(cand)
      yielded = true
      -- 继续走下面的逻辑
    end

    -- ========== 2. 新词推荐 ==========
    local nw = data.new_word[txt]
    if nw then
      if not yielded then
        yield(cand)
        yielded = true
      end
      -- 把推荐新词插入候选栏
      local c = Candidate("feminist", cand.start, cand._end, nw.recommend, "✨ 试试这个词")
      yield(c)
    end

    -- ========== 3. 警告词：标级别 + 平替插候选 ==========
    local w = data.warn[txt]
    if w then
      local mark = "⚠"
      if w.level == "severe" then mark = "🔴"
      elseif w.level == "mild" then mark = "🟠"
      elseif w.level == "implicit" then mark = "🟢" end

      cand:get_genuine().comment = mark
      if not yielded then
        yield(cand)
        yielded = true
      end

      -- 平替词插入候选栏（可点选）
      if w.alt and w.alt ~= "" then
        local alts = split_alt(w.alt)
        for _, alt_word in ipairs(alts) do
          if alt_word and alt_word ~= "" and alt_word ~= "（直接禁用）" and alt_word ~= "（禁用）" then
            local c = Candidate("feminist", cand.start, cand._end, alt_word, "← 平替")
            yield(c)
          end
        end
      end

    -- ========== 4. 可替换词 ==========
    elseif not yielded then
      local rep = data.replace[txt]
      if rep and rep ~= "" then
        cand:get_genuine().comment = "→ " .. rep
        yield(cand)
        yielded = true

        local alts = split_alt(rep)
        for _, alt_word in ipairs(alts) do
          if alt_word and alt_word ~= "" then
            local c = Candidate("feminist", cand.start, cand._end, alt_word, "← 替代方案")
            yield(c)
          end
        end

      -- ========== 5. 保留词 ==========
      elseif not yielded then
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
