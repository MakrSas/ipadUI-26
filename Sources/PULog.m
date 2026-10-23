#import "PULog.h"
#import <rootless.h>

static const unsigned long long PULogMaxSize = 512 * 1024;

NSString *PULogPath(void) {
	return ROOT_PATH_NS(@"/var/mobile/Library/Logs/iPadUI26.log");
}

static void PUAppendToFile(NSString *line) {
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("com.makrsas.ipadui26.log", DISPATCH_QUEUE_SERIAL);
	});
	dispatch_async(queue, ^{
		NSString *path = PULogPath();
		NSFileManager *manager = NSFileManager.defaultManager;
		NSDictionary *attributes = [manager attributesOfItemAtPath:path error:nil];
		if (!attributes || attributes.fileSize > PULogMaxSize) {
			[manager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
			[NSData.data writeToFile:path atomically:YES];
		}
		NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
		if (!handle) return;
		[handle seekToEndOfFile];
		[handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
		[handle closeFile];
	});
}

void PULog(NSString *format, ...) {
	va_list args;
	va_start(args, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	NSLog(@"[iPadUI26] %@", message);

	static NSDateFormatter *formatter;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		formatter = [NSDateFormatter new];
		formatter.dateFormat = @"HH:mm:ss";
	});
	NSString *process = NSProcessInfo.processInfo.processName;
	PUAppendToFile([NSString stringWithFormat:@"%@ %@: %@\n", [formatter stringFromDate:[NSDate date]], process, message]);
}
