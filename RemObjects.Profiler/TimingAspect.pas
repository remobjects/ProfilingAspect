namespace RemObjects.Profiler;

interface
uses
  RemObjects.Elements.Cirrus.*;

type
  [AttributeUsage(AttributeTargets.Class or AttributeTargets.Method)]
  TimingAspect = public class(IMethodImplementationDecorator)
  public
    method HandleImplementation(Services: IServices; aMethod: IMethodDefinition);
  end;
  
implementation

method TimingAspect.HandleImplementation(Services: IServices; aMethod: IMethodDefinition);
begin
  if aMethod.Virtual = VirtualMode.Abstract then exit;
  if aMethod.Empty then exit;
  if aMethod.Owner.TypeKind = TypeDefKind.Interface then exit;
  var lType := Services.GetType('RemObjects.Profiler.RemObjectsProfiler');
  var lName := aMethod.Owner.Name+'.'+aMethod.Name;
  aMethod.SurroundMethodBody(
    new StandaloneStatement(new ProcValue(new TypeValue(lType), 'Enter', new DataValue(lName))),
    new StandaloneStatement(new ProcValue(new TypeValue(lType), 'Exit', new DataValue(lName))),
    SurroundMethod.Always
  );
end;

end.
