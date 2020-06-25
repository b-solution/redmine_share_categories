module RedmineShareCategories
  module Patches
    module Controllers
      module ContextMenusControllerPatch
        def self.included(base) # :nodoc:
          base.send(:include, InstanceMethods)

          base.class_eval do
            alias_method :issues_without_shared_categories, :issues
            alias_method :issues, :issues_with_shared_categories

          end
        end
      end

      module InstanceMethods
        def issues_with_shared_categories
          if (@issues.size == 1)
            @issue = @issues.first
          end
          @issue_ids = @issues.map(&:id).sort

          @allowed_statuses = @issues.map(&:new_statuses_allowed_to).reduce(:&)

          @can = {:edit => @issues.all?(&:attributes_editable?),
                  :log_time => (@project && User.current.allowed_to?(:log_time, @project)),
                  :copy => User.current.allowed_to?(:copy_issues, @projects) && Issue.allowed_target_projects.any?,
                  :add_watchers => User.current.allowed_to?(:add_issue_watchers, @projects),
                  :delete => @issues.all?(&:deletable?)
          }

          @assignables = @issues.map(&:assignable_users).reduce(:&)
          @trackers = @projects.map {|p| Issue.allowed_target_trackers(p) }.reduce(:&)
          @versions = @projects.map {|p| p.shared_versions.open}.reduce(:&)

          @categories = @projects.map {|p| p.shared_categories}.reduce(:&)
          @priorities = IssuePriority.active.reverse
          @back = back_url

          @options_by_custom_field = {}
          if @can[:edit]
            custom_fields = @issues.map(&:editable_custom_fields).reduce(:&).reject(&:multiple?).select {|field| field.format.bulk_edit_supported}
            custom_fields.each do |field|
              values = field.possible_values_options(@projects)
              if values.present?
                @options_by_custom_field[field] = values
              end
            end
          end

          @safe_attributes = @issues.map(&:safe_attribute_names).reduce(:&)
          render :layout => false
        end
      end
    end
  end
end

unless ContextMenusController.included_modules.include?(RedmineShareCategories::Patches::Controllers::ContextMenusControllerPatch)
  ContextMenusController.send(:include, RedmineShareCategories::Patches::Controllers::ContextMenusControllerPatch)
end