// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../lib/forge-std/src/console.sol";
contract BlackJackProxy {
    address public implementation;
    address public owner;
    constructor(address _implementation) {
        implementation = _implementation;// 실제 구현 컨트랙트의 주소 저장
        owner = msg.sender;
    }
    function upgrade(address _newImplementation) external {
        require(msg.sender == owner);
        implementation = _newImplementation;
    }
    fallback(bytes calldata) external payable returns (bytes memory){
        (bool success, bytes memory ret)=implementation.delegatecall(msg.data);
        return ret;
    }
}
