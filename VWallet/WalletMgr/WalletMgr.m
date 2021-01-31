//
//  Wallet.m
//  Wallet
//
//  All rights reserved.
//

#import "WalletMgr.h"
#import <SAMKeychain/SAMKeychain.h>
#import "AppState.h"
#import "Language.h"
#import "Scrypt.h"
#import "Curve25519.h"
#import "Randomness.h"
#import "Ed25519.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
@import Vsys;

static NSString *VKeyChainService = @"vsys.wallet.cold";
static NSString *VKeyChainAccount = @"vsys";
static NSString *VKeyChainAccountSalt = @"salt";

static int  const ChecksumLength = 4;
static int  const HashLength = 20;
static int  const AddressLength = 1 + 1 + ChecksumLength + HashLength;

static WalletMgr *VWalletMgr = nil;

@implementation WalletMgr

+ (instancetype)shareInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        VWalletMgr = [[WalletMgr alloc] init];
        [SAMKeychain setAccessibilityType:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly];
    });
    return VWalletMgr;
}

- (BOOL)checkWalletBackup {
    NSError *error;
    [SAMKeychain passwordDataForService:VKeyChainService account:VKeyChainAccount error:&error];
    if (error) {
        return NO;
    }
    return YES;
}

- (NSData *)generatePassword:(NSString *)password salt:(NSString *)salt error:(NSError **)error {
    NSData *secureData = [Scrypt scrypt:[password dataUsingEncoding:NSUTF8StringEncoding] salt:[salt dataUsingEncoding:NSUTF8StringEncoding] n:32768 r:8 p:1 length:32 error:error];
    return secureData;
}

-(NSData*)sha256HashFor:(NSData*)input
{
    char str[32] ={0};
    memcpy(str, [input bytes], 32);
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(str, 32, result);
    
    return [[NSData alloc] initWithBytes:result length:32];
}

- (BOOL)validateAddress:(NSString* )address {
    NSData* dataAddress = VsysBase58Decode([address dataUsingEncoding:NSUTF8StringEncoding]);
    Byte * bAddress = (Byte *)[dataAddress bytes];
    if (bAddress[0] != [AddressVersion intValue]) {
        return NO;
    } else if(bAddress[1] != *(Byte *)[[[self network] dataUsingEncoding: NSUTF8StringEncoding] bytes]){
        return NO;
    } else if(dataAddress.length != AddressLength){
        return NO;
    } else {
        Byte bCheck[ChecksumLength] = {0};
        memcpy(bCheck,bAddress + AddressLength - ChecksumLength, ChecksumLength);
        
        Byte bWithoutCheck[AddressLength - ChecksumLength] = {0};
        memcpy(bWithoutCheck, bAddress, AddressLength - ChecksumLength);
        
        NSData* dataWithoutCheck = VsysHashChain([[NSData alloc]initWithBytes:bWithoutCheck length:AddressLength - ChecksumLength]);
        
        Byte * bCheckResult = (Byte *)[dataWithoutCheck bytes];
        for (int i = 0; i < ChecksumLength; i++) {
            if (bCheck[i] != bCheckResult[i]) {
                return NO;
            }
        }
    }
    
    return YES;
}

- (NSString *) createAddress:(NSString* )network : (NSString *)publicKey : (NSString *)version {
    NSData* dataPub = VsysBase58Decode([publicKey dataUsingEncoding:NSUTF8StringEncoding]);
    Byte * bPub = (Byte *)[VsysHashChain(dataPub) bytes];
    
    Byte bWithoutCheck[AddressLength - ChecksumLength] = {0};
    bWithoutCheck[0] = [version intValue];
    bWithoutCheck[1] = *(Byte *)[[network dataUsingEncoding: NSUTF8StringEncoding] bytes];
    memcpy(bWithoutCheck + 2, bPub,HashLength);
    
    NSData* dataWithoutCheck = VsysHashChain([[NSData alloc]initWithBytes:bWithoutCheck length:AddressLength - ChecksumLength]);
    Byte * bCheck = (Byte *)[dataWithoutCheck bytes];
    
    Byte bAddress[AddressLength] = {0};
    memcpy(bAddress, bWithoutCheck,AddressLength - ChecksumLength);
    memcpy(bAddress + AddressLength - ChecksumLength, bCheck,ChecksumLength);
    
    NSData* address = VsysBase58Encode([[NSData alloc]initWithBytes:bAddress length:AddressLength]);
    return [[NSString alloc] initWithData:address encoding:NSUTF8StringEncoding];
}

- (NSString *) createAddress:(NSString *)seed : (NSInteger)nonce : (NSString *)network :(NSString *)version{
    NSString *  seedEx      =   [[NSString stringWithFormat: @"%d", nonce] stringByAppendingString:seed];
    NSData*     dataSeed    =   VsysHashChain([seedEx dataUsingEncoding:NSUTF8StringEncoding]);
    ECKeyPair * key         =   [Curve25519 generateKeyPair:[self sha256HashFor:dataSeed]];
    
    Byte * bPublicKey = (Byte *)[VsysHashChain(key.publicKey) bytes];
    
    Byte bWithoutCheck[AddressLength - ChecksumLength] = {0};
    bWithoutCheck[0] = [version intValue];
    bWithoutCheck[1] = *(Byte *)[[network dataUsingEncoding: NSUTF8StringEncoding] bytes];
    memcpy(bWithoutCheck + 2, bPublicKey,HashLength);
    
    NSData* dataWithoutCheck = VsysHashChain([[NSData alloc]initWithBytes:bWithoutCheck length:AddressLength - ChecksumLength]);
    Byte * bCheck = (Byte *)[dataWithoutCheck bytes];
    
    Byte bAddress[AddressLength] = {0};
    memcpy(bAddress, bWithoutCheck,AddressLength - ChecksumLength);
    memcpy(bAddress + AddressLength - ChecksumLength, bCheck,ChecksumLength);
    
    NSData* address = VsysBase58Encode([[NSData alloc]initWithBytes:bAddress length:AddressLength]);
    return [[NSString alloc] initWithData:address encoding:NSUTF8StringEncoding];
}

- (NSError *)loadWallet:(NSString *)password {
    NSError *error;
    if (!password || [password isEqualToString:@""]) {
        return [NSError errorWithDomain:VKeyChainService code:-1 userInfo:nil];
    }
    
    [self loadSalt:&error];
    if (error) {
        return error;
    }
    
    self.securePassword = [self generatePassword:password salt:self.salt error:&error];
    if (!self.securePassword) {
        return [NSError errorWithDomain:VKeyChainService code:-1 userInfo:nil];
    }
    
    NSData *undecryptData = [SAMKeychain passwordDataForService:VKeyChainService account:VKeyChainAccount error:&error];
    if (error) {
        return error;
    }
    
    NSData *decryptedData = VsysAesDecrypt(self.securePassword, undecryptData, &error);
    if (error) {
        return error;
    }
    
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:decryptedData options:NSJSONReadingAllowFragments error:&error];
    if (error) {
        return error;
    }
    
    NSString *seed = dict[@"seed"];
    if (seed.length <=0) {
        return nil;
    }
    self.network = dict[@"network"];
    self.seed = seed;
    self.password = password;
    VsysWallet *wallet = VsysNewWallet(seed, self.network);
    self.wallet = wallet;
    
    NSInteger nonce = [dict[@"nonce"] integerValue];
    self.nonce = nonce;
    
    NSMutableArray *accArr = @[].mutableCopy;
    NSMutableArray *accSeedArr = @[].mutableCopy;
    for (int i = 0; i <= nonce; i++) {
        VsysAccount *account = [wallet generateAccount:i];
        VsysAccountEx *accountEx = [[VsysAccountEx alloc] init];
        accountEx.address = [self createAddress:seed:i:self.network:AddressVersion];
        accountEx.privateKey = account.privateKey;
        accountEx.publicKey = account.publicKey;
        accountEx.accountSeed = account.accountSeed;
        accountEx.account = account;
        [accArr addObject:accountEx];
        [accSeedArr addObject:account.accountSeed];
    }
    self.accounts = accArr;
    self.accountSeeds = accSeedArr;
    
    return nil;
}

- (NSString *)generateUUID {
    CFUUIDRef puuid = CFUUIDCreate(nil);
    CFStringRef uuidString = CFUUIDCreateString(nil, puuid);
    NSString *result = (NSString *)CFBridgingRelease(CFStringCreateCopy(NULL, uuidString));
    CFRelease(puuid);
    CFRelease(uuidString);
    return result;
}

- (NSError *)generateSalt:(NSString *)password {
    NSError *error;
    [self loadSalt:&error];
    if (error || !self.salt || [self.salt isEqualToString:@""]) {
        self.salt = [self generateUUID];
        // recovery status
        error = nil;
    }
    if (!self.salt || [self.salt isEqualToString:@""]) {
        error = [NSError errorWithDomain:VKeyChainService code:-1 userInfo:nil];
        return error;
    }
    
    [SAMKeychain setPassword:self.salt forService:VKeyChainService account:VKeyChainAccountSalt error:&error];
    if (error) {
        return error;
    }
    
    self.securePassword = [self generatePassword:password salt:self.salt error:&error];
    if (error) {
        return error;
    }
    return nil;
}

- (void)loadSalt:(NSError **)error {
    NSString *salt = [SAMKeychain passwordForService:VKeyChainService account:VKeyChainAccountSalt error:error];
    if (!error) {
        return;
    }
    if (!salt || [salt isEqualToString:@""]) {
        return;
    }
    self.salt = salt;
}

- (NSError *)saveToStorage {
    if (!self.salt || !self.securePassword) {
        return [NSError errorWithDomain:VKeyChainService code:-1 userInfo:nil];
    }
    
    NSDictionary *dict = @{
                           @"seed": self.seed,
                           @"accountSeeds": self.accountSeeds,
                           @"nonce": @(self.nonce),
                           @"api": @(VsysApi),
                           @"protocol": VsysProtocol,
                           @"network": self.network,
      };
    NSError *error;
    NSData *data;
    if (@available(iOS 11.0, *)) {
        data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingSortedKeys error:&error];
    } else {
        data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    }
    if (error) {
        NSLog(@"save wallet error: %@", error);
        return error;
    }
    
    NSData *encryptedData = VsysAesEncrypt(self.securePassword, data, &error);
    if (error || encryptedData.length <= 0) {
        NSLog(@"encrypt wallet data error: %@", error);
        return error;
    }

    [SAMKeychain setPasswordData:encryptedData forService:VKeyChainService account:VKeyChainAccount error:&error];

    if (error) {
        NSLog(@"save wallet data to dict error: %@", error);
        return error;
    }
    AppState.shareInstance.hasWallet = YES;
    return nil;
}

- (NSError *)logoutWallet {
    AppState.shareInstance.hasWallet = NO;
    AppState.shareInstance.autoBackupEnable = YES;
    AppState.shareInstance.connectionCheckEnable = YES;
    [self clearPropertyValue];
    return nil;
}

- (void)logoutWithoutDeleteWallet {
    AppState.shareInstance.hasWallet = NO;
    AppState.shareInstance.autoBackupEnable = YES;
    AppState.shareInstance.connectionCheckEnable = YES;
    [self clearPropertyValue];
}

- (void)clearPropertyValue {
    self.wallet = nil;
    self.seed = nil;
    self.network = nil;
    self.accounts = nil;
    self.accountSeeds = nil;
    self.nonce = 0;
    self.password = nil;
}

- (NSString *)network {
    if (!_network) {
        _network = NetworkTestnet;
    }
    return _network;
}

- (NSString *)networkDescription {
    if ([_network isEqualToString: NetworkMainnet]) {
        return VLocalize(@"network_mainnet");
    } else if ([_network isEqualToString: NetworkTestnet]) {
        return VLocalize(@"network_testnet");
    }
    return @"Unknown";
}

@end

@implementation VsysAccountEx

- (NSString*)signData:(NSData*)data{
    return  [self.account signData:data];
}

@end
