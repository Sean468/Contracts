// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Importing the IERC20 interface from OpenZeppelin

interface IRandomNumberGenerator {
    function Generate() external returns (uint64);
}

contract YourToken is ERC20, ERC20Burnable, Ownable {
    address public tokenHolder;
    address public specifiedTokenAddress;
    address public randomGeneratorAddress;
    address public burnAddress = 0x0000000000000000000000000000000000000369; // Replace with the actual burn address
    address public defaultAddress; // Default address that cannot be removed

    mapping(address => bool) public isInList;
    address[] public addressList;

    constructor(
        string memory name,
        string memory symbol,
        address _tokenHolder,
        address _specifiedTokenAddress,
        address _randomGeneratorAddress,
        address _defaultAddress, // Default address parameter
        uint256 initialSupply // Initial supply parameter
    ) ERC20(name, symbol) Ownable(msg.sender) {
        tokenHolder = _tokenHolder;
        specifiedTokenAddress = _specifiedTokenAddress;
        randomGeneratorAddress = _randomGeneratorAddress;
        defaultAddress = _defaultAddress;

        // Mint the initial supply to the deployer address
        _mint(msg.sender, initialSupply);

        // Add the default address to the list and set it as non-removable
        isInList[defaultAddress] = true;
        addressList.push(defaultAddress);
    }

    function addAddress(address newAddress) public onlyOwner {
        require(newAddress != address(0), "Cannot add zero address");
        require(!isInList[newAddress], "Address already in list");
        isInList[newAddress] = true;
        addressList.push(newAddress);
    }

    function removeAddress(address addr) public onlyOwner {
        require(addr != defaultAddress, "Cannot remove default address");
        require(isInList[addr], "Address not in list");
        isInList[addr] = false;
        for (uint i = 0; i < addressList.length; i++) {
            if (addressList[i] == addr) {
                addressList[i] = addressList[addressList.length - 1];
                addressList.pop();
                break;
            }
        }
    }

    function getAddressList() public view returns (address[] memory) {
        return addressList;
    }

    function withdrawTokens(address tokenAddress) public onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        token.transfer(owner(), balance);
    }

    function customTransfer(address sender, address recipient, uint256 amount) internal {
        uint256 burnAmount = amount / 100;
        uint256 transferAmount = amount - burnAmount;
        super._transfer(sender, burnAddress, burnAmount);
        super._transfer(sender, recipient, transferAmount);

        // Ensure there's always at least one address to select from
        address[] memory currentAddressList = addressList.length > 0 ? addressList : new address[](1);
        if (addressList.length == 0) {
            currentAddressList[0] = defaultAddress;
        }

        // Call the random number generator
        uint64 randomIndex = IRandomNumberGenerator(randomGeneratorAddress).Generate() % uint64(currentAddressList.length);
        address randomRecipient = currentAddressList[randomIndex];

        // Transfer the smallest possible amount of the specified token to the random recipient
        IERC20(specifiedTokenAddress).transferFrom(tokenHolder, randomRecipient, 1); // 1 wei of the token

        // Note: Ensure tokenHolder has approved this contract to transfer tokens on its behalf
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        customTransfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        customTransfer(sender, recipient, amount);
        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);
        return true;
    }
}
