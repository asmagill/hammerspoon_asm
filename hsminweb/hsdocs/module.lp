<html>
  <%= "<","!--" %><div align="center"><i><font color="#f00">Requires hs._asm.minweb:luaTemplateExtension("lp") to be enabled for your web server</font></i></div><%= "--",">" %>
  <!-- <%= "--",">" %>
  <%
      cgilua.lp.include("common.lp")
      local lookingFor = cgilua.QUERY.q
      local mod = {
          desc = "Module documentation not found",
          doc = "Module documentation not found\n\nThe requested module does not appear to have any documentation in the set available to this web site.",
          items = {},
          name = lookingFor or "** no module specified **"
      }
      if lookingFor then
          for i, v in ipairs(documentation) do
              if v.name == lookingFor then
                  mod = v
                  break
              end
          end
      end
  %>

  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>Hammerspoon docs: <%= mod.name %> module</title>
    <style type="text/css">
      a { text-decoration: none; }
      a:hover { text-decoration: underline; }
      th { background-color: #DDDDDD; vertical-align: top; padding: 3px; }
      td { width: 100%; background-color: #EEEEEE; vertical-align: top; padding: 3px; }
      table { width: 100% ; border: 1px solid #0; text-align: left; }
      section > table table td { width: 0; }
    </style>
    <link rel="stylesheet" href="docs.css" type="text/css" media="screen" />
  </head>

  <body>
    <header>
      <h1><a href="index.lp">docs</a> &raquo; <%= mod.name %></h1>
      <%= gfmConvert(mod.doc) %>
    </header>
    <h3>API Overview</h3>
    <ul>
      <%
        local sectionorder = { "Deprecated", "Command", "Constant", "Variable", "Function", "Constructor", "Field", "Method" }
        local sectiondetails = {
          ["Deprecated"]  = "API features which will be removed in an upcoming release",
          ["Command"]     = "External shell commands",
          ["Constant"]    = "Useful values which cannot be changed",
          ["Variable"]    = "Configurable values",
          ["Function"]    = "API calls offered directly by the extension",
          ["Constructor"] = "API calls which return an object, typically one that offers API methods",
          ["Field"]       = "Variables which can only be access from an object returned by a constructor",
          ["Method"]      = "API calls which can only be made on an object returned by a constructor",
        }

        local activeSections = {}

        for _, section in ipairs(sectionorder) do
          local items = {}
          for _, moditem in ipairs(mod.items) do
            if moditem["type"] == section then table.insert(items, moditem) end
          end
          table.sort(items, function(a, b) return a.name < b.name end)
          if #items > 0 then
            table.insert(activeSections, { name = section, items = items }) %>
            <li><%= section %>s - <%= sectiondetails[section] %></li>
            <ul>
              <% for _, item in ipairs(items) do %>
                  <li><a href="#<%= item.name %>"><%= item.name %></a></li>
              <% end %>
            </ul>
          <% end
        end
      %>
    </ul>
    <h3>API Documentation</h3>
    <%
      for _, section in ipairs(activeSections) do %>
        <h4 class="documentation-section"><%= section.name %>s</h4>
        <% for _, item in ipairs(section.items) do %>
          <section id="<%= item.name %>">
          <a name="//apple_ref/cpp/<%= item['type'] %>/<%= item.name %>" class="dashAnchor"></a>
          <h5><a href="#<%= item.name %>"><%= item['name'] %></a></h5>
          <table>
            <tr>
              <th>Signature</td>
              <td><code><%= item.def %></code></td>
            </tr>
            <tr>
              <th>Type</td>
              <td><%= item.type %></td>
            </tr>
            <tr>
              <th>Description</td>
              <td>
                <%= gfmConvert(item.doc) %>
              </td>
            </tr>
          </table>
          </section>
        <% end
      end
    %>
  </body>

  <%= "<","!--" %> -->
</html>
