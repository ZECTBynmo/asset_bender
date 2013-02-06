require 'time'
require 'rack/utils'
require 'rack/mime'

module AssetBender
  module Server
    module DirectoryIndexGenerator

      DIR_FILE = "<tr><td class='name'><a href='%s'>%s</a></td><td class='size'>%s</td><td class='type'>%s</td><td class='mtime'>%s</td></tr>"
      DIR_PAGE = <<-PAGE
<html><head>
  <title>%s</title>
  <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  <style type='text/css'>
table { width:100%%; }
.name { text-align:left; }
.size, .mtime { text-align:right; }
.type { width:11em; }
.mtime { width:15em; }
  </style>
</head><body>
<h1>%s</h1>
<hr />
<table>
  <tr>
    <th class='name'>Name</th>
    <th class='size'>Size</th>
    <th class='type'>Type</th>
    <th class='mtime'>Last Modified</th>
  </tr>
%s
</table>
<hr />
</body></html>
    PAGE

      F = ::File

      def list_of_files_for_directory(root_path, inner_path)
        @root_path = root_path
        @path = File.join root_path, inner_path

        if forbidden = check_forbidden
          forbidden
        else
          print "\n", "path:  #{@path.inspect}", "\n\n"
          list_path
        end
      end

      def check_forbidden
        return unless @path.include? ".."

        body = "Forbidden\n"
        size = Rack::Utils.bytesize(body)
        return [403, {"Content-Type" => "text/plain",
          "Content-Length" => size.to_s,
          "X-Cascade" => "pass"}, [body]]
      end

      def list_directory
        @files = [['../','Parent Directory','','','']]
        glob = F.join(@path, '*')

        path_without_root = @path.sub(/^#{@root_path}/,'')
        url_head = (path_without_root.split('/')).map do |part|
          Rack::Utils.escape part
        end

        Dir[glob].sort.each do |node|
          stat = stat(node)
          next  unless stat
          basename = F.basename(node)
          ext = F.extname(node)

          url = F.join(*url_head + [Rack::Utils.escape(basename)])
          size = stat.size
          type = stat.directory? ? 'directory' : Rack::Mime.mime_type(ext)
          size = stat.directory? ? '-' : filesize_format(size)
          mtime = stat.mtime.httpdate
          url << '/'  if stat.directory?
          basename << '/'  if stat.directory?

          @files << [ url, basename, size, type, mtime ]
        end

        return [ 200, {'Content-Type'=>'text/html; charset=utf-8'}, self ]
      end

      def stat(node, max = 10)
        F.stat(node)
      rescue Errno::ENOENT, Errno::ELOOP
        return nil
      end

      # TODO: add correct response if not readable, not sure if 404 is the best
      #       option
      def list_path
        @stat = F.stat(@path)

        if @stat.readable?
          return list_directory if @stat.directory?
        else
          raise Errno::ENOENT, 'No such file or directory'
        end

      rescue Errno::ENOENT, Errno::ELOOP
        return entity_not_found
      end

      def entity_not_found
        body = "Entity not found: #{@path}\n"
        size = Rack::Utils.bytesize(body)
        return [404, {"Content-Type" => "text/plain",
          "Content-Length" => size.to_s,
          "X-Cascade" => "pass"}, [body]]
      end

      def each
        show_path = @path.sub(/^#{@root_path}/,'')
        files = @files.map{|f| DIR_FILE % f }*"\n"
        page  = DIR_PAGE % [ show_path, show_path , files ]
        page.each_line{|l| yield l }
      end

      # Stolen from Ramaze

      FILESIZE_FORMAT = [
        ['%.1fT', 1 << 40],
        ['%.1fG', 1 << 30],
        ['%.1fM', 1 << 20],
        ['%.1fK', 1 << 10],
      ]

      def filesize_format(int)
        FILESIZE_FORMAT.each do |format, size|
          return format % (int.to_f / size) if int >= size
        end

        int.to_s + 'B'
      end



    end
  end
end