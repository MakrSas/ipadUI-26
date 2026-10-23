#import "PUPreviewCell.h"
#import "PUPreviews.h"
#import <Preferences/PSSpecifier.h>

@implementation PUPreviewCell {
	PUPreviewView *_preview;
	CGFloat _height;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier])) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		_height = [[specifier propertyForKey:@"height"] doubleValue] ?: 220;
		_preview = [PUPreviewView previewForKind:[specifier propertyForKey:@"pu_preview"]];
		_preview.frame = self.contentView.bounds;
		_preview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.contentView addSubview:_preview];
	}
	return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width {
	return _height;
}

@end
