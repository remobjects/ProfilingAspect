namespace ResultsViewer;

interface

uses
  System.Collections.Generic,
  System.Linq,
  System.Text;

type
  DataOrder = public enum (TotalTicks, TicksWithoutChildren, Count, Name); // Match with cb order
  Data = public class
  private
    fThreads: List<Integer> := new List<Int32>;
    fData: List<Methods> := new List<Methods>;
    fSubCalls: List<SubCalls> := new List<SubCalls>;
  protected
  public
    constructor(aFilename: String);
    property Threads: List<Integer> read fThreads;
    property MaxTicks: Int64;
    method GetData(aOrder: DataOrder; aNameFilter: String; aThread: nullable Integer): List<Methods>;
  end;
  Methods = public class
  private
    fOwner: Data;
  public
    constructor(aOwner: Data);
    property totalticksdisplay: String read (totalticks* 1.0 / fOwner.MaxTicks).ToString("0.##%")+ ' '+totalticks.ToString();
    property selfticksdisplay: String read (selfticks* 1.0/ fOwner.MaxTicks).ToString("0.##%")+ ' '+selfticks.ToString();
    property id: Int64;
    property thread: Integer;
    property count: Int64;
    property name: String;
    property totalticks: Int64;
    property selfticks: Int64;
    property mintotal: Int64;
    property maxtotal: Int64;
    property minself: Int64;
    property maxself: Int64;
  end;

  SubCalls = public class
  public
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
        var lItems := lLine.Split([','], StringSplitOptions.RemoveEmptyEntries);
        if lItems.Count <> 10 then raise new Exception('Methods not formatted in an expected way');
        for i: Integer := 0 to lItems.Count -1 do lItems[i] := lItems[i].Trim([' ', #39]);
        var lMethod := new Methods(self,
          id := Int64.Parse(lItems[0]), 
          thread := Int32.Parse(lItems[1]),
          count := Int64.Parse(lItems[2]),
          name := lItems[3],
          totalticks := Int64.Parse(lItems[4]),
          selfticks := Int64.Parse(lItems[5]),
          mintotal := Int64.Parse(lItems[6]),
          maxtotal  := Int64.Parse(lItems[7]),
          minself  := Int64.Parse(lItems[8]),
          maxself := Int64.Parse(lItems[9]));
        MaxTicks := Math.Max(MaxTicks, lMethod.totalticks);
        fData.Add(lMethod);
      end else
      if lLine.StartsWith('insert into subcalls') then begin

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

constructor Methods(aOwner: Data);
begin
  fOwner := aOwner;
end;


end.
