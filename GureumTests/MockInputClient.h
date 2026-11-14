//
//  MockInputClient.h
//  OSXTestApp
//
//  Created by Jeong YunWon on 13/01/2019.
//  Copyright © 2019 youknowone.org. All rights reserved.
//

@import Cocoa;
@import InputMethodKit;

NS_ASSUME_NONNULL_BEGIN

@interface MockInputClient : NSTextView<IMKTextInput, IMKUnicodeTextInput>

@property(nonatomic, readonly) NSArray<NSString *> *selectedInputModeRequests;

- (NSString *)markedString;
- (NSString *)selectedString;

@end

NS_ASSUME_NONNULL_END
