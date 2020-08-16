//
//  NSCrashCollect.m
//  gitLab实验
//
//  Created by 老玩童－赵永斐 on 2020/7/26.
//  Copyright © 2020 老顽童－赵永斐. All rights reserved.
//--收集崩溃

#import "NSCrashCollect.h"
//#import <execinfo.h>
static NSUncaughtExceptionHandler *crashCollect = NULL;

typedef void(*SignalHandler)(int signal, siginfo_t *info, void *context);
//signal崩溃
static SignalHandler previousABRTSignalHandler = NULL;
static SignalHandler previousBUSSignalHandler = NULL;
static SignalHandler previousFPESignalHandler = NULL;
static SignalHandler previousILLSignalHandler = NULL;
static SignalHandler previousPIPESignalHandler = NULL;
static SignalHandler previousSEGVSignalHandler = NULL;
static SignalHandler previousSYSSignalHandler = NULL;
static SignalHandler previousTRAPSignalHandler = NULL;

@implementation NSCrashCollect

+ (void)registerCrashCollect {
    [self registerExceptionHander];
   
    
    [self registerSignalHander];
}

#pragma mark -- 抓捕app内 常用崩溃
//注册app异常 崩溃
+ (void)registerExceptionHander {
    //获取别人注册的handler
       crashCollect = NSGetUncaughtExceptionHandler();
       //抓获的是
       NSSetUncaughtExceptionHandler(&cachCrrash);
}

static void cachCrrash(NSException *exception) {
    
    // 异常的堆栈信息
       NSArray *stackArray = [exception callStackSymbols];
       // 出现异常的原因
       NSString * reason = [exception reason];
       // 异常名称
       NSString * name = [exception name];
       
       NSString * exceptionInfo = [NSString stringWithFormat:@"========uncaughtException异常错误报告========\nname:%@\nreason:\n%@\ncallStackSymbols:\n%@", name, reason, [stackArray componentsJoinedByString:@"\n"]];
       
    NSLog(@"%@",exceptionInfo);
       //在自己handler处理完后自觉把别人的handler注册回去，规规矩矩的传递
       if (crashCollect) {
           crashCollect(exception);
       }
       
       // 杀掉程序，这样可以防止同时抛出的SIGABRT被SignalException捕获
       kill(getpid(), SIGKILL);
}

#pragma mark -- 注册signal信号 崩溃
+ (void)registerSignalHander {
    //获取别人的注册的handle
    [self backupOrigimalHandler];
    
    //获取别人的注册的handle
    [self signalRegister];
}


//获取别人的注册的handle
+ (void)backupOrigimalHandler {
    struct sigaction old_action_abrt;
    sigaction(SIGABRT, NULL, &old_action_abrt);
    if (old_action_abrt.sa_sigaction) {
        previousABRTSignalHandler = old_action_abrt.sa_sigaction;
    }
    
    struct sigaction old_action_bus;
    sigaction(SIGBUS, NULL, &old_action_bus);
    if (old_action_bus.sa_sigaction) {
        previousBUSSignalHandler = old_action_bus.sa_sigaction;
    }
    
    struct sigaction old_action_fpe;
    sigaction(SIGFPE, NULL, &old_action_fpe);
    if (old_action_fpe.sa_sigaction) {
        previousFPESignalHandler = old_action_fpe.sa_sigaction;
    }
    
    struct sigaction old_action_ill;
    sigaction(SIGILL, NULL, &old_action_ill);
    if (old_action_ill.sa_sigaction) {
        previousILLSignalHandler = old_action_ill.sa_sigaction;
    }
    
    struct sigaction old_action_pipe;
    sigaction(SIGPIPE, NULL, &old_action_pipe);
    if (old_action_pipe.sa_sigaction) {
        previousPIPESignalHandler = old_action_pipe.sa_sigaction;
    }
    
    struct sigaction old_action_segv;
    sigaction(SIGSEGV, NULL, &old_action_segv);
    if (old_action_segv.sa_sigaction) {
        previousSEGVSignalHandler = old_action_segv.sa_sigaction;
    }
    
    struct sigaction old_action_sys;
    sigaction(SIGSYS, NULL, &old_action_sys);
    if (old_action_sys.sa_sigaction) {
        previousSYSSignalHandler = old_action_sys.sa_sigaction;
    }
    
    struct sigaction old_action_trap;
    sigaction(SIGTRAP, NULL, &old_action_trap);
    if (old_action_trap.sa_sigaction) {
        previousTRAPSignalHandler = old_action_trap.sa_sigaction;
    }
}

+ (void)signalRegister {
    NWSignalRegister(SIGABRT);
    NWSignalRegister(SIGBUS);
    NWSignalRegister(SIGFPE);
    NWSignalRegister(SIGILL);
    NWSignalRegister(SIGPIPE);
    NWSignalRegister(SIGSEGV);
    NWSignalRegister(SIGSYS);
    NWSignalRegister(SIGTRAP);
}

static void NWSignalRegister(int signal) {
    struct sigaction action;
    action.sa_sigaction = NWSignalHandler;
    action.sa_flags = SA_NODEFER | SA_SIGINFO;
    sigemptyset(&action.sa_mask);
    sigaction(signal, &action, 0);
}


static void NWSignalHandler(int signal, siginfo_t* info, void* context) {
    NSMutableString *mstr = [[NSMutableString alloc] init];
    [mstr appendString:@"Signal Exception:\n"];
    [mstr appendString:[NSString stringWithFormat:@"Signal %@ was raised.\n", signalName(signal)]];
    [mstr appendString:@"Call Stack:\n"];
    
    // 这里过滤掉第一行日志
    // 因为注册了信号崩溃回调方法，系统会来调用，将记录在调用堆栈上，因此此行日志需要过滤掉
    for (NSUInteger index = 1; index < NSThread.callStackSymbols.count; index++) {
        NSString *str = [NSThread.callStackSymbols objectAtIndex:index];
        [mstr appendString:[str stringByAppendingString:@"\n"]];
    }
    
    [mstr appendString:@"threadInfo:\n"];
    [mstr appendString:[[NSThread currentThread] description]];
    
    // 保存崩溃日志到沙盒cache目录
//    [NWCrashTool saveCrashLog:[NSString stringWithString:mstr] fileName:@"Crash(Signal)"];
    
    NSLog(@"%@",mstr);
    NWClearSignalRegister();
    
    // 调用之前崩溃的回调函数
    // 在自己handler处理完后自觉把别人的handler注册回去，规规矩矩的传递
    previousSignalHandler(signal, info, context);
    
    kill(getpid(), SIGKILL);
}

#pragma mark -- 获取名字
static NSString *signalName(int signal) {
    NSString *signalName;
    switch (signal) {
        case SIGABRT:
            signalName = @"SIGABRT";
            break;
        case SIGBUS:
            signalName = @"SIGBUS";
            break;
        case SIGFPE:
            signalName = @"SIGFPE";
            break;
        case SIGILL:
            signalName = @"SIGILL";
            break;
        case SIGPIPE:
            signalName = @"SIGPIPE";
            break;
        case SIGSEGV:
            signalName = @"SIGSEGV";
            break;
        case SIGSYS:
            signalName = @"SIGSYS";
            break;
        case SIGTRAP:
            signalName = @"SIGTRAP";
            break;
        default:
            break;
    }
    return signalName;
}

//在自己handler处理完后自觉把别人的handler注册回去，规规矩矩的传递
static void previousSignalHandler(int signal, siginfo_t *info, void *context) {
    SignalHandler previousSignalHandler = NULL;
    switch (signal) {
        case SIGABRT:
            previousSignalHandler = previousABRTSignalHandler;
            break;
        case SIGBUS:
            previousSignalHandler = previousBUSSignalHandler;
            break;
        case SIGFPE:
            previousSignalHandler = previousFPESignalHandler;
            break;
        case SIGILL:
            previousSignalHandler = previousILLSignalHandler;
            break;
        case SIGPIPE:
            previousSignalHandler = previousPIPESignalHandler;
            break;
        case SIGSEGV:
            previousSignalHandler = previousSEGVSignalHandler;
            break;
        case SIGSYS:
            previousSignalHandler = previousSYSSignalHandler;
            break;
        case SIGTRAP:
            previousSignalHandler = previousTRAPSignalHandler;
            break;
        default:
            break;
    }
    
    if (previousSignalHandler) {
        previousSignalHandler(signal, info, context);
    }
}

static void NWClearSignalRegister() {
    signal(SIGSEGV,SIG_DFL);
    signal(SIGFPE,SIG_DFL);
    signal(SIGBUS,SIG_DFL);
    signal(SIGTRAP,SIG_DFL);
    signal(SIGABRT,SIG_DFL);
    signal(SIGILL,SIG_DFL);
    signal(SIGPIPE,SIG_DFL);
    signal(SIGSYS,SIG_DFL);
}

@end
