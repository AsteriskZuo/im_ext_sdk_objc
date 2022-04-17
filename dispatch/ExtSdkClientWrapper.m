//
//  ExtSdkClientWrapper.m
//
//
//  Created by 杜洁鹏 on 2019/10/8.
//

#import "ExtSdkClientWrapper.h"
#import "ExtSdkChatManagerWrapper.h"
#import "ExtSdkChatroomManagerWrapper.h"
#import "ExtSdkContactManagerWrapper.h"
#import "ExtSdkConversationWrapper.h"
#import "ExtSdkGroupManagerWrapper.h"
#import "ExtSdkMethodTypeObjc.h"
#import "ExtSdkPushManagerWrapper.h"
#import "ExtSdkThreadUtilObjc.h"
#import "ExtSdkToJson.h"
#import "ExtSdkUserInfoManagerWrapper.h"
#import <UserNotifications/UserNotifications.h>

@interface ExtSdkClientWrapper () <EMClientDelegate, EMMultiDevicesDelegate>
@end

@implementation ExtSdkClientWrapper

+ (nonnull instancetype)getInstance {
    static ExtSdkClientWrapper *instance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
      instance = [[ExtSdkClientWrapper alloc] init];
    });
    return instance;
}

#pragma mark - Actions

- (void)getToken:(NSDictionary *)param
          result:(nonnull id<ExtSdkCallbackObjc>)result {
    [self onResult:result
        withMethodType:ExtSdkMethodKeyGetToken
             withError:nil
            withParams:EMClient.sharedClient.accessUserToken];
}

- (void)initSDKWithDict:(NSDictionary *)param
                 result:(nonnull id<ExtSdkCallbackObjc>)result {

    EMOptions *options = [EMOptions fromJsonObject:param];
    if (nil == options) {
        EMError *e = [EMError errorWithDescription:@"params parse error." code:1];
        [self onResult:result withMethodType:ExtSdkMethodKeyInit withError:e withParams:nil];
        return;
    }
    //    options.enableConsoleLog = YES;
    [EMClient.sharedClient initializeSDKWithOptions:options];
    [EMClient.sharedClient removeDelegate:self];
    [EMClient.sharedClient addDelegate:self delegateQueue:nil];
    [EMClient.sharedClient removeMultiDevicesDelegate:self];
    [EMClient.sharedClient addMultiDevicesDelegate:self delegateQueue:nil];
    
    [ExtSdkChatManagerWrapper.getInstance initSdk];

    // 如果有证书名，说明要使用Apns
    if (options.apnsCertName.length > 0) {
        [self _registerAPNs];
    }
    [self onResult:result
        withMethodType:ExtSdkMethodKeyInit
             withError:nil
            withParams:nil];
}

- (void)createAccount:(NSDictionary *)param
               result:(nonnull id<ExtSdkCallbackObjc>)result {
    __weak typeof(self) weakSelf = self;
    NSString *username = param[@"username"];
    NSString *password = param[@"password"];
    [EMClient.sharedClient
        registerWithUsername:username
                    password:password
                  completion:^(NSString *aUsername, EMError *aError) {
                    [weakSelf onResult:result
                        withMethodType:ExtSdkMethodKeyCreateAccount
                             withError:aError
                            withParams:aUsername];
                  }];
}

- (void)login:(NSDictionary *)param
       result:(nonnull id<ExtSdkCallbackObjc>)result {
    __weak typeof(self) weakSelf = self;
    NSString *username = param[@"username"];
    NSString *pwdOrToken = param[@"pwdOrToken"];
    BOOL isPwd = [param[@"isPassword"] boolValue];

    if (isPwd) {
        [EMClient.sharedClient
            loginWithUsername:username
                     password:pwdOrToken
                   completion:^(NSString *aUsername, EMError *aError) {
                     [weakSelf onResult:result
                         withMethodType:ExtSdkMethodKeyLogin
                              withError:aError
                             withParams:@{
                                 @"username" : aUsername,
                                 @"token" :
                                     EMClient.sharedClient.accessUserToken
                             }];
                   }];
    } else {
        [EMClient.sharedClient
            loginWithUsername:username
                        token:pwdOrToken
                   completion:^(NSString *aUsername, EMError *aError) {
                     [weakSelf onResult:result
                         withMethodType:ExtSdkMethodKeyLogin
                              withError:aError
                             withParams:@{
                                 @"username" : aUsername,
                                 @"token" :
                                     EMClient.sharedClient.accessUserToken
                             }];
                   }];
    }
}

- (void)logout:(NSDictionary *)param
        result:(nonnull id<ExtSdkCallbackObjc>)result {
    __weak typeof(self) weakSelf = self;
    BOOL unbindToken = [param[@"unbindToken"] boolValue];
    [EMClient.sharedClient logout:unbindToken
                       completion:^(EMError *aError) {
                         [weakSelf onResult:result
                             withMethodType:ExtSdkMethodKeyLogout
                                  withError:aError
                                 withParams:@(!aError)];
                       }];
}

- (void)changeAppKey:(NSDictionary *)param
              result:(nonnull id<ExtSdkCallbackObjc>)result {
    NSString *appKey = param[@"appKey"];
    EMError *aError = [EMClient.sharedClient changeAppkey:appKey];
    [self onResult:result
        withMethodType:ExtSdkMethodKeyChangeAppKey
             withError:aError
            withParams:@(!aError)];
}

- (void)getCurrentUser:(NSDictionary *)param
                result:(nonnull id<ExtSdkCallbackObjc>)result {
    NSString *username = EMClient.sharedClient.currentUsername;
    [self onResult:result
        withMethodType:ExtSdkMethodKeyGetCurrentUser
             withError:nil
            withParams:username];
}

- (void)uploadLog:(NSDictionary *)param
           result:(nonnull id<ExtSdkCallbackObjc>)result {
    __weak typeof(self) weakSelf = self;
    [EMClient.sharedClient
        uploadDebugLogToServerWithCompletion:^(EMError *aError) {
          [weakSelf onResult:result
              withMethodType:ExtSdkMethodKeyUploadLog
                   withError:aError
                  withParams:nil];
        }];
}

- (void)compressLogs:(NSDictionary *)param
              result:(nonnull id<ExtSdkCallbackObjc>)result {
    __weak typeof(self) weakSelf = self;
    [EMClient.sharedClient
        getLogFilesPathWithCompletion:^(NSString *aPath, EMError *aError) {
          [weakSelf onResult:result
              withMethodType:ExtSdkMethodKeyCompressLogs
                   withError:aError
                  withParams:aPath];
        }];
}

- (void)kickDevice:(NSDictionary *)param
            result:(nonnull id<ExtSdkCallbackObjc>)result {
    __weak typeof(self) weakSelf = self;
    NSString *username = param[@"username"];
    NSString *password = param[@"password"];
    NSString *resource = param[@"resource"];

    [EMClient.sharedClient
        kickDeviceWithUsername:username
                      password:password
                      resource:resource
                    completion:^(EMError *aError) {
                      [weakSelf onResult:result
                          withMethodType:ExtSdkMethodKeyKickDevice
                               withError:aError
                              withParams:nil];
                    }];
}

- (void)kickAllDevices:(NSDictionary *)param
                result:(nonnull id<ExtSdkCallbackObjc>)result {
    __weak typeof(self) weakSelf = self;
    NSString *username = param[@"username"];
    NSString *password = param[@"password"];
    [EMClient.sharedClient
        kickAllDevicesWithUsername:username
                          password:password
                        completion:^(EMError *aError) {
                          [weakSelf onResult:result
                              withMethodType:ExtSdkMethodKeyKickAllDevices
                                   withError:aError
                                  withParams:nil];
                        }];
}

- (void)isLoggedInBefore:(NSDictionary *)param
                  result:(nonnull id<ExtSdkCallbackObjc>)result {
    [self onResult:result
        withMethodType:ExtSdkMethodKeyIsLoggedInBefore
             withError:nil
            withParams:@(EMClient.sharedClient.isLoggedIn)];
}

- (void)onMultiDeviceEvent:(NSDictionary *)param
                    result:(nonnull id<ExtSdkCallbackObjc>)result {
}

- (void)getLoggedInDevicesFromServer:(NSDictionary *)param
                              result:(nonnull id<ExtSdkCallbackObjc>)result {
    __weak typeof(self) weakSelf = self;
    NSString *username = param[@"username"];
    NSString *password = param[@"password"];
    [EMClient.sharedClient
        getLoggedInDevicesFromServerWithUsername:username
                                        password:password
                                      completion:^(NSArray *aList,
                                                   EMError *aError) {
                                        NSMutableArray *list =
                                            [NSMutableArray array];
                                        for (EMDeviceConfig
                                                 *deviceInfo in aList) {
                                            [list addObject:[deviceInfo
                                                                toJsonObject]];
                                        }

                                        [weakSelf onResult:result
                                            withMethodType:
                                                ExtSdkMethodKeyGetLoggedInDevicesFromServer
                                                 withError:aError
                                                withParams:nil];
                                      }];
}

- (void)loginWithAgoraToken:(NSDictionary *)param
                     result:(nonnull id<ExtSdkCallbackObjc>)result {
    __weak typeof(self) weakSelf = self;
    NSString *username = param[@"username"];
    NSString *agoraToken = param[@"agoratoken"];
    [EMClient.sharedClient
        loginWithUsername:username
               agoraToken:agoraToken
               completion:^(NSString *aUsername, EMError *aError) {
                 [weakSelf onResult:result
                     withMethodType:ExtSdkMethodKeyLoginWithAgoraToken
                          withError:aError
                         withParams:@{
                             @"username" : aUsername,
                             @"token" : EMClient.sharedClient.accessUserToken
                         }];
               }];
}

- (void)isConnected:(NSDictionary *)param
             result:(nonnull id<ExtSdkCallbackObjc>)result {
    [self onResult:result
        withMethodType:ExtSdkMethodKeyIsConnected
             withError:nil
            withParams:@(EMClient.sharedClient.isConnected)];
}

#pragma - mark EMClientDelegate

- (void)connectionStateDidChange:(EMConnectionState)aConnectionState {
    BOOL isConnected = aConnectionState == EMConnectionConnected;
    if (isConnected) {
        [self onConnected];
    } else {
        [self onDisconnected:2]; // 需要明确具体的code
    }
}

- (void)autoLoginDidCompleteWithError:(EMError *)aError {
    if (aError) {
        [self onDisconnected:1]; // 需要明确具体的code
    } else {
        [self onConnected];
    }
}

- (void)userAccountDidLoginFromOtherDevice {
    [self onDisconnected:206];
}

- (void)userAccountDidRemoveFromServer {
    [self onDisconnected:207];
}

- (void)userDidForbidByServer {
    [self onDisconnected:305];
}

- (void)userAccountDidForcedToLogout:(EMError *)aError {
    [self onDisconnected:1]; // 需要明确具体的code
}

// 声网token即将过期
- (void)tokenWillExpire:(int)aErrorCode {
    [self onReceive:ExtSdkMethodKeyOnTokenWillExpire withParams:nil];
}

// 声网token过期
- (void)tokenDidExpire:(int)aErrorCode {
    [self onReceive:ExtSdkMethodKeyOnTokenDidExpire withParams:nil];
}

#pragma mark - EMMultiDevicesDelegate

- (void)multiDevicesContactEventDidReceive:(EMMultiDevicesEvent)aEvent
                                  username:(NSString *)aUsername
                                       ext:(NSString *)aExt {
}

- (void)multiDevicesGroupEventDidReceive:(EMMultiDevicesEvent)aEvent
                                 groupId:(NSString *)aGroupId
                                     ext:(id)aExt {
}

#pragma mark - Merge Android and iOS Method
- (void)onConnected {
    [self onReceive:ExtSdkMethodKeyOnConnected
         withParams:@{@"connected" : @(YES)}];
}

- (void)onDisconnected:(int)errorCode {
    [self onReceive:ExtSdkMethodKeyOnDisconnected
         withParams:@{@"errorCode" : @(errorCode)}];
}

#pragma mark - register APNs
- (void)_registerAPNs {
    [ExtSdkThreadUtilObjc mainThreadExecute:^{
      UIApplication *application = [UIApplication sharedApplication];
      application.applicationIconBadgeNumber = 0;

      if (NSClassFromString(@"UNUserNotificationCenter")) {
          //        [UNUserNotificationCenter
          //        currentNotificationCenter].delegate = self;
          [[UNUserNotificationCenter currentNotificationCenter]
              requestAuthorizationWithOptions:UNAuthorizationOptionBadge |
                                              UNAuthorizationOptionSound |
                                              UNAuthorizationOptionAlert
                            completionHandler:^(BOOL granted, NSError *error) {
                              if (granted) {
#if !TARGET_IPHONE_SIMULATOR
                                  [ExtSdkThreadUtilObjc mainThreadExecute:^{
                                    [application
                                        registerForRemoteNotifications];
                                  }];

#endif
                              }
                            }];
          return;
      }

      if ([application respondsToSelector:@selector
                       (registerUserNotificationSettings:)]) {
          UIUserNotificationType notificationTypes =
              UIUserNotificationTypeBadge | UIUserNotificationTypeSound |
              UIUserNotificationTypeAlert;
          UIUserNotificationSettings *settings =
              [UIUserNotificationSettings settingsForTypes:notificationTypes
                                                categories:nil];
          [application registerUserNotificationSettings:settings];
      }

#if !TARGET_IPHONE_SIMULATOR
      if ([application
              respondsToSelector:@selector(registerForRemoteNotifications)]) {
          [application registerForRemoteNotifications];
      }
#endif
    }];
}

#pragma mark - AppDelegate

//- (BOOL)application:(UIApplication *)application
// didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
//
//    return YES;
//}
//
//- (void)applicationDidBecomeActive:(UIApplication *)application {
//
//}

@end
