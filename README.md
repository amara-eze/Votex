# Votex

## Overview

Votex is a decentralized autonomous organization (DAO) smart contract built in Clarity. It enables the creation and management of multiple DAOs, providing functionality for membership, governance, proposals, voting, and treasury control. Each DAO operates independently with its own configuration, members, and funds.

## Features

* **DAO Creation**: Users can create new DAOs with unique identifiers, governance tokens, and membership thresholds.
* **Membership Management**: Participants can join DAOs directly or by meeting specific token balance requirements.
* **Governance Settings**: Admins can adjust parameters like voting period, quorum, and proposal thresholds.
* **Proposal Lifecycle**: Members can create proposals, cast votes, and finalize results based on majority and quorum conditions.
* **Voting Power**: Determined by each member’s balance or assigned power, influencing proposal outcomes.
* **Treasury Management**: Supports adding STX funds and controlled withdrawals by DAO admins.
* **Read-only Queries**: Retrieve information on DAOs, members, proposals, votes, governance settings, and treasury status.

## Key Components

* **DAO Registry**: Tracks each DAO’s metadata including name, description, creator, and token.
* **Governance Settings**: Stores adjustable voting and proposal parameters for each DAO.
* **Members Map**: Maintains records of members’ roles, voting power, and activity status.
* **Proposals Map**: Contains proposal details such as title, description, status, and voting data.
* **Votes Map**: Records individual votes with timestamps and voting power used.
* **Treasury Map**: Manages DAO-specific STX balances and update timestamps.

## Error Codes

* `ERR-NOT-FOUND`: DAO, proposal, or record not found.
* `ERR-UNAUTHORIZED`: Action attempted by a non-admin or invalid member.
* `ERR-INVALID-PARAMS`: Input validation failure.
* `ERR-INSUFFICIENT-BALANCE`: Insufficient funds or voting power.
* `ERR-DAO-INACTIVE`: Attempt to interact with a deactivated DAO.
* `ERR-VOTING-ENDED`: Proposal voting period has expired.
* `ERR-ALREADY-VOTED`: Member has already cast a vote.

## Functions Summary

* **create-dao**: Initializes a new DAO with governance settings and treasury.
* **join-dao / join-dao-with-token**: Adds members manually or via token threshold validation.
* **update-governance-settings**: Admin-only update of DAO governance parameters.
* **create-proposal**: Allows members to submit proposals for voting.
* **vote-on-proposal**: Enables eligible members to cast votes on active proposals.
* **finalize-proposal**: Concludes voting and determines whether the proposal passes or fails.
* **add-treasury-funds / transfer-treasury-funds**: Manage DAO treasury STX funds.
* **get-dao-info / get-proposal-info / get-member-info / get-treasury-info / get-governance-info / get-vote-info**: Retrieve DAO and related data.

## Initialization

The contract starts with `next-dao-id` set to `u1`, incrementing with each DAO creation to ensure unique DAO identifiers.
