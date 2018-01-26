unit uEcho;

interface

uses u_UtilsWebServer, uROWebServer;
type
  TEcho = class
  private
    FNome: string;
  public
    function echoteste: string;
    function echo2: string;
    function index: string;
    property Nome : string read FNome write FNome;
    constructor Create;
  end;
implementation

{ TEcho }

constructor TEcho.Create;
begin
FNome := 'ECHO Classe';
end;

function TEcho.echo2: string;
begin
  Result := 'echo 2';
end;

function TEcho.echoteste: string;
begin
  Result := 'Teste echo Web Framework';
  TROWebServer.GetInstance.ResponseInfo.ContentType := 'text/html'; // DIGO QUAL O FORMATO DA RESPOSTA
end;

function TEcho.index: string;
begin
  Result := RenderTemplate('templates/index.html', 'teste', Self);
  TROWebServer.GetInstance.ResponseInfo.ContentType := 'text/html'; // DIGO QUAL O FORMATO DA RESPOSTA
end;

end.
