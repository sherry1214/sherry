# frozen_string_literal: true

# The BulkImport::Entity represents a Group or Project to be imported during the
# bulk import process. An entity is nested under the parent group when it is not
# a top level group.
#
# A full bulk import entity structure might look like this, where the links are
# parents:
#
#          **Before Import**              **After Import**
#
#             GroupEntity                      Group
#              |      |                        |   |
#     GroupEntity   ProjectEntity          Group   Project
#          |                                 |
#    ProjectEntity                        Project
#
# The tree structure of the entities results in the same structure for imported
# Groups and Projects.
class BulkImports::Entity < ApplicationRecord
  self.table_name = 'bulk_import_entities'

  FailedError = Class.new(StandardError)

  belongs_to :bulk_import, optional: false
  belongs_to :parent, class_name: 'BulkImports::Entity', optional: true

  belongs_to :project, optional: true
  belongs_to :group, foreign_key: :namespace_id, optional: true, inverse_of: :bulk_import_entities

  has_many :trackers,
    class_name: 'BulkImports::Tracker',
    inverse_of: :entity,
    foreign_key: :bulk_import_entity_id

  has_many :failures,
    class_name: 'BulkImports::Failure',
    inverse_of: :entity,
    foreign_key: :bulk_import_entity_id

  validates :project, absence: true, if: :group
  validates :group, absence: true, if: :project
  validates :source_type, presence: true
  validates :source_full_path,
            presence: true,
            format: { with: Gitlab::Regex.bulk_import_source_full_path_regex,
                      message: Gitlab::Regex.bulk_import_destination_namespace_path_regex_message }

  validates :destination_name,
            presence: true,
            format: { with: Gitlab::Regex.group_path_regex,
                      message: Gitlab::Regex.group_path_regex_message }

  validates :destination_namespace,
            exclusion: [nil],
            format: { with: Gitlab::Regex.bulk_import_destination_namespace_path_regex,
                      message: Gitlab::Regex.bulk_import_destination_namespace_path_regex_message },
            if: :group

  validates :destination_namespace,
            presence: true,
            format: { with: Gitlab::Regex.bulk_import_destination_namespace_path_regex,
                      message: Gitlab::Regex.bulk_import_destination_namespace_path_regex_message },
            if: :project

  validate :validate_parent_is_a_group, if: :parent
  validate :validate_imported_entity_type

  validate :validate_destination_namespace_ascendency, if: :group_entity?

  enum source_type: { group_entity: 0, project_entity: 1 }

  scope :by_user_id, ->(user_id) { joins(:bulk_import).where(bulk_imports: { user_id: user_id }) }
  scope :stale, -> { where('created_at < ?', 8.hours.ago).where(status: [0, 1]) }
  scope :by_bulk_import_id, ->(bulk_import_id) { where(bulk_import_id: bulk_import_id) }
  scope :order_by_created_at, ->(direction) { order(created_at: direction) }

  alias_attribute :destination_slug, :destination_name

  delegate  :default_project_visibility,
            :default_group_visibility,
            to: :'Gitlab::CurrentSettings.current_application_settings'

  state_machine :status, initial: :created do
    state :created, value: 0
    state :started, value: 1
    state :finished, value: 2
    state :timeout, value: 3
    state :failed, value: -1

    event :start do
      transition created: :started
    end

    event :finish do
      transition started: :finished
      transition failed: :failed
    end

    event :fail_op do
      transition any => :failed
    end

    event :cleanup_stale do
      transition created: :timeout
      transition started: :timeout
    end

    # rubocop:disable Style/SymbolProc
    after_transition any => [:finished, :failed, :timeout] do |entity|
      entity.update_has_failures
    end
    # rubocop:enable Style/SymbolProc
  end

  def self.all_human_statuses
    state_machine.states.map(&:human_name)
  end

  def encoded_source_full_path
    ERB::Util.url_encode(source_full_path)
  end

  def pipelines
    @pipelines ||= case source_type
                   when 'group_entity'
                     BulkImports::Groups::Stage.new(self).pipelines
                   when 'project_entity'
                     BulkImports::Projects::Stage.new(self).pipelines
                   end
  end

  def pipeline_exists?(name)
    pipelines.any? { _1[:pipeline].to_s == name.to_s }
  end

  def entity_type
    source_type.gsub('_entity', '')
  end

  def pluralized_name
    entity_type.pluralize
  end

  def base_resource_url_path
    "/#{pluralized_name}/#{encoded_source_full_path}"
  end

  def base_xid_resource_url_path
    "/#{pluralized_name}/#{source_xid}"
  end

  def base_resource_path
    if source_xid.present?
      base_xid_resource_url_path
    else
      base_resource_url_path
    end
  end

  def export_relations_url_path
    "#{base_resource_path}/export_relations"
  end

  def relation_download_url_path(relation)
    "#{export_relations_url_path}/download?relation=#{relation}"
  end

  def wikis_url_path
    "#{base_resource_path}/wikis"
  end

  def project?
    source_type == 'project_entity'
  end

  def group?
    source_type == 'group_entity'
  end

  def update_service
    "::#{pluralized_name.capitalize}::UpdateService".constantize
  end

  def full_path
    project? ? project&.full_path : group&.full_path
  end

  def default_visibility_level
    return default_group_visibility if group?

    default_project_visibility
  end

  def update_has_failures
    return if has_failures
    return unless failures.any?

    update!(has_failures: true)
  end

  private

  def validate_parent_is_a_group
    unless parent.group_entity?
      errors.add(:parent, s_('BulkImport|must be a group'))
    end
  end

  def validate_imported_entity_type
    if group.present? && project_entity?
      errors.add(
        :group,
        s_('BulkImport|expected an associated Project but has an associated Group')
      )
    end

    if project.present? && group_entity?
      errors.add(
        :project,
        s_('BulkImport|expected an associated Group but has an associated Project')
      )
    end
  end

  def validate_destination_namespace_ascendency
    source = Group.find_by_full_path(source_full_path)

    return unless source

    if source.self_and_descendants.any? { |namespace| namespace.full_path == destination_namespace }
      errors.add(
        :base,
        s_('BulkImport|Import failed: Destination cannot be a subgroup of the source group. Change the destination and try again.')
      )
    end
  end
end
