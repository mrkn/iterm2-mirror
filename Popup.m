// -*- mode:objc -*-
/*
 **  Popup.m
 **
 **  Copyright 20101
 **
 **  Author: George Nachman
 **
 **  Project: iTerm2
 **
 **  Description: Base classes for popup windows like autocomplete and
 **  pasteboardhistory.
 **
 **  This program is free software; you can redistribute it and/or modify
 **  it under the terms of the GNU General Public License as published by
 **  the Free Software Foundation; either version 2 of the License, or
 **  (at your option) any later version.
 **
 **  This program is distributed in the hope that it will be useful,
 **  but WITHOUT ANY WARRANTY; without even the implied warranty of
 **  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 **  GNU General Public License for more details.
 **
 **  You should have received a copy of the GNU General Public License
 **  along with this program; if not, write to the Free Software
 **  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#import "Popup.h"
#import "VT100Screen.h"
#import "PTYTextView.h"
#include <wctype.h>

@implementation PopupEntry

+ (PopupEntry*)entryWithString:(NSString*)s score:(double)score
{
    PopupEntry* e = [[[PopupEntry alloc] init] autorelease];
    [e setMainValue:s];
    [e setScore:score];
    [e setPrefix:@""];

    return e;
}

- (NSString*)mainValue
{
    return s_;
}

- (void)setScore:(double)score
{
    score_ = score;
}

- (void)setMainValue:(NSString*)s
{
    [s_ autorelease];
    s_ = [s retain];
}

- (double)score
{
    return score_;
}

- (BOOL)isEqual:(id)o
{
    if ([o respondsToSelector:@selector(mainValue)]) {
        return [[self mainValue] isEqual:[o mainValue]];
    } else {
        return [super isEqual:o];
    }
}

- (NSComparisonResult)compare:(id)otherObject
{
    return [[NSNumber numberWithDouble:score_] compare:[NSNumber numberWithDouble:[otherObject score]]];
}

- (void)setPrefix:(NSString*)prefix
{
    [prefix_ autorelease];
    prefix_ = [prefix retain];
}

- (NSString*)prefix
{
    return prefix_;
}

@end

@implementation PopupWindow

- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)aStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)flag
{
    self = [super initWithContentRect:contentRect
                            styleMask:NSBorderlessWindowMask
                              backing:bufferingType
                                defer:flag];
    [self setCollectionBehavior:NSWindowCollectionBehaviorMoveToActiveSpace];

    return self;
}

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (void)keyDown:(NSEvent *)event
{
    id cont = [self windowController];
    if (cont && [cont respondsToSelector:@selector(keyDown:)]) {
        [cont keyDown:event];
    }
}

@end

@implementation PopupModel

- (id)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    values_ = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc
{
    [values_ release];
    [super dealloc];
}

- (NSUInteger)count
{
    return [values_ count];
}

- (void)removeAllObjects
{
    [values_ removeAllObjects];
}

- (void)addObject:(id)object
{
    [values_ addObject:object];
}

- (PopupEntry*)entryEqualTo:(PopupEntry*)entry
{
    for (PopupEntry* candidate in values_) {
        if ([candidate isEqual:entry]) {
            return candidate;
        }
    }
    return nil;
}

- (void)addHit:(PopupEntry*)object
{
    PopupEntry* entry = [self entryEqualTo:object];
    if (entry) {
        [entry setScore:[entry score] + [object score]];
        NSLog(@"Add additional hit for %@ bringing score to %lf", [entry mainValue], [entry score]);
    } else {
        [self addObject:object];
        NSLog(@"Add entry for %@ with score %lf", [object mainValue], [object score]);
    }
}

- (id)objectAtIndex:(NSUInteger)i
{
    return [values_ objectAtIndex:i];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
    return [values_ countByEnumeratingWithState:state objects:stackbuf count:len];
}

- (NSUInteger)indexOfObject:(id)o
{
    return [values_ indexOfObject:o];
}

- (void)sortByScore
{
    NSSortDescriptor *sortDescriptor;
    sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"score"
                                                  ascending:NO] autorelease];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSArray *sortedArray;
    sortedArray = [values_ sortedArrayUsingDescriptors:sortDescriptors];
    [values_ release];
    values_ = [[NSMutableArray arrayWithArray:sortedArray] retain];
}

@end


@implementation Popup

- (id)initWithWindowNibName:(NSString*)nibName tablePtr:(NSTableView**)table model:(PopupModel*)model;
{
    self = [super initWithWindowNibName:nibName];
    if (!self) {
        return self;
    }

    [self window];

    tableView_ = [*table retain];
    model_ = [[PopupModel alloc] init];
    substring_ = [[NSMutableString alloc] init];
    unfilteredModel_ = [model retain];

    return self;
}

- (void)dealloc
{
    [substring_ release];
    [model_ release];
    [tableView_ release];
    [session_ release];
    [super dealloc];
}

- (void)popInSession:(PTYSession*)session
{
    [self setSession:session];
    [self showWindow:[session parent]];
    [[self window] makeKeyAndOrderFront:[session parent]];
}

- (void)setSession:(PTYSession*)session
{
    [session_ autorelease];
    session_ = [session retain];
}

- (PTYSession*)session
{
    return session_;
}

- (PopupModel*)unfilteredModel
{
    return unfilteredModel_;
}

- (PopupModel*)model
{
    return model_;
}

- (void)onClose
{
    clearFilterOnNextKeyDown_ = NO;
    if (timer_) {
        [timer_ invalidate];
        timer_ = nil;
    }
    [substring_ setString:@""];
}

- (void)onOpen
{
}

- (void)reloadData:(BOOL)canChangeSide
{
    [model_ removeAllObjects];
    [unfilteredModel_ sortByScore];
    for (PopupEntry* s in unfilteredModel_) {
        if ([self _word:[s mainValue] matchesFilter:substring_]) {
            [model_ addObject:s];
        }
    }
    [tableView_ reloadData];
    [self setPosition:canChangeSide];
    [tableView_ sizeToFit];
    [[tableView_ enclosingScrollView] setHasHorizontalScroller:NO];

    if ([tableView_ selectedRow] == -1 && [tableView_ numberOfRows] > 0) {
        NSIndexSet* indexes = [NSIndexSet indexSetWithIndex:[self convertIndex:0]];
        [tableView_ selectRowIndexes:indexes byExtendingSelection:NO];
    }
}

- (int)convertIndex:(int)i
{
    return onTop_ ? [model_ count] - i - 1 : i;
}

- (void)_setClearFilterOnNextKeyDownFlag:(id)sender
{
    clearFilterOnNextKeyDown_ = YES;
    timer_ = nil;
}

- (void)setPosition:(BOOL)canChangeSide
{
    BOOL onTop = NO;

    VT100Screen* screen = [session_ SCREEN];
    int cx = [screen cursorX] - 1;
    int cy = [screen cursorY];

    PTYTextView* tv = [session_ TEXTVIEW];
    [tv scrollEnd];
    NSRect frame = [[self window] frame];
    frame.size.height = [[tableView_ headerView] frame].size.height + [model_ count] * ([tableView_ rowHeight] + [tableView_ intercellSpacing].height);

    NSPoint p = NSMakePoint(MARGIN + cx * [tv charWidth],
                            ([screen numberOfLines] - [screen height] + cy) * [tv lineHeight]);
    p = [tv convertPoint:p toView:nil];
    p = [[tv window] convertBaseToScreen:p];
    p.y -= frame.size.height;

    NSRect monitorFrame = [[[[screen session] parent] windowScreen] visibleFrame];

    if (canChangeSide) {
        // p.y gives the bottom of the frame relative to the bottom of the screen, assuming it's below the cursor.
        float bottomOverflow = monitorFrame.origin.y - p.y;
        float topOverflow = p.y + 2 * frame.size.height + [tv lineHeight] - (monitorFrame.origin.y + monitorFrame.size.height);
        if (bottomOverflow > 0 && topOverflow < bottomOverflow) {
            onTop = YES;
        }
    } else {
        onTop = onTop_;
    }
    if (onTop) {
        p.y += frame.size.height + [tv lineHeight];
    }
    float rightX = monitorFrame.origin.x + monitorFrame.size.width;
    if (p.x + frame.size.width > rightX) {
        float excess = p.x + frame.size.width - rightX;
        p.x -= excess;
    }

    frame.origin = p;
    [[self window] setFrame:frame display:NO];
    if (canChangeSide) {
        BOOL flip = (onTop != onTop_);
        [self setOnTop:onTop];
        if (flip) {
            NSIndexSet* indexes = [NSIndexSet indexSetWithIndex:[self convertIndex:[tableView_ selectedRow]]];
            [tableView_ selectRowIndexes:indexes byExtendingSelection:NO];
        }
    }
}

- (void)setOnTop:(BOOL)onTop
{
    onTop_ = onTop;
}


- (void)keyDown:(NSEvent*)event
{
    unichar c = [[event characters] characterAtIndex:0];
    if (c == '\r') {
        [self rowSelected:self];
    } else if (c == 8 || c == 127) {
        // backspace
        if (timer_) {
            [timer_ invalidate];
            timer_ = nil;
        }
        clearFilterOnNextKeyDown_ = NO;
        [substring_ setString:@""];
        [self reloadData:NO];
    } else if (!iswcntrl(c)) {
        if (clearFilterOnNextKeyDown_) {
            [substring_ setString:@""];
            clearFilterOnNextKeyDown_ = NO;
        }
        [substring_ appendString:[event characters]];
        [self reloadData:NO];
        if (timer_) {
            [timer_ invalidate];
        }
        timer_ = [NSTimer scheduledTimerWithTimeInterval:4
                                                  target:self
                                                selector:@selector(_setClearFilterOnNextKeyDownFlag:)
                                                userInfo:nil
                                                 repeats:NO];
    } else if (c == 27) {
        // Escape
        [[self window] close];
        [self onClose];
    }
}

- (void)rowSelected:(id)sender
{
    [[self window] close];
    [self onClose];
}

- (NSAttributedString*)attributedStringForEntry:(PopupEntry*)entry
{
    float size = [NSFont systemFontSize];
    NSFont* sysFont = [NSFont systemFontOfSize:size];
    NSMutableAttributedString* as = [[[NSMutableAttributedString alloc] init] autorelease];
    NSColor* lightColor = [[NSColor blackColor] colorWithAlphaComponent:0.4];
    NSDictionary* lightAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     sysFont, NSFontAttributeName,
                                     lightColor, NSForegroundColorAttributeName,
                                     nil];
    NSDictionary* plainAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     sysFont, NSFontAttributeName,
                                     nil];
    NSDictionary* boldAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont boldSystemFontOfSize:size], NSFontAttributeName,
                                    nil];

    [as appendAttributedString:[[[NSAttributedString alloc] initWithString:[entry prefix] attributes:lightAttributes] autorelease]];
    NSString* value = [[entry mainValue] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];

    NSString* temp = value;
    for (int i = 0; i < [substring_ length]; ++i) {
        unichar wantChar = [substring_ characterAtIndex:i];
        NSRange r = [temp rangeOfString:[NSString stringWithCharacters:&wantChar length:1] options:NSCaseInsensitiveSearch];
        if (r.location == NSNotFound) {
            return nil;
        }
        NSRange prefix;
        prefix.location = 0;
        prefix.length = r.location;

        NSAttributedString* attributedSubstr;
        if (prefix.length > 0) {
            NSString* substr = [temp substringWithRange:prefix];
            attributedSubstr = [[[NSAttributedString alloc] initWithString:substr attributes:plainAttributes] autorelease];
            [as appendAttributedString:attributedSubstr];
        }

        unichar matchChar = [temp characterAtIndex:r.location];
        attributedSubstr = [[[NSAttributedString alloc] initWithString:[NSString stringWithCharacters:&matchChar length:1] attributes:boldAttributes] autorelease];
        [as appendAttributedString:attributedSubstr];

        r.length = [temp length] - r.location - 1;
        ++r.location;
        temp = [temp substringWithRange:r];
    }

    if ([temp length] > 0) {
        NSAttributedString* attributedSubstr = [[[NSAttributedString alloc] initWithString:temp
                                                                                attributes:plainAttributes] autorelease];
        [as appendAttributedString:attributedSubstr];
    }

    return as;
}

- (BOOL)_word:(NSString*)temp matchesFilter:(NSString*)filter
{
    for (int i = 0; i < [filter length]; ++i) {
        unichar wantChar = [filter characterAtIndex:i];
        NSRange r = [temp rangeOfString:[NSString stringWithCharacters:&wantChar length:1] options:NSCaseInsensitiveSearch];
        if (r.location == NSNotFound) {
            return NO;
        }
        r.length = [temp length] - r.location - 1;
        ++r.location;
        temp = [temp substringWithRange:r];
    }
    return YES;
}


// Delegate methods
- (void)windowDidResignKey:(NSNotification *)aNotification
{
    [[self window] close];
    [self onClose];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
    clearFilterOnNextKeyDown_ = NO;
    if (timer_) {
        [timer_ invalidate];
        timer_ = nil;
    }
    [substring_ setString:@""];
    [self onOpen];
    [self refresh];
    if ([tableView_ numberOfRows] > 0) {
        NSIndexSet* indexes = [NSIndexSet indexSetWithIndex:[self convertIndex:0]];
        [tableView_ selectRowIndexes:indexes byExtendingSelection:NO];
    }
}

- (void)refresh
{
}

// DataSource methods
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [model_ count];
}

// Tableview delegate methods
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    int i = [self convertIndex:rowIndex];
    PopupEntry* e = [[self model] objectAtIndex:i];
    return [self attributedStringForEntry:e];
}


@end
