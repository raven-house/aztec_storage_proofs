use aztec::macros::aztec;

#[aztec]
pub contract StorageProof {
    use aztec::{
        macros::{functions::{external, view}, storage::storage},
        messages::message_delivery::MessageDelivery,
        protocol::address::AztecAddress,
        state_vars::{Owned, PublicMutable},
    };

    use balance_set::BalanceSet;

    #[storage]
    struct Storage<Context> {
        private_balances: Owned<BalanceSet<Context>, Context>,
        public_balances: PublicMutable<u128, Context>,
    }

    #[external("private")]
    fn set_value(value: u128) {
        let sender = self.msg_sender();
        self.storage.private_balances.at(sender).add(value).deliver(
            MessageDelivery.ONCHAIN_CONSTRAINED,
        );
    }

    #[external("utility")]
    unconstrained fn get_value(owner: AztecAddress) -> u128 {
        self.storage.private_balances.at(owner).balance_of()
    }

    #[external("public")]
    #[view]
    fn get_public_balance() -> u128 {
        self.storage.public_balances.read()
    }
}
