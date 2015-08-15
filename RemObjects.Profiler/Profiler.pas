namespace RemObjects.Profiler;

interface
uses
  System.Collections.Generic,
  System.IO,
  System.Threading;

type
  RemObjectsProfiler = public static class
  private
    class constructor ;
    class var fFW: StreamWriter;
    var fThreads: Dictionary<Integer, ThreadInfo> := new Dictionary<Int32,ThreadInfo>;

    class method WriteData;
  protected
    class method AppDomainCurrentDomainProcessExit(sender: Object; e: EventArgs);
    const SubCallCount: Integer = 4;
  public
    class method Enter(aName: String);
    class method &Exit(aName: String);
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
    property SubCalls: Dictionary<SITuple, SubCall> := new Dictionary<SITuple,SubCall>;
  end;
  SubCall=  class
  public
    property &Method: MethodInfo;
    property Count: Int64;
    property TotalTicks: Int64;
    property SelfTicks: Int64;
  end;
    FrameInfo = class
  public  private
  public
    property Prev: FrameInfo;
    property &Method: String;
    property StartTime: Int64;
    property SubCallTime: Int64;
  end;

implementation

class constructor RemObjectsProfiler;
begin
  AppDomain.CurrentDomain.ProcessExit += AppDomainCurrentDomainProcessExit;
  System.Diagnostics.Stopwatch.GetTimestamp; // preload that
  
  var lFN := &System.Reflection.Assembly.GetEntryAssembly().Location+'.results-'+DateTime.Now.ToString('yyyy-MM-ddHH-mm-ss')+'.log';
  fFW := new StreamWriter(File.Create(lFN), System.Text.Encoding.UTF8);
  fFW.WriteLine('');
end;


class method RemObjectsProfiler.Enter(aName: String);
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
    lMI.PK := lTI.Methods.Count + 1;
    lMI.Name := aName;
    lTI.Methods.Add(aName, lMI);
  end;
  lTI.Add(new FrameInfo(&method := aName, StartTime := lStart - lTI.Bias, Prev := if lTI.Count = 0 then nil else lTI[lTI.Count-1]));

  lTI.Bias := lTI.Bias + System.Diagnostics.Stopwatch.GetTimestamp - lStart;
end;

class method RemObjectsProfiler.&Exit(aName: String);
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
  lMI.TotalTicks := lMI.TotalTicks + lTime;
  lMI.SelfTicks := lMI.SelfTicks + lSelfTime;
  lLastE := lLastE.Prev;
  for i: Integer := SubCallCount downto 1 do begin
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
    sc.TotalTicks := sc.TotalTicks + lTime;
    lLastE := lLastE.Prev;
  end;

  lTI.Bias := lTI.Bias + System.Diagnostics.Stopwatch.GetTimestamp - lStart;
end;

class method RemObjectsProfiler.AppDomainCurrentDomainProcessExit(sender: Object; e: EventArgs);
begin
  try
  finally
    WriteData;
  end;
end;

class method RemObjectsProfiler.WriteData;
begin
  fFW.WriteLine('create table methods (id integer primary key, thread integer, count integer, name text, totalticks integer, selfticks integer);');
  fFW.WriteLine('create table subcalls (fromid integer, toid integer, level integer, count integer, totalticks integer, selfticks integer);');
  for each el in fThreads do begin 
    var lThread := el.Key;
    for each m in el.Value.Methods.Values  do begin 
      fFW.WriteLine('insert into methods values ({0}, {1}, {2}, ''{3}'', {4}, {5});', m.PK, lThread, m.Count, m.Name, m.TotalTicks, m.SelfTicks);
      for each n in m.SubCalls do begin 
        fFW.WriteLine('insert into subcalls values ({0}, {1}, {2}, {3}, {4}, {5});', m.PK, n.Value.Method.PK, n.Key.Int, n.Value.Count, n.Value.TotalTicks, n.Value.SelfTicks);
      end;
    end;
    // METHOD: Byte(0) Int32(PK) Int32(Thread) Int64(Count) String(Name) Int64(TotalTicks) Int64(SelfTicks)
    // SUBCALL Byte(1) Int32(From) Int32(Level) Int32(ToPK) Int64(Count) Int64(TotalTicks) Int64(SelfTicks)
  end;
  fFW.Close;
  writeLn('Written profile data!');
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
