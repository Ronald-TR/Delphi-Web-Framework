unit WQViewTest;

interface

uses uClssViewBase;
type
    TWQTeste = class(TRView)
      private
      public
        [TContentType('text/html')]
        function echohtml(s : string): string;

        [TContentType('application/json')]
        function echojson(s : string): string;
    end;
implementation

uses
  System.SysUtils, System.Classes, System.JSON;

{ TWQTeste }

function TWQTeste.echohtml(s: string): string;
begin
  Result := '<p>echo <strong>' + s + '</strong></p> '
            + '<a>For route: ' + Self.RouteOperationalContext.Method + '</a>';
end;

function TWQTeste.echojson(s: string): string;
var
  sMsg : string;
  oJSMsg : TJSONObject;
begin
  oJSMsg := TJSONObject.Create;
  try
      oJSMsg.AddPair('msg', 'echo ' + s)
            .AddPair('route', Self.RouteOperationalContext.Method);

      Result := oJSMsg.ToJSON;
  finally
      oJSMsg.Free;
  end;
end;

initialization
  RegisterClass(TWQTeste);

end.
