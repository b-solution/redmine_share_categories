module RedmineShareCategories
  module Patches
    module Controllers
      module IssuesControllerPatch
        def self.included(base) # :nodoc:
          base.send(:include, InstanceMethods)

          base.class_eval do


          end
        end
      end

      module InstanceMethods

      end
    end
  end
end

unless IssuesController.included_modules.include?(RedmineShareCategories::Patches::Controllers::IssuesControllerPatch)
  IssuesController.send(:include, RedmineShareCategories::Patches::Controllers::IssuesControllerPatch)
end