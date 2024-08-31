// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../lib/forge-std/src/console.sol";
contract BlackJack {
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

    function initialize() external {// 카드를 값을 정해줌
        for (uint i=0;i<13;i++){
            cards[i]=i+1;
        }
        all_stay=false;
        player_count=0;
        deal_num=0;
        total_bet=0;
        p_state=program_state.new_born;
        stopped=false;
    }

    modifier only_player(uint key){
        require(player_info[key].addr==address(msg.sender), "you are not the player");
        _;
    }

    modifier is_new_born(){
        require(p_state==program_state.new_born, "not right timing");
        _;
    }

    modifier is_players_registered(){
        require(p_state==program_state.players_registered, "not right timing");
        _;
    }

    modifier is_dealer_registered(){
        require(p_state==program_state.dealer_registered, "not right timing");
        _;
    }

    modifier is_people_choosed(){
        require(p_state==program_state.people_choosed, "not right timing");
        _;
    }
    
    modifier is_dealer_choosed(){
        require(p_state==program_state.dealer_choosed, "not right timing");
        _;
    }

    modifier is_finished_game(){
        require(p_state==program_state.finished_game, "not right timing");
        _;
    }

    modifier stop_in_emergency { // Emergency Stop: 계약의 몇개 함수들의 실행을 중지하기 위한 체크
        require(!stopped, "emergency stop activated");
        _; 
    }

    function register(uint betting) stop_in_emergency is_new_born external payable returns (uint key){// 사용자가 플레이어로 등록하고 베팅
        require(betting>1 ether, "not enough betting");
        player_info[player_count].bet+=betting;
        total_bet+=betting;
        player_info[player_count].current_state=state.hit;
        player_info[player_count].addr=address(msg.sender);
        if (player_count==7){
            p_state=program_state.players_registered;
        }// 총 플레이어의 수는 8명으로 고정
        player_count++;
        return player_count-1;
    }

    function dealer_register(uint betting) is_players_registered stop_in_emergency external payable{
        require(betting> 1 ether, "not enough betting");
        total_bet+=betting;
        dealer=address(msg.sender);
        p_state=program_state.dealer_registered;
    }// 플레이어 8명이 다 등록을 끝내면 딜러가 등록함

    function hit(uint key) stop_in_emergency only_player(key) is_dealer_registered external returns (uint num){
        player_info[key].num+=cards[uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)))%13];
        if (player_info[key].num>21){
            failed(key);
            bool stay=true;
            for (uint i=0;i<player_count;i++){
                if (player_info[i].current_state==state.hit){
                    stay=false;
                }
            }// 모두가 staying 중인지 확인
            if (stay==true){
                p_state=program_state.people_choosed;
            }// 모두가 staying/failed 면, 마지막에 fail한 사람이 dealing_time()과 finish_game()까지 실행함
        }
        return player_info[key].num;
    }

    function stay(uint key) only_player(key) stop_in_emergency is_dealer_registered external{
        player_info[key].current_state=state.stay;
        bool stay=true;
        for (uint i=0;i<player_count;i++){
            if (player_info[i].current_state==state.hit){
                stay=false;
            }
        }// 모두가 staying 중인지 확인
        if (stay==true){
            p_state=program_state.people_choosed;
        }// 모두가 staying/failed 면, 마지막에 stay한 사람이 dealing_time()과 finish_game()까지 실행함
    }
 
    function dealing_time() is_people_choosed stop_in_emergency public {
        while(true){
            deal_num+=cards[uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)))%13];
            if (deal_num>=17){
                break;
            }
        }// deal_num까지 구하면
        p_state=program_state.dealer_choosed;
        finish_game();
    }

    function finish_game() is_dealer_choosed stop_in_emergency public {
        // Checks 단계: is_dealer_choosed modifier로 상태를 먼저 확인하고, 필요한 조건을 만족하는지 검증
        // Effects 단계: 상태를 먼저 변경하여 재진입 공격을 방지
        p_state = program_state.finished_game;
    
        for (uint i = 0; i < player_count; i++) {
            if (player_info[i].current_state == state.stay && player_info[i].num >= deal_num) {
                winner.push(i);
            } 
            else {
                failed(i);
            }
        }

        // Interactions 단계: 외부 호출을 여기서 수행, 모든 상태 변경이 완료된 후에만 수행
        if (winner.length > 0) {// winner인 player가 존재할 때
            uint reward = total_bet / winner.length;
            for (uint i = 0; i < winner.length; i++) {
                pending_withdrawals[player_info[winner[i]].addr] += reward; // Pull over Push: 직접 인출을 위해 보상 대기열에 추가
            }
        } 
        else {
            pending_withdrawals[dealer] += total_bet; // Pull over Push: 딜러에게 보상을 대기열에 추가
        }
    
    }

    function withdraw() external payable{ // Pull over Push: 사용자가 원할때 직접 보상을 인출
        uint amount = pending_withdrawals[msg.sender];
        require(amount>0, "you are not winner");
        pending_withdrawals[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "withdrawal failed");
    }

    function refresh() is_finished_game external {// 게임을 끝내고 new game을 위해 초기화
        dealer=address(0);
        all_stay=false;
        for (uint i=0;i<player_count;i++){
            delete player_info[i];// player_info 정보를 삭제
        }
        player_count=0;
        deal_num=0;
        total_bet=0;
        delete winner;
        p_state=program_state.new_born;
    }

    function failed(uint key) private {
        player_info[key].bet=0;
        player_info[key].current_state=state.dead;
    }

    receive() external payable{

    }
}
