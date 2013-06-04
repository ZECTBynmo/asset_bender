# Wrapping a string in this class gives you a prettier way to test
# for equality.
#
#   Something.env == 'production'
#
# you can call this:
#
#   Something.env.production?
#
# Stolen from https://github.com/rails/rails/blob/master/activesupport/lib/active_support/string_inquirer.rb
class StringInquirer < String
  private

    def respond_to_missing?(method_name, include_private = false)
      method_name[-1] == '?'
    end

    def method_missing(method_name, *arguments)
      if method_name[-1] == '?'
        self == method_name[0..-2]
      else
        super
      end
    end
end
