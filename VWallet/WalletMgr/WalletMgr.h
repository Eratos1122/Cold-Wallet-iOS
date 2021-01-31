//
//  Wallet.h
//  Wallet
//
//  All rights reserved.
//

#import <Foundation/Foundation.h>
@import Vsys;


static NSString* const NetworkMainnet = @";";
static NSString* const NetworkTestnet = @"T";

static NSString* const AddressVersion = @"29";

NS_ASSUME_NONNULL_BEGIN

@interface VsysAccountEx : NSObject

@property (nonatomic, copy) NSString* accountSeed;

@property (nonatomic, copy) NSString* address;

@property (nonatomic, copy) NSString* privateKey;

@property (nonatomic, copy) NSString* publicKey;

@property (nonatomic, strong) VsysAccount* account;

- (NSString*)signData:(NSData*)data;

@end

@interface WalletMgr : NSObject

@property (nonatomic, strong, nullable) VsysWallet *wallet;

@property (nonatomic, copy, nullable) NSString *seed;

@property (nonatomic, copy, nullable) NSString *salt;

@property (nonatomic, copy, nullable) NSString *network;

@property (nonatomic, copy, nullable) NSArray *accountSeeds;

@property (nonatomic, copy, nullable) NSArray *accounts;

@property (nonatomic, assign) NSInteger nonce;

@property (nonatomic, copy, nullable) NSString *password;

@property (nonatomic, copy, nullable) NSData *securePassword;


+ (instancetype)shareInstance;

- (BOOL)checkWalletBackup;

- (NSError *)loadWallet:(NSString *)password;

- (NSError *)generateSalt:(NSString *)password;

- (NSError *)saveToStorage;

- (NSString *)createAddress:(NSString *)seed : (NSInteger)nonce : (NSString *)network :(NSString *)version;

- (NSString *)createAddress:(NSString* )network : (NSString *)publicKey : (NSString *)version;

- (BOOL)validateAddress:(NSString* )address;

- (NSError *)logoutWallet;

- (NSString *)networkDescription;

- (void)clearPropertyValue;

- (void)logoutWithoutDeleteWallet;
@end

NS_ASSUME_NONNULL_END
