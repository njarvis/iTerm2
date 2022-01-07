//
//  PTYTriggerEvaluator.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 12/27/21.
//

#import "PTYTriggerEvaluator.h"

#import "DebugLogging.h"
#import "NSArray+iTerm.h"
#import "RegexKitLite.h"
#import "iTermAdvancedSettingsModel.h"
#import "iTermRateLimitedUpdate.h"
#import "iTermTextExtractor.h"

// Rate limit for checking instant (partial-line) triggers, in seconds.
static NSTimeInterval kMinimumPartialLineTriggerCheckInterval = 0.5;

// Trigger slowness detector event names.
NSString *const PTYSessionSlownessEventExecutel;
static NSString *const PTYSessionSlownessEventTriggers = @"triggers";
NSString *const PTYSessionSlownessEventExecute = @"execute";

@implementation PTYTriggerEvaluator {
    iTermRateLimitedUpdate *_idempotentTriggerRateLimit;
    BOOL _evaluating;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _triggerLineNumber = -1;
        _expect = [[iTermExpect alloc] initDry:NO];
        _triggersSlownessDetector = [[iTermSlownessDetector alloc] init];
    }
    return self;
}

- (void)clearTriggerLine {
    if ([_triggers count] || _expect.expectations.count) {
        [self checkTriggers];
        _triggerLineNumber = -1;
    }
}


- (void)checkTriggers {
    if (_triggerLineNumber == -1) {
        return;
    }

    long long startAbsLineNumber = 0;
    iTermStringLine *stringLine = [self.dataSource stringLineAsStringAtAbsoluteLineNumber:_triggerLineNumber
                                                                                 startPtr:&startAbsLineNumber];
    [self checkTriggersOnPartialLine:NO
                          stringLine:stringLine
                          lineNumber:startAbsLineNumber];
}

- (void)checkPartialLineTriggers {
    if (_triggerLineNumber == -1) {
        return;
    }
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - _lastPartialLineTriggerCheck < kMinimumPartialLineTriggerCheckInterval) {
        return;
    }
    _lastPartialLineTriggerCheck = now;
    long long startAbsLineNumber;
    iTermStringLine *stringLine = [self.dataSource stringLineAsStringAtAbsoluteLineNumber:_triggerLineNumber
                                                                                 startPtr:&startAbsLineNumber];
    [self checkTriggersOnPartialLine:YES
                          stringLine:stringLine
                          lineNumber:startAbsLineNumber];
}

- (void)checkTriggersOnPartialLine:(BOOL)partial
                        stringLine:(iTermStringLine *)stringLine
                        lineNumber:(long long)startAbsLineNumber {
    DLog(@"partial=%@ startAbsLineNumber=%@", @(partial), @(startAbsLineNumber));

    if (![self.delegate triggerEvaluatorShouldUseTriggers:self]) {
        DLog(@"Triggers disabled in interactive apps. Return early.");
        return;
    }

    [self reallyCheckTriggersOnPartialLine:partial
                                stringLine:stringLine
                                lineNumber:startAbsLineNumber
                        requireIdempotency:NO];
}


- (void)reallyCheckTriggersOnPartialLine:(BOOL)partial
                              stringLine:(iTermStringLine *)stringLine
                              lineNumber:(long long)startAbsLineNumber
                      requireIdempotency:(BOOL)requireIdempotency {
    if (_evaluating) {
        return;
    }
    _evaluating = YES;
    @try {
        for (iTermExpectation *expectation in [_expect.expectations copy]) {
            NSArray<NSString *> *capture = [stringLine.stringValue captureComponentsMatchedByRegex:expectation.regex];
            if (capture.count) {
                [expectation didMatchWithCaptureGroups:capture];
            }
        }

        NSArray<Trigger *> *triggers = _triggers;

        DLog(@"Start checking triggers");
        [_triggersSlownessDetector measureEvent:PTYSessionSlownessEventTriggers block:^{
            for (Trigger *trigger in triggers) {
                if (requireIdempotency && !trigger.isIdempotent) {
                    continue;
                }
                BOOL stop = [trigger tryString:stringLine
                                     inSession:self.delegate
                                   partialLine:partial
                                    lineNumber:startAbsLineNumber
                              useInterpolation:_triggerParametersUseInterpolatedStrings];
                if (stop || self.sessionExited || (_triggers != triggers)) {
                    break;
                }
            }
        }];
        [self maybeWarnAboutSlowTriggers];
        DLog(@"Finished checking triggers");
    }
    @finally {
        // I don't expect an exception but I do want to make sure an early return added in the
        // future doesn't prevent me from resetting this.
        _evaluating = NO;
    }
}

- (void)maybeWarnAboutSlowTriggers {
    if (!_triggersSlownessDetector.enabled) {
        return;
    }
    NSDictionary<NSString *, NSNumber *> *dist = [_triggersSlownessDetector timeDistribution];
    const NSTimeInterval totalTime = _triggersSlownessDetector.timeSinceReset;
    if (totalTime > 1) {
        const NSTimeInterval timeInTriggers = [dist[PTYSessionSlownessEventTriggers] doubleValue] / totalTime;
        const NSTimeInterval timeExecuting = [dist[PTYSessionSlownessEventExecute] doubleValue] / totalTime;
        DLog(@"For session %@ time executing=%@ time in triggers=%@", self, @(timeExecuting), @(timeInTriggers));
        if (timeInTriggers > timeExecuting * 0.5 && (timeExecuting + timeInTriggers) > 0.1) {
            // We were CPU bound for at least 10% of the sample time and
            // triggers were at least half as expensive as token execution.
            [self.delegate triggerEvaluatorOfferToDisableTriggersInInteractiveApps:self];
        }
        [_triggersSlownessDetector reset];
    }
}

- (void)appendStringToTriggerLine:(NSString *)s {
    if (_triggerLineNumber == -1) {
        _triggerLineNumber = _dataSource.numberOfScrollbackLines + _dataSource.cursorY - 1 + _dataSource.totalScrollbackOverflow;
    }

    // We used to build up the string so you could write triggers that included bells. That doesn't
    // really make sense, especially in the new model, but it's so useful to be able to customize
    // the bell that I'll add this special case.
    if ([s isEqualToString:@"\a"]) {
        iTermStringLine *stringLine = [iTermStringLine stringLineWithString:s];
        [self checkTriggersOnPartialLine:YES stringLine:stringLine lineNumber:_triggerLineNumber];
    }
}

- (void)loadFromProfileArray:(NSArray *)array {
#warning TODO: This causes state loss, such as _disabled in the alert trigger. Avoid replacing unchanged trigges.
    _triggers = [array mapWithBlock:^Trigger *(NSDictionary *triggerDict) {
        return [Trigger triggerFromDict:triggerDict];
    }];
}

- (void)checkIdempotentTriggersIfAllowed {
    if (![self.delegate triggerEvaluatorShouldUseTriggers:self] && [iTermAdvancedSettingsModel allowIdempotentTriggers]) {
        const NSTimeInterval interval = [iTermAdvancedSettingsModel idempotentTriggerModeRateLimit];
        if (!_idempotentTriggerRateLimit) {
            _idempotentTriggerRateLimit = [[iTermRateLimitedUpdate alloc] initWithName:@"idempotent triggers"
                                                                       minimumInterval:interval];
        } else {
            _idempotentTriggerRateLimit.minimumInterval = interval;
        }
        __weak __typeof(self) weakSelf = self;
        [_idempotentTriggerRateLimit performRateLimitedBlock:^{
            [weakSelf checkIdempotentTriggers];
        }];
    }
}

- (void)checkIdempotentTriggers {
    DLog(@"%@", self);
    if (!_shouldUpdateIdempotentTriggers) {
        DLog(@"Don't need to update idempotent triggers");
        return;
    }
    _shouldUpdateIdempotentTriggers = NO;
    iTermTextExtractor *extractor = [[iTermTextExtractor alloc] initWithDataSource:self.dataSource];
    DLog(@"Check idempotent triggers from line number %@", @(self.dataSource.numberOfScrollbackLines));
    [extractor enumerateWrappedLinesIntersectingRange:VT100GridRangeMake(self.dataSource.numberOfScrollbackLines, self.dataSource.height) block:
     ^(iTermStringLine *stringLine, VT100GridWindowedRange range, BOOL *stop) {
        [self reallyCheckTriggersOnPartialLine:NO
                                    stringLine:stringLine
                                    lineNumber:range.coordRange.start.y + self.dataSource.totalScrollbackOverflow
                            requireIdempotency:YES];
    }];
}

- (void)invalidateIdempotentTriggers {
    _shouldUpdateIdempotentTriggers = YES;
}

- (void)appendAsciiDataToCurrentLine:(AsciiData *)asciiData {
    if (![_triggers count] && !_expect.expectations.count) {
        return;
    }
    NSString *string = [[NSString alloc] initWithBytes:asciiData->buffer
                                                length:asciiData->length
                                              encoding:NSASCIIStringEncoding];
    [self appendStringToTriggerLine:string];

}

- (void)forceCheck {
    _lastPartialLineTriggerCheck = 0;
    [self clearTriggerLine];
}

- (NSIndexSet *)enabledTriggerIndexes {
    return [_triggers it_indexSetWithObjectsPassingTest:^BOOL(Trigger *trigger) {
        return !trigger.disabled;
    }];
}

@end
