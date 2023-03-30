use src::RPS;

use starknet::testing::set_caller_address;

use starknet::ContractAddress;
use starknet::Felt252TryIntoContractAddress;
use starknet::TryInto;
use starknet::OptionTrait;

#[test]
#[available_gas(2000000)]
fn join_empty_game() {
    let player: felt252 = 123;
    let player: ContractAddress = player.try_into().unwrap();

    set_caller_address(player);
    RPS::join();

    let player_one = RPS::get_player_one();

    assert(player_one == player, 'error');
}

