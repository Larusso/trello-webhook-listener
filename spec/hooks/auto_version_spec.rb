require_relative '../spec_helper'

module Hooks
	describe AutoVersion do
		include Helpers

		let(:action) 	{Trello::Action.new action_details(c)}
		let(:card) 		{Trello::Card.new cards_details(c)}
		let(:list) 		{Trello::List.new lists_details(c)}
		let(:board) 	{Trello::Board.new boards_details}
		let(:member) 	{Trello::Member.new user_details}
		let(:client) 	{Trello.client}
		let(:c) 		{:create_card}

		subject {Hooks::AutoVersion.new action}

		before(:each) do

			logger_mock = double('Logger').as_null_object
    		allow(Hooks).to receive(:logger).and_return(logger_mock)

			allow_get "/actions/abcdef123456789123456789/card", anything(), cards_payload(c)
			allow_get "/actions/abcdef123456789123456789/list", anything(), lists_payload(c)
			allow_get "/actions/abcdef123456789123456789/board", anything() , boards_payload
			allow_get "/boards/abcdef123456789123456789/labels", anything() , board_labels_payload(c)
			#allow_get "/cards/abcdef123456789123456789/labels", anything() , board_labels_payload(c)
			allow_get "/members/abcdef123456789123456789", anything, JSON.generate(user_details)

			allow(client).to receive(:get).with("/cards/abcdef123456789123456789/labels").
				and_return(board_labels_payload(c), JSON.generate(board_labels(c) + [version_label(version)]))
		end

		shared_examples_for "create card" do
			describe "#new" do
				it {expect(subject.action).not_to be_nil}

				it {expect(subject.action).to be_kind_of(Trello::Action)}
				it {expect(subject.action.id).to eq(action.id)}

				it {expect(subject.card).to be_kind_of(Trello::Card)}
				it {expect(subject.card.id).to eq(card.id)}

				it {expect(subject.list).to be_kind_of(Trello::List)}
				it {expect(subject.list.id).to eq(list.id)}

				it {expect(subject.board).to be_kind_of(Trello::Board)}
				it {expect(subject.board.id).to eq(board.id)}

				it {expect(subject.member_creator).to be_kind_of(Trello::Member)}
				it {expect(subject.member_creator.id).to eq(member.id)}

				describe '.card_created?' do
					it { expect(subject.card_created?).to eq(true) }
				end

				describe '.list_updated?' do
					it { expect(subject.list_updated?).to eq(false) }
				end

				describe '.card_update?' do
					it { expect(subject.card_update?).to eq(false) }
				end

				describe '.list_version' do
					it { expect(subject.list_version).to eq(version) }
					it { expect(subject.list_version).to be_kind_of(String) }
				end

				describe '.versioned_list?' do	
					it { expect(subject.versioned_list?).to eq(true) }
				end

				describe '.board_has_label?' do
					it { expect(subject.board_has_label? version).to be_boolean}
					it { expect(subject.board_has_label? version).to eq(false)}
					it { expect(subject.board_has_label? '4.5.6').to eq(true)}
				end

				describe '.board_version_labels' do
					it { expect(subject.board_version_labels).not_to be_nil}
					it { expect(subject.board_version_labels.count).to eql(2)}
				end

				describe '.card_has_label?' do
					it { expect(subject.card_has_label? subject.card, version).to be_boolean}
					it { expect(subject.card_has_label? subject.card, version).to eq(false)}
					it { expect(subject.card_has_label? subject.card, '4.5.6').to eq(true)}
				end

				describe '.card_version_labels' do
					it { expect(subject.card_version_labels).not_to be_nil}
					it { expect(subject.card_version_labels.count).to eql(2)}
				end
			end

			describe '.execute' do
				context 'board has no version label' do
					it 'executes' do
						allow(client).to receive(:get).with("/boards/abcdef123456789123456789/labels").
						and_return(board_labels_payload(c))

						expect(client).to receive(:post).with("/labels", hash_including(name: version, idBoard: board.id)).
						and_return(JSON.generate(version_label(version)))

						expect(client).to receive(:delete).twice.with("/cards/#{card.id}/idLabels/54656d9574d650d5672a06df")
						expect(client).to receive(:post).with("/cards/#{card.id}/idLabels", {value: 'abcdef123456789123456789'})

						subject.execute
					end
				end

				context 'board has version label' do
					it 'executes' do
						allow(client).to receive(:get).with("/boards/abcdef123456789123456789/labels").
						and_return(JSON.generate([version_label(version)] + board_labels(c)))

						expect(client).not_to receive(:post).with("/labels", hash_including(name: version, idBoard: board.id))
						expect(client).to receive(:delete).twice.with("/cards/#{card.id}/idLabels/54656d9574d650d5672a06df")
						expect(client).to receive(:post).with("/cards/#{card.id}/idLabels", {value: 'abcdef123456789123456789'})

						subject.execute
					end
				end

				context 'card has version label' do
					it 'executes' do
						allow_get "/cards/abcdef123456789123456789/labels", anything() , JSON.generate(board_labels(c) + [version_label(version)])
						allow(client).to receive(:get).with("/boards/abcdef123456789123456789/labels").
						and_return(JSON.generate(board_labels(c) + [version_label(version)]))

						expect(client).not_to receive(:post).with("/labels", hash_including(name: version, idBoard: board.id))
						expect(client).not_to receive(:delete).with("/cards/#{card.id}/idLabels/54656d9574d650d5672a06df")
						expect(client).not_to receive(:post).with("/cards/#{card.id}/idLabels", {value: 'abcdef123456789123456789'})

						subject.execute
					end
				end
			end
		end

		context 'when creating card in version list' do
			let(:c) {:create_card}
			let(:version) {'1.22.1'}

			it_behaves_like "create card"
		end

		context 'when converting card from checkitem in version list' do
			let(:c) {:convert_card}
			let(:version) {'1.22.1'}

			it_behaves_like "create card"
		end

		context 'when moving card' do
			let(:c) {:move_card}
			let(:version) {'1.22.1'}

			before :each do
				allow_get "/actions/abcdef123456789123456789/list", anything(), nil
				allow_get "/lists/abcdef123456789123456789", anything(), lists_payload(c)
			end

			describe "#new" do
				it {expect(subject.action).not_to be_nil}
				it {expect(subject.card).not_to be_nil}
				it {expect(subject.list).to be_nil}
				it {expect(subject.board).not_to be_nil}
				it {expect(subject.member_creator).not_to be_nil}
			end

			describe '.card_created?' do
				it { expect(subject.card_created?).to eq(false) }
			end

			describe '.list_updated?' do
				it { expect(subject.list_updated?).to eq(false) }
			end

			describe '.card_update?' do
				it { expect(subject.card_update?).to eq(true) }
			end

			describe '.card_moved?' do
				it { expect(subject.card_moved?).to eq(true) }
			end

			describe '.versioned_list?' do
				it { expect(subject.versioned_list?).to eq(false) }
			end

			describe '.execute' do
				context 'board has no version label' do
					it 'executes' do
						allow(client).to receive(:get).with("/boards/abcdef123456789123456789/labels").
						and_return(board_labels_payload(c), JSON.generate(board_labels(c) + [version_label(version)]))

						expect(client).to receive(:post).with("/labels", hash_including(name: version, idBoard: board.id)).
						and_return(JSON.generate(version_label(version)))

						expect(client).to receive(:delete).twice.with("/cards/#{card.id}/idLabels/54656d9574d650d5672a06df")
						expect(client).to receive(:post).with("/cards/#{card.id}/idLabels", {value: 'abcdef123456789123456789'})

						subject.execute
					end

					it 'executes' do
						allow(client).to receive(:get).with("/boards/abcdef123456789123456789/labels").
						and_return(board_labels_payload(c), JSON.generate(board_labels(c) + [version_label(version)]))

						expect(client).to receive(:post).with("/labels", hash_excluding(color: nil)).
						and_return(JSON.generate(version_label(version)))

						allow(client).to receive(:delete).twice.with("/cards/#{card.id}/idLabels/54656d9574d650d5672a06df")
						allow(client).to receive(:post).with("/cards/#{card.id}/idLabels", {value: 'abcdef123456789123456789'})
						subject.execute
					end
				end
		
				context 'board has version label' do
					it 'executes' do
						allow(client).to receive(:get).with("/boards/abcdef123456789123456789/labels").
						and_return(JSON.generate(board_labels(c) + [version_label(version)]))

						expect(client).not_to receive(:post).with("/labels", hash_including(name: version, idBoard: board.id))
						expect(client).to receive(:delete).twice.with("/cards/#{card.id}/idLabels/54656d9574d650d5672a06df")
						expect(client).to receive(:post).with("/cards/#{card.id}/idLabels", {value: 'abcdef123456789123456789'})

						subject.execute
					end
				end

				context 'card has version label' do
					it 'executes' do
						allow_get "/cards/abcdef123456789123456789/labels", anything() , JSON.generate(board_labels(c) + [version_label(version)])
						allow(client).to receive(:get).with("/boards/abcdef123456789123456789/labels").
						and_return(JSON.generate(board_labels(c) + [version_label(version)]))

						expect(client).not_to receive(:post).with("/labels", hash_including(name: version, idBoard: board.id))
						expect(client).not_to receive(:delete).with("/cards/#{card.id}/idLabels/54656d9574d650d5672a06df")
						expect(client).not_to receive(:post).with("/cards/#{card.id}/idLabels", {value: 'abcdef123456789123456789'})

						subject.execute
					end
				end
			end
		end

		context 'when updating versioned list' do
			let(:c) {:list_update}
			let(:version) {'1.22.1'}

			before :each do
				allow_get "/actions/abcdef123456789123456789/card", anything(), nil
				allow_get "/lists/abcdef123456789123456789/cards", anything(), JSON.generate([cards_details(c),cards_details(c),cards_details(c)])

				#super ugly setup here.
				# we have 3 cards in a list
				# each card will check for labels eg board_labels_payload(c)
				# than add a label
				# check the labels again eg JSON.generate(board_labels(c) + [version_label(version)])
				# delete all cards with wrong version
				# next iteration
				allow(client).to receive(:get).with("/cards/abcdef123456789123456789/labels").
				and_return(board_labels_payload(c), JSON.generate(board_labels(c) + [version_label(version)]),
					board_labels_payload(c), JSON.generate(board_labels(c) + [version_label(version)]),
					board_labels_payload(c), JSON.generate(board_labels(c) + [version_label(version)]))
			end

			describe "#new" do
				it {expect(subject.action).not_to be_nil}
				it {expect(subject.card).to be_nil}
				it {expect(subject.list).not_to be_nil}
				it {expect(subject.board).not_to be_nil}
				it {expect(subject.member_creator).not_to be_nil}
			end

			describe '.card_created?' do
				it { expect(subject.card_created?).to eq(false) }
			end

			describe '.list_updated?' do
				it { expect(subject.list_updated?).to eq(true) }
			end

			describe '.card_update?' do
				it { expect(subject.card_update?).to eq(false) }
			end

			describe '.list_version' do
				it { expect(subject.list_version).to eq(version) }
				it { expect(subject.list_version).to be_kind_of(String) }
			end

			describe '.versioned_list?' do
				it { expect(subject.versioned_list?).to be_boolean }
				it { expect(subject.versioned_list?).to eq(true) }
			end

			describe '.execute' do
				context 'board has no version label' do
					it 'executes' do
						allow(client).to receive(:get).with("/boards/abcdef123456789123456789/labels").
						and_return(board_labels_payload(c), JSON.generate(board_labels(c) + [version_label(version)]))

						expect(client).to receive(:post).with("/labels", hash_including(name: version, idBoard: board.id)).
						and_return(JSON.generate(version_label(version)))

						expect(client).to receive(:delete).exactly(6).times.with("/cards/#{card.id}/idLabels/54656d9574d650d5672a06df")
						expect(client).to receive(:post).exactly(3).with("/cards/#{card.id}/idLabels", {value: 'abcdef123456789123456789'})

						subject.execute
					end
				end

				context 'board has version label' do
					it 'executes' do
						allow(client).to receive(:get).with("/boards/abcdef123456789123456789/labels").
						and_return(JSON.generate(board_labels(c) + [version_label(version)]))

						expect(client).not_to receive(:post).with("/labels", hash_including(name: version, idBoard: board.id))
						expect(client).to receive(:delete).exactly(6).times.with("/cards/#{card.id}/idLabels/54656d9574d650d5672a06df")
						expect(client).to receive(:post).exactly(3).times.with("/cards/#{card.id}/idLabels", {value: 'abcdef123456789123456789'})

						subject.execute
					end
				end

				context 'card has version label' do
					it 'executes' do
						allow_get "/cards/abcdef123456789123456789/labels", anything() , JSON.generate(board_labels(c) + [version_label(version)])
						allow(client).to receive(:get).with("/boards/abcdef123456789123456789/labels").
						and_return(JSON.generate(board_labels(c) + [version_label(version)]))

						expect(client).not_to receive(:post).with("/labels", hash_including(name: version, idBoard: board.id))
						expect(client).not_to receive(:delete).with("/cards/#{card.id}/idLabels/54656d9574d650d5672a06df")
						expect(client).not_to receive(:post).with("/cards/#{card.id}/idLabels", {value: 'abcdef123456789123456789'})

						subject.execute
					end
				end
			end
		end
	end
end