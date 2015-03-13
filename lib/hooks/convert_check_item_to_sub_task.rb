require_relative 'base'
require_relative 'hook_helper'
require_relative '../trello/convert_to_card_action'

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
				
				#add converted card as checklist item to source card
				checklist_names = action.source_card.checklists.map { |checklist| checklist.name.downcase }
				index = checklist_names.find_index("sub tasks")
				checklist = action.source_card.checklists[index]
				checklist.add_item(card.short_url)

				#add link to source card to converted card description
				card.desc="parent task: #{action.source_card.short_url}\n#{card.desc}"
				card.update!
			end
		end
	end
end