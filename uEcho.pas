unit uEcho;

interface

uses u_UtilsWebServer;
type
  TEcho = class
    function echoteste: string;
    function index: string;
  end;
implementation

{ TEcho }

function TEcho.echoteste: string;
begin
  Result := 'Teste echo Web Framework';
end;

function TEcho.index: string;
begin
  Result := RenderTemplate('index.html', []);
end;

end.
