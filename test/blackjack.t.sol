// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol"; 
import "../src/black_jack_proxy.sol";
import "../src/black_jack.sol";
import "../lib/forge-std/src/console.sol";
contract BlackJackTest is Test {
    BlackJackProxy public proxy;
    address public implementation;
    BlackJack public blackjack = new BlackJack();
    address[8] users;
    uint[8] key;
    uint[8] num;
    uint[13] cards;
    uint deal_num;
    function setUp() public {
        for (uint i=0;i<8;i++){
            users[i]=address(uint160(0x1337+i));
            vm.deal(users[i], 2 ether);
        }
        // BlackJack 구현 계약 배포
        vm.deal(address(this), 2 ether);
        implementation = address(blackjack);
        // BlackJackProxy 계약 배포
        proxy = new BlackJackProxy(implementation);

        // 초기화 호출
        proxy.initialize();
        for (uint i=0;i<13;i++){
            cards[i]=i+1;
        }
    }

    function testFullGame() public payable {
        // 7명의 사용자가 등록할 데이터 생성
        for (uint i = 0; i < 8; i++) {
            vm.startPrank(users[i]);
            key[i]=proxy.register{value: 2 ether}(2 ether);
            vm.stopPrank();
        }
        // 딜러 등록
        proxy.dealer_register{value: 2 ether}(2 ether);
        for (uint i=0;i<8;i++){
            vm.startPrank(users[i]);
            while(num[i]<17){
                num[i]+=proxy.hit(key[i]);// 합이 17이상이 되면 더이상 hit하지 않음
            }
            proxy.stay(key[i]);
        }
        
        while(true){
            deal_num+=cards[uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)))%13];
            if (deal_num>=17){
                break;
            }
        }// deal_num까지 구하면
        proxy.dealing_time();
        for (uint i=0;i<8;i++){
            if (num[i]>=deal_num){
                vm.startPrank(users[i]);
                proxy.withdraw();
            }// 위너는 돈을 인출. (되는지 확인)
        }
        proxy.refresh();
    }
    receive() external payable{}
}
