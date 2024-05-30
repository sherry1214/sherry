# frozen_string_literal: true

class AddAgentActivityEventsAgentProjectIdTrigger < Gitlab::Database::Migration[2.2]
  milestone '17.1'

  def up
    install_sharding_key_assignment_trigger(
      table: :agent_activity_events,
      sharding_key: :agent_project_id,
      parent_table: :cluster_agents,
      parent_sharding_key: :project_id,
      foreign_key: :agent_id
    )
  end

  def down
    remove_sharding_key_assignment_trigger(
      table: :agent_activity_events,
      sharding_key: :agent_project_id,
      parent_table: :cluster_agents,
      parent_sharding_key: :project_id,
      foreign_key: :agent_id
    )
  end
end
