unit uROWebServer;
{
  Ronald Rodrigues Farias
  last ver..: 31/01/2018
}
interface
uses
  idHTTP,
  IdHTTPServer,
  System.Classes,
  Generics.Collections,
  System.Rtti,
  IdContext, IdCustomHTTPServer,
  System.SysUtils,
  System.Variants,
  IdGlobal, System.JSON,
  uROMiddlewaresWS;
type

    TParamsValue = Array of TValue;

    TRouteInfo = record
      FQualifiedClassName : String;
      FMethod : String;
      FResources : TParamsValue;
    end;

    TROWebServer = class
    strict private
      class var FInstancia : TROWebServer;
    private
      FidServer : TidHTTPServer;
      FListOfRecursos : TStringList;
      FROMiddlewares : TStringList;

      FRequestInfo : TIdHTTPRequestInfo;
      FResponseInfo : TIdHTTPResponseInfo;

      procedure IdHTTPServerCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);

      procedure IDHTTPServerException(AContext: TIdContext;
      AException : Exception);

      procedure OnParseAuthentication(AContext: TIdContext; const AAuthType, AAuthData: String; var VUsername, VPassword: String; var VHandled: Boolean);

      constructor Create;
      destructor Destroy; override;

      function ifPost(ABody : TStream; AResources: String): TRouteInfo;
      function ifGet(AResources : String): TRouteInfo;
      function ExtractMetaDataFromRequest(ARequest : TIdHTTPRequestInfo): TRouteInfo;

      function MiddlewareValidator(ARouteInfo : TRouteInfo) : Boolean;
      function isMiddlewareExists(ARouteInfo : TRouteInfo): Boolean;

    public
      function ResponseInfo: TIdHTTPResponseInfo;

      procedure ResetPort(ADefaultPort: integer = 8011);

      class function GetInstance: TROWebServer;
      class procedure ReleaseInstance;

      function ExecRecurso(a_classname, a_metodo : string; a_params : array of TValue): string;
      procedure StartServer;

      procedure AddRecurso(a_Recurso : TClass ; a_URI: string); overload;
      procedure AddMiddleware(AClass : TClass; AROMiddleware : TROMiddleware);
    end;

implementation

{ TROWebServer }

procedure TROWebServer.AddRecurso(a_Recurso : TClass ; a_URI: string);
begin
   FListOfRecursos.AddPair(a_URI, a_Recurso.QualifiedClassName);
end;

function TROWebServer.ResponseInfo: TIdHTTPResponseInfo;
begin
    Result := FResponseInfo;
end;


constructor TROWebServer.Create;
begin
   Self.FListOfRecursos := TStringList.Create;
   Self.FROMiddlewares  := TStringList.Create;
   Self.FROMiddlewares.OwnsObjects := True;
   Self.FidServer       := TIdHTTPServer.Create(nil);
   Self.ResetPort(8002);
   Self.FidServer.OnCommandGet := Self.IdHTTPServerCommandGet;
   Self.FidServer.OnException  := Self.IdHTTPServerException;


   Self.FidServer.OnParseAuthentication :=  Self.OnParseAuthentication;
  // Self.FidServer.OnParseAuthentication :=  nil;
end;

destructor TROWebServer.Destroy;
begin
   Self.FidServer.Active := False;
   Self.FidServer.Free;
   Self.FListOfRecursos.Free;
   Self.FROMiddlewares.Free;
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
  sQualifiedNameClass, sURIClass, sURIMethod : string;
  streamData : TStream;
  sPostData  : string;
  ojsPost    : TJSONObject;
  params     : array of TValue;
  i          : integer;
  array_URIs : TArray<string>;
  sValue : string;
  oRouteInfo : TRouteInfo;
begin
    FResponseInfo := AResponseInfo;
    FRequestInfo  := ARequestInfo;

    oRouteInfo := ExtractMetaDataFromRequest(ARequestInfo);

    if isMiddlewareExists(oRouteInfo) then
       if not MiddlewareValidator(oRouteInfo) then
          raise EIdHTTPServerError.Create('Bloqueio por Middleware');


    // CASO A URL NÃO SEJA ENCONTRADA, LISTA TODAS AS DISPONIVEIS
    if oRouteInfo.FQualifiedClassName.IsEmpty then
    begin
        AResponseInfo.CharSet := 'utf-8';
        AResponseInfo.ContentText := 'uris e classes disponiveis: <br>' + Self.FListOfRecursos.Text.Replace('\n', '<br>');

        exit;
    end;

    // A RESPOSTA DO RECURSO SOLICITADO

    AResponseInfo.ContentText := Self.ExecRecurso(oRouteInfo.FQualifiedClassName,oRouteInfo.FMethod, oRouteInfo.FResources);
    AResponseInfo.CharSet := 'utf-8';

end;

procedure TROWebServer.IDHTTPServerException(AContext: TIdContext;
  AException: Exception);
begin
    //AException.Message;
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

procedure TROWebServer.StartServer;
begin
    Self.FidServer.Active := True;
end;

// VÃO SER FUNÇÕES DE LIB PARA O WEB SERVICE
function TROWebServer.ExtractMetaDataFromRequest(
  ARequest: TIdHTTPRequestInfo): TRouteInfo;
var
  sResources : TStringList;
  params     : TParamsValue;
begin
      if ARequest.Command = 'POST' then
      begin
         Result := Self.ifPost(ARequest.PostStream, ARequest.URI);
      end;

      if ARequest.Command = 'GET' then
      begin
         Result := Self.ifGet(ARequest.URI);
      end;
end;

function TROWebServer.ifGet(AResources: String): TRouteInfo;
var
  I : integer;
  sAux : string;
  arrResources : TArray<String>;
  sMethod : String;
  Value : TParamsValue;
  bRouteFind : Boolean;
  sQualifiedClassName : String;
begin
    bRouteFind := False;

    Result.FQualifiedClassName := '';
    Result.FMethod := '';

    sAux := AResources;
    for I := 0 to FListOfRecursos.Count -1 do
    begin
         AResources := AResources.Replace(FListOfRecursos.Names[i], '');
         if AResources <> sAux then
         begin
            arrResources := AResources.Split(['/']);
            sQualifiedClassName := FListOfRecursos.ValueFromIndex[i]; // SETANDO O NOME DA CLASSE SELECIONADA
            bRouteFind := True;
            Break;
         end;
    end;

    if bRouteFind then // se uma rota foi encontrada, processar os dados da URI
    begin
        sMethod := arrResources[0]; // PEGANDO A POSICAO 0 SUBTENDENDO-SE SER O NOME DO METODO
        if Length(arrResources) > 1 then // se houverem recursos na rota, extrai-los para serem executados pelo metodo
        begin
        SetLength(Value, Length(arrResources)-1); // SETANDO TAMANHO DO ARRAY DE VALORES DE ACORDO COM A QTD DOS RECURSOS
            for I := 0 to Length(arrResources)-2 do   // populando o array de parametros ignorando a posicao 0
            begin
                 Value[i] := arrResources[i+1];
            end;
        end;
        Result.FMethod := sMethod;
        Result.FResources := Value;
        Result.FQualifiedClassName := sQualifiedClassName;
    end;
end;

function TROWebServer.ifPost(ABody: TStream; AResources: String): TRouteInfo;
var
 sPostData : string;  // O CORPO PURO RECEBIDO DA REQUISICAO
 sValue : string; //O VALOR CORRENTE DO OBJETO JSON RECEBIDO
 oJSPost : TJSONObject;
 params : TParamsValue; // RETORNO CONTENDO OS PARAMETROS EXTRAIDOS
 i: integer;
 array_URIs : TArray<string>;
 sURIMethod : String;
 sURIClass : String;
 sQualifiedNameClass : String;
begin

    array_URIs := AResources.Split(['/']);
    sURIMethod  := array_URIs[Length(array_URIs)-1];

    array_URIs[Length(array_URIs)-1] := '';

    sURIClass := ''.Join('/', array_URIs);

    if Assigned(ABody) then
    begin
        ABody.Position := 0;
        sPostData := ReadStringFromStream(ABody).Replace('"{', '{', [rfReplaceAll, rfIgnoreCase])
                                                     .Replace('}"', '}', [rfReplaceAll, rfIgnoreCase]);

        ojsPost := TJSONObject.ParseJSONValue(sPostData) as TJSONObject;
        try
            SetLength(params, ojsPost.Count);
            for i:= 0 to ojsPost.Count-1 do
            begin
                // VERIFICO SE O VALOR DO PAIR É UM OBJETO OU UM DADO SIMPLES
                sValue := ojsPost.Pairs[i].JsonValue.Value;

                if sValue.IsEmpty then
                begin
                   sValue := ojsPost.Pairs[i].JsonValue.ToString;
                end;

                params[i] := sValue;
            end;
        finally
            ojsPost.Free;
        end;
    end;
    Result.FQualifiedClassName := FListOfRecursos.Values[sURIClass];
    Result.FMethod := sURIMethod;
    Result.FResources := params;
end;

function TROWebServer.ExecRecurso(a_classname, a_metodo : string; a_params : array of TValue): string;
var
  rtContext : TRttiContext;
  aObj : TObject;
begin
    rtContext := TRttiContext.Create;
    aObj := rtContext.FindType(a_classname).AsInstance.MetaclassType.Create;
    try
       Result := rtContext.GetType(aObj.ClassType).GetMethod(a_metodo).Invoke(aObj, a_params).ToString;
    finally
       aObj.Free;
       rtContext.Free;
    end;
end;

function TROWebServer.MiddlewareValidator(ARouteInfo : TRouteInfo): Boolean;
var
   indexOfMiddleware : integer;

begin
    Result := False;
    indexOfMiddleware := FROMiddlewares.IndexOf(ARouteInfo.FQualifiedClassName);
    if indexOfMiddleware <> -1 then
    begin
       Result := TROMiddleware(FROMiddlewares.Objects[indexOfMiddleware]).
                      Validate(Self.FRequestInfo.RawHeaders);
    end;
end;

procedure TROWebServer.OnParseAuthentication(AContext: TIdContext;
  const AAuthType, AAuthData: String; var VUsername, VPassword: String;
  var VHandled: Boolean);
begin
   //   ('ver o que fazer aqui posteriormente');
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
        if FROMiddlewares[i] = ARouteInfo.FQualifiedClassName then
        begin
           Result := True;
           Break;
        end;
    end;
end;


end.
