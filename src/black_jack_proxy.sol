// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../lib/forge-std/src/console.sol";
contract BlackJackProxy {
    mapping (uint=>player) private player_info;// player_info[key]라는 구조체 변수 생성
    address public dealer;
    uint public total_bet;
    bool all_stay;
    uint private deal_num;
    uint[] winner;
    program_state public p_state;
    bool private stopped; // Emergency Stop: 계약의 실행을 중지할 수 있는 플래그
    mapping(address => uint) public pending_withdrawals; // Pull over Push: 보상을 직접 인출할 수 있도록 보상 대기열을 관리
    enum program_state{// State Machine: 상태 6개를 구현하여 각 상태에 따른 단계별 행동(함수)를 지정
        new_born,
        players_registered,
        dealer_registered,
        people_choosed,
        dealer_choosed,
        finished_game
    }
    enum state{
        hit, // 카드를 더 받아야 하는 상태
        stay, // 최종 결정된 상태
        dead // 죽은 상태
    }
    struct player {
        uint bet;
        state current_state;
        uint num;
        address addr;
    }
    uint player_count;
    uint[13] cards;
    address public implementation;
    constructor(address _implementation) {
        implementation = _implementation;// 실제 구현 컨트랙트의 주소 저장
    }
    function initialize() external{
        (bool success,)=implementation.delegatecall(abi.encodeWithSignature("initialize()"));
        require(success, "initialize delegation fail");
    }
    function register(uint betting) external payable returns (uint key) {
        require(msg.value==betting, "value no match");
        (bool success, bytes memory ret)=implementation.delegatecall(abi.encodeWithSignature("register(uint256)", betting));
        uint key=abi.decode(ret, (uint256));
        return key;
    }
    function dealer_register(uint betting) external payable {
        implementation.delegatecall(abi.encodeWithSignature("dealer_register(uint256)", betting));
    }
    function hit(uint key) external returns (uint num){
        (bool success, bytes memory ret)=implementation.delegatecall(abi.encodeWithSignature("hit(uint256)", key));
        uint num=abi.decode(ret, (uint256));
        return num;
    }
    function stay(uint key) external{
        implementation.delegatecall(abi.encodeWithSignature("stay(uint256)", key));
    }
    function dealing_time() external{
        implementation.delegatecall(abi.encodeWithSignature("dealing_time()"));
    }
    function finish_game() external {
        implementation.delegatecall(abi.encodeWithSignature("finish_game()"));
    }
    function withdraw() external payable{
        implementation.delegatecall(abi.encodeWithSignature("withdraw()"));
    }
    function refresh() external{
        implementation.delegatecall(abi.encodeWithSignature("refresh()"));
    }
    function upgrade(address _newImplementation) external {
        implementation = _newImplementation;
    }

    receive() external payable {}
}