// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./WNFT.sol";

contract WNFTFactory is AccessControl{
    event AllowedNFT(address nft, bool newAllowed, bool oldAllowed);
    event Created(address nft, address WNFT);
    event PrivilegeIncreased(address nft, address wnft, uint privilegeId);
    bytes32 public constant CONTROL_ROLE = keccak256("CONTROL_ROLE");
    mapping(address => bool) public allowedNFT;
    mapping(address => address) public getWNFT;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTROL_ROLE, msg.sender);
    }

    function setAllowedNFT(address nft, bool isAllowed) external onlyRole(CONTROL_ROLE) {
        require(allowedNFT[nft] != isAllowed, "no change");
        emit AllowedNFT(nft, isAllowed, allowedNFT[nft]);
        allowedNFT[nft] = isAllowed;
    }

    function createWNFT(address nft) external onlyRole(CONTROL_ROLE) returns(address wnft) {
        require(allowedNFT[nft], "nft not allowed");
        require(getWNFT[nft] == address(0), "already existed");
        bytes memory bytecode = type(WNFT).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(nft));
        assembly {
            wnft := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        WNFT(wnft).initialize(nft);
        getWNFT[nft] = wnft;
        emit Created(nft, wnft);
    }

    function increasePrivileges(address nft, bool _cloneable) external onlyRole(CONTROL_ROLE) {
        require(getWNFT[nft] != address(0), "invalid nft");
        uint privilegeId = WNFT(getWNFT[nft]).increasePrivileges(_cloneable);
        emit PrivilegeIncreased(nft, getWNFT[nft], privilegeId);
    }
}