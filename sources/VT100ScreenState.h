//
//  VT100ScreenState.h
//  iTerm2SharedARC
//
//  Created by George Nachman on 12/10/21.
//
// All state from VT100Screen should eventually migrate here to facilitate a division between
// mutable and immutable code paths.

#import <Foundation/Foundation.h>

#import "IntervalTree.h"
#import "VT100Grid.h"
#import "VT100Terminal.h"

NS_ASSUME_NONNULL_BEGIN

@class IntervalTree;
@class VT100InlineImageHelper;
@class iTermOrderEnforcer;

@protocol VT100ScreenState<NSObject>

@property (nonatomic, readonly) BOOL audibleBell;
@property (nonatomic, readonly) BOOL showBellIndicator;
@property (nonatomic, readonly) BOOL flashBell;
@property (nonatomic, readonly) BOOL postUserNotifications;
@property (nonatomic, readonly) BOOL cursorBlinks;

// When set, strings, newlines, and linefeeds are appended to printBuffer_. When ANSICSI_PRINT
// with code 4 is received, it's sent for printing.
@property (nonatomic, readonly) BOOL collectInputForPrinting;

@property (nullable, nonatomic, strong, readonly) NSString *printBuffer;

// OK to report window title?
@property (nonatomic, readonly) BOOL allowTitleReporting;

@property (nonatomic, readonly) NSTimeInterval lastBell;

// Line numbers containing animated GIFs that need to be redrawn for the next frame.
@property (nonatomic, strong, readonly) NSIndexSet *animatedLines;

// base64 value to copy to pasteboard, being built up bit by bit.
@property (nullable, nonatomic, strong, readonly) NSString *pasteboardString;

// All currently visible marks and notes. Maps an interval of
//   (startx + absstarty * (width+1)) to (endx + absendy * (width+1))
// to an id<IntervalTreeObject>, which is either PTYNoteViewController or VT100ScreenMark.
@property (nonatomic, strong, readonly) id<IntervalTreeReading> intervalTree;

@property (nonatomic, strong, readonly) id<VT100GridReading> primaryGrid;
@property (nullable, nonatomic, strong, readonly) id<VT100GridReading> altGrid;
// Points to either primaryGrid or altGrid.
@property (nonatomic, strong, readonly) id<VT100GridReading> currentGrid;
// When a saved grid is swapped in, this is the live current grid.
@property (nonatomic, strong, readonly) id<VT100GridReading> realCurrentGrid;

// Holds notes on alt/primary grid (the one we're not in). The origin is the top-left of the
// grid.
@property (nullable, nonatomic, strong, readonly) IntervalTree *savedIntervalTree;

// Cached copies of terminal attributes
@property (nonatomic, readonly) BOOL wraparoundMode;
@property (nonatomic, readonly) BOOL ansi;
@property (nonatomic, readonly) BOOL insert;

// This flag overrides maxScrollbackLines:
@property (nonatomic, readonly) BOOL unlimitedScrollback;

@property (nonatomic, strong, readonly) VT100Terminal *terminal;
@end

@interface VT100ScreenMutableState: NSObject<VT100ScreenState, NSCopying>

@property (nonatomic, readwrite) BOOL audibleBell;
@property (nonatomic, readwrite) BOOL showBellIndicator;
@property (nonatomic, readwrite) BOOL flashBell;
@property (nonatomic, readwrite) BOOL postUserNotifications;
@property (nonatomic, readwrite) BOOL cursorBlinks;
@property (nonatomic, readwrite) BOOL collectInputForPrinting;
@property (nullable, nonatomic, strong, readwrite) NSMutableString *printBuffer;
@property (nonatomic, readwrite) BOOL allowTitleReporting;
@property (nullable, nonatomic, strong) VT100InlineImageHelper *inlineImageHelper;
@property (nonatomic, readwrite) NSTimeInterval lastBell;
@property (nonatomic, strong, readwrite) NSMutableIndexSet *animatedLines;
@property (nullable, nonatomic, strong, readwrite) NSMutableString *pasteboardString;
@property (nonatomic, strong, readwrite) iTermOrderEnforcer *setWorkingDirectoryOrderEnforcer;
@property (nonatomic, strong, readwrite) iTermOrderEnforcer *currentDirectoryDidChangeOrderEnforcer;
@property (nonatomic, strong, readwrite) IntervalTree *intervalTree;

@property (nonatomic, strong, readwrite) VT100Grid *primaryGrid;
@property (nullable, nonatomic, strong, readwrite) VT100Grid *altGrid;
@property (nonatomic, strong, readwrite) VT100Grid *currentGrid;
// When a saved grid is swapped in, this is the live current grid.
@property (nullable, nonatomic, strong, readwrite) VT100Grid *realCurrentGrid;
@property (nullable, nonatomic, strong, readwrite) IntervalTree *savedIntervalTree;
@property (nonatomic, strong, readwrite) VT100Terminal *terminal;
@property (nonatomic, readwrite) BOOL wraparoundMode;
@property (nonatomic, readwrite) BOOL ansi;
@property (nonatomic, readwrite) BOOL insert;
@property (nonatomic, readwrite) BOOL unlimitedScrollback;

- (id<VT100ScreenState>)copy;

@end

NS_ASSUME_NONNULL_END