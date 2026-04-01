#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]
extern crate alloc;

use alloc::vec::Vec;
use stylus_sdk::{
    alloy_primitives::{Address, U256, U64},
    alloy_sol_types::sol,
    call::transfer::transfer_eth,
    prelude::*,
    storage::{StorageAddress, StorageBool, StorageMap, StorageU256, StorageU64},
};

sol! {
    event Contribution(address indexed contributor, uint256 amount, uint256 total_raised);
    event Claimed(address indexed owner, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);
    event Initialized(address indexed owner, uint256 goal, uint256 deadline);

    error NotInitialized();
    error AlreadyInitialized();
    error DeadlinePassed();
    error DeadlineNotPassed();
    error GoalNotReached();
    error GoalAlreadyReached();
    error AlreadyClaimed();
    error NotOwner();
    error ZeroContribution();
    error NothingToRefund();
}

#[derive(SolidityError)]
pub enum CrowdfundingError {
    NotInitialized(NotInitialized),
    AlreadyInitialized(AlreadyInitialized),
    DeadlinePassed(DeadlinePassed),
    DeadlineNotPassed(DeadlineNotPassed),
    GoalNotReached(GoalNotReached),
    GoalAlreadyReached(GoalAlreadyReached),
    AlreadyClaimed(AlreadyClaimed),
    NotOwner(NotOwner),
    ZeroContribution(ZeroContribution),
    NothingToRefund(NothingToRefund),
}

#[storage]
#[entrypoint]
pub struct Crowdfunding {
    initialized: StorageBool,
    owner: StorageAddress,
    goal: StorageU256,
    deadline: StorageU64,
    total_raised: StorageU256,
    claimed: StorageBool,
    contributions: StorageMap<Address, StorageU256>,
}

#[public]
impl Crowdfunding {
    /// Initialize the crowdfunding campaign. Can only be called once.
    /// Sets the caller as the owner, with a funding goal (in wei) and
    /// a duration (in seconds from now) for the campaign.
    pub fn initialize(
        &mut self,
        goal: U256,
        duration_seconds: u64,
    ) -> Result<(), CrowdfundingError> {
        if self.initialized.get() {
            return Err(CrowdfundingError::AlreadyInitialized(AlreadyInitialized {}));
        }

        let owner = self.vm().msg_sender();
        let now = self.vm().block_timestamp();
        let deadline = U64::from(now + duration_seconds);

        self.initialized.set(true);
        self.owner.set(owner);
        self.goal.set(goal);
        self.deadline.set(deadline);

        self.vm().log(Initialized {
            owner,
            goal,
            deadline: U256::from(deadline.as_limbs()[0]),
        });

        Ok(())
    }

    /// Contribute ETH to the campaign. Must be before the deadline.
    #[payable]
    pub fn contribute(&mut self) -> Result<(), CrowdfundingError> {
        if !self.initialized.get() {
            return Err(CrowdfundingError::NotInitialized(NotInitialized {}));
        }
        let now = U64::from(self.vm().block_timestamp());
        if now > self.deadline.get() {
            return Err(CrowdfundingError::DeadlinePassed(DeadlinePassed {}));
        }

        let value = self.vm().msg_value();
        if value == U256::ZERO {
            return Err(CrowdfundingError::ZeroContribution(ZeroContribution {}));
        }

        let sender = self.vm().msg_sender();
        let current = self.contributions.get(sender);
        self.contributions.setter(sender).set(current + value);

        let new_total = self.total_raised.get() + value;
        self.total_raised.set(new_total);

        self.vm().log(Contribution {
            contributor: sender,
            amount: value,
            total_raised: new_total,
        });

        Ok(())
    }

    /// Owner claims the funds after the goal has been reached.
    pub fn claim(&mut self) -> Result<(), CrowdfundingError> {
        if !self.initialized.get() {
            return Err(CrowdfundingError::NotInitialized(NotInitialized {}));
        }
        if self.vm().msg_sender() != self.owner.get() {
            return Err(CrowdfundingError::NotOwner(NotOwner {}));
        }
        if self.total_raised.get() < self.goal.get() {
            return Err(CrowdfundingError::GoalNotReached(GoalNotReached {}));
        }
        if self.claimed.get() {
            return Err(CrowdfundingError::AlreadyClaimed(AlreadyClaimed {}));
        }

        self.claimed.set(true);
        let amount = self.total_raised.get();
        let owner = self.owner.get();

        transfer_eth(self.vm(), owner, amount).map_err(|_| {
            CrowdfundingError::GoalNotReached(GoalNotReached {})
        })?;

        self.vm().log(Claimed { owner, amount });

        Ok(())
    }

    /// Contributors can refund their ETH if the deadline has passed
    /// and the goal was NOT reached.
    pub fn refund(&mut self) -> Result<(), CrowdfundingError> {
        if !self.initialized.get() {
            return Err(CrowdfundingError::NotInitialized(NotInitialized {}));
        }
        let now = U64::from(self.vm().block_timestamp());
        if now <= self.deadline.get() {
            return Err(CrowdfundingError::DeadlineNotPassed(DeadlineNotPassed {}));
        }
        if self.total_raised.get() >= self.goal.get() {
            return Err(CrowdfundingError::GoalAlreadyReached(GoalAlreadyReached {}));
        }

        let sender = self.vm().msg_sender();
        let amount = self.contributions.get(sender);
        if amount == U256::ZERO {
            return Err(CrowdfundingError::NothingToRefund(NothingToRefund {}));
        }

        self.contributions.delete(sender);
        let new_total = self.total_raised.get() - amount;
        self.total_raised.set(new_total);

        transfer_eth(self.vm(), sender, amount).map_err(|_| {
            CrowdfundingError::NothingToRefund(NothingToRefund {})
        })?;

        self.vm().log(Refunded {
            contributor: sender,
            amount,
        });

        Ok(())
    }

    // --- View functions ---

    /// Returns the funding goal in wei.
    pub fn goal(&self) -> Result<U256, CrowdfundingError> {
        Ok(self.goal.get())
    }

    /// Returns the total ETH raised so far.
    pub fn total_raised(&self) -> Result<U256, CrowdfundingError> {
        Ok(self.total_raised.get())
    }

    /// Returns the deadline as a unix timestamp.
    pub fn deadline(&self) -> Result<U64, CrowdfundingError> {
        Ok(self.deadline.get())
    }

    /// Returns the owner address.
    pub fn owner(&self) -> Result<Address, CrowdfundingError> {
        Ok(self.owner.get())
    }

    /// Returns whether the funds have been claimed.
    pub fn claimed(&self) -> Result<bool, CrowdfundingError> {
        Ok(self.claimed.get())
    }

    /// Returns the contribution amount for a specific address.
    pub fn contribution_of(&self, contributor: Address) -> Result<U256, CrowdfundingError> {
        Ok(self.contributions.get(contributor))
    }

    /// Returns the contract's current ETH balance.
    pub fn balance(&self) -> Result<U256, CrowdfundingError> {
        let addr = self.vm().contract_address();
        Ok(self.vm().balance(addr))
    }

    /// Returns whether the campaign is still active (before deadline).
    pub fn is_active(&self) -> Result<bool, CrowdfundingError> {
        let now = U64::from(self.vm().block_timestamp());
        Ok(self.initialized.get() && now <= self.deadline.get())
    }

    /// Returns whether the goal has been reached.
    pub fn goal_reached(&self) -> Result<bool, CrowdfundingError> {
        Ok(self.total_raised.get() >= self.goal.get())
    }
}
