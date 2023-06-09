use src::RPS;

use starknet::testing::set_caller_address;
use starknet::testing::set_block_timestamp;

use starknet::get_block_info;
use starknet::ContractAddress;
use starknet::Felt252TryIntoContractAddress;
use starknet::TryInto;
use starknet::OptionTrait;
use box::BoxTrait;

use debug::PrintTrait;

#[test]
#[available_gas(2000000)]
fn join_empty_game() {
    let player: felt252 = 123;
    let player: ContractAddress = player.try_into().unwrap();

    set_caller_address(player);
    RPS::join();

    let player_one = RPS::get_player_one();

    assert(player_one == player, 'failed to join game');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Cannot vs yourself', ))]
fn cannot_join_twice() {
    let player: felt252 = 123;
    let player: ContractAddress = player.try_into().unwrap();

    set_caller_address(player);
    RPS::join();
    set_caller_address(player);
    RPS::join();
}

#[test]
#[available_gas(2000000)]
fn join_game_starts() {
    let player_one: felt252 = 123;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 456;
    let player_two: ContractAddress = player_two.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    let state = RPS::get_game_state();

    assert(state == 1, 'incorrect game state');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('!JOINING', ))]
fn cannot_join_after_start() {
    let player_one: felt252 = 123;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 456;
    let player_two: ContractAddress = player_two.try_into().unwrap();
    let player_three: felt252 = 789;
    let player_three: ContractAddress = player_three.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    set_caller_address(player_three);
    RPS::join();
}

#[test]
#[available_gas(2000000)]
fn can_submit_move() {
    let player_one: felt252 = 123;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 456;
    let player_two: ContractAddress = player_two.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    let player_one_move = 1;
    let player_one_salt = 12345;
    set_caller_address(player_one);
    let player_one_hashed_move = RPS::generate_hashed_move(player_one_move, player_one_salt); 

    let player_two_move = 2;
    let player_two_salt = 67890;
    set_caller_address(player_two);
    let player_two_hashed_move = RPS::generate_hashed_move(player_two_move, player_two_salt); 

    set_caller_address(player_one);
    RPS::submit(player_one_hashed_move);
    
    set_caller_address(player_two);
    RPS::submit(player_two_hashed_move);

    let player_one_stored_move = RPS::get_player_one_hashed_move();
    let player_two_stored_move = RPS::get_player_two_hashed_move();

    assert(player_one_hashed_move == player_one_stored_move, 'hashed move not submitted');
    assert(player_two_hashed_move == player_two_stored_move, 'hashed move not submitted');

    let state = RPS::get_game_state();
    assert(state == 2, 'incorrect game state');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('cannot claim abandoned yet', ))]
fn cannot_claim_abandoned_early_submit() {
    let player_one: felt252 = 123;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 456;
    let player_two: ContractAddress = player_two.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    let player_one_move = 1;
    let player_one_salt = 12345;
    set_caller_address(player_one);
    let player_one_hashed_move = RPS::generate_hashed_move(player_one_move, player_one_salt); 

    set_caller_address(player_one);
    RPS::submit(player_one_hashed_move);

    set_caller_address(player_one);
    RPS::claim_abandoned();
}

#[test]
#[available_gas(2000000)]
fn can_claim_abandoned_submit() {
    let player_one: felt252 = 123;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 456;
    let player_two: ContractAddress = player_two.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    let player_one_move = 1;
    let player_one_salt = 12345;
    set_caller_address(player_one);
    let player_one_hashed_move = RPS::generate_hashed_move(player_one_move, player_one_salt); 

    set_caller_address(player_one);
    RPS::submit(player_one_hashed_move);

    set_block_timestamp(get_timestamp() + 5000_u64);
    
    set_caller_address(player_one);
    RPS::claim_abandoned();
}

#[test]
#[available_gas(2000000)]
fn can_reveal_move() {
    let player_one: felt252 = 123;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 456;
    let player_two: ContractAddress = player_two.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    let player_one_move = 1;
    let player_one_salt = 12345;
    set_caller_address(player_one);
    let player_one_hashed_move = RPS::generate_hashed_move(player_one_move, player_one_salt); 
    let player_two_move = 2;
    let player_two_salt = 67890;
    set_caller_address(player_two);
    let player_two_hashed_move = RPS::generate_hashed_move(player_two_move, player_two_salt); 

    set_caller_address(player_one);
    RPS::submit(player_one_hashed_move);
    set_caller_address(player_two);
    RPS::submit(player_two_hashed_move);

    set_caller_address(player_one);
    RPS::reveal(player_one_move, player_one_salt);
    set_caller_address(player_two);
    RPS::reveal(player_two_move, player_two_salt);

    let state = RPS::get_game_state();
    assert(state == 0, 'game did not finish');

    let winner = RPS::get_previous_winner();
    assert(winner == player_two, 'winner mistake');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('invalid move', ))]
fn cannot_reveal_invalid_move() {
    let player_one: felt252 = 123;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 456;
    let player_two: ContractAddress = player_two.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    let player_one_move = 1;
    let player_one_salt = 12345;
    set_caller_address(player_one);
    let player_one_hashed_move = RPS::generate_hashed_move(player_one_move, player_one_salt); 
    let player_two_move = 6;
    let player_two_salt = 67890;
    set_caller_address(player_two);
    let player_two_hashed_move = RPS::generate_hashed_move(player_two_move, player_two_salt); 

    set_caller_address(player_one);
    RPS::submit(player_one_hashed_move);
    set_caller_address(player_two);
    RPS::submit(player_two_hashed_move);

    set_caller_address(player_one);
    RPS::reveal(player_one_move, player_one_salt);
    set_caller_address(player_two);
    RPS::reveal(player_two_move, player_two_salt);
}

#[test]
#[available_gas(4000000)]
fn can_start_new_game_after_reveal() {
    let player_one: felt252 = 123;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 456;
    let player_two: ContractAddress = player_two.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    let player_one_move = 1;
    let player_one_salt = 12345;
    set_caller_address(player_one);
    let player_one_hashed_move = RPS::generate_hashed_move(player_one_move, player_one_salt); 
    let player_two_move = 2;
    let player_two_salt = 67890;
    set_caller_address(player_two);
    let player_two_hashed_move = RPS::generate_hashed_move(player_two_move, player_two_salt); 

    set_caller_address(player_one);
    RPS::submit(player_one_hashed_move);
    set_caller_address(player_two);
    RPS::submit(player_two_hashed_move);

    set_caller_address(player_one);
    RPS::reveal(player_one_move, player_one_salt);
    set_caller_address(player_two);
    RPS::reveal(player_two_move, player_two_salt);

    let player_one: felt252 = 321;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 654;
    let player_two: ContractAddress = player_two.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    let player_one_move = 2;
    let player_one_salt = 12345;
    set_caller_address(player_one);
    let player_one_hashed_move = RPS::generate_hashed_move(player_one_move, player_one_salt); 
    let player_two_move = 3;
    let player_two_salt = 67890;
    set_caller_address(player_two);
    let player_two_hashed_move = RPS::generate_hashed_move(player_two_move, player_two_salt); 

    set_caller_address(player_one);
    RPS::submit(player_one_hashed_move);
    set_caller_address(player_two);
    RPS::submit(player_two_hashed_move);

    set_caller_address(player_one);
    RPS::reveal(player_one_move, player_one_salt);
    set_caller_address(player_two);
    RPS::reveal(player_two_move, player_two_salt);

    let state = RPS::get_game_state();
    assert(state == 0, 'game did not finish');

    let winner = RPS::get_previous_winner();
    assert(winner == player_two, 'winner mistake');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('cannot claim abandoned yet', ))]
fn cannot_claim_abandoned_early_reveal() {
    let player_one: felt252 = 123;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 456;
    let player_two: ContractAddress = player_two.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    let player_one_move = 1;
    let player_one_salt = 12345;
    set_caller_address(player_one);
    let player_one_hashed_move = RPS::generate_hashed_move(player_one_move, player_one_salt); 
    let player_two_move = 2;
    let player_two_salt = 67890;
    set_caller_address(player_two);
    let player_two_hashed_move = RPS::generate_hashed_move(player_two_move, player_two_salt); 

    set_caller_address(player_one);
    RPS::submit(player_one_hashed_move);
    set_caller_address(player_two);
    RPS::submit(player_two_hashed_move);

    set_caller_address(player_one);
    RPS::reveal(player_one_move, player_one_salt);

    set_caller_address(player_one);
    RPS::claim_abandoned();
}

#[test]
#[available_gas(2000000)]
fn can_claim_abandoned_reveal() {
    let player_one: felt252 = 123;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 456;
    let player_two: ContractAddress = player_two.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    let player_one_move = 1;
    let player_one_salt = 12345;
    set_caller_address(player_one);
    let player_one_hashed_move = RPS::generate_hashed_move(player_one_move, player_one_salt); 
    let player_two_move = 2;
    let player_two_salt = 67890;
    set_caller_address(player_two);
    let player_two_hashed_move = RPS::generate_hashed_move(player_two_move, player_two_salt); 

    set_caller_address(player_one);
    RPS::submit(player_one_hashed_move);
    set_caller_address(player_two);
    RPS::submit(player_two_hashed_move);

    set_caller_address(player_one);
    RPS::reveal(player_one_move, player_one_salt);

    set_block_timestamp(get_timestamp() + 5000_u64);

    set_caller_address(player_one);
    RPS::claim_abandoned();
}

#[test]
#[available_gas(4000000)]
fn can_start_new_match_after_abandon() {
    let player_one: felt252 = 123;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 456;
    let player_two: ContractAddress = player_two.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    let player_one_move = 1;
    let player_one_salt = 12345;
    set_caller_address(player_one);
    let player_one_hashed_move = RPS::generate_hashed_move(player_one_move, player_one_salt); 

    set_caller_address(player_one);
    RPS::submit(player_one_hashed_move);

    set_block_timestamp(get_timestamp() + 5000_u64);
    
    set_caller_address(player_one);
    RPS::claim_abandoned();

    let player_one: felt252 = 123;
    let player_one: ContractAddress = player_one.try_into().unwrap();
    let player_two: felt252 = 456;
    let player_two: ContractAddress = player_two.try_into().unwrap();

    set_caller_address(player_one);
    RPS::join();
    set_caller_address(player_two);
    RPS::join();

    let player_one_move = 1;
    let player_one_salt = 12345;
    set_caller_address(player_one);
    let player_one_hashed_move = RPS::generate_hashed_move(player_one_move, player_one_salt); 
    let player_two_move = 2;
    let player_two_salt = 67890;
    set_caller_address(player_two);
    let player_two_hashed_move = RPS::generate_hashed_move(player_two_move, player_two_salt); 

    set_caller_address(player_one);
    RPS::submit(player_one_hashed_move);
    set_caller_address(player_two);
    RPS::submit(player_two_hashed_move);

    set_caller_address(player_one);
    RPS::reveal(player_one_move, player_one_salt);
    set_caller_address(player_two);
    RPS::reveal(player_two_move, player_two_salt);

    let state = RPS::get_game_state();
    assert(state == 0, 'game did not finish');

    let winner = RPS::get_previous_winner();
    assert(winner == player_two, 'winner mistake');
}

fn get_timestamp() -> u64 {
    get_block_info().unbox().block_timestamp
}
