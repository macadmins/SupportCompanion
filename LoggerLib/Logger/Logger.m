//
//  Logger.m
//  Logger
//
//  Created by Tobias on 2024-05-02.
//

#import "Logger.h"

@implementation LoggerHelper
+ (void)logWithSubsystem:(NSString *)subsystem category:(NSString *)category message:(NSString *)message severity:(int)severity {
    os_log_t log = os_log_create([subsystem UTF8String], [category UTF8String]);

    switch (severity) {
        case 0:
            os_log_info(log, "%{public}s", [message UTF8String]);
            break;
        case 1:
            os_log_debug(log, "%{public}s", [message UTF8String]);
            break;
        case 2:
            os_log_error(log, "%{public}s", [message UTF8String]);
            break;
        case 3:
            os_log_fault(log, "%{public}s", [message UTF8String]);
            break;
        default:
            os_log(log, "%{public}s", [message UTF8String]);
            break;
    }
}
@end

__attribute__((visibility("default"))) void LogWithSubsystem(const char* subsystem, const char* category, const char* message, int severity) {
    [LoggerHelper logWithSubsystem:[NSString stringWithUTF8String:subsystem] category:[NSString stringWithUTF8String:category] message:[NSString stringWithUTF8String:message] severity:severity];
}
