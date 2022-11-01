// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0; 

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./extensions/ERC5496Cloneable.sol";

contract WNFT is ERC5496Cloneable, IERC721Receiver {
    event Wrap(address indexed nft, uint tokenId, address sender, address receiver);
    event Unwrap(address indexed nft, uint tokenId, address sender, address receiver);
    address public factory;
    address public nft;
    bool private initialized;

    constructor() ERC5496("WNFT.one", "WNFT") {
        factory = msg.sender;
    }

    function initialize(address _nft) external {
        require(msg.sender == factory, 'FORBIDDEN');
        require(!initialized, "already initialized");
        nft = _nft;
        initialized = true;
    }

    function wrap(uint256 tokenId, address to) external {
        IERC721(nft).transferFrom(msg.sender, address(this), tokenId);
        _mint(to, tokenId);
        emit Wrap(nft, tokenId, msg.sender, to);
    }

    function unwrap(uint256 tokenId, address to) external {
        require(getBlockTimestamp() >= privilegeBook[tokenId].lastExpiresAt, "privilege not yet expired");
        require(ownerOf(tokenId) == msg.sender, "not owner");
        _burn(tokenId);
        IERC721(nft).transferFrom(address(this), to, tokenId);
        emit Unwrap(nft, tokenId, msg.sender, to);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function getBlockTimestamp() internal view returns (uint) {
        //solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }

    function tokenURI(uint tokenId) public view virtual override returns (string memory) {
        return IERC721Metadata(nft).tokenURI(tokenId);
    }

    // function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) internal pure returns(bytes memory) {
    //     if (success) {
    //         return returndata;
    //     } else {
    //         if (returndata.length > 0) {
    //             assembly {
    //                 let returndata_size := mload(returndata)
    //                 revert(add(32, returndata), returndata_size)
    //             }
    //         } else {
    //             revert(errorMessage);
    //         }
    //     }
    // }

    function increasePrivileges(bool _cloneable) external returns(uint) {
        require(msg.sender == factory, 'FORBIDDEN');
        uint privId = privilegeTotal;
        _setPrivilegeTotal(privilegeTotal + 1);
        cloneable[privId] = _cloneable;
        return privId;
    }

}

