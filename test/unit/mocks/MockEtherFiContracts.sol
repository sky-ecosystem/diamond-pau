// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

contract MockWEETH {

    address public eETH;

    function __setEETH(address eETH_) external {
        eETH = eETH_;
    }

}

contract MockEETH {

    address public liquidityPool;

    constructor(address liquidityPool_) {
        liquidityPool = liquidityPool_;
    }

}

contract MockLiquidityPool {

    address public withdrawRequestNFT;

    constructor(address withdrawRequestNFT_) {
        withdrawRequestNFT = withdrawRequestNFT_;
    }

}

contract MockWithdrawRequestNFT {

    mapping(uint256 => bool) public isValid;
    mapping(uint256 => bool) public isFinalized;

    mapping(uint256 => address) internal _owners;

    function __setIsValid(uint256 requestId, bool value) external {
        isValid[requestId] = value;
    }

    function __setIsFinalized(uint256 requestId, bool value) external {
        isFinalized[requestId] = value;
    }

    function __setOwner(uint256 requestId, address owner) external {
        _owners[requestId] = owner;
    }

    // Mirrors ERC721: reverts for a request that does not exist (never minted or burned).
    function ownerOf(uint256 requestId) external view returns (address) {
        require(_owners[requestId] != address(0), "ERC721: invalid token ID");
        return _owners[requestId];
    }

    // Mirrors EtherFi: any account can settle a request, the ETH is paid to the owner and the
    // request is burned.
    function claimWithdraw(uint256 requestId) external {
        address owner = _owners[requestId];

        require(owner != address(0), "ERC721: invalid token ID");

        delete _owners[requestId];

        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "MockWithdrawRequestNFT/claimWithdraw-failed");
    }

}

contract MockWETH {

    mapping(address => uint256) public balanceOf;

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

}
