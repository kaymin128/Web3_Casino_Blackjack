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
    struct player{
        address addr;
        uint key;
        uint num;
        bool winner;
    }
    struct dealer_{
        address addr;
        uint num;
        bool winner;
    }
    uint[13] cards;
    player[8] users;
    dealer_ dealer;
    function setUp() public {
        for (uint i=0;i<8;i++){
            users[i].addr=address(uint160(0x1337+i));
            vm.deal(users[i].addr, 2 ether);
        }
        dealer.addr=address(uint160(0x1557));
        // BlackJack 구현 계약 배포
        vm.deal(dealer.addr, 2 ether);
        implementation = address(blackjack);
        // BlackJackProxy 계약 배포
        proxy = new BlackJackProxy(implementation);

        // 초기화 호출
        bytes memory data=abi.encodeWithSignature("initialize()");
        (bool success,)=address(proxy).call(data);
        require(success, "call failed");
        for (uint i=0;i<13;i++){
            cards[i]=i+1;
        }
    }

    function testFullGame() public payable {
        bytes memory data;
        bool success;
        bytes memory ret;
        uint winner_count;
        uint reward;
        // 7명의 사용자가 등록할 데이터 생성
        for (uint i = 0; i < 8; i++) {
            vm.startPrank(users[i].addr);
            data=abi.encodeWithSignature("register(uint256)", 2 ether);
            (success, ret)=address(proxy).call{value: 2 ether}(data);
            require(success, "call failed");
            users[i].key=abi.decode(ret, (uint256));
            vm.stopPrank();
        }
        // 딜러 등록
        vm.startPrank(dealer.addr);
        data=abi.encodeWithSignature("dealer_register(uint256)", 2 ether);
        (success,)=address(proxy).call{value: 2 ether}(data);
        require(success, "call failed");
        vm.stopPrank();
        for (uint i=0;i<8;i++){
            vm.startPrank(users[i].addr);
            while(users[i].num<17){
                data=abi.encodeWithSignature("hit(uint256)", users[i].key);
                (success, ret)=address(proxy).call(data);
                require(success, "call failed");
                users[i].num+=abi.decode(ret, (uint256));// 합이 17이상이 되면 더이상 hit하지 않음
            }
            data=abi.encodeWithSignature("stay(uint256)", users[i].key);
            (success,)=address(proxy).call(data);
            require(success, "call failed");
            vm.stopPrank();
        }
        
        while(true){
            dealer.num+=cards[uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)))%13];
            if (dealer.num>=17){
                break;
            }
        }// deal_num까지 구하면

        data=abi.encodeWithSignature("dealing_time()");
        (success,)=address(proxy).call(data);
        require(success, "call failed");
        for (uint i=0;i<8;i++){
            if (users[i].num>=dealer.num){
                users[i].winner=true;
                winner_count++;
                vm.startPrank(users[i].addr);
                data=abi.encodeWithSignature("withdraw()");
                (success,)=address(proxy).call(data);
                require(success, "call failed");
            }// 위너 수를 세고 위너는 돈을 인출
            else{
                users[i].winner=false;
            }
        }
        if (winner_count>0){
            reward=(18 ether)/winner_count;
            for (uint i=0;i<8;i++){
                if (users[i].winner){
                    require(users[i].addr.balance==reward, "reward and balance not matching");
                }
                else{
                    require(users[i].addr.balance==0, "failed user having reward error");
                }
            }
        }
        else{
            reward=(18 ether);
            require(dealer.addr.balance==reward, "reward and balance not matching");
        }

    }
    receive() external payable{}
}
