// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "solady/src/tokens/ERC20.sol";
import "solady/src/utils/FixedPointMathLib.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC3156FlashBorrower.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC3156FlashLender.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "./V2Factory.sol";
// import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Requirements
// Use the Solady ERC20 library to accomplish the LP token, also use the Solady library to accomplish the square root

contract V2Pair is ERC20, IERC3156FlashLender, ReentrancyGuard {
    using FixedPointMathLib for uint256;

    V2Factory public f;

    // errors
    error OnlySupportedTokensAllowed(address token);
    error NotFlashLender(address sender);

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant CUSTOM_FEE = 2;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public factory;
    address public token0;
    address public token1;
    uint256 public totalSupply;

    uint112 private reserve0; // why is this private ?
    uint112 private reserve1; // why is this private ?
    uint32 private blockTimestampLast;
    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    // IERC3156FlashLender[] flashLenders;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);


    constructor(IERC3156FlashLender[] memory _flashLender) public {
        factory = address(f);
        // flashLenders = _flashLender;
    }

    // function addflashLenders(address[] calldata flashLenders) public {
    //     for (uint256 i = 0 ; i < flashLenders.length; ++i){
    //         flashLenders.push(flashLenders);
    //     }
    // }

    // modifier flashLender() {
    //     for (uint256 i = 0 ; i < flashLenders.length; ++i){
    //         require(msg.sender == address(flashLenders[i]), "FlashLender: caller is not the lender");
    //         _;
    //     }
    // }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    // function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
    //     require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "V2Pair: OVERFLOW");
    //     uint32 blockTimestamp = uint32(blocktimestamp % 2 ** 32);
    //     uint32 timeElapsed = blockTimestamp - blockTimestampLast;
    //     if (timeElapsed > 0 && _reserve != 0 && _reserve1 != 0) {
    //         price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
    //         price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
    //     }
    //     reserve0 = uint112(balance0);
    //     reserve1 = uint112(balance1);
    //     blockTimestampLast = blockTimestamp;
    //     emit Sync(reserve0, reserve1);
    // }

    function feeTo() internal view returns (address) {
        return f.factoryFeeTo();
    }

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = FixedPointMathLib.sqrt(uint256(_reserve0).mulDiv(_reserve1, 1));
                uint256 rootKLast = FixedPointMathLib.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply.mulDiv(rootK.rawSub(rootKLast), 1);
                    uint256 denominator = rootK.mulDiv(5, 1).rawAdd(rootKLast);
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // override
    function maxFlashLoan(address token) internal view override returns (uint256 _max) {
        uint112 scaleValue = 10 ** 18;
        uint112 maxReserve0 = (reserve0 ** 3 / 4) * scaleValue;
        uint112 maxReserve1 = (reserve1 ** 3 / 4) ** scaleValue;
        _max = token == token0 ? maxReserve0 : maxReserve1;
    }

    function flashFee(address, uint256 amount) internal view override returns (uint256 fee) {
        fee = (amount * CUSTOM_FEE) / 100;
    }

    // TO DO : ONLY CALLABLE BY FLASHLOAN LENDER
    function customFlashLoan(IERC3156FlashBorrower receiver, address token, uint256 borrowedAmount, bytes calldata data)
        external
        nonReentrant
        returns (bool)
    {
        require(borrowedAmount < maxFlashLoan(token));

        uint256 fee = flashFee(token, borrowedAmount);
        uint256 returnAmount = borrowedAmount + fee;

        //check if token is supported
        if (token != token0 && token != token1) {
            revert OnlySupportedTokensAllowed(token);
        }

        // flashlender borrow
        ERC20(token).transfer(address(receiver), borrowedAmount);

        // flashlender SHOULD transfer back tokens
        require(ERC20(token).transferFrom(address(receiver), address(this), returnAmount), "Repayment failed");

        return true;
    }

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        uint256 balance0 = ERC20(token0).balanceOf(address(this));
        uint256 balance1 = ERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSypply = totalSupply;

        if (_totalSypply == 0) {
            liquidity = FixedPointMathLib.sqrt(amount0.mulDiv(amount1, 1)) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = (amount0 * _totalSypply) / _reserve0;
            liquidity = (amount1 * _totalSypply) / _reserve1;
        }
        require(liquidity > 0, "V2Pair: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        // _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0).mulDiv(reserve1, 1);
        emit Mint(msg.sender, amount0, amount1);
    }

    
}
