namespace RemObjects.Profiler;

uses
  System.Collections.Generic,
  System.IO,
  System.Threading;

type
  RemObjectsProfiler = public static class
  private
    fSocket: System.Net.Sockets.Socket;
    fNames: Dictionary<String, Integer>;
    fMS: MemoryStream;
    class var DT: DateTime := new DateTime(1970, 1, 1, 0,0,0,0, DateTimeKind.Utc);
    method AddVarUInt(val: UInt64);
    begin 
      repeat
        fMS.WriteByte((val and $7f) or (if val > $7f then $80 else $80));
        val := val shr 7;
      until val = 0;
    end;

    method AddString(s: String);
    begin 
      var c := System.Text.Encoding.UTF8.GetBytes(s);
      AddVarUInt(c.Length);
      fMS.Write(c, 0, c.Length);
    end;

    method GetMethodId(s: String): Integer;
    begin 
      if fNames.TryGetValue(s, out result) then exit;
      result := fNames.Count;
      fNames.Add(s, result);

      AddVarUInt(0);
      AddVarUInt(result);
      AddString(s);
      Send;
    end;

    method Send;
    begin 
      var s := 0;
      while s < fMS.Length do begin 
        var c := fSocket.Send(fMS.GetBuffer, s, fMS.Length - s, System.Net.Sockets.SocketFlags.None);
        s := s + c;
      end;
      fMS.SetLength(0);
    end;

    class constructor;
    begin 
      if String.IsNullOrEmpty(Environment.GetEnvironmentVariable('PROFILECONNECTHOST')) then exit;
      try
        fSocket := new System.Net.Sockets.Socket(System.Net.Sockets.AddressFamily.InterNetwork, System.Net.Sockets.SocketType.Stream, System.Net.Sockets.ProtocolType.Tcp);
        fSocket.Connect(Environment.GetEnvironmentVariable('PROFILECONNECTHOST'), Int32.Parse(Environment.GetEnvironmentVariable('PROFILECONNECTPORT')));
        fMS := new MemoryStream;
        AddString('REMOBJECTSPROFILER');
        AddVarUInt(1);
        AddVarUInt(0);
        fNames := new Dictionary<String, Integer>;
      except 
        fSocket := nil;
      end;
    end;
  protected
  public
    method Enter(aName: String);
    begin 
      var t := DateTime.UtcNow;
      locking fSocket do begin 
        var lMID := GetMethodId(aName);
        AddVarUInt(1);
        AddVarUInt(lMID);
        AddVarUInt(Thread.CurrentThread.ManagedThreadId);
        AddVarUInt(Int64((t - DT).TotalMilliseconds));
        AddVarUInt(Int64((DateTime.UtcNow - t).TotalMilliseconds));
        Send;
      end;
    end;

    method &Exit(aName: String);
    begin 
      var t := DateTime.UtcNow;
      locking fSocket do begin 
        var lMID := GetMethodId(aName);
        AddVarUInt(2);
        AddVarUInt(lMID);
        AddVarUInt(Thread.CurrentThread.ManagedThreadId);
        AddVarUInt(Int64((t - DT).TotalMilliseconds));
        AddVarUInt(Int64((DateTime.UtcNow - t).TotalMilliseconds));
        Send;
      end;
    end;
  end;
  


end.
