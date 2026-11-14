-- Pandoc Lua filter (PDF build only): hard-wrap code-block lines that would overflow the page and
-- mark each break so a reader can tell a wrapped line from a real newline:
--   the line that continues ends with "↩", the continuation starts with "↪" (indented to match).
-- Breaks at a space when there is one in the back half of the window, otherwise mid-token (regexes).
local MAX = 82          -- characters that fit across a Letter page in 8.6pt DejaVu Sans Mono
local len, sub = pandoc.text.len, pandoc.text.sub

local function wrap(line)
  if len(line) <= MAX then return { line } end
  local indent = line:match("^(%s*)")
  local pad = len(indent) > 12 and string.rep(" ", 12) or indent
  local out, rest, first = {}, line, true
  local prefix = ""
  while len(prefix) + len(rest) > MAX do
    local room = MAX - len(prefix) - 1                     -- leave a column for "↩"
    local cut = room
    local window = sub(rest, 1, room + 1)
    for i = room, math.floor(room / 2), -1 do              -- prefer a space
      if sub(window, i + 1, i + 1) == " " then cut = i; break end
    end
    local head = sub(rest, 1, cut)
    rest = sub(rest, cut + 1):gsub("^ ", "")
    out[#out + 1] = prefix .. head .. "↩"
    if first then prefix = pad .. "↪ "; first = false end
  end
  out[#out + 1] = prefix .. rest
  return out
end

function CodeBlock(cb)
  local lines = {}
  for l in (cb.text .. "\n"):gmatch("(.-)\n") do
    for _, w in ipairs(wrap(l)) do lines[#lines + 1] = w end
  end
  cb.text = table.concat(lines, "\n")
  return cb
end
