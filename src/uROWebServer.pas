unit uROWebServer;
{
  Ronald Rodrigues Farias
}
interface
uses
  idHTTP,
  IdHTTPServer,
  idSync,
  System.Classes,
  Generics.Collections,
  System.Rtti,
  IdContext, IdCustomHTTPServer,
  System.SysUtils,
  System.Variants,
  IdGlobal, System.JSON,
  IWSystem,
  Winapi.ActiveX,

  // external uses
  uRouteInfo,
  uROMiddlewaresWS,
  u_UtilsWebServer,
  uClssResource;
type

    TROWebServer = class
    strict private
      class var FInstancia : TROWebServer;
    private
      { -- singleton hearth -- }
      FidServer : TidHTTPServer;

      { -- mainteins the business rule of the microservice -- }
      FROMiddlewares : TStringList;
      FResources : TThreadList<TResourceInfo>;

      FExceptionType : TROWebServerExceptionType;

      { -- MAIN METHOD -- }
      procedure IdHTTPServerCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);

      procedure IDHTTPServerException(AContext: TIdContext;
      AException : Exception);

      procedure OnParseAuthentication(AContext: TIdContext; const AAuthType,
      AAuthData: String; var VUsername, VPassword: String; var VHandled: Boolean);

      constructor Create;
      destructor Destroy; override;

      function MiddlewareValidator(ARouteInfo : TRouteInfo; ARequestInfo : TIdHTTPRequestInfo) : Boolean;
      function isMiddlewareExists(ARouteInfo : TRouteInfo): Boolean;
      procedure OnException(AContext: TIdContext; AException: Exception);

    public
      procedure InitResourcesFromConfigFile(AFileName : String);
      procedure ResetPort(ADefaultPort: integer = 8011);

      class function GetInstance: TROWebServer;
      class procedure ReleaseInstance;


      procedure StartServer;

      procedure SetExceptionMsgType(AROMsgExceptionType :  TROWebServerExceptionType);

      procedure AddResource(a_Recurso : TClass ; a_URI: string); overload;
      procedure AddMiddleware(AClass : TClass; AROMiddleware: TROMiddleware);
    end;

implementation

{ TROWebServer }

procedure TROWebServer.AddResource(a_Recurso : TClass ; a_URI: string);
begin
   FResources.Add(TResourceInfo.Create(A_Recurso, a_URI));
end;

constructor TROWebServer.Create;
begin
      Self.FResources := TThreadList<TResourceInfo>.Create;
      Self.FROMiddlewares  := TStringList.Create;
      Self.FROMiddlewares.OwnsObjects := True;
      Self.FidServer       := TIdHTTPServer.Create(nil);
      Self.ResetPort(8002);

      Self.FidServer.OnCommandGet := Self.IdHTTPServerCommandGet;
      Self.FidServer.OnException  := Self.IdHTTPServerException;
      Self.FidServer.OnException  := Self.OnException;
      Self.SetExceptionMsgType(JSONMsg);


      Self.FidServer.OnParseAuthentication :=  Self.OnParseAuthentication;
end;

destructor TROWebServer.Destroy;
begin
   Self.FidServer.Active := False;
   Self.FidServer.Free;
   Self.FROMiddlewares.Free;

   Self.FResources.Free;
  inherited;
end;

class function TROWebServer.GetInstance: TROWebServer;
begin
    if not Assigned(Self.FInstancia) then
      Self.FInstancia := TROWebServer.Create;
    Result := Self.FInstancia;
end;

procedure TROWebServer.IdHTTPServerCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  oRouteInfo : TRouteInfo;
  sMsgMiddlewareError : string;
  sResponse : String;
  oListOfResources : TList<TResourceInfo>;
begin
    oListOfResources := FResources.LockList;
    FResources.UnlockList;

    oRouteInfo := TRouteInfo.Create(ARequestInfo, oListOfResources);

    case FExceptionType of
         HTMLMsg : AResponseInfo.ContentType := 'text/html';
         JSONMsg : AResponseInfo.ContentType := 'application/json';
    end;
    try
        TThread.Synchronize(nil,
        procedure
        begin
           if isMiddlewareExists(oRouteInfo) then
           begin
               if not MiddlewareValidator(oRouteInfo, ARequestInfo) then
               begin
                   sMsgMiddlewareError := '{"route": "aroute", "error": "falha na requisicao, bloqueio por middleware"}'
                                          .Replace('aroute', oRouteInfo.RootRoute.Replace('/', ''));

                   raise EIdHTTPServerError.Create(sMsgMiddlewareError);
               end;
           end;
        end);

        // CASO A URL NÃO SEJA ENCONTRADA, LISTA TODAS AS DISPONIVEIS
        if (oRouteInfo.QualifiedClassName.IsEmpty) or ((oRouteInfo.RootRoute = '/') and (oRouteInfo.Method.IsEmpty)) then
        begin
            sResponse := get_index_msg(oListOfResources, Self.FExceptionType);
            exit;
        end;

        // RETORNA ARQUIVOS ESTATICOS DE ESTILIZACAO
        if oRouteInfo.Method = 'static' then
        begin
            with load_static_file(oRouteInfo) do
            begin
                sResponse := Text;
                AResponseInfo.ContentType := ContentType;
            end;
            exit;
        end;

        // A RESPOSTA DO RECURSO SOLICITADO
        AResponseInfo.CharSet := 'utf-8';
        try
            CoInitialize(nil);
            try
               with call_method(oRouteInfo, oListOfResources) do
               begin
                   sResponse := Text;
                   AResponseInfo.ContentType := ContentType;
               end;
            except on e: Exception do
              begin
                  sResponse := get_error_msg(oRouteInfo.RootRoute, e.Message,
                        oListOfResources[oRouteInfo.ResourceIndex].ClassView,
                        Self.FExceptionType);

                  raise EIdHTTPServerError.Create(sResponse);
              end;
            end;
        finally
            CoUninitialize;
        end;
    finally
      oRouteInfo.Free;
      AResponseInfo.ContentText := sResponse;
    end;
end;

procedure TROWebServer.IDHTTPServerException(AContext: TIdContext;
  AException: Exception);
begin
   //showmessage(AException.Message);
end;

procedure TROWebServer.InitResourcesFromConfigFile(AFileName: String);
var
  slRoutes          : TStringList;
  oJSServiceConfig  : TJSONObject;
  oJSArrRoutes      : TJSONArray;
  oJSRoute          : TJSONObject;
  rtContext         : TRttiContext;
  sClassName,
  sRoute            : String;
  oClass            : TClass;
  port, i           : integer;
begin

    slRoutes := TStringList.Create;
    try
       slRoutes.LoadFromFile(gsAppPath + AFileName);
       oJSServiceConfig := TJSONObject.ParseJSONValue(slRoutes.Text) as TJSONObject;
    finally
       slRoutes.Free;
    end;

    rtContext := TRttiContext.Create;
    try
        port := oJSServiceConfig.GetValue('port').Value.ToInteger;
        Self.ResetPort(port);
        oJSArrRoutes := oJSServiceConfig.GetValue('routes') as TJSONArray;
        for i := 0 to oJSArrRoutes.Count-1 do
        begin
           oJSRoute   := oJSArrRoutes.Items[i] as TJSONObject;
           sClassName := oJSRoute.GetValue('class_name').Value;
           sRoute     := oJSRoute.GetValue('route').Value;

           try
              oClass := rtContext.FindType(sClassName).AsInstance.MetaclassType;
           except
              raise Exception.Create('Classe nao existe no contexto da aplicação');
           end;
           Self.AddResource(oClass, sRoute);
        end;
    finally
        oJSServiceConfig.Free;
        rtContext.Free;
    end;

end;

class procedure TROWebServer.ReleaseInstance;
begin
    if Assigned(Self.FInstancia) then
       Self.FInstancia.Free;
end;

procedure TROWebServer.ResetPort(ADefaultPort: integer);
begin
    Self.FidServer.DefaultPort := ADefaultPort;
end;

procedure TROWebServer.SetExceptionMsgType(
  AROMsgExceptionType: TROWebServerExceptionType);
begin
    FExceptionType := AROMsgExceptionType;
end;

procedure TROWebServer.StartServer;
begin
    Self.FidServer.Active := True;
end;

function TROWebServer.MiddlewareValidator(ARouteInfo : TRouteInfo; ARequestInfo : TIdHTTPRequestInfo): Boolean;
var
 indexOfMiddleware : integer;
begin

    Result := False;

    indexOfMiddleware := FROMiddlewares.IndexOf(ARouteInfo.QualifiedClassName);
    if indexOfMiddleware <> -1 then
    begin
        try
           with TROMiddleware(FROMiddlewares.Objects[indexOfMiddleware]) do
           begin
               Result := Validate(ARequestInfo.RawHeaders);
               ARouteInfo.Token := Token;
           end;
        except
            // pass
        end;
    end;

end;

procedure TROWebServer.OnException(AContext: TIdContext; AException: Exception);
begin
//     AException.Message := AException.Message + 'blabla';
end;

procedure TROWebServer.OnParseAuthentication(AContext: TIdContext;
  const AAuthType, AAuthData: String; var VUsername, VPassword: String;
  var VHandled: Boolean);
begin
//     showmessage('ver o que fazer aqui');
      VHandled := True;
end;

procedure TROWebServer.AddMiddleware(AClass : TClass; AROMiddleware: TROMiddleware);
begin
    Self.FROMiddlewares.AddObject(AClass.QualifiedClassName, AROMiddleware);
end;

function TROWebServer.isMiddlewareExists(ARouteInfo : TRouteInfo): Boolean;
var
 i : integer;
begin
    Result := False;
    for i :=0 to FROMiddlewares.Count-1 do
    begin
        if FROMiddlewares[i].Contains(ARouteInfo.QualifiedClassName) then
        begin
           Result := True;
           Break;
        end;
    end;
end;

end.


