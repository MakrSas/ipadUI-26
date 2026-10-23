#import <Foundation/Foundation.h>

// Logs to the system log with the [iPadUI26] prefix and appends the same line to
// PULogPath(), which the settings can show without a Mac. Sandboxed apps cannot write
// the file, so their lines only reach the system log.
void PULog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
NSString *PULogPath(void);
