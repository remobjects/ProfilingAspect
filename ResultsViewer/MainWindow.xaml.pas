namespace ResultsViewer;

interface

uses
  System.Collections.Generic,
  System.Linq,
  System.Windows,
  System.Windows.Controls,
  System.Windows.Data,
  System.Windows.Documents,
  System.Windows.Media,
  System.Windows.Navigation,
  System.Windows.Shapes;

type
  MainWindow = public partial class(System.Windows.Window)
  private
    method RefreshSub;
    method lvData_SelectionChanged(sender: System.Object; e: System.Windows.Controls.SelectionChangedEventArgs);
    method cbThread_SelectionChanged(sender: System.Object; e: System.Windows.Controls.SelectionChangedEventArgs);
    method cbFilter_TextChanged(sender: System.Object; e: System.Windows.Controls.TextChangedEventArgs);
    method cbOrder_SelectionChanged(sender: System.Object; e: System.Windows.Controls.SelectionChangedEventArgs);
    method cbSubOrder_SelectionChanged(sender: System.Object; e: System.Windows.Controls.SelectionChangedEventArgs);
    fData: Data;
  private
    method FileExit_Click(sender: System.Object; e: System.Windows.RoutedEventArgs);
    method FileOpen_Click(sender: System.Object; e: System.Windows.RoutedEventArgs);
    method HelpAbout_Click(sender: System.Object; e: System.Windows.RoutedEventArgs);
    method Refresh;
  public
    property CurrentData: List<Methods>; notify;
    property SubData: List<SubCalls>; notify;
    constructor;
  end;
  
implementation

constructor MainWindow;
begin
  InitializeComponent();
  DataContext := self;
end;

method MainWindow.FileExit_Click(sender: System.Object; e: System.Windows.RoutedEventArgs);
begin
  Close;
end;

method MainWindow.FileOpen_Click(sender: Object; e: RoutedEventArgs);
begin
  var lFiledlg := new Microsoft.Win32.OpenFileDialog();
  lFiledlg.Filter := '*.log|*.log';
  if lFiledlg.ShowDialog then begin
    try
      fData := new Data(lFiledlg.FileName);
      cbFilter.Text := '';
      SubData := nil;
      cbOrder.SelectedIndex := 0;
      cbThread.Items.Clear;
      cbThread.Items.Add('All Threads');
      for each item in fData.Threads do
        cbThread.Items.Add(item);
      cbThread.SelectedIndex := 0;
      Refresh;
    except
      on ez: Exception do
        MessageBox.Show(self, ez.Message, 'Error', MessageBoxButton.OK, MessageBoxImage.Error);
    end;
  end;
end;

method MainWindow.HelpAbout_Click(sender: Object; e: RoutedEventArgs);
begin
  MessageBox.Show(self, "RemObjects Profile Viewer

Copyright (c) 2014-2015 RemObjects Software");
end;

method MainWindow.Refresh;
begin
  if fData = nil then begin
    CurrentData := nil;
    exit;
  end;
  CurrentData := fData.GetData(DataOrder(cbOrder.SelectedIndex), cbFilter.Text, 
    if cbThread.SelectedIndex <= 0 then nil else Int32.Parse(cbThread.SelectedValue:ToString));
end;

method MainWindow.cbOrder_SelectionChanged(sender: System.Object; e: System.Windows.Controls.SelectionChangedEventArgs);
begin
  Refresh;
end;

method MainWindow.cbFilter_TextChanged(sender: System.Object; e: System.Windows.Controls.TextChangedEventArgs);
begin
  Refresh;
end;

method MainWindow.cbThread_SelectionChanged(sender: System.Object; e: System.Windows.Controls.SelectionChangedEventArgs);
begin
  Refresh;
end;

method MainWindow.lvData_SelectionChanged(sender: System.Object; e: System.Windows.Controls.SelectionChangedEventArgs);
begin
  RefreshSub;
end;

method MainWindow.RefreshSub;
begin
  if lvData.SelectedItem = nil then
    SubData := nil
  else
    SubData := fData:GetSubCalls(Methods(lvData.SelectedItem).id, SubOrder(cbSubOrder.SelectedIndex));
end;

method MainWindow.cbSubOrder_SelectionChanged(sender: Object; e: SelectionChangedEventArgs);
begin
  RefreshSub
end;
  
end.
