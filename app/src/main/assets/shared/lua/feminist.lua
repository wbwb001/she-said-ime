-- feminist.lua
-- 女性主义输入法 · 候选过滤插件
-- 功能：
--   1. 辱女词检测 -> 候选后面加提示(🔴/🟠/🟢 + 建议平替)
--   2. 可替换词   -> 候选后面加“→建议平替”
--   3. 保留词     -> 候选后面加 💪
--   4. 性别反转   -> 打“父母”时，紧跟着多出一个“母父”候选
--
-- 说明：本插件只“加提示/加候选”，不删除、不拦截任何字，
--       所以正常打字、词语联想等基础功能完全不受影响。

local data = require("feminist_data")

local function filter(input, env)
  for cand in input:iter() do
    local txt = cand.text

    -- 1. 警告词
    local w = data.warn[txt]
    if w then
      local mark = "⚠"
      if w.level == "severe" then mark = "🔴"
      elseif w.level == "mild" then mark = "🟠"
      elseif w.level == "implicit" then mark = "🟢" end
      if w.alt and w.alt ~= "" then
        cand:get_genuine().comment = mark .. " 建议:" .. w.alt
      else
        cand:get_genuine().comment = mark
      end
    else
      -- 2. 可替换词(没被警告命中时才提示)
      local rep = data.replace[txt]
      if rep and rep ~= "" then
        cand:get_genuine().comment = "→ " .. rep
      else
        -- 3. 保留词
        local rc = data.reclaim[txt]
        if rc then
          cand:get_genuine().comment = "💪"
        end
      end
    end

    yield(cand)

    -- 4. 性别反转：紧跟着插入女本位版
    local rev = data.reverse[txt]
    if rev and rev ~= "" then
      local c = Candidate("feminist", cand.start, cand._end, rev, "♀ 女本位")
      yield(c)
    end
  end
end

return filter
