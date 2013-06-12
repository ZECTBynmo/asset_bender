def fix_compiled_extensions(extension)
  extension = 'css' if ['sass', 'scss'].include? extension
  extension = 'js' if extension == 'coffee'
  extension
end

interactor :off

group :asset_bender do
  guard 'livereload' do

    # Internal asset bender assetss
    watch(%r{assets/(.+)\.(css|js|html|sass|scss|coffee)}) do |m|
      extension = fix_compiled_extensions m[2]
      "/asset_bender_assets/#{m[1]}.#{extension}"
    end

    # External project assets
    watch(%r{/\w+/(.+)\.(css|js|html|sass|scss|coffee)}) do |m|
      extension = fix_compiled_extensions m[2]
      "#{m[1]}.#{extension}"
    end
  end
end

group :server do
  guard 'rack', :port => 9292 do
    watch(%r{^config.yaml})
    watch(%r{^Gemfile.lock})
    watch(%r{^lib/.+\.rb})
  end
end
