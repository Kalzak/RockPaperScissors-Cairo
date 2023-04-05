#[contract]
mod RPS {

    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;
    use starknet::ContractAddressIntoFelt252;
    use starknet::get_block_info;
    use option::OptionTrait;
    use traits::TryInto;
    use traits::Into;
    use box::BoxTrait;

    struct Storage {
        state: felt252, // 0=JOINING, 1=SUBMITTING, 2=REVEALING
        player_one: ContractAddress,
        player_two: ContractAddress,
        player_one_hashed_move: felt252,
        player_two_hashed_move: felt252,
        player_one_move: felt252, // 1=ROCK, 2=PAPER, 3=SCISSORS
        player_two_move: felt252, // 1=ROCK, 2=PAPER, 3=SCISSORS
        player_one_interacted: bool,
        player_two_interacted: bool,
        interaction_time_limit: u64,
        previous_winner: ContractAddress,
    }

    //////////////////////////////////////////
    // EVENTS
    //////////////////////////////////////////

    #[event]
    fn PlayerOneWins(winner: ContractAddress, winner_move: felt252, losing_move: felt252) {}

    #[event]
    fn PlayerTwoWins(winner: ContractAddress, winner_move: felt252, losing_move: felt252) {}

    #[event]
    fn Draw(draw_move: felt252) {}

    //////////////////////////////////////////
    // VIEW FUNCTIONS
    //////////////////////////////////////////

    #[view]
    fn get_player_one() -> ContractAddress {
        player_one::read()
    }

    #[view]
    fn get_player_two() -> ContractAddress {
        player_two::read()
    }

    #[view]
    fn get_game_state() -> felt252 {
        state::read()
    }

    fn get_player_one_hashed_move() -> felt252 {
        player_one_hashed_move::read()
    }

    #[view]
    fn get_player_two_hashed_move() -> felt252 {
        player_two_hashed_move::read()
    }

    #[view]
    fn get_previous_winner() -> ContractAddress {
        previous_winner::read()
    }

    #[view]
    fn generate_hashed_move(move: felt252, salt: felt252) -> felt252 {
        let caller: ContractAddress = get_caller_address();
        let caller: felt252 = caller.into();
        pedersen(caller, pedersen(move, salt))
    }
    
    //////////////////////////////////////////
    // EXTERNAL FUNCTIONS
    //////////////////////////////////////////

    #[external]
    fn join() {
        let caller = get_caller_address();
        let _player_one = player_one::read();
        let _player_two = player_two::read();
        let zero_address = contract_address_const::<0>();

        assert(state::read() == 0, '!JOINING');

        if _player_one == zero_address {
            player_one::write(caller);
        } else {
            assert(_player_one != caller, 'Cannot vs yourself');
            if _player_two == zero_address {
                player_two::write(caller);
                state::write(1);
                interaction_time_limit::write(get_timestamp() + 3600_u64);
            }
        }
    }

    #[external]
    fn submit(hashed_move: felt252) {
        let caller = get_caller_address();
        let _player_one = player_one::read();
        let _player_two = player_two::read();

        assert(state::read() == 1, '!SUBMITTING');

        caller_is_player(caller, _player_one, _player_two);

        if caller == _player_one {
            player_one_hashed_move::write(hashed_move);
            player_one_interacted::write(true);
        } else if caller == _player_two {
            player_two_hashed_move::write(hashed_move);
            player_two_interacted::write(true);
        }

        let _player_one_hashed_move = player_one_hashed_move::read();
        let _player_two_hashed_move = player_two_hashed_move::read();

        if _player_one_hashed_move != 0 {
            if _player_two_hashed_move != 0 {
                state::write(2);
                interaction_time_limit::write(get_timestamp() + 3600_u64);
            }
        }
    }

    #[external]
    fn reveal(move: felt252, salt: felt252) { // 1=ROCK, 2=PAPER, 3=SCISSORS
        let caller = get_caller_address();
        let _player_one = player_one::read();
        let _player_two = player_two::read();

        assert(state::read() == 2, '!REVEALING');

        caller_is_player(caller, _player_one, _player_two);

        check_move(move);

        let hashed_move = pedersen(caller.into(), pedersen(move, salt));

        if caller == _player_one {
            assert(player_one_hashed_move::read() == hashed_move, 'hash did not match');
            player_one_move::write(move);
        } else {
            assert(player_two_hashed_move::read() == hashed_move, 'hash did not match');
            player_two_move::write(move);
        }

        let _player_one_move = player_one_move::read();
        let _player_two_move = player_two_move::read();

        if _player_one_move != 0 {
            if _player_two_move != 0 {
                decide_winner(_player_one_move, _player_two_move);
            }
        }
    }

    #[external]
    fn claim_abandoned() {
        let _player_one_interacted = player_one_interacted::read();
        let _player_two_interacted = player_two_interacted::read();

        assert(get_timestamp() > interaction_time_limit::read(), 'cannot claim abandoned yet');

        if _player_one_interacted == _player_two_interacted {
            Draw(0);
        } else if _player_one_interacted {
            PlayerOneWins(player_one::read(), 0, 0);
        } else if _player_two_interacted { 
            PlayerTwoWins(player_one::read(), 0, 0);
        }

        reset();
    }

    //////////////////////////////////////////
    // INTERNAL FUNCTIONS
    //////////////////////////////////////////

    fn caller_is_player(caller: ContractAddress, _player_one: ContractAddress, _player_two: ContractAddress) {
        let is_player_one: bool = caller == _player_one;
        let is_player_two: bool = caller == _player_two;
        assert(is_player_one != is_player_two, 'caller not player');
    }

    fn get_timestamp() -> u64 {
        get_block_info().unbox().block_timestamp
    }

    fn check_move(move: felt252) {
        let mut valid = false;

        if move == 1 {
            valid = true;
        } else if move == 2 {
            valid = true;
        } else if move == 3 {
            valid = true;
        }

        assert(valid == true, 'invalid move');
    }

    fn decide_winner(mut player_one_move: felt252, player_two_move: felt252) {
        let player_one_move_int: u8 = player_one_move.try_into().unwrap();
        let player_two_move_int: u8 = player_two_move.try_into().unwrap();
    
        if player_one_move == player_two_move {
            Draw(player_one_move);
        } else {
            if player_one_move_int - 1_u8 == player_two_move_int % 3_u8 {
                let player_one_address = player_one::read();
                PlayerOneWins(player_one_address, player_one_move, player_two_move);
                previous_winner::write(player_one_address);
            } else {
                let player_two_address = player_two::read();
                PlayerTwoWins(player_two_address, player_two_move, player_one_move);
                previous_winner::write(player_two_address);
            }
        }

        reset();
    }

    fn reset() {
        let zero_address = contract_address_const::<0>();
        state::write(0);
        player_one::write(zero_address);
        player_two::write(zero_address);
        player_one_hashed_move::write(0);
        player_two_hashed_move::write(0);
        player_one_move::write(0);
        player_two_move::write(0);
        reset_interactions();
        interaction_time_limit::write(0_u64);
    }

    fn reset_interactions() {
        player_one_interacted::write(false);
        player_two_interacted::write(false);
    }   
}
