require 'time'
require 'rack/utils'
require 'rack/mime'

module AssetBender
  module Server

    # Helper class used to render the top level index that shows all projects and deps
    class ProjectIndexGenerator

      PROJECT_TEMPLATE = "<tr><td class='name'><a href='%s'>%s</a></td><td class='path'>%s</td><td class='mtime'>%s</td></tr>"
      PROJECTS_PAGE = <<-PAGE
<html><head>
  <title>AssetBender Projects</title>
  <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  <style type='text/css'>
  </style>
</head><body>
<h1>AssetBender</h1>

<h2>Projects</h2>
<hr />
<table>
  <tr>
    <th class='name'>Name</th>
    <th class='path'>Path</th>
    <th class='mtime'>Last Modified</th>
  </tr>
%s
</table>

<h2>Dependencies</h2>
<hr />

</body></html>
    PAGE

      def list_of_projects_and_deps()
        @project_info = []

        AssetBender::State.available_projects.each do |project|
          stat = File.stat "#{project.path}/"
          url = Rack::Utils.escape(project.name) + "/"

          @project_info << [ url, project.name, project.path, stat.mtime.httpdate ]
        end

        return [ 200, {'Content-Type'=>'text/html; charset=utf-8'}, self ]
      end

      def each
        projects = @project_info.map{|f| PROJECT_TEMPLATE % f }*"\n"
        page  = PROJECTS_PAGE % [ projects ]
        page.each_line{|l| yield l }
      end


    end
  end
end