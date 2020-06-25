Redmine::Plugin.register :redmine_share_categories do
  name 'Redmine Share Categories plugin'
  author 'Bilel kedidi'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'https://www.github.com/bilel-kedidi/redmine_share_categories'
  author_url 'https://www.github.com/bilel-kedidi'
end

require 'redmine_share_categories/patches/controllers/context_menus_controller_patch'
require 'redmine_share_categories/patches/controllers/issue_categories_controller_patch'
require 'redmine_share_categories/patches/controllers/issues_controller_patch'

# require 'redmine_share_categories/patches/helpers/issue_categories_helper_patch'
# require 'redmine_share_categories/patches/helpers/projects_helper_patch'

require 'redmine_share_categories/patches/models/issue_patch'
require 'redmine_share_categories/patches/models/issue_category_patch'
require 'redmine_share_categories/patches/models/project_patch'

module IssueCategoriesHelper

  def category_filtered_issues_path(category, options = {})
    options = {:category_id => category, :set_filter => 1}.merge(options)
    project = case category.sharing
              when 'hierarchy', 'tree'
                if version.project && category.project.root.visible?
                  category.project.root
                else
                  category.project
                end
              when 'system'
                nil
              else
                category.project
              end

    if project
      project_issues_path(project, options)
    else
      issues_path(options)
    end
  end
end

module ProjectsHelper
  def format_category_sharing(sharing)
    sharing = 'none' unless %w(none descendants hierarchy tree system).include?(sharing)
    l("label_category_sharing_#{sharing}")
  end

  def category_options_for_select(categories, selected=nil)
    grouped = Hash.new {|h,k| h[k] = []}
    categories.each do |category|
      grouped[category.project.name] << [category.name, category.id]
    end

    selected = selected.is_a?(IssueCategory) ? selected.id : selected
    if grouped.keys.size > 1
      grouped_options_for_select(grouped, selected)
    else
      options_for_select((grouped.values.first || []), selected)
    end
  end

end

