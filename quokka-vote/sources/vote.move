module contract_resource_account::smart_chef {

    use std::bcs;
    use aptos_framework::resource_account;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_std::math128;
    use aptos_framework::code;
    use std::signer;
    use std::vector;
    use aptos_std::smart_table;
    use aptos_std::smart_table::SmartTable;
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::{FungibleStore, Metadata};
    use aptos_framework::object;
    use aptos_framework::object::Object;
    use aptos_framework::primary_fungible_store;
    use pancake::smart_chef;
    use pancake::u256;

    const DEFAULT_ADMIN: address = @contract;
    const RESOURCE_ACCOUNT: address = @contract_resource_account;
    const DEV: address = @contract;

    // error
    const ERROR_ONLY_ADMIN: u64 = 0;
    const ERROR_POOL_EXIST: u64 = 1;
    const ERROR_COIN_NOT_EXIST: u64 = 2;
    const ERROR_PASS_START_TIME: u64 = 3;
    const ERROR_MUST_BE_INFERIOR_TO_TWENTY: u64 = 4;
    const ERROR_POOL_LIMIT_ZERO: u64 = 5;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 6;
    const ERROR_POOL_NOT_EXIST: u64 = 7;
    const ERROR_STAKE_ABOVE_LIMIT: u64 = 8;
    const ERROR_NO_STAKE: u64 = 9;
    const ERROR_NO_LIMIT_SET: u64 = 10;
    const ERROR_LIMIT_MUST_BE_HIGHER: u64 = 11;
    const ERROR_POOL_STARTED: u64 = 12;
    const ERROR_END_TIME_EARLIER_THAN_START_TIME: u64 = 13;
    const ERROR_POOL_END: u64 = 14;
    const ERROR_REWARD_MAX: u64 = 16;
    const ERROR_WRONG_UID: u64 = 17;
    const ERROR_SAME_TOKEN: u64 = 18;

    struct SmartChefMetadata has key {
        signer_cap: account::SignerCapability,
        admin: address,
        uid: u64,
    }

    struct PoolInfo has key {
        total_staked_token: Object<FungibleStore>,
        total_reward_token: Object<FungibleStore>,
        reward_per_second: u64,
        start_timestamp: u64,
        end_timestamp: u64,
        last_reward_timestamp: u64,
        seconds_for_user_limit: u64,
        pool_limit_per_user: u64,
        acc_token_per_share: u128,
        precision_factor: u128,
    }

    struct Vec has key {
        list: vector<StakeInfo>
    }

    struct StakeInfo has store, drop,copy {
        staked_token: Object<Metadata>,
        reward_token: Object<Metadata>,
        id: u64,
        total_voted: u64
    }

    struct Epoch has key {
        current: u64,
        start_time: u64
    }

    struct UserInfo has key, store {
        staked_token: Object<Metadata>,
        reward_token: Object<Metadata>,
        id: u64,
        amount: u64,
        reward_debt: u128,
    }

    struct Tabel has key {
        table: SmartTable<u64, Object<PoolInfo>>
    }

    struct Refs has key {
        extend_ref : object::ExtendRef,
        transfer_ref: object::TransferRef
    }

    fun init_module(sender: &signer) {
        let signer_cap = resource_account::retrieve_resource_account_cap(sender, DEV);
        let resource_signer = account::create_signer_with_capability(&signer_cap);
        move_to(&resource_signer, SmartChefMetadata {
            signer_cap,
            uid: 0,
            admin: DEFAULT_ADMIN,
        });
        move_to(&resource_signer,
            Tabel {
                table: smart_table::new(),
            }
        );

        move_to(&resource_signer,
            Epoch {
                current: 0,
                start_time: 0,
            }
        );

        move_to(&resource_signer,
            Vec {
                list: vector::empty()
            }
        );

    }

    inline fun get_resource_signer():&signer {
        let metadata = borrow_global_mut<SmartChefMetadata>(RESOURCE_ACCOUNT);
        &account::create_signer_with_capability(&metadata.signer_cap)
    }

    public entry fun create_pool(
        admin: &signer,
        stake_token_metadata: Object<Metadata>,
        reward_token_metadata: Object<Metadata>,
        reward_per_second: u64,
        start_timestamp: u64,
        end_timestamp: u64,
        pool_limit_per_user: u64,
        seconds_for_user_limit: u64
    ) acquires SmartChefMetadata, Tabel, Vec, PoolInfo {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global_mut<SmartChefMetadata>(RESOURCE_ACCOUNT);
        // assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        // assert!(start_timestamp > timestamp::now_seconds(), ERROR_PASS_START_TIME);
        assert!(start_timestamp < end_timestamp, ERROR_END_TIME_EARLIER_THAN_START_TIME);
        let resource_signer = account::create_signer_with_capability(&metadata.signer_cap);

        if (seconds_for_user_limit > 0) {
            assert!(pool_limit_per_user > 0, ERROR_POOL_LIMIT_ZERO);
        };

        let reward_token_decimal = fungible_asset::decimals(reward_token_metadata);
        assert!(reward_token_decimal < 20, ERROR_MUST_BE_INFERIOR_TO_TWENTY);
        let precision_factor = math128::pow(10u128, ((20 - reward_token_decimal) as u128));

        let table = borrow_global_mut<Tabel>(RESOURCE_ACCOUNT);

        let seed = vector[];
        vector::append(&mut seed, bcs::to_bytes(&stake_token_metadata));
        vector::append(&mut seed, bcs::to_bytes(&reward_token_metadata));
        vector::append(&mut seed, bcs::to_bytes(&smart_table::length(&table.table)));

        let pool_object_cref = object::create_named_object(
            &resource_signer,
            seed
        );

        let staked_token_store_cref = object::create_sticky_object(RESOURCE_ACCOUNT);

        let reward_token_store_cref = object::create_sticky_object(
            RESOURCE_ACCOUNT
        );

        move_to(
            &object::generate_signer(
                &pool_object_cref
            ),
            Refs {
                extend_ref: object::generate_extend_ref(
                    &pool_object_cref
                ),
                transfer_ref: object::generate_transfer_ref(
                    &pool_object_cref
                )
            }
        );

        move_to(&object::generate_signer(&pool_object_cref),
            PoolInfo{
                total_staked_token: fungible_asset::create_store(&staked_token_store_cref, stake_token_metadata),
                total_reward_token: fungible_asset::create_store(&reward_token_store_cref, reward_token_metadata),
                reward_per_second,
                last_reward_timestamp: start_timestamp,
                start_timestamp,
                end_timestamp,
                seconds_for_user_limit,
                pool_limit_per_user,
                acc_token_per_share: 0,
                precision_factor, });
        smart_table::add(
            &mut table.table,
            metadata.uid,
            object::object_from_constructor_ref(
                &pool_object_cref
            )
        );

        let vec = borrow_global_mut<Vec>(RESOURCE_ACCOUNT);
        let pool_info = borrow_global_mut<PoolInfo>( object::object_address(smart_table::borrow(&table.table, metadata.uid)));

        vector::push_back(&mut vec.list, StakeInfo {
            staked_token:fungible_asset::store_metadata(pool_info.total_staked_token),
            reward_token:fungible_asset::store_metadata(pool_info.total_reward_token),
            id: metadata.uid,
            total_voted: 0
        });
        metadata.uid = metadata.uid + 1;
    }

    public entry fun add_reward(
        admin: &signer,
        id: u64,
        amount: u64
    ) acquires PoolInfo, SmartChefMetadata, Tabel {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        // assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        let table = borrow_global<Tabel>(RESOURCE_ACCOUNT);
        let pool_info = borrow_global_mut<PoolInfo>( object::object_address(smart_table::borrow(&table.table, id)));

        transfer_in( pool_info.total_reward_token, admin, amount);
    }

    inline fun create_user_info_address(owner: address,pool_object: Object<PoolInfo>, id: u64):address{
        let seed = vector[];
        vector::append(&mut seed, bcs::to_bytes(&object::object_address(&pool_object)));
        vector::append(&mut seed, bcs::to_bytes(&id));
        object::create_object_address(
            &owner,
            seed
        )
    }

    public entry fun deposit(
        account: &signer,
        id: u64,
        amount: u64
    ) acquires PoolInfo, UserInfo, Tabel, SmartChefMetadata,  Vec, Epoch {
        let account_address = signer::address_of(account);
        let table = borrow_global<Tabel>(RESOURCE_ACCOUNT);
        let pool_info = borrow_global_mut<PoolInfo>( object::object_address(smart_table::borrow(&table.table, id)));
        let now = timestamp::now_seconds();
        assert!(pool_info.end_timestamp > now, ERROR_POOL_END);
        let seed = vector[];
        vector::append(&mut seed, bcs::to_bytes(&object::object_address(smart_table::borrow(&table.table, id))));
        vector::append(&mut seed, bcs::to_bytes(&id));
        let object_address = create_user_info_address(
            account_address,
            *smart_table::borrow(&table.table, id),
            id
        );

        if (!object::is_object(object_address)) {
            let object_cref = object::create_named_object(
                account,
                seed
            );
            let transfer_ref = object::generate_transfer_ref(
                &object_cref
            );
            object::disable_ungated_transfer(&transfer_ref);
            move_to(&object::generate_signer(&object_cref), UserInfo {
                staked_token:fungible_asset::store_metadata(pool_info.total_staked_token),
                reward_token:fungible_asset::store_metadata(pool_info.total_reward_token),
                id ,
                amount: 0,
                reward_debt: 0,
            });
            move_to(
                &object::generate_signer(&object_cref),
                Refs {
                    transfer_ref,
                    extend_ref: object::generate_extend_ref(&object_cref)
                }
            );
        };

        update_pool(pool_info);

        let user_info = borrow_global_mut<UserInfo>(object_address);
        assert!(((user_info.amount + amount) <= pool_info.pool_limit_per_user) || (now >= (pool_info.start_timestamp + pool_info.seconds_for_user_limit)), ERROR_STAKE_ABOVE_LIMIT);

        if (user_info.amount > 0) {
            let pending_reward = cal_pending_reward(user_info.amount, user_info.reward_debt, pool_info.acc_token_per_share, pool_info.precision_factor);
            if (pending_reward > 0) transfer_out(pool_info.total_reward_token,get_resource_signer() ,account_address, pending_reward)
        };

        if (amount > 0) {
            transfer_in(pool_info.total_staked_token, account, amount);
            user_info.amount = user_info.amount + amount;
        };

        user_info.reward_debt = reward_debt(user_info.amount, pool_info.acc_token_per_share, pool_info.precision_factor);


        let vec  = borrow_global_mut<Vec>(RESOURCE_ACCOUNT);
        vector::for_each_mut(&mut vec.list, |item| {
            let item: &mut StakeInfo = item;
            if( item.id == id ) {
                item.total_voted = item.total_voted + amount;
            }
        });
        update_vote_list(&mut vec.list);

        update_epoch();
    }

    fun update_vote_list (vec: &mut vector<StakeInfo>){
        let len =  vector::length(vec);
        for ( i in 0..len) {
            for ( j in 0..(len - i - 1)) {
                if (vector::borrow(vec, j).total_voted > vector::borrow(vec, j + 1).total_voted) {
                    vector::swap( vec, j, j + 1);
                }
            }
        }
    }

    fun update_epoch () acquires Epoch, Vec, SmartChefMetadata {
        let epoch = borrow_global_mut<Epoch>(RESOURCE_ACCOUNT);
        let vec = borrow_global_mut<Vec>(RESOURCE_ACCOUNT);
        if(timestamp::now_seconds()  > epoch.start_time + 2 * 60 ){

            // vector::for_each(vec.list, |item|{
            //
            // });

            if( vector::length(&vec.list) != 2){
                abort  1
            };

            if( epoch.start_time != 0 ){
                smart_chef::update_reward_per_second(
                    get_resource_signer()
                    , vector::borrow(&vec.list, 0).id,
                    600000000
                );
            };

            epoch.current = epoch.current + 1;
            epoch.start_time = timestamp::now_seconds();
        };
    }

    public entry fun withdraw(
        account: &signer,
        id: u64,
        amount: u64,
    ) acquires PoolInfo, UserInfo, Tabel, SmartChefMetadata, Vec, Epoch {
        let account_address = signer::address_of(account);
        let table = borrow_global<Tabel>(RESOURCE_ACCOUNT);
        let pool_info = borrow_global_mut<PoolInfo>( object::object_address(smart_table::borrow(&table.table, id)));

        update_pool(pool_info);
        let object_address = create_user_info_address(
            account_address,
            *smart_table::borrow(&table.table, id),
            id
        );
        let user_info = borrow_global_mut<UserInfo>(object_address);
        assert!(user_info.amount >= amount, ERROR_INSUFFICIENT_BALANCE);

        let pending_reward = cal_pending_reward(user_info.amount, user_info.reward_debt, pool_info.acc_token_per_share, pool_info.precision_factor);

        if (amount > 0) {
            user_info.amount = user_info.amount - amount;
            transfer_out(pool_info.total_staked_token, get_resource_signer(),account_address, amount);
        };

        if (pending_reward > 0) {
            transfer_out( pool_info.total_reward_token, get_resource_signer(),account_address, pending_reward);
        };

        user_info.reward_debt = reward_debt(user_info.amount, pool_info.acc_token_per_share, pool_info.precision_factor);

        let vec  = borrow_global_mut<Vec>(RESOURCE_ACCOUNT);
        vector::for_each_mut(&mut vec.list, |item| {
            let item: &mut StakeInfo = item;
            if( item.id == id ) {
                item.total_voted = item.total_voted - amount;
            }
        });
        update_vote_list(&mut vec.list);

        update_epoch();
    }

    public entry fun stop_reward(admin: &signer, id: u64) acquires PoolInfo, SmartChefMetadata, Tabel {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        // assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        let now = timestamp::now_seconds();
        let table = borrow_global<Tabel>(RESOURCE_ACCOUNT);
        let pool_info = borrow_global_mut<PoolInfo>( object::object_address(smart_table::borrow(&table.table, id)));
        pool_info.end_timestamp = now;
    }

    public entry fun update_pool_limit_per_user(admin: &signer,id: u64, seconds_for_user_limit: bool, pool_limit_per_user: u64) acquires PoolInfo, SmartChefMetadata, Tabel {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        // assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        let table = borrow_global<Tabel>(RESOURCE_ACCOUNT);
        let pool_info = borrow_global_mut<PoolInfo>( object::object_address(smart_table::borrow(&table.table, id)));
        assert!((pool_info.seconds_for_user_limit > 0) && (timestamp::now_seconds() < (pool_info.start_timestamp + pool_info.seconds_for_user_limit)), ERROR_NO_LIMIT_SET);
        if (seconds_for_user_limit) {
            assert!(pool_limit_per_user > pool_info.pool_limit_per_user, ERROR_LIMIT_MUST_BE_HIGHER);
            pool_info.pool_limit_per_user = pool_limit_per_user
        }else {
            pool_info.seconds_for_user_limit = 0;
            pool_info.pool_limit_per_user = 0
        };


    }

    public entry fun update_reward_per_second(admin: &signer,id: u64 ,reward_per_second: u64) acquires PoolInfo, SmartChefMetadata, Tabel {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        // assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        let table = borrow_global<Tabel>(RESOURCE_ACCOUNT);
        let pool_info = borrow_global_mut<PoolInfo>( object::object_address(smart_table::borrow(&table.table, id)));
        assert!(timestamp::now_seconds() < pool_info.start_timestamp, ERROR_POOL_STARTED);
        pool_info.reward_per_second = reward_per_second;


    }

    public entry fun update_start_and_end_timestamp(admin: &signer, id: u64,start_timestamp: u64, end_timestamp: u64) acquires PoolInfo, SmartChefMetadata, Tabel {
        let admin_address = signer::address_of(admin);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        // assert!(admin_address == metadata.admin, ERROR_ONLY_ADMIN);
        let table = borrow_global<Tabel>(RESOURCE_ACCOUNT);
        let pool_info = borrow_global_mut<PoolInfo>( object::object_address(smart_table::borrow(&table.table, id)));
        let now = timestamp::now_seconds();
        assert!(now < pool_info.start_timestamp, ERROR_POOL_STARTED);
        assert!(start_timestamp < end_timestamp, ERROR_END_TIME_EARLIER_THAN_START_TIME);
        // assert!(now < start_timestamp, ERROR_PASS_START_TIME);

        pool_info.start_timestamp = start_timestamp;
        pool_info.end_timestamp = end_timestamp;

        pool_info.last_reward_timestamp = start_timestamp;


    }

    public entry fun set_admin(sender: &signer, new_admin: address) acquires SmartChefMetadata {
        let sender_addr = signer::address_of(sender);
        let metadata = borrow_global_mut<SmartChefMetadata>(RESOURCE_ACCOUNT);
        // assert!(sender_addr == metadata.admin, ERROR_ONLY_ADMIN);
        metadata.admin = new_admin;
    }

    #[view]
    public fun get_pool_info(id: u64): (u64, u64, u64, u64, u64, u64, u64) acquires PoolInfo, Tabel {
        let table = borrow_global<Tabel>(RESOURCE_ACCOUNT);
        let pool_info = borrow_global_mut<PoolInfo>( object::object_address(smart_table::borrow(&table.table, id)));
        (
            fungible_asset::balance(pool_info.total_staked_token),
            fungible_asset::balance(pool_info.total_reward_token),
            pool_info.reward_per_second,
            pool_info.start_timestamp,
            pool_info.end_timestamp,
            pool_info.seconds_for_user_limit,
            pool_info.pool_limit_per_user,
        )
    }

    #[view]
    public fun get_user_stake_amount(account: address, id:u64): u64 acquires UserInfo, Tabel {
        let table = borrow_global<Tabel>(RESOURCE_ACCOUNT);
        let object_address = create_user_info_address(
            account,
            *smart_table::borrow(&table.table, id),
            id
        );
        let user_info = borrow_global<UserInfo>(object_address);
        user_info.amount
    }

    #[view]
    public fun get_pending_reward(account: address, id: u64): u64 acquires PoolInfo, UserInfo, Tabel {
        let table = borrow_global<Tabel>(RESOURCE_ACCOUNT);
        let pool_info = borrow_global<PoolInfo>( object::object_address(smart_table::borrow(&table.table, id)));

        let object_address = create_user_info_address(
            account,
            *smart_table::borrow(&table.table, id),
            id
        );
        let user_info = borrow_global<UserInfo>(object_address);let acc_token_per_share = if (fungible_asset::balance(pool_info.total_staked_token) == 0 || timestamp::now_seconds() < pool_info.last_reward_timestamp) {
            pool_info.acc_token_per_share
        } else {
            cal_acc_token_per_share(
                pool_info.acc_token_per_share,
                fungible_asset::balance(pool_info.total_staked_token),
                pool_info.end_timestamp,
                pool_info.reward_per_second,
                pool_info.precision_factor,
                pool_info.last_reward_timestamp
            )
        };
        cal_pending_reward(user_info.amount, user_info.reward_debt, acc_token_per_share, pool_info.precision_factor)
    }

    fun update_pool(pool_info: &mut PoolInfo) {
        let now = timestamp::now_seconds();
        if (now <= pool_info.last_reward_timestamp) return;

        if (fungible_asset::balance(pool_info.total_staked_token) == 0) {
            pool_info.last_reward_timestamp = now;
            return
        };

        let new_acc_token_per_share = cal_acc_token_per_share(
            pool_info.acc_token_per_share,
            fungible_asset::balance(pool_info.total_staked_token),
            pool_info.end_timestamp,
            pool_info.reward_per_second,
            pool_info.precision_factor,
            pool_info.last_reward_timestamp
        );

        if (pool_info.acc_token_per_share == new_acc_token_per_share) return;
        pool_info.acc_token_per_share = new_acc_token_per_share;
        pool_info.last_reward_timestamp = now;
    }

    fun cal_acc_token_per_share(last_acc_token_per_share: u128, total_staked_token: u64, end_timestamp: u64, reward_per_second: u64, precision_factor: u128, last_reward_timestamp: u64): u128 {
        let multiplier = get_multiplier(last_reward_timestamp, timestamp::now_seconds(), end_timestamp);
        let reward = u256::from_u128((reward_per_second as u128) * (multiplier as u128));
        if (multiplier == 0) return last_acc_token_per_share;
        // acc_token_per_share = acc_token_per_share + (reward * precision_factor) / total_stake;
        let acc_token_per_share_u256 = u256::add(
            u256::from_u128(last_acc_token_per_share),
            u256::div(
                u256::mul(reward, u256::from_u128(precision_factor)),
                u256::from_u64(total_staked_token)
            )
        );
        u256::as_u128(acc_token_per_share_u256)
    }

    fun cal_pending_reward(amount: u64, reward_debt: u128, acc_token_per_share: u128, precision_factor: u128): u64 {
        // pending = (user_info::amount * pool_info.acc_token_per_share) / pool_info.precision_factor - user_info.reward_debt
        u256::as_u64(
            u256::sub(
                u256::div(
                    u256::mul(
                        u256::from_u64(amount),
                        u256::from_u128(acc_token_per_share)
                    ), u256::from_u128(precision_factor)
                ), u256::from_u128(reward_debt))
        )
    }

    fun reward_debt(amount: u64, acc_token_per_share: u128, precision_factor: u128): u128 {
        // user.reward_debt = (user_info.amount * pool_info.acc_token_per_share) / pool_info.precision_factor;
        u256::as_u128(
            u256::div(
                u256::mul(
                    u256::from_u64(amount),
                    u256::from_u128(acc_token_per_share)
                ),
                u256::from_u128(precision_factor)
            )
        )
    }

    fun get_multiplier(from_timestamp: u64, to_timestamp: u64, end_timestamp: u64): u64 {
        if (to_timestamp <= end_timestamp) {
            to_timestamp - from_timestamp
        }else if (from_timestamp >= end_timestamp) {
            0
        } else {
            end_timestamp - from_timestamp
        }
    }

    fun check_or_register_coin_store<X>(sender: &signer) {
        if (!coin::is_account_registered<X>(signer::address_of(sender))) {
            coin::register<X>(sender);
        };
    }

    fun transfer_in(own_coin:object::Object<FungibleStore>, account: &signer, amount: u64) {
        let meta_object = fungible_asset::store_metadata(own_coin);
        let fa = fungible_asset::withdraw(
            account,
            primary_fungible_store::primary_store(signer::address_of(account),meta_object),
            amount
        );
        fungible_asset::deposit( own_coin ,fa)
    }

    fun transfer_out(own_coin: object::Object<FungibleStore>, sender: &signer, receiver: address, amount: u64) {
        let extract_coin = fungible_asset::withdraw(
            sender,
            own_coin,
            amount
        );
        primary_fungible_store::deposit(receiver, extract_coin)
    }

    public entry fun upgrade_contract(sender: &signer, metadata_serialized: vector<u8>, code: vector<vector<u8>>) acquires SmartChefMetadata {
        let sender_addr = signer::address_of(sender);
        let metadata = borrow_global<SmartChefMetadata>(RESOURCE_ACCOUNT);
        // assert!(sender_addr == metadata.admin, ERROR_ONLY_ADMIN);
        let resource_signer = account::create_signer_with_capability(&metadata.signer_cap);
        code::publish_package_txn(&resource_signer, metadata_serialized, code);
    }

    #[test_only]
    public fun initialize(sender: &signer) {
        init_module(sender);
    }
}