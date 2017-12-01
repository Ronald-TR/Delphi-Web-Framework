unit uROWebServer;
{
  Ronald Rodrigues Farias
  last ver..: 09/11/2017
}
interface
uses
  idHTTP,
  IdHTTPServer,
  System.Classes,
  Generics.Collections,
  Vcl.Dialogs,
  System.Rtti,
  IdContext, IdCustomHTTPServer,
  System.SysUtils,
  System.Variants,
  IdGlobal, System.JSON;
type
    TROWebServer = class
    strict private
      class var FInstancia : TROWebServer;
    private
      FidServer : TidHTTPServer;
      FListOfRecursos : TStringList;
      procedure IdHTTPServer1CommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);

      constructor Create;
      destructor Destroy; override;
    public
      class function GetInstance: TROWebServer;
      class procedure ReleaseInstance;

      function ExecRecurso(a_classname, a_metodo : string; a_params : array of TValue): string;
      procedure StartServer;
      procedure AddRecurso(a_Recurso : TClass ; a_URI: string);


    end;

implementation

{ TROWebServer }

procedure TROWebServer.AddRecurso(a_Recurso : TClass ; a_URI: string);
begin
   FListOfRecursos.AddPair(a_URI, a_Recurso.QualifiedClassName);
end;

constructor TROWebServer.Create;
begin
   Self.FListOfRecursos := TStringList.Create;
   Self.FidServer := TIdHTTPServer.Create(nil);
   Self.FidServer.DefaultPort := 8000;
   Self.FidServer.OnCommandGet := Self.IdHTTPServer1CommandGet;
end;

destructor TROWebServer.Destroy;
begin
   Self.FidServer.Active := False;
   Self.FidServer.Free;
   Self.FListOfRecursos.Free;
  inherited;
end;

class function TROWebServer.GetInstance: TROWebServer;
begin
    if not Assigned(Self.FInstancia) then
      Self.FInstancia := TROWebServer.Create;
    Result := Self.FInstancia;

end;

procedure TROWebServer.IdHTTPServer1CommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  sQualifiedNameClass, sURIClass, sURIMethod : string;
  streamData : TStream;
  sPostData  : string;
  sResult    : string;
  ojsPost    : TJSONObject;
  params     : array of TValue;
  i          : integer;
  array_URIs : TArray<string>;
  sValue     : string;
begin
    if ARequestInfo.Command = 'POST' then
    begin
         streamData := ARequestInfo.PostStream;

         if Assigned(streamData) then
         begin
             streamData.Position := 0;
             sPostData := ReadStringFromStream(streamData);

             ojsPost := TJSONObject.ParseJSONValue(sPostData) as TJSONObject;
             try
                 SetLength(params, ojsPost.Count);
                 for i:= 0 to ojsPost.Count-1 do
                 begin
                     { VERIFICO SE O VALOR DO PAIR É UM OBJETO OU UM DADO SIMPLES }
                     sValue := ojsPost.Pairs[i].JsonValue.Value;

                     if sValue.IsEmpty then
                     begin
                        sValue := ojsPost.Pairs[i].JsonValue.ToString
                     end;
                     params[i] := sValue;
                 end;
             finally
                 ojsPost.Free;
             end;
         end;
    end;

    array_URIs := ARequestInfo.URI.Split(['/']);
    sURIMethod  := array_URIs[Length(array_URIs)-1];

    array_URIs[Length(array_URIs)-1] := '';

    sURIClass := ''.Join('/', array_URIs);

    sQualifiedNameClass := Self.FListOfRecursos.Values[sURIClass];

    if sQualifiedNameClass.IsEmpty then
    begin
        AResponseInfo.ContentText := 'uris e classes disponiveis: ' + #13 + Self.FListOfRecursos.Text;
        exit;
    end;

    AResponseInfo.ContentText := Self.ExecRecurso(sURIClass,sURIMethod, params);

end;

class procedure TROWebServer.ReleaseInstance;
begin
     if Assigned(Self.FInstancia) then
       Self.FInstancia.Free;
end;

procedure TROWebServer.StartServer;
begin
    Self.FidServer.Active := True;
end;

function TROWebServer.ExecRecurso(a_classname, a_metodo : string; a_params : array of TValue): string;
var
  rtContext : TRttiContext;
  aObj : TObject;
begin
    rtContext := TRttiContext.Create;
    aObj := rtContext.FindType(Self.FListOfRecursos.Values[a_classname]).AsInstance.MetaclassType.Create;
    try
      result := rtContext.GetType(aObj.ClassType).GetMethod(a_metodo).Invoke(aObj, a_params).ToString;
    finally
      aObj.Free;
      rtContext.Free;
    end;
end;

end.
