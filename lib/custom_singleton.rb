module AssetBender 
  module CustomSingleton
     # Raises a TypeError to prevent cloning.
    def clone
      raise TypeError, "can't clone instance of singleton #{self.class}"
    end

    # Raises a TypeError to prevent duping.
    def dup
      raise TypeError, "can't dup instance of singleton #{self.class}"
    end 

    def self.included(klass)
      klass.private_class_method :new, :allocate
    end

    def self.extended(klass)
      klass.private_class_method :new, :allocate
    end
  end

end
