lpeg = require('lpeg')

--------------------------------------------------------------------------------

-- Base definitions
tws                = lpeg.S' ' ^ 1
tnewline           = lpeg.S'\n'
tlowcasedword      = lpeg.R'az' ^ 1
tdigit             = lpeg.locale()['digit']
talphanum          = lpeg.locale()['alnum']
tanyprintable      = lpeg.locale()['print']
tcontrol           = lpeg.locale()['cntrl']
ttabtrigger        = tanyprintable ^ 1
ttag               = lpeg.Cg(lpeg.Cp(), 'selstart') 
                     * lpeg.P'${'
                     * lpeg.Cg(tdigit^1, 'tag-order') 
                     * (
                         (lpeg.S':' * lpeg.Cg(talphanum^1, 'default-value') * lpeg.S'}')
                         + lpeg.S'}'
                       )
                     * lpeg.Cg(lpeg.Cp(), 'selend')
tsnippetdecl       = lpeg.P'snippet' * lpeg.S' ' * lpeg.Cg(ttabtrigger, 'tabtrigger') * tnewline
tsnippetcontent    = lpeg.C(
                       lpeg.Cp() *
                       (lpeg.S'\t '^1 
                        * (lpeg.Ct(ttag) + tanyprintable)^1
                        * tnewline
                       )^1
                     ) 

-- Constructs
tsnippet = tsnippetdecl * tsnippetcontent
tcomment = lpeg.S'#' * tanyprintable^0 * tnewline

-- The way grammar captures:
-- Every snippet gets its own table, and every table has:
-- 'tabtrigger' - the tabtrigger
-- [1]          - full content
-- [2..n]       - tags
tsnippetsfile = lpeg.Ct((tcomment + lpeg.Ct(tsnippet) + tnewline) ^1)
--------------------------------------------------------------------------------

testsingle = [[
snippet sim
        ${1:public} static int Main(string[] args)
        {
                ${0}
                return 0;
        }
]]

testmulti = [[
snippet sim
        ${1:public} static int Main(string[] args)
        {
                ${0}
                return 0;
        }
snippet simc
        public class Application
        {
                ${1:public} static int Main(string[] args)
                {
                        ${0}
                        return 0;
                }
        }
snippet svm
        ${1:public} static void Main(string[] args)
        {
                ${0}
        }
]]

testfile = [[
# I'll most propably add more stuff in here like
# * List/Array constructio
# * Mostly used generics
# * Linq
# * Funcs, Actions, Predicates
# * Lambda
# * Events
#
# Feedback is welcome!
#
# Main
snippet sim
        ${1:public} static int Main(string[] args)
        {
                ${0}
                return 0;
        }
snippet simc
        public class Application
        {
                ${1:public} static int Main(string[] args)
                {
                        ${0}
                        return 0;
                }
        }
snippet svm
        ${1:public} static void Main(string[] args)
        {
                ${0}
        }
# if condition
snippet if
        if (${1:true})
        {
                ${0:${VISUAL}}
        }
snippet el
        else
        {
                ${0:${VISUAL}}
        }
]]

--------------------------------------------------------------------------------
-- Test

function print_table(tableau, tabwidth)
  if tabwidth == nil then
    tabwidth = 0
  end

  -- Iterate
  for k,v in pairs(tableau) do
    local tabs = ('\t'):rep(tabwidth)

    print(tabs .. k .. ':"' .. tostring(v) .. '"')
    if type(v) == "table" then
      print_table(v, tabwidth + 1)
    end
  end
end

--print("------------ header ------------------------------------")
--p = lpeg.Ct(tsnippetdecl)
--t = p:match([[
--snippet classy
--]])
--print_table(t)
--print("--------------------------------------------------------------")

--print("------------ tag ------------------------------------")
--print_table(
--  lpeg.Ct(ttag):match('${0:VISUAL}')
--)
--print_table(
--  lpeg.Ct(ttag):match('${12:Badonkadong}')
--)
--print_table(
--  lpeg.Ct(ttag):match('${1}')
--)
--print("--------------------------------------------------------------")

--print("------------ single snippet test ------------------------------------")
--print_table(lpeg.Ct(tsnippet):match(testsingle))
--print("--------------------------------------------------------------")

--print("------------ multi snippet test ------------------------------------")
--print_table(lpeg.Ct(tsnippetsfile):match(testmulti))
--print("--------------------------------------------------------------")

print("------------ file with comments -------------------------------------")
print_table(tsnippetsfile:match(testfile))
print("--------------------------------------------------------------")

