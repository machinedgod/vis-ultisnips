--------------------------------------------------------------------------------
-- Modules

local M = {}
local cwd = ...
local SnipMate  = require(cwd .. '.snipmate-parser')
local UltiSnips = require(cwd .. '.ultisnips-parser')



--------------------------------------------------------------------------------
-- Config

M.snipmate  = ''
M.ultisnips = ''



--------------------------------------------------------------------------------
-- Helper functions

-- Takes list of snippets and concatenates them into the string suitable
-- for passing to dmenu (or, very probably, vis-menu)
local function snippetslist(snippets)
  local list = ''

  for k,v in pairs(snippets) do
    if not v.description then
      list = list .. k .. '\n'
    else
      list = list .. k .. ' - ' .. v.description .. '\n'
    end
  end

  return list
end



local function load_ultisnips()
  local snippetfile = M.ultisnips .. vis.win.syntax .. '.snippets'
  local snippets, success = UltiSnips.load_snippets(snippetfile)
  if not success then
    vis:info('Failed to load a correct UltiSnip: ' .. snippetfile)
  end
  return snippets, success
end



local function load_snipmate()
  local snippetfile = M.snipmate .. vis.win.syntax .. '.snippets'
  local snippets, success = SnipMate.load_snippets(snippetfile)
  if not success then
    vis:info('Failed to load a correct SnipMate: ' .. snippetfile)
  end
  return snippets, success
end



-- Second will append to first using suffix for distinguishing
local function merge_and_override(snips1, snips2, suffix)
  for k,v in pairs(snips2) do
    snips1[k .. suffix] = v
  end
  return snips1
end



--------------------------------------------------------------------------------
-- Plugging it all in

vis:map(vis.modes.INSERT, "<C-x><C-j>", function()
  local snippets = merge_and_override(load_snipmate(), load_ultisnips(), '_us')

  local win = vis.win
  local file = win.file
  local pos = win.selection.pos

  if not pos then
    return
  end
  -- TODO do something clever here

  -- Use prefix W if exists
  local initial = ' '
  local range = file:text_object_longword(pos > 0 and pos - 1 or pos)
  if file:content(range):match('[%w]+') then
    initial = initial .. file:content(range)
  else
    range = nil
  end

  -- Note, for one reason or another, using vis-menu corrupts my terminal
  -- (urxvt) for exact amount of lines that vis-menu takes
  -- dmenu has no such problems, but can't take initial input :-\
  --local stdout = io.popen("echo '" .. snippetslist(snippets) .. "' | dmenu -l 5", "r")
  local stdout = io.popen("echo '" .. snippetslist(snippets) .. "' | vis-menu " .. initial, "r")
  local chosen = stdout:lines()()
  local success, msg, status = stdout:close()
  if status ~= 0 or not chosen then
    vis:message(msg)
    return
  end

  local trigger = chosen:gmatch('[^ ]+')()
  local snipcontent = snippets[trigger].content
  if range then
    file:delete(range)
    -- Update position after deleting the range
    pos = pos - (range.finish - range.start)
  end

  vis:insert(snipcontent.str)
  vis:redraw()


  if #snipcontent.tags > 0 then
    vis:info("Use 'g>' and 'g<' to navigate between anchors.")

    -- Create selections iteratively using `:#n,#n2 p` command and `gs` to
    -- save it in the jumplist
    for k,v in ipairs(snipcontent.tags) do
      -- Can't use 'x' command because it'd select stuff across
      -- whole file
      vis:command('#' .. pos + v.selstart ..',#' .. pos + v.selend .. ' p')
      --vis:feedkeys('gs') -- Tested, works without this too, but just in case
      --vis:message('Command: ' .. cmd)
    end

    -- Backtrack through all selections we've made first
    -- (so that we can use g> to move us forward)...
    for _ in ipairs(snipcontent.tags) do
      vis:feedkeys('g<')
    end

    -- ... then set us on the first selection
    vis:feedkeys('g>')
  else
    win.selection.pos = pos + #snipcontent.str
  end
end, "Insert a snippet")



--------------------------------------------------------------------------------
-- End module

return M