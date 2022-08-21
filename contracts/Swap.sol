// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISwap.sol";
import "./sAsset.sol";

contract Swap is Ownable, ISwap {

    address token0;
    address token1;
    uint reserve0;
    uint reserve1;
    mapping (address => uint) shares;
    uint public totalShares;

    constructor(address addr0, address addr1) {
        token0 = addr0;
        token1 = addr1;
    }

    function init(uint token0Amount, uint token1Amount) external override onlyOwner {
        require(reserve0 == 0 && reserve1 == 0, "init - already has liquidity");
        require(token0Amount > 0 && token1Amount > 0, "init - both tokens are needed");

        require(sAsset(token0).transferFrom(msg.sender, address(this), token0Amount));
        require(sAsset(token1).transferFrom(msg.sender, address(this), token1Amount));
        reserve0 = token0Amount;
        reserve1 = token1Amount;
        totalShares = sqrt(token0Amount * token1Amount);
        shares[msg.sender] = totalShares;
    }

    // https://github.com/Uniswap/v2-core/blob/v1.0.1/contracts/libraries/Math.sol
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function getReserves() external view returns (uint, uint) {
        return (reserve0, reserve1);
    }

    function getTokens() external view returns (address, address) {
        return (token0, token1);
    }

    function getShares(address LP) external view returns (uint) {
        return shares[LP];
    }

    /* TODO: implement your functions here */

    function getTS()  external view returns (uint) {
        return totalShares;
    }

    function addLiquidity(uint token0Amount) external override {
        require(token0Amount >= 0, "token0Amount should be larger than zero");
        require(reserve0 > 0, "reserve0 should be larger than zero");
        require(reserve1 > 0, "reserve1 should be larger than zero");
        
        uint256 token1Amount =  reserve1 * token0Amount / reserve0;
        uint256 new_shares =  totalShares * token0Amount / reserve0;
        shares[msg.sender] += new_shares;
        reserve0 += token0Amount;
        reserve1 += token1Amount;
        totalShares += new_shares;
        require(sAsset(token0).transferFrom(msg.sender, address(this), token0Amount));
        require(sAsset(token1).transferFrom(msg.sender, address(this), token1Amount));
    }

    function token0To1(uint token0Amount) external override {
        require(token0Amount >= 0, "token0Amount should be larger than zero");
        require(reserve0 > 0, "reserve0 should be larger than zero");
        require(reserve1 > 0, "reserve1 should be larger than zero");
        // uint token0_to_exchange = token0Amount * 997;
        uint256 protocol_fee = token0Amount / 1000  * 3;
        uint256 token0_to_exchange = token0Amount - protocol_fee;
        uint256 token1_to_return = reserve1 - reserve0 * reserve1 / (reserve0 + token0_to_exchange);
        require(token1_to_return < reserve1, "token1_to_return should be smaller than reserve1");
        //uint token1_to_return = reserve1 - totalShares / (reserve0 + token0_to_exchange);
        // reserve0 += token0_to_exchange;
        reserve0 += token0Amount;
        reserve1 -= token1_to_return;
        // totalShares = sqrt(reserve0 * reserve1);
        // 这里不知道怎么更新 当前用户的shares 不知道他原来的shares有多少
        // 应该是不用变？那token0换token1 shares没有变
        //shares[msg.sender] = totalShares * (shares[msg.sender] + token0Amount) / reserve0;

        require(sAsset(token0).transferFrom(msg.sender, address(this), token0Amount));
        require(sAsset(token1).transfer(msg.sender, token1_to_return));
    }

    function token1To0(uint token1Amount) external override {
        require(token1Amount >= 0, "token1Amount should be larger than zero");
        require(reserve0 > 0, "reserve0 should be larger than zero");
        require(reserve1 > 0, "reserve1 should be larger than zero");
        // uint token1_to_exchange = token1Amount * 997;
        uint256 protocol_fee = token1Amount / 1000  * 3;
        uint256 token1_to_exchange = token1Amount - protocol_fee;
        uint256 token0_to_return = reserve0 - reserve0 * reserve1 / (reserve1 + token1_to_exchange);
        require(token0_to_return < reserve0, "token0_to_return should be smaller than reserve0");
        reserve1 += token1Amount;
        reserve0 -= token0_to_return;
        // totalShares = sqrt(reserve0 * reserve1);
        //shares[msg.sender] = totalShares * (shares[msg.sender] + token1Amount) / reserve1;
        require(sAsset(token0).transfer(msg.sender, token0_to_return));
        require(sAsset(token1).transferFrom(msg.sender, address(this), token1Amount));
    }

    function removeLiquidity(uint withdrawShares) external override {
        require(reserve0 > 0, "reserve0 should be larger than zero");
        require(reserve1 > 0, "reserve1 should be larger than zero");
        require(withdrawShares >= 0, "withdrawShares should be larger than zero");
        require(shares[msg.sender] >= withdrawShares, "withdrawShares should be larger than zero");
        // uint amount0 = reserve0 * withdrawShares / totalShares;
        // uint amount1 = reserve1 * withdrawShares / totalShares;
        // uint new_shares = totalShares * amount0 / reserve0;



        // uint256 amount0 = reserve0 * withdrawShares / totalShares;
        // uint256 amount1 = reserve1 * withdrawShares / totalShares;
        // require(amount0 < reserve0, "amount0 should be smaller than reserve0");
        // require(amount1 < reserve1, "amount1 should be smaller than reserve1");
        // reserve0 -= amount0;
        // reserve1 -= amount1;
        // shares[msg.sender] -= withdrawShares;
        // require(sAsset(token0).transfer(msg.sender, amount0));
        // require(sAsset(token1).transfer(msg.sender, amount1));


        uint amount0 = reserve0 * withdrawShares / totalShares;
        uint amount1 = reserve1 * withdrawShares / totalShares;
        require(amount0 <= reserve0, "amount0 should be smaller than reserve0");
        require(amount1 <= reserve1, "amount1 should be smaller than reserve1");
        uint new_shares = totalShares * amount0 / reserve0;
        shares[msg.sender] -= new_shares;
        reserve0 -= amount0;
        reserve1 -= amount1;
        totalShares -= new_shares;
        require(sAsset(token0).transfer(msg.sender, amount0));
        require(sAsset(token1).transfer(msg.sender, amount1));
    }
}