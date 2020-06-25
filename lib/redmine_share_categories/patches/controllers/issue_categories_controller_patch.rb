module RedmineShareCategories
  module Patches
    module Controllers
      module IssueCategoriesControllerPatch
        def self.included(base) # :nodoc:
          base.send(:include, InstanceMethods)

          base.class_eval do
            helper :issue_categories
            helper :projects
            include ProjectsHelper
            alias_method :create_without_shared_categories, :create
            alias_method :create, :create_with_shared_categories

            alias_method :update_without_shared_categories, :update
            alias_method :update, :update_with_shared_categories

          end
        end
      end

      module InstanceMethods
        def create_with_shared_categories
          @category = @project.issue_categories.build
          if params[:issue_category]
            attributes = params[:issue_category].dup
            attributes.delete('sharing') unless attributes.nil? || @category.allowed_sharings.include?(attributes['sharing'])
            @category.safe_attributes = attributes
          end

          if request.post?
            if @category.save
              respond_to do |format|
                format.html do
                  flash[:notice] = l(:notice_successful_create)
                  redirect_back_or_default settings_project_path(@project, :tab => 'categories')
                end
                format.js
                format.api do
                  render :action => 'show', :status => :created, :location => issue_category_path(@category)
                end
              end
            else
              respond_to do |format|
                format.html { render :action => 'new' }
                format.js { render :action => 'new' }
                format.api { render_validation_errors(@category) }
              end
            end

          end
        end

        def update_with_shared_categories
          if params[:issue_category]
            attributes = params[:issue_category].dup
            attributes.delete('sharing') unless @category.allowed_sharings.include?(attributes['sharing'])
            @category.safe_attributes = attributes
            if @category.save
              respond_to do |format|
                format.html {
                  flash[:notice] = l(:notice_successful_update)
                  redirect_back_or_default settings_project_path(@project, :tab => 'categories')
                }
                format.api { render_api_ok }
              end
            else
              respond_to do |format|
                format.html { render :action => 'edit' }
                format.api { render_validation_errors(@category) }
              end
            end
          end
        end
      end
    end
  end
end

unless IssueCategoriesController.included_modules.include?(RedmineShareCategories::Patches::Controllers::IssueCategoriesControllerPatch)
  IssueCategoriesController.send(:include, RedmineShareCategories::Patches::Controllers::IssueCategoriesControllerPatch)
end