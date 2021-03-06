﻿namespace RemObjects.Elements.Profiler;

uses
  RemObjects.Elements.Cirrus.*;

type
  [AttributeUsage(AttributeTargets.Class or AttributeTargets.Method)]
  ProfileAspect = public class(IMethodImplementationDecorator)
  private
    var fOptionalDefine: String;
  public

    constructor; empty;

    constructor (aOptionalDefine: not nullable String);
    begin
      fOptionalDefine := aOptionalDefine;
    end;

    method HandleImplementation(aServices: IServices; aMethod: IMethodDefinition);
    begin
      if aMethod.Virtual = VirtualMode.Abstract then exit;
      if aMethod.Empty then exit;
      if aMethod.Owner.TypeKind = TypeDefKind.Interface then exit;
      if aMethod.Name.StartsWith("get_") then exit;
      if aMethod.Name.StartsWith("set_") then exit;
      if aMethod.Name.StartsWith("add_") then exit;
      if aMethod.Name.StartsWith("remove_") then exit;

      if not aServices.IsDefined('PROFILE') then
        exit;
      if (length(fOptionalDefine) > 0) and not aServices.IsDefined(fOptionalDefine) then
        exit;

      var lType := aServices.GetType('RemObjects.Elements.Profiler.Profiler');
      var lName := aMethod.Owner.Name+'.'+aMethod.Name+'(';
      for i: Integer := 0 to aMethod.ParameterCount -1 do begin
        if i <> 0 then lName := lName+',';
        lName := lName+ aMethod.GetParameter(i).Type.Fullname;
      end;
      lName := lName+')';
      aMethod.SurroundMethodBody(
        new StandaloneStatement(new ProcValue(new TypeValue(lType), 'Enter', new DataValue(lName))),
        new StandaloneStatement(new ProcValue(new TypeValue(lType), 'Exit', new DataValue(lName))),
        SurroundMethod.Always);
    end;
  end;

end.