module RedmineShareCategories
  module Patches
    module Models
      module ProjectPatch
        def self.included(base) # :nodoc:
          base.send(:include, InstanceMethods)

          base.class_eval do


          end
        end
      end

      module InstanceMethods
        def inherited_projects
          l = [self]
          self_and_ancestors.reverse.each { |p|
            if p.inherit_categs and ! p.parent.nil?
              l << p.parent
            else
              break
            end
          }
          return l
        end
        # get inherited categories (all = false) or all categories from inherited
        # projects if all is true
        def inherited_categories(all = false)
          categs = IssueCategory.find(:all ,
                                      :joins => :project,
                                      :conditions => { :project_id => inherited_projects },
                                      :order => "name, #{Project.table_name}.rgt")
          old = nil
          # a category from a deep project masks categories of same name from others
          return all ? categs : categs.reject { |c| cr = (c.name == old)
          old = c.name
          cr
          }
        end

        # Returns a scope of the Categories used by the project
        def shared_categories
          if new_record?
            IssueCategory.
                joins(:project).
                preload(:project).
                where("#{Project.table_name}.status <> ? AND #{IssueCategory.table_name}.sharing = 'system'", STATUS_ARCHIVED)
          else
            @shared_categories ||= begin
                                     r = root? ? self : root
                                     IssueCategory.
                                         joins(:project).
                                         preload(:project).
                                         where("#{Project.table_name}.id = #{id}" +
                                                   " OR (#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED} AND (" +
                                                   " #{IssueCategory.table_name}.sharing = 'system'" +
                                                   " OR (#{Project.table_name}.lft >= #{r.lft} AND #{Project.table_name}.rgt <= #{r.rgt} AND #{IssueCategory.table_name}.sharing = 'tree')" +
                                                   " OR (#{Project.table_name}.lft < #{lft} AND #{Project.table_name}.rgt > #{rgt} AND #{IssueCategory.table_name}.sharing IN ('hierarchy', 'descendants'))" +
                                                   " OR (#{Project.table_name}.lft > #{lft} AND #{Project.table_name}.rgt < #{rgt} AND #{IssueCategory.table_name}.sharing = 'hierarchy')" +
                                                   "))")
                                   end
          end
        end


      end
    end
  end
end

unless Project.included_modules.include?(RedmineShareCategories::Patches::Models::ProjectPatch)
  Project.send(:include, RedmineShareCategories::Patches::Models::ProjectPatch)
end