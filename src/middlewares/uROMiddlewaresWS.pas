unit uROMiddlewaresWS;

 {
    PARA CRIAR SEU PROPRIO MIDDLEWARE, CRIE UMA CLASSE QUE POSSUA IROMiddleware
    COMO ANCESTRAL E IMPLEMENTE SEU METODO VALIDATE ( NÃO ESQUECENDO DA ASSINATURA OVERRIDE);

    == Tenha TMiddlewareToken como exemplo ==
 }
interface
uses
  Bcl.Jose.Core.JWT,
  Bcl.Jose.Core.Builder, Bcl.Jose.Core.JWK, System.Classes, SysUtils;
type
  // INTERFACES
  IROMiddleware = interface;
  IMiddlewareToken = interface;

  IROMiddleware = interface
      function Validate(ARequestHeaders : TStringList): boolean;
      //function TokenObject : TJWT;
  end;

  IMiddlewareToken = interface
     function TokenObject : TJWT;
  end;

  TROMiddleware = class(TInterfacedObject, IROMiddleware)
  protected
     FToken : String;
     FKey : String;
  public
     constructor Create;
     destructor Destroy; override;

     function Validate(ARequestHeaders : TStringList): boolean; virtual;
     property Token: string   read FToken   write FToken;
  end;

  // default token middleware validator

  TMiddlewareToken = class(TROMiddleware)
  private
     FoKey : TJWK;
     FTokenObject : TJWT;
  public
      function Validate(ARequestHeaders : TStringList): boolean; override;
      function TokenObject : TJWT;

      constructor Create(AKEY : string); overload;
      constructor Create(AKEY, AToken : string); overload;

      class function New(AKEY : string) : IROMiddleware; overload;
      class function New(AKEY, AToken : string): IROMiddleware; overload;
      destructor Destroy; override;
  end;

implementation

uses
  Bcl.Jose.Core.JWA, Bcl.Jose.Types.Bytes;

{ TMiddlewareToken }

constructor TMiddlewareToken.Create(AKEY, AToken: string);
begin
     FToken := AToken;
     FKey := AKEY;
     FTokenObject := TJOSE.Verify(TJWK.Create(FKEY), AToken);
end;

constructor TMiddlewareToken.Create(AKEY: string);
begin
     Self.FKey := AKEY;
end;

destructor TMiddlewareToken.Destroy;
begin
     Inherited Destroy;
     if Self.FTokenObject <> nil then
     begin
        FreeAndNil(FTokenObject);
        FreeAndNil(FoKey);
     end;
end;

class function TMiddlewareToken.New(AKEY: string): IROMiddleware;
begin
     Result := Self.Create(AKEY);
end;

class function TMiddlewareToken.New(AKEY, AToken: string): IROMiddleware;
begin
    Result := Self.Create(AKEY, AToken);
end;

function TMiddlewareToken.Validate(ARequestHeaders : TStringList): boolean;
var
  oToken : TJWT;
  oKey   : TJWK;
  sToken : String;
  i : integer;
begin
    Result := False;
    for I := 0 to ARequestHeaders.Count -1 do
    begin
      if ARequestHeaders[i].Contains('Authorization') then
      begin
         // SEPARO O "Authorization: " para pegar o token
         sToken :=  ARequestHeaders[i].Split([':'])[1].Replace(' ', '');
         Break;
      end;
    end;

    FToken := sToken;

    if sToken = '' then
       Exit;

    try
       oKey := TJWK.Create(Self.FKey);

       oToken := TJOSE.Verify(oKey, sToken);

       if oToken <> nil then
       begin
          Result := oToken.verified and (oToken.Claims.Expiration > Now);
       end;
    finally
       oToken.Free;
       oKey.Free;
    end;

end;

function TMiddlewareToken.TokenObject: TJWT;
begin
     if not (FTokenObject = nil) then
     begin
         Self.FTokenObject.Free;
         Self.FoKey.Free;
     end;

     FoKey := TJWK.Create(FKEY);
     FTokenObject :=  TJOSE.Verify(FoKey, Self.FToken);

     Result := Self.FTokenObject;
end;

{ TROMiddleware }

constructor TROMiddleware.Create;
begin

end;

destructor TROMiddleware.Destroy;
begin

  inherited;
end;

function TROMiddleware.Validate(ARequestHeaders: TStringList): boolean;
begin
      // METODO ANCESTRAL PARA OS MIDDLEWARES
     // pass
end;

end.


