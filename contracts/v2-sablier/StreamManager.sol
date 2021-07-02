// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./PatronageToken.sol";

import { IERC1620 } from "./external/IERC1620.sol";

import "solidity-bytes-utils/contracts/BytesLib.sol";

contract StreamManager {
    using Counters for Counters.Counter;

    IERC1620 private sablier;

    // TODO: Accept more than one token
    IERC20 public acceptedToken;

    struct Stream {
        address sender;
        uint256 sablierStreamId;
        // uint256 streamRate;
    }

    mapping (uint256 => Stream) streams;

    Counters.Counter private _streamIds;

    constructor(
        IERC1620 _sablier,
        IERC20 _acceptedToken
    ) {
        sablier = _sablier;
        acceptedToken = _acceptedToken;
    }

    function _isStreamActive(uint256 streamId) internal view returns (bool) {
        Stream memory stream = streams[streamId];
        uint256 remainingDeposit = sablier.balanceOf(stream.sablierStreamId, address(this));
        return remainingDeposit > 0;
    }

    function _closeStreamAndRefund(uint256 streamId) internal returns (uint256) {
        uint256 refundedDeposit = _closeStream(streamId);

        if (refundedDeposit != 0) {
            acceptedToken.transfer(streams[streamId].sender, refundedDeposit);
        }

        return refundedDeposit;
    }

    function _closeStream(uint256 streamId) internal returns (uint256) {
        Stream memory stream = streams[streamId];

        uint256 remainingDeposit = sablier.balanceOf(stream.sablierStreamId, address(this));
        sablier.cancelStream(stream.sablierStreamId);

        return remainingDeposit;
    }

    function _createStream(address sender, address receiver, uint256 deposit, uint256 stopTime) internal returns (uint256) {
        _streamIds.increment();
        uint256 streamId = _streamIds.current();

        acceptedToken.transferFrom(sender, address(this), deposit);
        uint256 sablierStreamId = sablier.createStream(receiver, deposit, address(acceptedToken), block.timestamp, stopTime);
        streams[streamId] = Stream(sender, sablierStreamId);

        return streamId;
    }

    function _depositToStream(uint256 streamId, uint256 extraDeposit) internal {
        Stream memory stream = streams[streamId];

        uint256 remainingDeposit = sablier.balanceOf(stream.sablierStreamId, address(this));
        sablier.cancelStream(stream.sablierStreamId);

        (, address receiver,,,,, , uint256 ratePerSecond) = sablier.getStream(streamId);

        uint256 newDeposit = remainingDeposit + extraDeposit;
        uint256 newDuration = newDeposit / ratePerSecond;
        uint256 newStopTime = block.timestamp + newDuration;

        uint256 sablierStreamId = sablier.createStream(receiver, newDeposit, address(acceptedToken), block.timestamp, newStopTime);
        streams[streamId].sablierStreamId = sablierStreamId;
    }

    function _updateStreamRate(uint256 streamId, uint256 ratePerSecond) internal {
        Stream memory stream = streams[streamId];

        uint256 remainingDeposit = sablier.balanceOf(stream.sablierStreamId, address(this));
        sablier.cancelStream(stream.sablierStreamId);

        (, address receiver,,,,,,) = sablier.getStream(streamId);

        uint256 newDuration = remainingDeposit / ratePerSecond;
        uint256 newStopTime = block.timestamp + newDuration;

        uint256 sablierStreamId = sablier.createStream(receiver, remainingDeposit, address(acceptedToken), block.timestamp, newStopTime);
        streams[streamId].sablierStreamId = sablierStreamId;
    }

    function _removeStream(uint256 streamId) internal {
        _closeStreamAndRefund(streamId);
        delete streams[streamId];
    }

    function _collectableAmount(uint256 streamId) internal view returns (uint256) {
        uint256 sablierStreamId = streams[streamId].sablierStreamId;
        (, address receiver,,,,,,) = sablier.getStream(sablierStreamId);
        uint256 amount = sablier.balanceOf(sablierStreamId, receiver);
        return amount;
    }

    function _collectFromStream(uint256 streamId) internal {
        uint256 collectableAmount = _collectableAmount(streamId);
        require(collectableAmount > 0, "StreamManager: No collectable amount");
        uint256 sablierStreamId = streams[streamId].sablierStreamId;
        sablier.withdrawFromStream(sablierStreamId, collectableAmount);
    }

    function _changeStreamReceiver(uint256 streamId, address newReceiver) internal {
        require(newReceiver != address(0), "StreamManager: New receiver is zero address");

        (,,,,,uint256 stopTime, uint256 remainingBalance,) = sablier.getStream(streamId);

        if(remainingBalance == 0) return;

        uint256 refundedDeposit = _closeStream(streamId);

        if (refundedDeposit == 0) return;

        // TODO: Check if this math works out
        acceptedToken.approve(address(sablier), refundedDeposit);
        uint256 sablierStreamId = sablier.createStream(newReceiver, refundedDeposit, address(acceptedToken), block.timestamp, stopTime);

        streams[streamId].sablierStreamId = sablierStreamId;
    }

    // returns (
    //         address sender,
    //         address recipient,
    //         uint256 deposit,
    //         address token,
    //         uint256 startTime,
    //         uint256 stopTime,
    //         uint256 remainingBalance,
    //         uint256 ratePerSecond
    //     );

}
