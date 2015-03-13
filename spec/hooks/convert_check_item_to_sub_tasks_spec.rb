require_relative '../spec_helper'

module Hooks
	describe ConvertCheckItemToSubTask do
		include Helpers

		let(:action) 	{Trello::Action.new action_details(c)}
		let(:client) 	{Trello.client}
		let(:c) 		{:convert_card}

		subject {Hooks::ConvertCheckItemToSubTask.new action}

		before(:each) do
			logger_mock = double('Logger').as_null_object
    		allow(Hooks).to receive(:logger).and_return(logger_mock)
    		allow_get "/actions/abcdef123456789123456789", anything(), action_payload(c)
    	end

    	describe '#new' do
    		context 'when creating with invalid action (create card)' do
    			let(:c) {:create_card}

    			it 'fails with json' do
    				expect{ Hooks::ConvertCheckItemToSubTask.new action_payload(c) }.to raise_error(Failure)	
    			end

    			it 'fails with Hash' do
    				expect{ Hooks::ConvertCheckItemToSubTask.new action_details(c) }.to raise_error(Failure)	
    			end

    			it 'fails with Trello::Action' do
    				expect{ Hooks::ConvertCheckItemToSubTask.new(Trello::Action.new action_details(c)) }.to raise_error(Failure)	
    			end

    			it 'fails with Trello::ConvertToCardAction' do
    				expect{ Hooks::ConvertCheckItemToSubTask.new(Trello::ConvertToCardAction.new action_details(c)) }.to raise_error(Failure)	
    			end
    		end

    		context 'when creating with valid action (convertToCardFromCheckItem)' do
    			let(:c) {:convert_card}

    			it 'succeeds with json' do
    				expect{ Hooks::ConvertCheckItemToSubTask.new action_payload(c) }.not_to raise_error
    			end

    			it 'succeeds with Hash' do
    				expect{ Hooks::ConvertCheckItemToSubTask.new action_details(c) }.not_to raise_error
    			end

    			it 'succeeds with Trello::Action' do
    				expect{ Hooks::ConvertCheckItemToSubTask.new(Trello::Action.new action_details(c)) }.not_to raise_error	
    			end

    			it 'succeeds with Trello::ConvertToCardAction' do
    				expect{ Hooks::ConvertCheckItemToSubTask.new(Trello::ConvertToCardAction.new action_details(c)) }.not_to raise_error	
    			end
    		end
		end

		describe '.execute' do

			before :each do
				allow_get "/cards/54eef8a54e22aeee50bcee3f", anything(), cards_payload(:create_card)
				allow_get "/actions/abcdef123456789123456789/card", anything(), cards_payload(:create_card)
				allow_get "/cards/abcdef123456789123456789/checklists", anything(), check_list_payload
			end

			context 'when source card hash one sub task' do
				let(:check_list_payload) {JSON.generate( [named_checklist("sub tasks")])}
				
				it "adds checklist item to source card" do
					expect(client).to receive(:post).with("/checklists/namedabcdef123456789123456789/checkItems", hash_including(name: "https://trello.com/c/abcdef12", checked: false))
					subject.execute
				end
			end

			context 'when source card hash many sub task' do
				let(:check_list_payload) {JSON.generate(checklists_details + [named_checklist("sub tasks")])}
				
				it "adds checklist item to source card" do
					expect(client).to receive(:post).with("/checklists/namedabcdef123456789123456789/checkItems", hash_including(name: "https://trello.com/c/abcdef12", checked: false))
					subject.execute
				end
			end

			context 'when source card has no sub tasks' do
				let(:check_list_payload) {checklists_payload 1}

				it "adds no checklist item to source card" do
					expect(client).not_to receive(:post).with("/checklists/abcdef123456789123456789/checkItems", anything )
					subject.execute
				end
			end
		end
	end
end