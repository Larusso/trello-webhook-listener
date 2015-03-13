require_relative 'base'
require_relative 'hook_helper'

module Hooks
	class ConvertCheckItemToSubTask < Base

		include CardHelper

		def initialize action
			case action
			when String
				@action = action.json_into(Trello::ConvertToCardAction)
			when Hash
				@action = Trello::ConvertToCardAction.new action
			when Trello::ConvertToCardAction
				@action = action
			when Trello::Action
				@action = Trello::ConvertToCardAction.convert_from_action action
			end
			raise Failure unless @action.valid?
			@data = @action.data
		end

		def execute
			if task_group? action.source_card, "sub tasks"
				checklist_names = action.source_card.checklists.map { |checklist| checklist.name.downcase }
				index = checklist_names.find_index("sub tasks")
				checklist = action.source_card.checklists[index]
				checklist.add_item(card.short_url)
			end
		end
	end
end