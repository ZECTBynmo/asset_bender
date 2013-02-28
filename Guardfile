# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard 'livereload' do
  watch(%r{(\w+/(view|static)/\w+/.+)\.(css|js|html|haml|png|gif|jpg).*})
  watch(%r{(\w+/(view|static)/\w+/.+)\.(sass|scss).*}) { |m| "#{m[1]}.css" }
  watch(%r{(\w+/(view|static)/\w+/.+)\.(coffee).*}) { |m| "#{m[1]}.js" }
end
