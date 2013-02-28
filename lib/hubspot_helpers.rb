module HubspotHelpers
    JS_EXTENSIONS = ["js", "coffee", "handlebars"]
    CSS_EXTENSIONS = ["css", "sass", "scss"]

    def extract_file_extension(path)
        extension = nil

        filename = path.split('/')[-1]
        last_period_index = filename.rindex('.')

        # Grab extension if it exists
        extension = filename[last_period_index + 1..-1] if last_period_index

        # If the extension is erb, look for the next extension down
        extension = extract_file_extension(filename[0 ... last_period_index]) if extension == 'erb'
        
        extension
    end

    # Returns true if the path ends with a javascript-ish file extention. Or if there
    # is no file extention, looks for a javascript-ish folder in the path.
    def is_js_bundle(path)
        path = path.to_s
        file_extension = extract_file_extension path

        if file_extension
            JS_EXTENSIONS.include? file_extension
        else
            JS_EXTENSIONS.any? {|ext| path.include? "/#{ext}/" }
        end
    end

    # Returns true if the path ends with a css-ish file extention. Or if there
    # is no file extention, looks for a css-ish folder in the path.
    def is_css_bundle(path)
        path = path.to_s

        file_extension = extract_file_extension path

        if file_extension
            CSS_EXTENSIONS.include? file_extension
        else
            CSS_EXTENSIONS.any? {|ext| path.include? "/#{ext}/" }
        end
    end
end
