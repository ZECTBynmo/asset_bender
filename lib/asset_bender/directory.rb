require 'time'
require 'rack/utils'
require 'rack/mime'

module AssetBender

  # Helper class used to render the directory indexes when browsing the
  # folder structure of a project
  class Directory
 
    F = ::File

    def initialize(inner_path, project_or_dep)
      @root_path = project_or_dep.parent_path
      @inner_path = inner_path
      @path = File.join @root_path, @inner_path

      if true
        @project = project_or_dep
      else
        @dependency = project_or_dep
      end

    end

    def is_project
      @dependency.nil?
    end

    def split_path
      @inner_path.split(File::SEPARATOR).reject {|t| t == ''}
    end

    def check_forbidden
      return unless @path.include? ".."

      body = "Forbidden\n"
      size = Rack::Utils.bytesize(body)
      return [403, {"Content-Type" => "text/plain",
        "Content-Length" => size.to_s,
        "X-Cascade" => "pass"}, [body]]
    end

    def sub_directories_and_files
      files = []

      glob = F.join @path, '*'
      path_without_root = @path.sub(/^#{@root_path}/,'')

      url_head = (path_without_root.split('/')).map do |part|
        Rack::Utils.escape part
      end

      Dir[glob].sort.each do |node|
        stat = stat(node)
        next unless stat

        basename = F.basename(node)
        ext = F.extname(node)

        url = F.join(*url_head + [Rack::Utils.escape(basename)])
        size = stat.size
        type = stat.directory? ? 'directory' : Rack::Mime.mime_type(ext)
        size = stat.directory? ? '-' : filesize_format(size)
        mtime = stat.mtime.strftime "%b %e %Y %l:%m %P"

        if stat.directory?
          url << '/'
          basename << '/'
        end

        files << { 
          :url => url,
          :name => basename,
          :type => type,
          :mtime => mtime
        }
      end

      files
    end

    def stat(node, max = 10)
      F.stat(node)
    rescue Errno::ENOENT, Errno::ELOOP
      return nil
    end

    def check_directory_exists
      @stat = F.stat(@path)

      if not @stat.readable? or not @stat.directory?
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

    # def each
    #   show_path = @path.sub(/^#{@root_path}/,'')
    #   files = @files.map{|f| DIR_FILE % f }*"\n"
    #   page  = DIR_PAGE % [ show_path, show_path , files ]
    #   page.each_line{|l| yield l }
    # end

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