module RedmineShareCategories
  module Patches
    module Models
      module IssueCategoryPatch
        def self.included(base) # :nodoc:
          base.send(:include, InstanceMethods)
          # CATEGORY_SHARINGS =
          base.class_eval do
            after_update :update_issues_from_sharing_change

            validates_inclusion_of :sharing, :in => %w(none descendants hierarchy tree system)
            safe_attributes 'name', 'assigned_to_id', 'sharing'

            scope :visible, lambda {|*args|
              joins(:project).
                  where(Project.allowed_to_condition(args.first || User.current, :view_issues))
            }

          end
        end
      end

      module InstanceMethods

        def category_sharing
          %w(none descendants hierarchy tree system)
        end

        def visible?(user=User.current)
          user.allowed_to?(:view_issues, self.project)
        end

        def open?
          true
        end

        # Returns the sharings that user can set the version to
        def allowed_sharings(user = User.current)
          category_sharing.select do |s|
            if sharing == s
              true
            else
              case s
              when 'system'
                # Only admin users can set a systemwide sharing
                user.admin?
              when 'hierarchy', 'tree'
                # Only users allowed to manage versions of the root project can
                # set sharing to hierarchy or tree
                project.nil? || user.allowed_to?(:manage_categories, project.root)
              else
                true
              end
            end
          end
        end

        # Returns true if the version is shared, otherwise false
        def shared?
          sharing != 'none'
        end

        # treat categories like fixed versions
        # Update the issue's fixed versions. Used if a version's sharing changes.
        def update_issues_from_sharing_change
          if sharing_changed?
            if category_sharing.index(sharing_was).nil? ||
                category_sharing.index(sharing).nil? ||
                category_sharing.index(sharing_was) > category_sharing.index(sharing)
              Issue.update_categories_from_sharing_change self
            end
          end
        end

      end
    end
  end
end

unless IssueCategory.included_modules.include?(RedmineShareCategories::Patches::Models::IssueCategoryPatch)
  IssueCategory.send(:include, RedmineShareCategories::Patches::Models::IssueCategoryPatch)
end