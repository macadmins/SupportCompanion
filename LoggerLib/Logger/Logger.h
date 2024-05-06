//
//  Logger.h
//  Logger
//
//  Created by Tobias on 2024-05-02.
//

#import <Foundation/Foundation.h>
#import <os/log.h>

@interface LoggerHelper : NSObject
+ (void)logWithSubsystem:(NSString *)subsystem category:(NSString *)category message:(NSString *)message;
@end
