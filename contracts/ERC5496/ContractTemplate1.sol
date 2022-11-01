// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./IERC5496.sol";

struct EIP712Domain {
    string  name;
    string  version;
    uint256 chainId;
    address verifyingContract;
}

struct NftRegistration{
    address nftAddress;
    uint privilegeId;
}

contract ContractTemplate1 {
    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    // keccak256("TaskConfirm(address account,uint256 nonce,uint256 deadline)");
    bytes32 constant TASKCONFIRM_TYPEHASH = 0x250cdec45eac54cbd611f9a03f4199cee6afeb43b3f5b76544e7828e24015768;
    bytes32 public DOMAIN_SEPARATOR;

    // Mapping from NFT(ERC721P) address -> isSupported
    mapping(address => bool) supportNFT;
    // Mapping from NFT(ERC721P) address -> privId
    mapping(address => uint) requiredPrivilege;
    
    IERC20 public token;
    // Mapping from NFT(ERC721P) address -> tokenId -> claimed
    mapping(address => mapping(uint => bool)) public claimRecords;
    // Mapping from account address -> isTaskCompleted
    mapping(address => bool) public extraTask;
    // Mapping from signer address -> isValid
    mapping(address => bool) public validSigner;
    // Mapping from account address -> nonceId
    mapping(address => uint) public nonces;
    uint public amountPerAddress;
    uint public startTime;
    uint public endTime;
    bool extraTaskVerify;
    uint public total;
    uint public claimed;
    mapping(address => uint) public depositToken;
    event SupportNFT(address nft, uint privilegeId, bool isSupported);
    event Claimed(address nft, uint tokenId, uint privilegeId, address user, uint amount);

    constructor(NftRegistration[] memory nftRegs, IERC20 _token,uint _amountPerAddress,uint _startTime, uint _endTime, uint _total,bool _extraTaskVerify) {
        uint chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = hash(EIP712Domain({
            name: "WNFTCampaign",
            version: '1',
            chainId: chainId,
            verifyingContract: address(this)
        }));
        uint supportNftTotal = nftRegs.length;
        for (uint i=0; i < supportNftTotal; i++) {
            supportNFT[nftRegs[i].nftAddress] = true;
            requiredPrivilege[nftRegs[i].nftAddress] = nftRegs[i].privilegeId;
            emit SupportNFT(nftRegs[i].nftAddress, nftRegs[i].privilegeId, true);
        }
        validSigner[msg.sender] = true;
        token = _token;
        amountPerAddress = _amountPerAddress;
        startTime = _startTime;
        endTime = _endTime;
        extraTaskVerify = _extraTaskVerify;
        total = _total;
    }

    function claim(address nft, uint tokenId, bytes memory extraVerify) external {
        require(getBlockTimestamp() >= startTime, "campaign not started");
        require(getBlockTimestamp() <= endTime, "campaign has ended");
        require(supportNFT[nft], "nft not supported");
        require(!claimRecords[nft][tokenId], "already claimed");
        require(claimed < total, "quota reached");
        require(IERC5496(nft).hasPrivilege(tokenId, requiredPrivilege[nft], msg.sender), "no privileges");
        if (extraTaskVerify) {
            (bool success, bytes memory returndata) = address(this).call(extraVerify);
            _verifyCallResult(success, returndata, "(unknown)");
            require(extraTask[msg.sender], "extra task not completed");
        }
        claimRecords[nft][tokenId] = true;
        claimed += 1;
        token.transfer(msg.sender, amountPerAddress);
        emit Claimed(nft, tokenId, requiredPrivilege[nft], msg.sender, amountPerAddress);
    }

    function taskConfirm(address account, uint nonce, uint deadline, bytes32 r, bytes32 s, uint8 v) external {
        bytes32 txInputHash = keccak256(abi.encode(TASKCONFIRM_TYPEHASH, account, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            txInputHash
        ));
        address signatory = ecrecover(digest, v, r, s);
        require(validSigner[signatory], "signature not match");
        require(getBlockTimestamp() <= deadline, "signature expired");
        require(nonces[account]++ == nonce, "nonce error");
        extraTask[account] = true;
    }


    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
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
        token.transferFrom(msg.sender, address(this), amount);
        depositToken[msg.sender] += amount;
    }

    function withdrawToken(uint amount) external {
        require(getBlockTimestamp() > endTime, "campaign not ended");
        // uint balance = token.balanceOf(msg.sender);
        require(depositToken[msg.sender] >= amount, "amount too large");
        depositToken[msg.sender] -= amount;
        token.transfer(msg.sender, amount);
    }

    // function isContract(address account) internal view returns (bool) {
    //     uint256 size;
    //     // solhint-disable-next-line no-inline-assembly
    //     assembly { size := extcodesize(account) }
    //     return size > 0;
    // }
}