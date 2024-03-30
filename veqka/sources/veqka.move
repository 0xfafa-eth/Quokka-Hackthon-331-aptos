module veqka::veqka {
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use std::string::utf8;
    use std::option;
    use aptos_std::smart_vector;
    use aptos_framework::account;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::timestamp;
    use qka::qka;

    /// Only fungible asset metadata owner can make changes.
    const ENOT_OWNER: u64 = 1;

    const ASSET_SYMBOL: vector<u8> = b"veqka";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Hold refs to control the minting, transfer and burning of fungible assets.
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

    struct Cap has key {
        cap: SignerCapability
    }
    struct StakeList has key {

        list: smart_vector::SmartVector<StakeInfo>
    }

    struct StakeInfo has store {
        start_time: u64,
        end_time: u64,
        amount: u64
    }

    /// Initialize metadata object and store the refs.
    // :!:>initialize
    fun init_module(admin: &signer) {
        let (signer, cap) = account::create_resource_account(
            admin,
            b"veqka"
        );

        move_to(
            admin,
            Cap {cap}
        );

        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(b"VeQuokka"),
            utf8(ASSET_SYMBOL),
            8,
            utf8(b"http://example.com/favicon.ico"),
            utf8(b"http://example.com"),
        );

        // Create mint/burn/transfer refs to allow creator to manage the fungible asset.
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(
            &metadata_object_signer,
            ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref }
        )// <:!:initialize
    }

    #[view]
    /// Return the address of the managed fungible asset that's created when this module is deployed.
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@veqka, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }


    inline fun get_resource_address():address {
        account::create_resource_address(
            &@veqka,
            b"veqka"
        )
    }


    public entry fun stake(sender: &signer, time: u64 ,amount: u64) acquires ManagedFungibleAsset, StakeList {
        let asset = get_metadata();
        let managed_fungible_asset = borrow_refs(asset);

        let to_wallet = primary_fungible_store::ensure_primary_store_exists(signer::address_of(sender), asset);

        if(!exists<StakeList>(signer::address_of(sender))){
            move_to(
                sender,
                StakeList {
                    list: smart_vector::new()
                }
            );
        };

        let list_mut = borrow_global_mut<StakeList>(signer::address_of(sender));

        smart_vector::push_back(
            &mut list_mut.list,
            StakeInfo {
                start_time: timestamp::now_seconds(),
                end_time: timestamp::now_seconds() + time,
                amount,
            }
        );

        primary_fungible_store::transfer(
            sender,
            qka::get_metadata(),
            get_resource_address(),
            amount
        );

        let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, calc(time, amount));

        fungible_asset::deposit_with_ref(&managed_fungible_asset.transfer_ref, to_wallet, fa);
    }// <:!:mint

    #[view]
    public fun calc(time: u64, amount: u64): u64 {
        let i = ((2 * 365 * 24 * 60 * 60)) / time ;
        ( (amount)  / i )
    }

    /// Transfer as the owner of metadata object ignoring `frozen` field.
    public entry fun transfer(admin: &signer, from: address, to: address, amount: u64) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        fungible_asset::transfer_with_ref(transfer_ref, from_wallet, to_wallet, amount);
    }

    /// Burn fungible assets as the owner of metadata object.
    public entry fun burn(admin: &signer, from: address, amount: u64) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let burn_ref = &authorized_borrow_refs(admin, asset).burn_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::burn_from(burn_ref, from_wallet, amount);
    }

    /// Freeze an account so it cannot transfer or receive fungible assets.
    public entry fun freeze_account(admin: &signer, account: address) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, true);
    }

    /// Unfreeze an account so it can transfer or receive fungible assets.
    public entry fun unfreeze_account(admin: &signer, account: address) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, false);
    }

    /// Withdraw as the owner of metadata object ignoring `frozen` field.
    public fun withdraw(admin: &signer, amount: u64, from: address): FungibleAsset acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::withdraw_with_ref(transfer_ref, from_wallet, amount)
    }

    /// Deposit as the owner of metadata object ignoring `frozen` field.
    public fun deposit(admin: &signer, to: address, fa: FungibleAsset) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        fungible_asset::deposit_with_ref(transfer_ref, to_wallet, fa);
    }

    /// Borrow the immutable reference of the refs of `metadata`.
    /// This validates that the signer is the metadata object's owner.
    inline fun authorized_borrow_refs(
        owner: &signer,
        asset: Object<Metadata>,
    ): &ManagedFungibleAsset acquires ManagedFungibleAsset {
        assert!(object::is_owner(asset, signer::address_of(owner)), error::permission_denied(ENOT_OWNER));
        borrow_global<ManagedFungibleAsset>(object::object_address(&asset))
    }

    inline fun borrow_refs (
        asset: Object<Metadata>,
    ):&ManagedFungibleAsset acquires ManagedFungibleAsset{
        borrow_global<ManagedFungibleAsset>(object::object_address(&asset))
    }

}
