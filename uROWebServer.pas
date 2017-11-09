unit uROWebServer;

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
var
a : tclass;
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
  sPostData, sResult : string;
  ojsPost : TJSONObject;
  params : array of TValue;
  i : integer;
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
                  params[i] := ojsPost.Pairs[i].JsonValue.Value;
               end;
               sResult := ojsPost.ToString;
           finally
               ojsPost.Free;
               //streamData.Free;  // NAO POSSO DAR FREE, POIS SEU PONTEIRO REFERENCIA UM OBJETO DE ARequestInfo
           end;

       end;
  end;


  sURIClass  := ARequestInfo.URI.Split(['/'])[1];
  sURIMethod := ARequestInfo.URI.Split(['/'])[2];
  sQualifiedNameClass := Self.FListOfRecursos.Values[sURIClass];



  sResult := Self.ExecRecurso(sURIClass,sURIMethod, params);



  if sQualifiedNameClass.IsEmpty then
      AResponseInfo.ContentText := 'uris e classes disponiveis: ' + #13 + Self.FListOfRecursos.Text
  else
      AResponseInfo.ContentText := sResult;



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
