// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
contract MockSwap {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
    external
    payable
    returns (uint amountToken, uint amountETH, uint liquidity){
        IERC20(token).transferFrom(msg.sender,address(this),amountTokenDesired);
        console.log("addLiquidityETH value =",msg.value);
        return (amountTokenDesired,msg.value,1);
    }

}