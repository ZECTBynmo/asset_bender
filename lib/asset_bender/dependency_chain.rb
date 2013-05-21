module AssetBender

    class CircularDependencyError < AssetBender::Error
        attr_reader :dep_chain

        def initialize(dep_chain)
            @dep_chain = dep_chain
        end

        def message
            "Failing build due to circular dependency at #{@dep_chain} !!"
        end
    end

    class DependencyChain < Array
        attr_reader :parent

        def initialize(chain_parent_or_chain)
            if chain_parent_or_chain.is_a? DependencyChain
                other_chain = chain_parent_or_chain

                @parent = other_chain.parent
                self.concat other_chain
            else
                @parent = chain_parent_or_chain
            end
        end

        def add_link proj_or_dep
            self << project_or_dep
        end

        def to_s
            "#{parent} -> #{self.join(' -> ')}"
        end
    end
    

end
