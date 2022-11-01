// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC5496.sol";

struct EIP712Domain {
    string  name;
    string  version;
    uint256 chainId;
    address verifyingContract;
}

struct NftRegistration{
    address wnftAddress;
    uint privilegeId;
}

contract ContractTemplate3 is Ownable{
    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    // keccak256("TaskConfirm(address account,uint256 nonce,uint256 deadline)");
    bytes32 constant TASKCONFIRM_TYPEHASH = 0x250cdec45eac54cbd611f9a03f4199cee6afeb43b3f5b76544e7828e24015768;
    bytes32 public DOMAIN_SEPARATOR;

    // Mapping from WNFT address -> isSupported
    mapping(address => bool) supportNFT;
    // Mapping from WNFT address -> privId
    mapping(address => uint) requiredPrivilege;
    
    IERC20 public sellToken;
    IERC20 public payToken;
    address public eventOwner;
    // Mapping from WNFT address -> tokenId -> claimed
    mapping(address => mapping(uint => bool)) public exchangeRecords;
    uint public amountPerAddress;
    uint public amountPerOrder;
    uint public startTime;
    uint public endTime;
    mapping(address => uint) public depositToken;
    event SupportNFT(address wnft, uint privilegeId, bool isSupported);
    event Fulfillment(address wnft, uint tokenId, uint privilegeId, address user, uint payAmount, uint gainAmount);
    event EventOwnerChange(address newOwner, address oldOwner);

    constructor(NftRegistration[] memory wnftRegs, IERC20 _sellToken, IERC20 _payToken, address _eventOwner,uint _amountPerAddress,uint _amountPerOrder,uint _startTime, uint _endTime) {
        uint chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = hash(EIP712Domain({
            name: "WNFT.one",
            version: '1',
            chainId: chainId,
            verifyingContract: address(this)
        }));
        uint supportNftTotal = wnftRegs.length;
        for (uint i=0; i < supportNftTotal; i++) {
            supportNFT[wnftRegs[i].wnftAddress] = true;
            requiredPrivilege[wnftRegs[i].wnftAddress] = wnftRegs[i].privilegeId;
            emit SupportNFT(wnftRegs[i].wnftAddress, wnftRegs[i].privilegeId, true);
        }
        sellToken = _sellToken;
        payToken = _payToken;
        eventOwner = _eventOwner;
        amountPerAddress = _amountPerAddress;
        amountPerOrder = _amountPerOrder;
        startTime = _startTime;
        endTime = _endTime;
    }

    function setEventOwner(address newOwner) external {
        emit EventOwnerChange(newOwner, eventOwner);
        eventOwner = newOwner;
    }

    function fulfillment(address wnft, uint tokenId) external {
        require(getBlockTimestamp() >= startTime, "campaign not started");
        require(getBlockTimestamp() <= endTime, "campaign has ended");
        require(supportNFT[wnft], "wnft not supported");
        require(!exchangeRecords[wnft][tokenId], "already claimed");
        require(IERC5496(wnft).hasPrivilege(tokenId, requiredPrivilege[wnft], msg.sender), "no privileges");
        
        exchangeRecords[wnft][tokenId] = true;
        payToken.transferFrom(msg.sender, address(this), amountPerOrder);
        sellToken.transfer(msg.sender, amountPerAddress);
        emit Fulfillment(wnft, tokenId, requiredPrivilege[wnft], msg.sender, amountPerOrder, amountPerAddress);
    }

    function getBlockTimestamp() internal view returns (uint) {
        //solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }

    function hash(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712DOMAIN_TYPEHASH,
            keccak256(bytes(eip712Domain.name)),
            keccak256(bytes(eip712Domain.version)),
            eip712Domain.chainId,
            eip712Domain.verifyingContract
        ));
    }

    function deposit(uint amount) external {
        sellToken.transferFrom(msg.sender, address(this), amount);
        depositToken[msg.sender] += amount;
    }

    function withdrawToken(uint amount) external {
        require(getBlockTimestamp() > endTime, "campaign not ended");
        // uint balance = token.balanceOf(msg.sender);
        require(depositToken[msg.sender] >= amount, "amount too large");
        depositToken[msg.sender] -= amount;
        sellToken.transfer(msg.sender, amount);
    }

    function withdrawPaid() external {
        require(getBlockTimestamp() > endTime, "campaign not ended");
        require(msg.sender == eventOwner, "not owner");
        uint balance = payToken.balanceOf(address(this));
        payToken.transfer(eventOwner, balance);
    }
}