namespace RemObjects.Profiler;

interface

uses
  System.Collections.Generic,
  System.IO,
  System.Threading;

type
  RemObjectsProfiler = public static class
  private
    constructor ;
    var fThreads: Dictionary<Integer, ThreadInfo> := new Dictionary<Int32,ThreadInfo>;
  protected
    method AppDomainCurrentDomainProcessExit(sender: Object; e: EventArgs);
    const SubCallCount: Integer = 4;
  public
    method WriteData;
    method Reset; // sets all counters to 0
    method Enter(aName: String);
    method &Exit(aName: String);
    
    property LogFileBaseName: String;
  end;
  
  ThreadInfo = class(List<FrameInfo>)
  private
  public
    property Bias: Int64;
    property Methods: Dictionary<String, MethodInfo> := new Dictionary<String,MethodInfo>;
  end;
  
  SITuple = class(IEquatable<SITuple>)
  public
    constructor(aKey: String; aInt: Integer);
    property Key: String; readonly;
    property Int: Integer;readonly;
    method &Equals(obj: Object): Boolean; override;
    method &Equals(other: SITuple): Boolean;
    method GetHashCode: Integer; override;
  end;
  
  MethodInfo = class
  public
    property PK: Integer;

    property Count: Int64;
    property Name: String;
    property TotalTicks: Int64;
    property SelfTicks: Int64;
    property MinTotalTicks: Int64 := Int64.MaxValue;
    property MinSelfTicks: Int64 := Int64.MaxValue;
    property MaxTotalTicks: Int64;
    property MaxSelfTicks: Int64;
    property SubCalls: Dictionary<SITuple, SubCall> := new Dictionary<SITuple,SubCall>;
  end;
  
  SubCall = class
  public
    property &Method: MethodInfo;
    property Count: Int64;
    property TotalTicks: Int64;
    property SelfTicks: Int64;
    property MinTotalTicks: Int64 := Int64.MaxValue;
    property MinSelfTicks: Int64 := Int64.MaxValue;
    property MaxTotalTicks: Int64;
    property MaxSelfTicks: Int64;
  end;
    FrameInfo = class
  public  private
  public
    property Prev: FrameInfo;
    property &Method: String;
    property StartTime: Int64;
    property SubtractFromTotal: Int64;
    property SubCallTime: Int64;
  end;

implementation

constructor RemObjectsProfiler;
begin
  AppDomain.CurrentDomain.ProcessExit += AppDomainCurrentDomainProcessExit;
  System.Diagnostics.Stopwatch.GetTimestamp; // preload that  
end;


method RemObjectsProfiler.Enter(aName: String);
begin
  var lStart := System.Diagnostics.Stopwatch.GetTimestamp;
  var lTID := Thread.CurrentThread.ManagedThreadId;
  var lTI: ThreadInfo;
  locking fThreads do
    if not fThreads.TryGetValue(lTID, out lTI) then begin
      lTI := new ThreadInfo;
      fThreads.Add(lTID, lTI);
    end;
  
  var lMI: MethodInfo;
  if not lTI.Methods.TryGetValue(aName, out lMI) then begin 
    lMI := new MethodInfo;
    lMI.Name := aName;
    lTI.Methods.Add(aName, lMI);
  end;
  lTI.Add(new FrameInfo(&method := aName, StartTime := lStart - lTI.Bias, Prev := if lTI.Count = 0 then nil else lTI[lTI.Count-1]));

  lTI.Bias := lTI.Bias + System.Diagnostics.Stopwatch.GetTimestamp - lStart;
end;

method RemObjectsProfiler.&Exit(aName: String);
begin
  var lStart := System.Diagnostics.Stopwatch.GetTimestamp;
  var lTID := Thread.CurrentThread.ManagedThreadId;
  var lTI: ThreadInfo;
  locking fThreads do
    if not fThreads.TryGetValue(lTID, out lTI) then begin
      lTI := new ThreadInfo;
      fThreads.Add(lTID, lTI);
    end;
  var lLastE := lTI[lTI.Count -1];
  lTI.RemoveAt(lTI.Count-1);
  assert(lLastE.Method = aName);
            
  var lTime := lStart - lTI.Bias - lLastE.StartTime;
  if lTI.Count > 0 then 
    lTI[lTI.Count -1].SubCallTime := lTI[lTI.Count -1].SubCallTime + lTime;
  var lMI := lTI.Methods[aName];
  lMI.Count := lMI.Count + 1;
  var lSelfTime := lTime - lLastE.SubCallTime;
  lMI.TotalTicks := lMI.TotalTicks + lTime - lLastE.SubtractFromTotal;
  var lWorkLastE := lLastE.Prev;
  while lWorkLastE <> nil do begin
    if lWorkLastE.Method = aName then begin
      lWorkLastE.SubtractFromTotal := lWorkLastE.SubtractFromTotal + lTime - lLastE.SubtractFromTotal;
    end;
    lWorkLastE := lWorkLastE.Prev;
  end;
  lMI.MinTotalTicks := Math.Min(lMI.MinTotalTicks, lTime);
  lMI.MaxTotalTicks := Math.Max(lMI.MaxTotalTicks, lTime);
  lMI.SelfTicks := lMI.SelfTicks + lSelfTime;
  lMI.MinSelfTicks := Math.Min(lMI.MinSelfTicks, lSelfTime);
  lMI.MaxSelfTicks := Math.Max(lMI.MaxSelfTicks, lSelfTime);

  lLastE := lLastE.Prev;
  for i: Integer := 1 to SubCallCount do begin
    if lLastE = nil then break;
    var tp := new SITuple(aName, i);
    var lCA := lTI.Methods[lLastE.Method];
    var sc: SubCall;
    if not lCA.SubCalls.TryGetValue(tp, out sc) then begin
      sc := new SubCall;
      lCA.SubCalls.Add(tp, sc);
      sc.Method :=lMI;
    end;
    sc.Count := sc.Count + 1;
    sc.SelfTicks := sc.SelfTicks + lSelfTime;
    sc.TotalTicks := sc.TotalTicks + lTime - lLastE.SubtractFromTotal;
    sc.MinTotalTicks := Math.Min(sc.MinTotalTicks, lTime);
    sc.MaxTotalTicks := Math.Max(sc.MaxTotalTicks, lTime);
    sc.MinSelfTicks := Math.Min(sc.MinSelfTicks, lSelfTime);
    sc.MaxSelfTicks := Math.Max(sc.MaxSelfTicks, lSelfTime);

    lLastE := lLastE.Prev;
  end;

  lTI.Bias := lTI.Bias + System.Diagnostics.Stopwatch.GetTimestamp - lStart;
end;

method RemObjectsProfiler.AppDomainCurrentDomainProcessExit(sender: Object; e: EventArgs);
begin
  try
  finally
    WriteData;
  end;
end;

method RemObjectsProfiler.WriteData;
begin
  var lFilename := LogFileBaseName;
  if lFilename = nil then lFilename := &System.Reflection.Assembly.GetEntryAssembly():Location;
  if lFilename = nil then lFilename := 'test';
  lFilename := lFilename+'.results-'+DateTime.Now.ToString('yyyy-MM-dd-HH-mm-ss')+'.log';
  
  using lWriter := new StreamWriter(File.Create(lFilename), System.Text.Encoding.UTF8) do begin
    lWriter.WriteLine('');
    lWriter.WriteLine('create table methods (id integer primary key, thread integer, count integer, name text, totalticks integer, selfticks integer, mintotal integer, maxtotal integer, minself integer, maxself integer);');
    lWriter.WriteLine('create table subcalls (fromid integer, toid integer, level integer, count integer, totalticks integer, selfticks integer, mintotal integer, maxtotal integer, minself integer, maxself integer);');
    var nc := 0;
    for each el in fThreads do begin 
      for each m in el.Value.Methods do begin
        Inc(nc);
        m.Value.PK := nc;
      end;
    end;
    for each el in fThreads do begin 
      var lThread := el.Key;
      for each m in el.Value.Methods.Values  do begin 
        lWriter.WriteLine('insert into methods values ({0}, {1}, {2}, ''{3}'', {4}, {5}, {6},{7},{8},{9});', m.PK, lThread, m.Count, m.Name, m.TotalTicks, m.SelfTicks, m.MinTotalTicks, m.MaxTotalTicks, m.MinSelfTicks, m.MaxSelfTicks);
        for each n in m.SubCalls do begin 
          lWriter.WriteLine('insert into subcalls values ({0}, {1}, {2}, {3}, {4}, {5}, {6},{7},{8},{9});', m.PK, n.Value.Method.PK, n.Key.Int, n.Value.Count, n.Value.TotalTicks, n.Value.SelfTicks, n.Value.MinTotalTicks, n.Value.MaxTotalTicks, n.Value.MinSelfTicks, n.Value.MaxSelfTicks);
        end;
      end;
    end;
    lWriter.Close;
  end;
  writeLn('Written profile data to '+lFilename);
end;

method RemObjectsProfiler.Reset;
begin
  fThreads.Clear;
end;

constructor SITuple(aKey: String; aInt: Integer);
begin
  Key := aKey;
  Int := aInt;
end;

method SITuple.&Equals(obj: Object): Boolean;
begin
  exit Equals(SITuple(obj));
end;

method SITuple.&Equals(other: SITuple): Boolean;
begin
  exit (other.Key = Key) and (other.Int = Int);
end;

method SITuple.GetHashCode: Integer;
begin
  exit Key.GetHashCode xor Int;
end;

end.
