module RedmineShareCategories
  module Patches
    module Models
      module IssuePatch
        def self.included(base) # :nodoc:
          base.send(:include, InstanceMethods)

          base.class_eval do
            alias_method :reload_without_shared_categories, :reload
            alias_method :reload, :reload_with_shared_categories

            # alias_method :blocked_without_shared_categories?, :blocked?
            # alias_method :blocked?, :blocked_with_shared_categories?

            alias_method :project_without_shared_categories=, :project=
            alias_method :project=, :project_with_shared_categories=

            alias_method :validate_required_fields_without_shared_categories, :validate_required_fields
            alias_method :validate_required_fields, :validate_required_fields_with_shared_categories

          end
        end
      end

      module InstanceMethods

        # Unassigns issues from categories if it's no longer shared with issue's project
        def self.update_categories_from_sharing_change(category)
          # Update issues assigned to the category
          update_categories(["#{Issue.table_name}.category_id = ?", category.id])
        end

        # Unassigns issues from categories that are no longer shared
        # after project was moved
        def self.update_categories_from_hierarchy_change(project)
          moved_project_ids = project.self_and_descendants.reload.collect(&:id)
          # Update issues of the moved projects and issues assigned to a category of a moved project
          Issue.update_categories(
              ["#{IssueCategory.table_name}.project_id IN (?) OR #{Issue.table_name}.project_id IN (?)",
               moved_project_ids, moved_project_ids]
          )
        end

        def self.update_categories(conditions=nil)
          # Only need to update issues with a categories from
          # a different project and that is not systemwide shared
          Issue.joins(:project, :category).
              where("#{Issue.table_name}.category_id IS NOT NULL" +
                        " AND #{Issue.table_name}.project_id <> #{IssueCategory.table_name}.project_id" +
                        " AND #{IssueCategory.table_name}.sharing <> 'system'").
              where(conditions).each do |issue|
            next if issue.project.nil? || issue.category_id.nil?
            unless issue.project.shared_categories.include?(issue.category_id)
              issue.init_journal(User.current)
              issue.category_id = nil
              issue.save
            end
          end
        end


        def assignable_categories
          return @assignable_categories if @assignable_categories

          # category not status=open
          categories = project.shared_categories.to_a
          if category
            if category_id_changed?
              # nothing to do
            elsif project_id_changed?
              if project.shared_categories.include?(category)
                categories << category
              end
            else
              categories << category
            end
          end
          @assignable_categories = categories.uniq.sort
        end
        def reload_with_shared_categories(*args)
          reload_without_shared_categories(args)
          @assignable_categories = nil
        end

        def project_with_shared_categories=(project, keep_tracker = false)
          project_was = self.project
          association(:project).writer(project)
          if project != project_was
            @safe_attribute_names = nil
          end
          if project_was && project && project_was != project
            @assignable_versions = nil

            unless keep_tracker || project.trackers.include?(tracker)
              @assignable_categories = nil
              self.tracker = project.trackers.first
            end
            # Reassign to the category with same name if any

            if category && category.project != project && !project.shared_categories.include?(category)
              self.category = nil
            end

            # Clear the assignee if not available in the new project for new issues (eg. copy)
            # For existing issue, the previous assignee is still valid, so we keep it
            if new_record? && assigned_to && !assignable_users.include?(assigned_to)
              self.assigned_to_id = nil
            end
            # Keep the fixed_version if it's still valid in the new_project
            if fixed_version && fixed_version.project != project && !project.shared_versions.include?(fixed_version)
              self.fixed_version = nil
            end
            # Clear the parent task if it's no longer valid
            unless valid_parent_project?
              self.parent_issue_id = nil
            end
            reassign_custom_field_values
            @workflow_rule_by_attribute = nil
          end
          # Set fixed_version to the project default version if it's valid
          if new_record? && fixed_version.nil? && project && project.default_version_id?
            if project.shared_versions.open.exists?(project.default_version_id)
              self.fixed_version_id = project.default_version_id
            end
          end
          self.project
        end

        def validate_required_fields_with_shared_categories
          user = new_record? ? author : current_journal.try(:user)

          required_attribute_names(user).each do |attribute|
            if attribute =~ /^\d+$/
              attribute = attribute.to_i
              v = custom_field_values.detect {|v| v.custom_field_id == attribute }
              if v && Array(v.value).detect(&:present?).nil?
                errors.add :base, v.custom_field.name + ' ' + l('activerecord.errors.messages.blank')
              end
            else
              if respond_to?(attribute) && send(attribute).blank? && !disabled_core_fields.include?(attribute)
                next if attribute == 'category_id' && assignable_categories.blank?
                next if attribute == 'fixed_version_id' && assignable_versions.blank?
                errors.add attribute, :blank
              end
            end
          end
        end

        #
        # def blocked?
        #   !relations_to.detect {|ir| ir.relation_type == 'blocks' && !ir.issue_from.closed?}.nil?
        # end

      end
    end
  end
end

unless Issue.included_modules.include?(RedmineShareCategories::Patches::Models::IssuePatch)
  Issue.send(:include, RedmineShareCategories::Patches::Models::IssuePatch)
end