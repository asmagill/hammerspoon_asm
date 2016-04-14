<html>
<%= "<","!--" %><div align="center"><i><font color="#f00">Requires hs._asm.minweb:luaTemplateExtension("lp") to be enabled for your web server</font></i></div><%= "--",">" %>
<!-- <%= "--",">" %>

<%

  -- modify markdownCommand to point to your markdown conversion tool of choice, if you have one.
  -- if the file specified does not exist, a minimal cleanup will be done and contents will be
  -- displayed as raw text
  --
  -- A few that I have tested (please let me know if you have a different one to suggest)
  --
  --  * HomeBrew's markdown:
  --    * Install with `brew install markdown`
  --    * Probably installed as /usr/local/bin/markdown
  --    * Botches display of links file index.md in index.lp
  --    * links in index.lp aren't turned into actual links
  --    * list items in some command descriptions are run together -- see mimic_LAX_SPAXING below
  --    * no fenced code support
  --
  --  * HomeBrew's multimarkdown:
  --    * Install with `brew install multimarkdown`
  --    * Probably installed as /usr/local/bin/multimarkdown
  --    * links in index.lp aren't turned into actual links
  --    * list items in some command descriptions are run together -- see mimic_LAX_SPAXING below
  --    * no fenced code support
  --
  --  * HomeBrew's discount:
  --    * Install with `brew install discount`
  --    * Probably installed as /usr/local/bin/markdown
  --    * set markdownCommand to "/usr/local/bin/markdown -f autolink,githubtags,fencedcode"
  --    * list items in some command descriptions are run together -- see mimic_LAX_SPAXING below
  --
  --  * Ruby's github-markdown gem:
  --    * Probably installed as something like /usr/local/gems/github-markdown-0.6.9/bin/gfm
  --    * the same renderering engine used to generate the Hammerspoon Dash documentation
  --    * slowest of those tested

  -- local markdownCommand = "/usr/local/gems/github-markdown-0.6.9/bin/gfm"
  local markdownCommand = "/usr/local/bin/markdown -f autolink,githubtags,fencedcode"

  -- The Ruby gem used has the MKDEXT_LAX_SPACING enabled by default; the others do not, so comment this out if you use the Ruby github-markdown gem:
  local mimic_LAX_SPACING = true

  gfmConvert = function(theText, simple)
      -- gfmConvert is not local because we want our caller to have access... the cgilua wrapper makes sure this goes into _ENV, rather than _G.

      local results
      local fs      = require("hs.fs")
      local hshost  = require("hs.host")

      if not simple and markdownCommand and fs.attributes(markdownCommand:match("^([^ ]*)")) then

          if mimic_LAX_SPACING then
              theText = theText:gsub("([^\r\n])(\r?\n)([ \t]*%*)", "%1%2\n%3")
          end

          local tempFileName = fs.temporaryDirectory() .. "/" .. hshost.globallyUniqueString()
          tmpInputFile = io.open(tempFileName, "w")
          tmpInputFile:write(theText)
          tmpInputFile:close()

          local out, stat, typ, rc = hs.execute(markdownCommand .. " " .. tempFileName .. " 2> " .. tempFileName .. "err")

          if stat then
              results = out
          else
              local errOutput = "** no stderr **"
              local errf = io.open(tempFileName .. "err", "rb")
              if errf then
                  errOut = errf:read("a")
                  errf:close()
              end
              hsminweb.log.ef("hsdocs markdown conversion error: output:%s, stderr:%s, %s code:%d", out, errOut, typ, rc)
          end
          os.execute("rm " .. tempFileName)
          os.execute("rm " .. tempFileName .. "err")
      end

      if not results then
          local blockType  = "p"
          local lineEnding = "<br/>"

          -- detect index.md contents
          if theText:match("^### Project links") then
              blockType = "pre"
              lineEnding = "\n"
          end

          results = "<" .. blockType .. ">" ..
              (theText:gsub("%[([^%]\r\n]+)%]%(#([^%)\r\n]+)%)", "`%1`")
                      :gsub("<", "&lt;")
                      :gsub(">", "&gt;")
                      :gsub("\n", lineEnding)
                      :gsub("(\n[ ]+)", function(_) return _:gsub(" ", "&nbsp;&nbsp;") end)
              ) .. "</" .. blockType .. ">"

          if not hsminweb.self._loggedMarkdownSuggestion then
              hsminweb.self._loggedMarkdownSuggestion = true
              hsminweb.log.wf("\n\nResults of hsdocs web site will look noticeably better with a markdown conversion tool installed.  See the comments at the top of the `common.lp` file for more information.\n\n")
          end
      end
      return results
  end

%>

<script type="text/javascript">

  // modified from code at http://stackoverflow.com/a/18990842
  var setInvertLevel = function (level) {
    var css = 'html {-webkit-filter: invert(' + level + '%);' + '-moz-filter: invert(' + level + '%);' + '-o-filter: invert(' + level + '%);' + '-ms-filter: invert(' + level + '%); }';
    var head = document.getElementsByTagName('head')[0];
    var style = document.createElement('style');

    style.type = 'text/css';
    if (style.styleSheet) {
      style.styleSheet.cssText = css;
    } else {
      style.appendChild(document.createTextNode(css));
    }
    head.appendChild(style);
  }

  // see http://austinmatzko.com/2008/04/14/addevent-preserving-this/
  var addEvent = function( obj, type, fn ) {
    if (obj.addEventListener)
      obj.addEventListener(type, fn, false);
    else if (obj.attachEvent)
      obj.attachEvent('on' + type, function() { return fn.apply(obj, new Array(window.event));});
  }
</script>

<%

--    local forceCore = true
    if not hs._docsAsArray then
        if not forceCore and package.searchpath("utils.docmaker", package.path) then
            -- ultimately, this is going to allow me to include in progress docs, third part, etc.
            local docmaker = require"utils.docmaker"
            hs._docsAsArray = {
                from = "DocMaker",
                -- change this to your hammerspoon source directory
                docs = docmaker.coreDocs("/opt/amagill/src/hammerspoon/hammerspoon"),
            }
        else
            -- stuff that is solely part of core
            local input = io.open(hs.docstrings_json_file, "rb")
            hs._docsAsArray = {
                from = "Core JSON",
                docs = require"hs.json".decode(input:read("a")),
            }
            input:close()
        end
    end

    documentationSourceTag, documentation = hs._docsAsArray.from, hs._docsAsArray.docs

    -- inversion mode option for night time, dark mode, etc.
    local invertLevel = require"hs.settings".get("_hsminWeb.invertDocs")
    if type(invertLevel) == "nil" then
        invertLevel = (require"hs.host".interfaceStyle() == "Dark")
    end
    if type(invertLevel) == "boolean" then
        invertLevel = invertLevel and 100 or 0
    end
%>

<script type="text/javascript">
  addEvent(window, 'load', function() { setInvertLevel(<%= invertLevel %>); } );
</script>

<%= "<","!--" %> -->
</html>