/*
 **  BookmarkTableController.m
 **  iTerm
 **
 **  Created by George Nachman on 8/26/10.
 **  Project: iTerm
 **
 **  Description: Custom view that shows a search field and table of bookmarks
 **    and integrates them.
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
 */

#import <Cocoa/Cocoa.h>
#import "BookmarkModel.h"

@protocol BookmarkTableDelegate
- (void)bookmarkTableSelectionDidChange:(id)bookmarkTable;
- (void)bookmarkTableSelectionWillChange:(id)bookmarkTable;
- (void)bookmarkTableRowSelected:(id)bookmarkTable;
@end

@interface BookmarkListView : NSView {
    int rowHeight_;
    NSScrollView* scrollView_;
    NSSearchField* searchField_;
    NSTableView* tableView_;
    NSTableColumn* tableColumn_;
    NSTableColumn* commandColumn_;
    NSTableColumn* shortcutColumn_;
    NSTableColumn* starColumn_;
    id<BookmarkTableDelegate> delegate_;
    BOOL showGraphic_;
    NSSet* selectedGuids_;
    BOOL debug;
    BookmarkModel* dataSource_;
}

- (void)awakeFromNib;
- (id)initWithFrame:(NSRect)frameRect;
- (void)setDelegate:(id<BookmarkTableDelegate>)delegate;
- (void)dealloc;
- (void)setDataSource:(BookmarkModel*)dataSource;

// DataSource methods
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView;
- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation;

// Drag drop
- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard;
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op;
- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation;


// Delegate methods
- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView;
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;

// Don't use this if you've called allowMultipleSelection.
- (int)selectedRow;
- (void)reloadData;
- (void)selectRowIndex:(int)theIndex;
- (void)selectRowByGuid:(NSString*)guid;
- (int)numberOfRows;
- (void)hideSearch;
- (void)setShowGraphic:(BOOL)showGraphic;
- (void)allowEmptySelection;
- (void)allowMultipleSelections;
- (void)deselectAll;
- (void)multiColumns;

// Dont' use this if you've called allowMultipleSelection
- (NSString*)selectedGuid;
- (NSSet*)selectedGuids;
- (void)dataChangeNotification:(id)sender;
- (void)onDoubleClick:(id)sender;
- (void)eraseQuery;
- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize;
- (id)retain;
- (oneway void)release;
- (void)turnOnDebug;
- (void)allowMultipleSelection;

@end
