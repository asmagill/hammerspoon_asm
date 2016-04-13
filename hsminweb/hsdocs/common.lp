<!--<%

  -- modify markdownCommand to point to your markdown conversion tool of choice, if you have one.
  -- if the file specified does not exist, a minimal cleanup will be done and contents will be
  -- displayed as raw text
  --
  -- A few that I have tested (please let me know if you have a different one to suggest)
  --
  --  * HomeBrew's markdown:
  --    * Probably installed as /usr/local/bin/markdown
  --    * Botches display of links file index.md in index.lp
  --    * links in index.lp aren't turned into actual links
  --    * list items in some command descriptions are run together
  --    * no fenced code support
  --
  --  * HomeBrew's multimarkdown:
  --    * Probably installed as /usr/local/bin/multimarkdown
  --    * links in index.lp aren't turned into actual links
  --    * list items in some command descriptions are run together
  --    * no fenced code support
  --
  --  * HomeBrew's discount:
  --    * Probably installed as /usr/local/bin/markdown
  --    * Needs to be installed with `brew install discount --with-fenced-code`
  --    * set markdownCommand to "/usr/local/bin/markdown -f autolink,githubtags,fencedcode"
  --    * list items in some command descriptions are run together
  --
  --  * Ruby's github-markdown gem:
  --    * Probably installed as something like /usr/local/gems/github-markdown-0.6.9/bin/gfm
  --    * the same renderering engine used to generate the Hammerspoon Dash documentation
  --    * slowest of those tested

  local markdownCommand = "/usr/local/gems/github-markdown-0.6.9/bin/gfm"

  -- globals go into the HTTP request function's _ENV, not _G.  It's the only way for an included file to return anything that can be used by the calling file

  gfmConvert = function(theText, simple)
      local results
      local fs      = require("hs.fs")
      local hshost  = require("hs.host")

      if not simple and markdownCommand and fs.attributes(markdownCommand:match("^([^ ]*)")) then
          local tempFileName = fs.temporaryDirectory() .. "/" .. hshost.globallyUniqueString()
          tmpInputFile = io.open(tempFileName, "w")
          tmpInputFile:write(theText)
          tmpInputFile:close()

          local out, stat, typ, rc = hs.execute("/bin/cat " .. tempFileName .. " | " .. markdownCommand .. " 2> " .. tempFileName .. "err")

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
          results = [[<p>]] ..
              (theText:gsub("%[([^%]\r\n]+)%]%(#([^%)\r\n]+)%)", "`%1`")
                      :gsub("<", "&lt;")
                      :gsub(">", "&gt;")
                      :gsub("\n", "<br/>\n")
                      :gsub("(\n[ ]+)", function(_) return _:gsub(" ", "&nbsp;&nbsp;") end)
              ) .. [[</p>]]
      end
      return results
  end

%>-->

<script type="text/javascript">
  setInvertLevel = function (level) {
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
</script>
<!--<%

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
%>-->

<script type="text/javascript">
  window.onload = function(){setInvertLevel(<%= invertLevel %>);};
</script>
