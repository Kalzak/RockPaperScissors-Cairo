#[contract]
mod RPS {

    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;
    use starknet::ContractAddressIntoFelt252;
    use traits::TryInto;
    use traits::Into;
    use option::OptionTrait;

    struct Storage {
        state: felt252, // 0=JOINING, 1=SUBMITTING, 2=REVEALING
        player_one: ContractAddress,
        player_two: ContractAddress,
        player_one_hashed_move: felt252,
        player_two_hashed_move: felt252,
        player_one_move: felt252,
        player_two_move: felt252,
        previous_winner: ContractAddress,
    }

    #[event]
    fn PlayerOneWins(winner: ContractAddress, winner_move: felt252, losing_move: felt252) {}

    #[event]
    fn PlayerTwoWins(winner: ContractAddress, winner_move: felt252, losing_move: felt252) {}

    #[event]
    fn Draw(draw_move: felt252) {}

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
    
    #[external]
    fn join() {
        let caller = get_caller_address();
        let _player_one = player_one::read();
        let _player_two = player_two::read();
        let zero_address = contract_address_const::<0>();
        let _state = state::read();

        assert(_state == 0, '!JOINING');

        if _player_one == zero_address {
            player_one::write(caller);
        } else {
            assert(_player_one != caller, 'Cannot vs yourself');
            if _player_two == zero_address {
                player_two::write(caller);
                state::write(1)
            }
        }
    }

    #[external]
    fn submit(hashed_move: felt252) {
        let caller = get_caller_address();
        let _player_one = player_one::read();
        let _player_two = player_two::read();
        let _state = state::read();

        assert(_state == 1, '!SUBMITTING');

        if caller == _player_one {
            player_one_hashed_move::write(hashed_move);
        } else if caller == _player_two {
            player_two_hashed_move::write(hashed_move);
        }

        let _player_one_hashed_move = player_one_hashed_move::read();
        let _player_two_hashed_move = player_two_hashed_move::read();

        if _player_one_hashed_move != 0 {
            if _player_two_hashed_move != 0 {
                state::write(2);
            }
        }
    }

    #[external]
    fn reveal(move: felt252, salt: felt252) { // 1=ROCK, 2=PAPER, 3=SCISSORS
        let caller = get_caller_address();
        let _player_one = player_one::read();
        let _player_two = player_two::read();
        let _state = state::read();

        assert(_state == 2, '!REVEALING');

        let hashed_move = pedersen(move, salt);
        let hashed_move = pedersen(caller.into(), hashed_move);

        if caller == _player_one {
            let _player_one_hashed_move = player_one_hashed_move::read();
            if _player_one_hashed_move == hashed_move {
                check_move(move);
                player_one_move::write(move);
            } else {
                assert(0 == 1, 'did not match');
            }
        } else if caller == _player_two {
            let _player_two_hashed_move = player_two_hashed_move::read();
            if _player_two_hashed_move == hashed_move {
                check_move(move);
                player_two_move::write(move);
            } else {
                assert(0 == 1, 'did not match');
            }
        }

        let _player_one_move = player_one_move::read();
        let _player_two_move = player_two_move::read();

        if _player_one_move != 0 {
            if _player_two_move != 0 {
                decide_winner(_player_one_move, _player_two_move);
            }
        }

    }

    fn check_move(move: felt252) {
        let mut valid = false;

        if move == 1 {
            valid = true;
        }
        if move == 2 {
            valid = true;
        }
        if move == 3 {
            valid = true;
        }

        assert(valid == true, 'invalid move');
    }

    fn decide_winner(mut player_one_move: felt252, player_two_move: felt252) {

        let player_one_move_int: u8 = player_one_move.try_into().unwrap();
        let player_two_move_int: u8 = player_two_move.try_into().unwrap();
    
        if player_one_move == player_two_move {
            // EMIT DRAW EVENT
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

        state::write(0);
    }
}
