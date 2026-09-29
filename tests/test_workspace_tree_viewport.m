function tests=test_workspace_tree_viewport
    tests=functiontests(localfunctions);
end
function testExpandedTreeKeepsReadableRowsAndScrollsToSelection(testCase)
    repo=fileparts(fileparts(mfilename('fullpath')));addpath(genpath(fullfile(repo,'src')));
    fig=figure('Visible','off','Position',[100 100 700 500]);
    cleanup=onCleanup(@()delete(fig)); %#ok<NASGU>
    ax=axes('Parent',fig,'Units','pixels','Position',[10 10 600 440]);
    tree=epicGraphicalTree(ax,'Root');
    for i=1:510,tree.newNode(tree.trunk,sprintf('Epoch %d',i));end
    tree.draw();
    verifyEqual(testCase,diff(get(ax,'YLim')),30);
    verifyEqual(testCase,char(get(tree.widgetList{20}.group,'Visible')),'on');
    verifyEqual(testCase,char(get(tree.widgetList{21}.group,'Visible')),'off');
    tree.selectWidget(511);
    verifyEqual(testCase,tree.firstVisibleRow,492);
    verifyEqual(testCase,char(get(tree.widgetList{511}.group,'Visible')),'on');
    verifyEqual(testCase,char(get(tree.widgetList{1}.group,'Visible')),'off');
    tree.scrollByRows(-1000);
    verifyEqual(testCase,tree.firstVisibleRow,1);
    tree.scrollByRows(1000);
    verifyEqual(testCase,tree.firstVisibleRow,492);
    tree.trunk.isExpanded=false;tree.draw();
    verifyEqual(testCase,tree.firstVisibleRow,1);
    verifyEqual(testCase,diff(get(ax,'YLim')),30);
    verifyEqual(testCase,char(get(tree.widgetList{1}.group,'Visible')),'on');
    set(ax,'Position',[10 10 600 220]);tree.updateViewport();
    verifyEqual(testCase,diff(get(ax,'YLim')),15);
end
