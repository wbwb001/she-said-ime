-- feminist.lua
-- 她说输入法 · 女性主义候选过滤插件 v4
-- 功能：
--   1. 辱女词检测 -> 候选标🔴/🟠/🟢 + 平替直接插入候选栏
--   2. 教育模式   -> 检测到历史污名化字时加📖提示
--   3. 新词推荐   -> 打旧词时推荐女本位造词
--   4. 双标对照   -> 同一行为男女不同词的提示
--   5. 夸奖陷阱   -> 表面夸实则束缚的词
--   6. 控制性语言 -> 关系中的隐形束缚表达

local data = require("feminist_data")

-- 按 "/" 拆分平替词
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

    -- ========== 优先级1: 教育模式（历史污名化字） ==========
    local edu = data.educate[txt]
    if edu then
      cand:get_genuine().comment = "📖 "
      yield(cand)
      yielded = true
    end

    -- ========== 优先级2: 新词推荐 ==========
    local nw = data.new_word[txt]
    if nw then
      if not yielded then
        yield(cand)
        yielded = true
      end
      local c = Candidate("feminist", cand.start, cand._end, nw.recommend, "✨ 试试这个词")
      yield(c)
    end

    -- ========== 优先级3: 警告词（标级别+平替） ==========
    local w = data.warn[txt]
    if w and not yielded then
      local mark = "⚠"
      if w.level == "severe" then mark = "🔴"
      elseif w.level == "mild" then mark = "🟠"
      elseif w.level == "implicit" then mark = "🟢" end

      cand:get_genuine().comment = mark
      yield(cand)
      yielded = true

      if w.alt and w.alt ~= "" then
        local alts = split_alt(w.alt)
        for _, alt_word in ipairs(alts) do
          if alt_word and alt_word ~= "" and alt_word ~= "（直接禁用）" and alt_word ~= "（禁用）" then
            local c = Candidate("feminist", cand.start, cand._end, alt_word, "← 平替")
            yield(c)
          end
        end
      end
    end

    -- ========== 优先级4: 双标对照 ==========
    local ds = data.double_standard[txt]
    if ds and not yielded then
      cand:get_genuine().comment = "⚖"
      yield(cand)
      yielded = true
    end

    -- ========== 优先级5: 夸奖陷阱 ==========
    local pt = data.praise_trap[txt]
    if pt and not yielded then
      cand:get_genuine().comment = "⭐"
      yield(cand)
      yielded = true
    end

    -- ========== 优先级6: 控制性语言 ==========
    local cl = data.control_lang[txt]
    if cl and not yielded then
      cand:get_genuine().comment = "💬"
      yield(cand)
      yielded = true
    end

    -- ========== 都没命中: 正常候选 ==========
    if not yielded then
      -- 可替换词
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
      -- 保留词
      else
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
