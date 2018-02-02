unit uROMiddlewaresWS;

 {
    PARA CRIAR SEU PROPRIO MIDDLEWARE, CRIE UMA CLASSE QUE HERDE DE TROMIDDLEWARE
    E IMPLEMENTE SEU METODO VALIDATE ( NÃO ESQUECENDO DA ASSINATURA OVERRIDE);
 }
interface
uses
  Bcl.Jose.Core.JWT,
  Bcl.Jose.Core.Builder, Bcl.Jose.Core.JWK, System.Classes, SysUtils;
type
  IROMiddleware = interface
      function Validate(ARequestHeaders : TStringList): boolean;
  end;

  TROMiddleware = class(TInterfacedObject, IROMiddleware)
     function Validate(ARequestHeaders : TStringList): boolean; virtual;
  end;

  // default token middleware validator
  TMiddlewareToken = class(TROMiddleware)
  private
     FToken : String;
     FKey : String;
     FTokenObject : TJWT;
  public
      function Validate(ARequestHeaders : TStringList): boolean; override;
      function TokenObject : TJWT;

      constructor Create(AKEY : string); overload;
      constructor Create(AKEY, AToken : string); overload;

      class function New(AKEY : string) : IROMiddleware; overload;
      class function New(AKEY, AToken : string): IROMiddleware; overload;
      destructor Destroy;
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
     Self.FTokenObject.Free;
end;

class function TMiddlewareToken.New(AKEY: string): IROMiddleware;
begin
     Result := Self.Create(AKEY);
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
         // SEPARO O "Authorization: 1234123123" para pegar o token
         sToken :=  ARequestHeaders[i].Split([':'])[1].Replace(' ', '');
         Break;
      end;
    end;

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

class function TMiddlewareToken.New(AKEY, AToken: string): IROMiddleware;
begin
    Result := Self.Create(AKEY, AToken);
end;

function TMiddlewareToken.TokenObject: TJWT;
begin
     Result := Self.FTokenObject;
end;

{ TROMiddleware }

function TROMiddleware.Validate(ARequestHeaders: TStringList): boolean;
begin
      // METODO ANCESTRAL PARA OS MIDDLEWARES
     // pass
end;

end.
