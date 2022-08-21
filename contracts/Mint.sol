// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPriceFeed.sol";
import "./interfaces/IMint.sol";
import "./sAsset.sol";
import "./EUSD.sol";

contract Mint is Ownable, IMint{

    struct Asset {
        address token;
        uint minCollateralRatio;
        address priceFeed;
    }

    struct Position {
        uint idx;
        address owner;
        uint collateralAmount;
        address assetToken;
        uint assetAmount;
    }

    mapping(address => Asset) _assetMap;
    uint _currentPositionIndex;
    mapping(uint => Position) _idxPositionMap;
    address public collateralToken;
    

    constructor(address collateral) {
        collateralToken = collateral;
    }

    function registerAsset(address assetToken, uint minCollateralRatio, address priceFeed) external override onlyOwner {
        require(assetToken != address(0), "Invalid assetToken address");
        require(minCollateralRatio >= 1, "minCollateralRatio must be greater than 100%");
        require(_assetMap[assetToken].token == address(0), "Asset was already registered");
        
        _assetMap[assetToken] = Asset(assetToken, minCollateralRatio, priceFeed);
    }

    function getPosition(uint positionIndex) external view returns (address, uint, address, uint) {
        require(positionIndex < _currentPositionIndex, "Invalid index");
        Position storage position = _idxPositionMap[positionIndex];
        return (position.owner, position.collateralAmount, position.assetToken, position.assetAmount);
    }

    function getMintAmount(uint collateralAmount, address assetToken, uint collateralRatio) public view returns (uint) {
        Asset storage asset = _assetMap[assetToken];
        (int relativeAssetPrice, ) = IPriceFeed(asset.priceFeed).getLatestPrice();
        uint8 decimal = sAsset(assetToken).decimals();
        uint mintAmount = collateralAmount * (10 ** uint256(decimal)) / uint(relativeAssetPrice) / collateralRatio ;
        return mintAmount;
    }

    function checkRegistered(address assetToken) public view returns (bool) {
        return _assetMap[assetToken].token == assetToken;
    }

    /* TODO: implement your functions here */
    
    function openPosition(uint collateralAmount, address assetToken, uint collateralRatio) external override onlyOwner{
        require(checkRegistered(assetToken), "asset is registered");
        Asset storage asset = _assetMap[assetToken];
        require(collateralRatio >= asset.minCollateralRatio, "must be greater than MCR");
        uint assetAmount = getMintAmount(collateralAmount, assetToken, collateralRatio);
        _idxPositionMap[_currentPositionIndex] = Position(_currentPositionIndex, msg.sender, collateralAmount, assetToken, assetAmount);
        _currentPositionIndex = _currentPositionIndex + 1;
        EUSD(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);
        sAsset(assetToken).mint(msg.sender, assetAmount);
    }
    
    function closePosition(uint positionIndex) external override onlyOwner{
        require(positionIndex < _currentPositionIndex, "Invalid index");
        require(msg.sender == _idxPositionMap[positionIndex].owner, "invaild position");
        Position storage position = _idxPositionMap[positionIndex];
        sAsset(position.assetToken).burn(position.owner,position.assetAmount);
        EUSD(collateralToken).transfer(msg.sender, position.collateralAmount);
        delete(_idxPositionMap[positionIndex]);
    }

    function deposit(uint positionIndex, uint collateralAmount) external override onlyOwner{
        require(positionIndex < _currentPositionIndex, "Invalid index");
        require(msg.sender == _idxPositionMap[positionIndex].owner, "Only the owner can close a position");
        require(collateralAmount >= 0, "collateralAmount must be greater than zero");
        //address owner_addr = _idxPositionMap[positionIndex].owner;
        //uint owner_balance = EUSD(collateralToken).balanceOf(owner_addr);
        // require(owner_balance >= collateralAmount, "balance of owner must be greater than collateralAmount");
        EUSD(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);
        uint current_collateralAmount = _idxPositionMap[positionIndex].collateralAmount;
        _idxPositionMap[positionIndex].collateralAmount = current_collateralAmount + collateralAmount;
    }

    function withdraw(uint positionIndex, uint withdrawAmount) external override onlyOwner{
        require(positionIndex < _currentPositionIndex, "Invalid index");
        require(msg.sender == _idxPositionMap[positionIndex].owner, "Only the owner can close a position");
        uint owner_collateralAmount = _idxPositionMap[positionIndex].collateralAmount;
        require(owner_collateralAmount >= withdrawAmount, "owner's owner_collateralAmount must be greater than withdrawAmount");
        uint new_collateralAmount = owner_collateralAmount - withdrawAmount;
        uint current_ratio = new_collateralAmount / _idxPositionMap[positionIndex].assetAmount;
        uint min_ratio = _assetMap[_idxPositionMap[positionIndex].assetToken].minCollateralRatio;
        require(current_ratio >= min_ratio, "current MCR must be greater than min MCR");
        EUSD(collateralToken).transfer(msg.sender, withdrawAmount);
        _idxPositionMap[positionIndex].collateralAmount = new_collateralAmount;
    }

    function mint(uint positionIndex, uint mintAmount) external override onlyOwner{        
        // uint owner_collateralAmount = _idxPositionMap[positionIndex].collateralAmount;
        // require(owner_collateralAmount >= mintAmount, "owner's owner_collateralAmount must be greater than mintAmount");
        // address cur_asset_token = ;
        // uint min_ratio = _assetMap[cur_asset_token].minCollateralRatio;
        // uint new_collateralAmount = owner_collateralAmount - mintAmount;
        // //uint new_assertAmount = _idxPositionMap[positionIndex].assetAmount + mintAmount / min_ratio;
        // uint new_assertAmount = getMintAmount(mintAmount, cur_asset_token, min_ratio);
        // require(new_collateralAmount / new_assertAmount >= min_ratio, "current MCR must be greater than min MCR");
        // _idxPositionMap[positionIndex].collateralAmount = new_collateralAmount;
        // _idxPositionMap[positionIndex].assetAmount = new_assertAmount;
        require(positionIndex < _currentPositionIndex, "Invalid index");
        require(msg.sender == _idxPositionMap[positionIndex].owner, "Only the owner can close a position");
        uint new_amount = _idxPositionMap[positionIndex].assetAmount + mintAmount;
        uint curr_collateralAmount = _idxPositionMap[positionIndex].collateralAmount;
        uint curr_ratio =  curr_collateralAmount/new_amount;
        address curr_asset_token = _idxPositionMap[positionIndex].assetToken;
        uint min_ratio = _assetMap[curr_asset_token].minCollateralRatio;
        require(curr_ratio >= min_ratio, "current MCR must be greater than min MCR");
        sAsset(curr_asset_token).mint(msg.sender, mintAmount);
        _idxPositionMap[positionIndex].assetAmount = new_amount;
    }

    function burn(uint positionIndex, uint burnAmount) external override onlyOwner{
        require(positionIndex < _currentPositionIndex, "Invalid index");
        require(msg.sender == _idxPositionMap[positionIndex].owner, "Only the owner can close a position");
        uint curr_amount = _idxPositionMap[positionIndex].assetAmount;
        require(burnAmount <= curr_amount, "burnAmount must be smaller than current amount");
        address curr_asset_token = _idxPositionMap[positionIndex].assetToken;
        uint new_amount = curr_amount - burnAmount;
        sAsset(curr_asset_token).burn(msg.sender, burnAmount);
        _idxPositionMap[positionIndex].assetAmount = new_amount;
    }
}