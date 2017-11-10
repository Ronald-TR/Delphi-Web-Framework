unit u_UtilsWebServer;

interface

uses uROWebServer, System.Rtti, System.Classes;

function RenderTemplate( PathFile : string; params : array of TValue) : string;

implementation

function RenderTemplate( PathFile : string; params : array of TValue) : string;
var
  sHTML : TStringList;
begin
     sHTML := TStringList.Create;
     try
        sHTML.LoadFromFile(PathFile);
        Result := sHTML.Text;
     finally
        sHTML.Free;
     end;
end;

end.
