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

    struct WithdrawRequest {
        uint96 amountOfEEth;
        uint96 shareOfEEth;
        bool   isValid;
        uint32 feeGwei;
    }

    mapping(uint256 => bool) public isFinalized;

    mapping(uint256 => address)         internal _owners;
    mapping(uint256 => WithdrawRequest) internal _requests;

    function __setRequest(uint256 requestId, address owner, uint96 shareOfEEth, bool isValid) external {
        _owners[requestId]   = owner;
        _requests[requestId] = WithdrawRequest(shareOfEEth, shareOfEEth, isValid, 0);
    }

    function __setIsFinalized(uint256 requestId, bool value) external {
        isFinalized[requestId] = value;
    }

    // Mirrors EtherFi: any account can settle a request, the ETH is paid to the owner and the
    // request is burned and deleted.
    function claimWithdraw(uint256 requestId) external {
        address owner = ownerOf(requestId);

        delete _owners[requestId];
        delete _requests[requestId];

        ( bool success, ) = owner.call{ value: address(this).balance }("");

        require(success, "MockWithdrawRequestNFT/claimWithdraw-failed");
    }

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory) {
        return _requests[requestId];
    }

    // Mirrors ERC721: reverts for a request that does not exist (never minted or burned).
    function ownerOf(uint256 requestId) public view returns (address) {
        require(_owners[requestId] != address(0), "ERC721: invalid token ID");

        return _owners[requestId];
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
