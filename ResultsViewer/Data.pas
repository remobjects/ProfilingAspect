namespace ResultsViewer;

interface

uses
  System.Collections.Generic,
  System.Linq,
  System.Text;

type
  DataOrder = public enum (TotalTicks, TicksWithoutChildren, Count, Name); // Match with cb order
  SubOrder = public enum (LevelCount, LevelTotalTicks, LevelSubTicks);
  
  Data = public class
  private
    class method SplitString(stringToSplit: String): array of String;
    class method FixLevelSort(aVal: Integer): Integer;
    fThreads: List<Integer> := new List<Int32>;
    fData: List<Methods> := new List<Methods>;
    fDataDict: Dictionary<Int64, Methods> := new Dictionary<Int64,Methods>;
    fSubCalls: List<SubCalls> := new List<SubCalls>;
  protected
  public
    constructor(aFilename: String);
    property Threads: List<Integer> read fThreads;
    property MaxTicks: Int64;
    property DataDict: Dictionary<Int64, Methods> read fDataDict;
    method GetData(aOrder: DataOrder; aNameFilter: String; aThread: nullable Integer): List<Methods>;
    method GetSubCalls(aMethod, aThread: Int64; aOrder: SubOrder): List<SubCalls>;
  end;
  Methods = public class
  private
    fOwner: Data;
  public
    constructor(aOwner: Data);
    property totalticksdisplay1: String read (totalticks* 1.0 / fOwner.MaxTicks).ToString("0.##%");
    property totalticksdisplay2: String read new TimeSpan(totalticks).TotalMilliseconds.ToString("N");
    property selfticksdisplay1: String read (selfticks* 1.0/ fOwner.MaxTicks).ToString("0.##%");
    property selfticksdisplay2: String read new TimeSpan(selfticks).TotalMilliseconds.ToString("N");
    property id: Int64;
    property thread: Integer;
    property count: Int64;
    property name: String;
    property &params: String;
    property totalticks: Int64;
    property selfticks: Int64;
    property mintotal: Int64;
    property maxtotal: Int64;
    property minself: Int64;
    property maxself: Int64;
  end;

  SubCalls = public class
    fOwner: Data;
  public
    constructor(aOwner: Data);
    method CloneNegative: SubCalls;
    property Thread: Integer read fOwner.DataDict[toid].thread;
    property totalticksdisplay1: String read (totalticks* 1.0 / fOwner.MaxTicks).ToString("0.##%");
    property totalticksdisplay2: String read new TimeSpan(totalticks).TotalMilliseconds.ToString("N");
    property selfticksdisplay1: String read (selfticks* 1.0/ fOwner.MaxTicks).ToString("0.##%");
    property selfticksdisplay2: String read new TimeSpan(selfticks).TotalMilliseconds.ToString("N");
    property name: String read 
      (if level < 0 then 'From: ' else 'To: ')+
      fOwner.DataDict[toid].name;
    property &params: String read 
      fOwner.DataDict[toid].params;
    property fromid: Int64;
    property toid: Int64;
    property level: Integer;
    property count: Int64;
    property totalticks: Int64;
    property selfticks: Int64;
    property mintotal: Int64;
    property maxtotal: Int64;
    property minself: Int64;
    property maxself: Int64;
  end;

implementation
class method Data.SplitString(stringToSplit: String): array of String;
begin
  var characters: array of Char := stringToSplit.ToCharArray();
  var returnValueList: List<String> := new List<String>();
  var tempString: String := '';
  var blockUntilEndQuote: Boolean := false;
  var characterCount: Integer := 0;
  for each character in characters do begin
    characterCount := characterCount + 1;
    if character = '''' then begin
      blockUntilEndQuote := not blockUntilEndQuote;
    end;
    if character ≠ #44 then begin
      tempString := tempString + character;
    end
    else begin
      if (character = #44) and (blockUntilEndQuote = true) then begin
        tempString := tempString + character;
      end
      else begin
        returnValueList.Add(tempString);
        tempString := '';
      end;
    end;
    if characterCount = characters.Length then begin
      returnValueList.Add(tempString);
      tempString := '';
    end;
  end;
  exit returnValueList.ToArray();
end;


constructor Data(aFilename: String);
begin
  // This was originally written to be used from sqlite, but we skip that part. This code is not clean, but it works.
  using sr := new System.IO.StreamReader(aFilename) do begin 
    loop begin
      var lLine := sr.ReadLine:Trim;
      if lLine = nil then break;
      if lLine.StartsWith('create ')then continue;
      if lLine.StartsWith('insert into methods') then begin
        lLine := lLine.Substring(lLine.IndexOf('(')+1);
        lLine := lLine.Substring(0, lLine.LastIndexOf(')'));
        var lItems := SplitString(lLine);
        if lItems.Count <> 10 then raise new Exception('Methods not formatted in an expected way');
        for i: Integer := 0 to lItems.Count -1 do lItems[i] := lItems[i].Trim([' ', #39]);
        var lName := lItems[3];
        var lParams := '';
        if lName.Contains('(') then begin 
          lParams := lName.Substring(lName.IndexOf('('));
          lName := lName.Substring(0, lName.IndexOf('('));
        end;
        var lMethod := new Methods(self,
          id := Int64.Parse(lItems[0]), 
          thread := Int32.Parse(lItems[1]),
          count := Int64.Parse(lItems[2]),
          name := lName,
          params := lParams,
          totalticks := Int64.Parse(lItems[4]),
          selfticks := Int64.Parse(lItems[5]),
          mintotal := Int64.Parse(lItems[6]),
          maxtotal  := Int64.Parse(lItems[7]),
          minself  := Int64.Parse(lItems[8]),
          maxself := Int64.Parse(lItems[9]));
        MaxTicks := Math.Max(MaxTicks, lMethod.totalticks);
        fData.Add(lMethod);
        fDataDict[lMethod.id] := lMethod;
      end else
      if lLine.StartsWith('insert into subcalls') then begin
        lLine := lLine.Substring(lLine.IndexOf('(')+1);
        lLine := lLine.Substring(0, lLine.LastIndexOf(')'));
        
        var lItems := SplitString(lLine);
        if lItems.Count <> 10 then raise new Exception('Methods not formatted in an expected way');
        for i: Integer := 0 to lItems.Count -1 do lItems[i] := lItems[i].Trim([' ', #39]);
        fSubCalls.Add(new SubCalls(self,
          fromid := Int64.Parse(lItems[0]), 
          toid := Int64.Parse(lItems[1]), 
          level := Int32.Parse(lItems[2]),
          count := Int64.Parse(lItems[3]),
          totalticks := Int64.Parse(lItems[4]),
          selfticks := Int64.Parse(lItems[5]),
          mintotal := Int64.Parse(lItems[6]),
          maxtotal  := Int64.Parse(lItems[7]),
          minself  := Int64.Parse(lItems[8]),
          maxself := Int64.Parse(lItems[9])));
      end;
    end;
  end;
  fThreads.AddRange(fData.Select(a->a.thread).Distinct.OrderBy(a->a));
end;


method Data.GetData(aOrder: DataOrder; aNameFilter: String; aThread: nullable Integer): List<Methods>;
begin
  var lTmp: sequence of Methods := fData;
  if aThread <> nil then begin
    var lTID := Integer(aThread);
    lTmp := lTmp.Where(a->a.thread = lTID);
  end;
  if not String.IsNullOrEmpty(aNameFilter) then begin
    lTmp := fData.Where(a -> a.name.IndexOf(aNameFilter, StringComparison.InvariantCultureIgnoreCase) <> -1);
  end;
  case aOrder of
    DataOrder.TotalTicks: lTmp := lTmp.OrderByDescending(a -> a.totalticks);
    DataOrder.TicksWithoutChildren: lTmp := lTmp.OrderByDescending(a -> a.selfticks);
    DataOrder.Count: lTmp := lTmp.OrderByDescending(a -> a.count);
    DataOrder.Name: lTmp := lTmp.OrderByDescending(a -> a.name);
  end;
  exit lTmp.ToList;
end;

method Data.GetSubCalls(aMethod, aThread: Int64; aOrder: SubOrder): List<SubCalls>;
begin
  var lTmp := fSubCalls.Where(a->a.fromid = aMethod);
  lTmp := lTmp.Concat(fSubCalls.Where(a->a.toid = aMethod).Select(a->a.CloneNegative));
  case aOrder of
    SubOrder.LevelCount: lTmp := lTmp.OrderBy(a-> FixLevelSort(a.level)).ThenByDescending(a->a.count);
    SubOrder.LevelTotalTicks: lTmp := lTmp.OrderBy(a->FixLevelSort(a.level)).ThenByDescending(a->a.totalticks);
    SubOrder.LevelSubTicks: lTmp := lTmp.OrderBy(a->FixLevelSort(a.level)).ThenByDescending(a->a.selfticks);
  end;
  result := lTmp.ToList;
end;

class method Data.FixLevelSort(aVal: Integer): Integer;
begin
  if aVal < 0 then
    exit 100 + -aVal;
  exit aVal;
end;

constructor Methods(aOwner: Data);
begin
  fOwner := aOwner;
end;

constructor SubCalls(aOwner: Data);
begin
  fOwner := aOwner;
end;

method SubCalls.CloneNegative: SubCalls;
begin
  result :=  new SubCalls(fOwner);
  result.fromid := toid;
  result.toid := fromid;
  result.level := -level;
  result.count := count;
  result.totalticks := totalticks;
  result.selfticks := selfticks;
  result.mintotal := mintotal;
  result.maxtotal := maxtotal;
  result.minself := minself;
  result.maxself := maxself;
end;


end.
