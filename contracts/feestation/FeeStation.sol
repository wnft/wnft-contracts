// SPDX-License-Identifier: CC0
pragma solidity >= 0.8.13;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./TransferHelper.sol";

contract FeeStation is Ownable {
    struct FeeRecord {
        uint amount;
        bool listed;
    }
    event EventPayment(uint eventId, address token, uint totalAmount, address payer, uint increaseAmount);
    event Withdraw(address token, address to, uint amount);
    event PaymentChange(address token, bool isOpen);
    mapping(address => bool) public availablePayments;
    mapping(uint => mapping(address => FeeRecord)) public records;
    mapping(uint => address[]) internal eventPayments;

    constructor(address[] memory tokens) {
        uint length = tokens.length;
        for(uint i = 0; i < length; i++) {
            supportPayment(tokens[i], true);
        }
    }

    function supportPayment(address token, bool isOpen) public {
        availablePayments[token] = isOpen;
        emit PaymentChange(token, isOpen);
    }

    function _savePayment(uint eventId, address token) internal {
        address[] storage payments = eventPayments[eventId];
        if (!records[eventId][token].listed) {
            payments.push(token);
            records[eventId][token].listed = true;
        }
    }

    function getPayments(uint eventId) external view returns (address[] memory) {
        uint length = eventPayments[eventId].length;
        address[] memory payments = new address[](length);
        for(uint i = 0; i < length; i++ ) {
            payments[i] = eventPayments[eventId][i];
        }
        return payments;
    }

    function pay(uint eventId, address token, uint amount) external payable {
        require(availablePayments[token], "payment token not support");
        if (token == address(0)) {
            require(msg.value >= amount, "amount error");
        } else {
            TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);
        }
        _savePayment(eventId, token);
        FeeRecord storage rec = records[eventId][token];
        rec.amount += amount;
        emit EventPayment(eventId, token, rec.amount, msg.sender, amount);
    }

    function withdraw(address token) external onlyOwner {
        if (token == address(0)) {
            uint amount = address(this).balance;
            TransferHelper.safeTransferNative(payable(msg.sender), amount);
            emit Withdraw(token, msg.sender, amount);
        } else {
            uint amount = IERC20(token).balanceOf(address(this));
            TransferHelper.safeTransfer(token, msg.sender, amount);
            emit Withdraw(token, msg.sender, amount);
        }
    }
}