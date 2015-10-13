namespace RemObjects.Profiler;

interface
uses
  RemObjects.Elements.Cirrus.*;

type
  [AttributeUsage(AttributeTargets.Class or AttributeTargets.Method)]
  ProfileAspect = public class(IMethodImplementationDecorator)
    class var fShownWarning: Boolean;
  public
    method HandleImplementation(aServices: IServices; aMethod: IMethodDefinition);
  end;
  
implementation

method ProfileAspect.HandleImplementation(aServices: IServices; aMethod: IMethodDefinition);
begin
  if aMethod.Virtual = VirtualMode.Abstract then exit;
  if aMethod.Empty then exit;
  if aMethod.Owner.TypeKind = TypeDefKind.Interface then exit;
  if aMethod.Name.StartsWith("get_") then exit;
  if aMethod.Name.StartsWith("set_") then exit;
  if aMethod.Name.StartsWith("add_") then exit;
  if aMethod.Name.StartsWith("remove_") then exit;
  if not aServices.IsDefined('PROFILE') then begin
    if not fShownWarning then begin
      aServices.EmitHint('Profiling aspect used but PROFILE not defined, aspect will be ignored');
    end;
    fShownWarning := true;
    exit;
  end;

  var lType := aServices.GetType('RemObjects.Profiler.RemObjectsProfiler');
  var lName := aMethod.Owner.Name+'.'+aMethod.Name;
  aMethod.SurroundMethodBody(
    new StandaloneStatement(new ProcValue(new TypeValue(lType), 'Enter', new DataValue(lName))),
    new StandaloneStatement(new ProcValue(new TypeValue(lType), 'Exit', new DataValue(lName))),
    SurroundMethod.Always
  );
end;

end.
