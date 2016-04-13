<html>
  <%= "<","!--" %><div align="center"><i><font color="#f00">Requires hs._asm.minweb:luaTemplateExtension("lp") to be enabled for your web server</font></i></div><%= "--",">" %>
  <!-- <%= "--",">" %>
  <%
      cgilua.lp.include("common.lp")

      local f = io.open("index.md")
      local indexMD = "<i>Header file, index.md, not present</i>"
      if f then
          indexMD = f:read("a")
          f:close()
      end
  %>

  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>Hammerspoon docs</title>
    <style type="text/css">
      a { text-decoration: none; }
      a:hover { text-decoration: underline; }
      th, td { border: 1px solid #ccc; padding: 5px 10px; text-align: left; vertical-align: top; }
    </style>
    <link rel="stylesheet" href="docs.css" type="text/css" media="screen" />
  </head>

  <body>
    <header>
      <h1>Hammerspoon.app</h1>
      <i>Documentation Source: <%= documentationSourceTag %></i>
    </header>
    <section><%= gfmConvert(indexMD) %></section>
    <section>
    <!-- tables suck., I know, but it's fast to code -->
      <h3>API documentation</h3>
      <table class="api-documentation-overview">
        <% for i, mod in ipairs(documentation) do %>
          <tr>
            <td><a href="<%= cgilua.mkabsoluteurl(cgilua.mkurlpath("module.lp", { q = mod.name })) %>"><%= mod.name %></a></td>
       <!-- for the handfull of description lines that use styles, the slowdown on index.lp isn't worth it -->
            <td><%= mod.desc %></td>
          </tr>
        <% end %>
      </table>
    </section>
  </body>

  <%= "<","!--" %> -->
</html>
