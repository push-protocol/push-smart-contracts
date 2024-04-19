// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Errors } from "../libraries/Errors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract PushMigrationHelper is OwnableUpgradeable, PausableUpgradeable{
    using SafeERC20 for IERC20;

   IERC20 public oldPushToken;
   IERC20 public newPushToken;
   bool public unMigrationPaused;
   
   /// @notice thrown when a user attempts to unmigrate while unmigration is locked
   error UnmigrationPaused();

   event TokenMigrated(address indexed _tokenHolder, address indexed _tokenReceiver, uint256 _amountMigrated);
   event TokenUnmigrated(address indexed _tokenHolder, uint256 _amountUnmigrated);


    modifier whenUnMigrationIsAllowed(){
        if(unMigrationPaused){
            revert UnmigrationPaused();
        }
        _;
    }

    function initialize(address _owner, address _oldToken) external initializer {
        oldPushToken = IERC20(_oldToken);

        __Ownable_init(_owner);
    }
    
    function pauseContract() external onlyOwner{
        _pause();
    }

    function unPauseContract() external onlyOwner{
        _unpause();
    }
    /// @notice Allows owner to pause or unpause the Un-Migration activity in this contract
    function toggleUnMigrationStatus(bool _unMigrationFlag) external onlyOwner {
        unMigrationPaused = _unMigrationFlag;
    }
       
    /// @notice Allows setting up the new PUSH Token
    /// @param _newToken Address of new PUSH Token
    function setNewPushToken(address _newToken) external onlyOwner {
        if (_newToken == address(0) || address(newPushToken) != address(0)){
            revert Errors.InvalidArgument_WrongAddress(_newToken);
        } 
        newPushToken = IERC20(_newToken);
    }

    /// @notice Allows 1:1 migration of old push token to new Push Tokens
    /// @param _amount Amount of tokens to be migrated
    function migratePushTokens(uint256 _amount) external whenNotPaused{
        oldPushToken.safeTransferFrom(msg.sender, address(this), _amount);
        newPushToken.safeTransfer(msg.sender, _amount);
                
        emit TokenMigrated(msg.sender, msg.sender, _amount);
    }

    /// @notice Allows 1:1 migration of old push token to new Push Tokens. 
    /// @dev    Caller can send migrated tokens to any preferred recipient address
    /// @param _amount Amount of tokens to be migrated
    function migratePushTokensTo(address _recipient, uint256 _amount) external whenNotPaused{
        if(_recipient == address(0)){
            revert Errors.InvalidArgument_WrongAddress(_recipient);
        }

        oldPushToken.safeTransferFrom(msg.sender, address(this), _amount);
        newPushToken.safeTransfer(_recipient, _amount);
                
        emit TokenMigrated(msg.sender, _recipient, _amount);
    }

    /// @notice Allows users to un-migrate their tokens. 
    /// @dev    Can only be called if un-migration is allowed by the governance
    /// @param _amount Amount of tokens to be un-migrated
    function unmigratePushTokens(uint256 _amount) external whenUnMigrationIsAllowed {
        newPushToken.safeTransferFrom(msg.sender, address(this), _amount);
        oldPushToken.safeTransfer(msg.sender, _amount);

        emit TokenUnmigrated(msg.sender, _amount);
    }

    /// @notice Allows owner to BURN old PUSH Tokens in the contract
    /// @dev    Can only be called if un-migration is allowed by the governance
    /// @param _amount Amount of tokens to be un-migrated    
    function burnOldTokens(uint256 _amount) external onlyOwner {
        oldPushToken.safeTransfer(0x000000000000000000000000000000000000dEaD, _amount);
    }
}