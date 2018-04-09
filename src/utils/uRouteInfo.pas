unit uRouteInfo;

interface
uses
  System.SysUtils,
  System.Variants,
  System.Rtti,
  IdContext,
  IdGlobal,
  IdCustomHTTPServer,
  System.Classes,
  System.JSON,
  IdHTTPServer,
  uROMiddlewaresWS,
  uClssResource,
  System.Generics.Collections, IWSystem;

type

    {-- Responsavel por guardar metadados da requisicao corrente --}

    TParamsValue = Array of TValue;

    TRouteInfo = class
    private
      FQualifiedClassName : String;
      FMethod : String;
      FRootRoute: String;
      FBody : String;
      FVerbHTTP : String;
      FResources : TParamsValue;
      FToken : String;
      FFullResource : String;
      FResourceIndex : integer;

      procedure isPost(ABody : TStream; AResources: String; AListOfResources: TList<TResourceInfo>);
      procedure isGet(AResources : String; AListOfResources: TList<TResourceInfo>);
    public
      property QualifiedClassName : String          read FQualifiedClassName;
      property Method             : String          read FMethod;
      property RootRoute          : String          read FRootRoute;
      property Resources          : TParamsValue    read FResources;
      property Body               : String          read FBody                write FBody;
      property VerbHTTP           : String          read FVerbHTTP            write FVerbHTTP;
      property Token              : String          read FToken               write FToken;
      property ResourceIndex      : integer         read FResourceIndex;
      property FullResource       : String          read FFullResource;

      constructor Create(ARequestInfo : TidHTTPRequestInfo; AListOfResources : TList<TResourceInfo>);
      destructor Destroy; override;
    end;

implementation

{ TRouteInfo }

constructor TRouteInfo.Create(ARequestInfo: TidHTTPRequestInfo; AListOfResources : TList<TResourceInfo>);
var
  I : integer;
begin
      for I := 0 to ARequestInfo.RawHeaders.Count -1 do
         begin
            if ARequestInfo.RawHeaders[i].Contains('Authorization') then
            begin
               // SEPARO O "Authorization: " para pegar o token
               Self.FToken :=  ARequestInfo.RawHeaders[i].Split([':'])[1].Replace(' ', '');
               Break;
            end;
         end;


      if ARequestInfo.Command = 'POST' then
      begin
         Self.isPost(ARequestInfo.PostStream, ARequestInfo.URI, AListOfResources);
      end;

      if ARequestInfo.Command = 'GET' then
      begin
         Self.isGet(ARequestInfo.URI, AListOfResources);
      end;

      // recolho a rota completa do recurso
     FFullResource := '/' + FMethod;
     for I := 0 to Length(FResources)-1 do
       begin
           FFullResource := FFullResource + '/' + FResources[i].AsString;
       end;
       FFullResource := gsAppPath + FFullResource;
end;

destructor TRouteInfo.Destroy;
begin
  inherited;
end;

procedure TRouteInfo.isGet(AResources: String; AListOfResources: TList<TResourceInfo>);
var
  I : integer;
  sAux : string;
  arrResources : TArray<String>;
  sMethod : String;
  Value : TParamsValue;
  bRouteFind : Boolean;
  sQualifiedClassName : String;
  Alist : TList<TResourceInfo>;
begin
    bRouteFind := False;

    Self.FQualifiedClassName := '';
    Self.FMethod := '';

    sAux := AResources;

    Alist := AListOfResources;

    for I := 0 to Alist.Count -1 do
    begin
         AResources := AResources.Replace(Alist[i].Route, '', []);
         if AResources <> sAux then
         begin
            arrResources := AResources.Split(['/']);
            Self.FRootRoute := Alist[i].Route;
            sQualifiedClassName := Alist[i].ClassView.QualifiedClassName; // SETANDO O NOME DA CLASSE SELECIONADA
            Self.FResourceIndex := i;
            bRouteFind := True;
            Break;
         end;
    end;

    if bRouteFind then // se uma rota foi encontrada, processar os dados da URI
    begin
        try
            if Length(arrResources) > 0 then
              sMethod := arrResources[0]; // PEGANDO A POSICAO 0 SUBTENDENDO-SE SER O NOME DO METODO

        except
           exit;
        end;
        if Length(arrResources) > 1 then // se houverem recursos na rota, extrai-los para serem executados pelo metodo
        begin
            SetLength(Value, Length(arrResources)-1); // SETANDO TAMANHO DO ARRAY DE VALORES DE ACORDO COM A QTD DOS RECURSOS
            for I := 0 to Length(arrResources)-2 do   // populando o array de parametros ignorando a posicao 0
            begin
                 Value[i] := arrResources[i+1];
            end;
        end;
        Self.FMethod := sMethod;
        Self.FResources := Value;
        Self.FQualifiedClassName := sQualifiedClassName;
        Self.VerbHTTP := 'GET';
    end;
end;

procedure TRouteInfo.isPost(ABody: TStream; AResources: String; AListOfResources: TList<TResourceInfo>);
var
 sPostData : string;  // O CORPO PURO RECEBIDO DA REQUISICAO
 sValue : string; //O VALOR CORRENTE DO OBJETO JSON RECEBIDO
 oJSPost : TJSONObject;
 params : TParamsValue; // RETORNO CONTENDO OS PARAMETROS EXTRAIDOS
 i: integer;
 arrURIs : TArray<string>;
 sMethod : String;
 sURIClean : String;
 sQualifiedNameClass : String;
begin

    arrURIs := AResources.Split(['/']);
    sMethod  := arrURIs[Length(arrURIs)-1];

    arrURIs[Length(arrURIs)-1] := '';

    sURIClean := ''.Join('/', arrURIs);

    if Assigned(ABody) then
    begin
        ABody.Position := 0;
        sPostData := ReadStringFromStream(ABody);

        ojsPost := TJSONObject.ParseJSONValue(sPostData) as TJSONObject;
        if ojsPost <> nil then
        begin
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
    end;

    for i := 0 to AListOfResources.Count -1 do
    begin
        if AListOfResources[i].Route = sURIClean then
        begin
            Self.FQualifiedClassName := AListOfResources[i].ClassView.QualifiedClassName;
            Self.FResourceIndex      := i;
        end;
    end;

    Self.FRootRoute := sURIClean;
    Self.FMethod := sMethod;
    Self.FResources := params;
    Self.VerbHTTP := 'POST';
    Self.Body := sPostData;
end;

end.

