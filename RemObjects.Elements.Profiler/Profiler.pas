namespace RemObjects.Elements.Profiler;

interface

uses
  RemObjects.Elements.RTL;

type
  Profiler = public static class
  private
    var fLock: {$IFDEF ISLAND}Monitor{$ELSE}Object{$ENDIF} := new {$IFDEF ISLAND}Monitor{$ELSE}Object{$ENDIF};
    var fThreads: Dictionary<Integer, ThreadInfo> := new Dictionary<Int32,ThreadInfo>;
    constructor;
    method GetDefaultFileName: String;
  protected
    const SubCallCount: Integer = 9;
  public
    method WriteData;
    method Reset; // sets all counters to 0
    method Enter(aName: String);
    method &Exit(aName: String);

    property LogFileBaseName: String;
  end;

  ThreadInfo = class
  private
  public
    property Items: List<FrameInfo> := new List<FrameInfo>;
    property Bias: Int64;
    property Methods: Dictionary<String, MethodInfo> := new Dictionary<String,MethodInfo>;
  end;

  SITuple = class(Object{$IFDEF ECHOES or ISLAND}, IEquatable<SITuple>{$ELSEIF TOFFEE}INSCopying{$ENDIF})
  public
    constructor (aKey: String; aInt: Integer);
    property Key: String read private write;
    property Int: Integer read private write;

    {$IFDEF ISLAND OR ECHOES}
    method &Equals(obj: Object): Boolean; override;
    begin
      exit Equals(SITuple(obj));
    end;

    method &Equals(other: SITuple): Boolean;
    begin
      exit (other.Key = Key) and (other.Int = Int);
    end;

    method GetHashCode: Integer; override;
    begin
      exit Key.GetHashCode xor Int;
    end;
    {$ELSEIF COOPER}
    method &equals(other: SITuple): Boolean;
    begin
      exit (other.Key = Key) and (other.Int = Int);
    end;

    method hashCode: Integer; override;
    begin
      exit Key.hashCode xor Int;
    end;
    {$ELSEIF TOFFEE}
    method isEqual(obj: Object): Boolean; override;
    begin
      exit isEqual(SITuple(obj));
    end;

    method isEqual(other: SITuple): Boolean;
    begin
      exit (other.Key = Key) and (other.Int = Int);
    end;

    method hash: Foundation.NSUInteger; override;
    begin
      exit Key.hash xor Int;
    end;

    method copyWithZone(aZone: ^Foundation.NSZone): instancetype;
    begin
      result := new SITuple();
      result.Key := Key;
      result.Int := Int;
    end;
    {$ENDIF}

  end;

  MethodInfo = class
  public
    property PK: Integer;

    property Count: Int64;
    property Name: String;
    property TotalTicks: Int64;
    property SelfTicks: Int64;
    property MinTotalTicks: Int64 := $7FFFFFFFFFFFFFFF;
    property MinSelfTicks: Int64 := $7FFFFFFFFFFFFFFF;
    property MaxTotalTicks: Int64;
    property MaxSelfTicks: Int64;
    property SubCalls: Dictionary<SITuple, SubCall> := new Dictionary<SITuple,SubCall>;
  end;

  SubCall=  class
  public
    property &Method: MethodInfo;
    property Count: Int64;
    property TotalTicks: Int64;
    property SelfTicks: Int64;
    property MinTotalTicks: Int64 := $7FFFFFFFFFFFFFFF;
    property MinSelfTicks: Int64 := $7FFFFFFFFFFFFFFF;
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

{$IFDEF TOFFEE OR ISLAND}
method __elements_write_data;
begin
  Profiler.WriteData;
end;
{$ENDIF}

method GetTimestamp: Int64;
begin
  {$IFDEF ECHOES}
  exit System.Diagnostics.Stopwatch.GetTimestamp;
  {$else}
  exit DateTime.UtcNow.Ticks;
  {$ENDIF}
end;

constructor Profiler;
begin
  {$IFDEF ECHOES}
    AppDomain.CurrentDomain.ProcessExit += (o, e) -> begin
      try
      finally
        WriteData;
      end;
    end;
    System.Diagnostics.Stopwatch.GetTimestamp; // preload that
  {$ELSEIF COOPER}
  Runtime.Runtime.addShutdownHook(new Thread(-> WriteData));
  {$ELSEIF WINDOWS and ISLAND}
  ExternalCalls.atexit(-> WriteData);
  {$ELSEIF TOFFEE or ISLAND}
  rtl.atexit(@__elements_write_data);
  {$else}
  {$ERROR Invalid Target!}
  {$ENDIF}
end;


method Profiler.Enter(aName: String);
begin
  var lStart := GetTimestamp;
  var lTID := {$IFDEF ISLAND}RemObjects.Elements.System.Thread.CurrentThreadID{$ELSE}Thread.CurrentThread.ThreadId{$ENDIF};
  var lTI: ThreadInfo;
  locking fLock do begin
    lTI := fThreads[lTID];
    if lTI = nil then begin
      lTI := new ThreadInfo;
      fThreads.Add(lTID, lTI);
    end;
  end;

  var lMI: MethodInfo := lTI.Methods[aName];
  if lMI = nil then begin
    lMI := new MethodInfo;
    lMI.Name := aName;
    lTI.Methods.Add(aName, lMI);
  end;
  lTI.Items.Add(new FrameInfo(&method := aName, StartTime := lStart - lTI.Bias, Prev := if lTI.Items.Count = 0 then nil else lTI.Items[lTI.Items.Count-1]));

  lTI.Bias := lTI.Bias + GetTimestamp - lStart;
end;

method Profiler.&Exit(aName: String);
begin
  var lStart := GetTimestamp;
  var lTID := {$IFDEF ISLAND}RemObjects.Elements.System.Thread.CurrentThreadID{$ELSE}Thread.CurrentThread.ThreadId{$ENDIF};
  var lTI: ThreadInfo;
  locking fLock do begin
    lTI := fThreads[lTID];
    if lTI = nil then begin
      lTI := new ThreadInfo;
      fThreads.Add(lTID, lTI);
    end;
  end;
  var lLastE := lTI.Items[lTI.Items.Count -1];
  lTI.Items.RemoveAt(lTI.Items.Count-1);
  assert(lLastE.Method = aName);

  var lTime := lStart - lTI.Bias - lLastE.StartTime;
  if lTI.Items.Count > 0 then
    lTI.Items[lTI.Items.Count -1].SubCallTime := lTI.Items[lTI.Items.Count -1].SubCallTime + lTime;
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
    var sc: SubCall := lCA.SubCalls[tp];
    if sc = nil then begin
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

  lTI.Bias := lTI.Bias + GetTimestamp - lStart;
end;

method Profiler.GetDefaultFileName: String;
begin
  const ELEMENTS_PROFILER_LOG_FILE = "ELEMENTS_PROFILER_LOG_FILE";
  result := Environment.EnvironmentVariable[ELEMENTS_PROFILER_LOG_FILE];
  if defined("TOFFEE") and not assigned(result) then
    result := (Foundation.NSProcessInfo.processInfo.arguments.Where(s -> (s as String).StartsWith("--"+ELEMENTS_PROFILER_LOG_FILE+"=")).FirstOrDefault as String):Substring(3+length(ELEMENTS_PROFILER_LOG_FILE));
  if defined("ECHOES") and not assigned(result) then
    result := &System.Reflection.Assembly.GetEntryAssembly():Location;
end;

method Profiler.WriteData;
begin
  var lFilename := coalesce(LogFileBaseName, GetDefaultFileName, "app.profile");

  var lWriter := new StringBuilder;
  begin
    lWriter.AppendLine('');
    lWriter.AppendLine('create table methods (id integer primary key, thread integer, count integer, name text, totalticks integer, selfticks integer, mintotal integer, maxtotal integer, minself integer, maxself integer);');
    lWriter.AppendLine('create table subcalls (fromid integer, toid integer, level integer, count integer, totalticks integer, selfticks integer, mintotal integer, maxtotal integer, minself integer, maxself integer);');
  var nc := 0;
  fThreads.ForEach(el -> begin
    el.Value.Methods.ForEach(m ->  begin
      inc(nc);
      m.Value.PK := nc;
    end);
  end);
  fThreads.ForEach(el -> begin
    var lThread := el.Key;
    el.Value.Methods.ForEach(m ->  begin
        lWriter.AppendFormat('insert into methods values ({0}, {1}, {2}, ''{3}'', {4}, {5}, {6},{7},{8},{9});{10}', m.Value.PK, lThread, m.Value.Count, m.Value.Name, m.Value.TotalTicks, m.Value.SelfTicks, m.Value.MinTotalTicks, m.Value.MaxTotalTicks, m.Value.MinSelfTicks, m.Value.MaxSelfTicks, Environment.LineBreak);
      m.Value.SubCalls.ForEach(n -> begin
          lWriter.AppendFormat('insert into subcalls values ({0}, {1}, {2}, {3}, {4}, {5}, {6},{7},{8},{9});{10}', m.Value.PK, n.Value.Method.PK, n.Key.Int, n.Value.Count, n.Value.TotalTicks, n.Value.SelfTicks, n.Value.MinTotalTicks, n.Value.MaxTotalTicks, n.Value.MinSelfTicks, n.Value.MaxSelfTicks, Environment.LineBreak);
      end);
    end);
  end);
  end;
  File.WriteText(lFilename, lWriter.ToString, Encoding.UTF8);
  writeLn("Elements Profiler results have been saved to '"+lFilename+"'.");
end;

method Profiler.Reset;
begin
  fThreads.RemoveAll;
end;

constructor SITuple(aKey: String; aInt: Integer);
begin
  Key := aKey;
  Int := aInt;
end;

end.