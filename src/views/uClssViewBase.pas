unit uClssViewBase;

interface
uses
system.Rtti, uRouteInfo, System.Classes;
type

  { CUSTOM ATTRIBUTES }
  TContentType = class(TCustomAttribute)
    private
       FContentType : String;
    public
       property ContentType : String read FContentType write FContentType;

       constructor Create(AContentType : String);
       destructor Destroy; override;
  end;

  { VIEW UTILITIES }
  TViewResult = record
  private
    FContentType: String;
    FText: String;
  public
     property Text : String read FText write FText;
     property ContentType : String read FContentType write FContentType;

     constructor Create(AText, AContentType : String);

  end;

  { DEFAULT ANCESTOR }
  TRView = class(TPersistent)
  private
    FContext : TRouteInfo;
  public
    property RouteOperationalContext : TRouteInfo read FContext write FContext;

    constructor Create;
    destructor Destroy; override;
  end;

implementation


constructor TRView.Create;
begin

end;

destructor TRView.Destroy;
begin

  inherited;
end;

{ TContentType }

constructor TContentType.Create(AContentType: String);
begin
    Self.FContentType := AContentType;
end;

destructor TContentType.Destroy;
begin

  inherited;
end;

{ TViewResult }

constructor TViewResult.Create(AText, AContentType: String);
begin
    Self.FContentType := AContentType;
    Self.FText        := AText;
end;

end.
