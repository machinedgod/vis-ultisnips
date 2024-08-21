# UltiSnips plugin for Vis editor.

This isn't an official plugin reimplementation. I am not in any way
affiliated with UltiSnips developer(s).

I needed this functionality in [Vis](https://github.com/martanne/vis),
and UltiSnips seemed powerful and mature enough, and had plenty of
templates available.

## How to make it work
### 0. Overview
1. Install plugin (clone or use [vis-plug](https://github.com/erf/vis-plug))
2. (Optionally) Clone snippets from [vim-snippets](https://github.com/honza/vim-snippets)
3. Configure plugin paths and mappings inside your `visrc.lua`
4. Use `<C-x><C-j>` to execute

### 1. Install plugin
#### Directly
Clone `vis-ultisnips` into your `.config/vis/plugins` directory

#### Using `vis-plug`
As per `vis-plug` instructions, add to your `visrc.lua`:
```
-- configure plugins in an array of tables with git urls and options 
local plugins = {
...
  { url = 'git@github.com:machinedgod/vis-ultisnips', alias = 'snips' },
...
}

-- require and optionally install plugins on init
visplug.init(plugins, true)
```

We assign alias `snips` to use in subsequent configuration.

### 2. (Optionally) Clone snippets
If you don't already have snippets, [get
them](https://github.com/honza/vim-snippets).  Of course, you can just
create your own as well.



### 3. Configure the plugin
#### Paths
In your `visrc.lua`:
```
snips.snipmate  = '<path-to-SnipMate-snippets>'
snips.ultisnips = '<path-to-SnipMate-UltiSnips>'
```
Trailing slash is *necessary*!

If you're using `vis-plug`, configuration *must* come after you execute
`visplug.init(...)` as shown in [Installation](#markdown-header-1-install-plugin):
```
-- access plugins via alias
visplug.plugins.snips.snipmate  = '/home/john/.config/vis/vim-snippets/snippets/'
visplug.plugins.snips.ultisnips = '/home/john/.config/vis/vim-snippets/UltiSnips/'
```

#### Syntaxfile → snippetfile mappings that don't match
Setup any lexer syntax file to snippet file mapping using two tables,
one for each snippet format. The key is the vis lexer (the thing you
type when you set syntax with `:set syntax syntaxfile`), while the value
is the string representing the filename of the snippetfile, without
extension.

The default mapping includes `cpp.lua` lexer to SnipMate's `c.snippets`
file as below.

If you report it as an issue (or even more lovely, as a pull request),
I'll add it to default maps, but to quickly get it to work without
messing with the `init.lua` file, add the mappings in your `visrc.lua`
(purescript is just an example!):
```
snips.syntaxfilemaps =
  { snipmate  = { cpp        = "c"
                , purescript = "pure"
                }
  , ultisnips = { purescript = "pure"
				}
  }

```


### 4. Usage
In insert mode, hit `<C-x><C-j>` to show `vis-menu` with all snippets
found for the currently set syntax - it literally looks for a file in
your path called `<syntax>.snippet`.

You can also pre-type the snippet tabtrigger that you're looking for,
for example:
```
newt<C-x><C-j>
```

When snippet is expanded, all of its tags will be added to the selection
jumplist with first tag selection(s) active. You can use Vis motions
`g<` and `g>` to navigate between them.

## What works
You can:

- get a list of snippets per syntax
- insert the snippet
- navigate around its anchor points

## What is known to _not_ work and is unlikely to work until someone else fixes it (ie. I don't care much about it right now)
1. python interpolations, date interpolations, etc etc etc
1. nested tags (correctly parsed, but not correctly inserted)
1. options


## What is _supposed_ to work but might _not_ (ie. is a bug if it doesn't)
- Parsing of more complex snippets. Lpeg grammar for this is quite complex
(I'm looking at you, nested tags feature)

- `vis-menu` for one or the other reason corrupts my terminal when
invoked. This might be plugin doing something its not supposed to -
but I don't know what. If you do, please PR. Mind you, dmenu has no
such problems.

- who knows??? This was supposed to be few hours project max, ended up
being a rabbit hole!


## Final notes
All of this, because muscle memory from vim made me remember I can't
just insert `{-# LANGUAGE ...#-}` pragma via template.

And I didn't like that.

So I spent upwards of 15h writing this plugin.

Go figure.