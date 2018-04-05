# Delphi-Web-Framework
*A Micro **Delphi** Web-Framework composed by an indy http listener and much Rtti*

Alternative to develop micro services web in delphi, without a bigger datasnap project or some additional component paid.

  ## New Features ##
  ***For 1.0 version***
  
  * Global RequestInfo and ResponseInfo Objects for the current transaction.
  * RESTful urls modelling support.
  * Middleware support.
  
  ### Global Context Objects: ###
  ```Delphi
    Self.RouteOperationalContext;
  // with the inherited from TWQViewBase Class, this object turn visible.
  ```
  Alternatively, you can do the same with the RequestInfo object.
  ### RESTful urls modelling: ###
    Now, you can rescue the resources of the url without declare variables explicity:
  ```Delphi
    with TROWebServer.GetInstance do
    begin
        AddResource(TWQExample, '/example/');
        StartServer;
    end;
  ```
  
  for an example class:
  ```Delphi
     type
     TWQExample = class
      [TContentType('application/json')]
      function examplecall(param1, param2 : string): string;
     end;
  ```  
  If the request method are GET, in the browser the user can do this:
  
  ```http://localhost:8000/example/examplecall/1/2```
  
  This says the web server to call the 'examplecall' method in the TWQExample class, using the "1" and "2" wich arguments.
  
  If the request method are POST, you must have to send a JSON object with a key for each argument in your method.
  ```
  {"param1": 1, "param2": 2}
  // the key names are irrelevant, fell free to call what you want, just the values will be used.
  ```
  The example above explain a valid body for a POST request in the same resource, but, without sending the params in the URL:
  
  ```http://localhost:8000/example/examplecall/```
  
  Using a valid JSON in the body request like the explained above. You will have the "same" behavior. Be carefull in how your class will be writted to follow the right behavior to GET or POST verbs.
  
  ### Middleware support* ###
  ***See the future helper for this section***
  
 Now you can write your own Middleware, for validate the request before the response be proccess in the server.
The framework brings a default Token Middleware validator, that you can use easily!
  ```Delphi
    with TROWebServer.GetInstance do
    begin
        AddResource(TWQExample, '/example/');
        
        AddMiddleware(TWQExample, TMiddlewareToken.Create('your_jwt_secret_key_here'));
        StartServer;
    end;
  ``` 
  Each time the TWQExample class is called in a request, the corresponding Middleware Object assigned will be called before,
  
  if the 'Validate' method of the Middleware returns True, then the request is free to continue, otherwise, the server will be raise an 
  EidHTTPProtocolException, returning a 500 error code and a "bloqueio por middleware" message.

## Using this you have a few resources very usefull  ## 
* **Instantly run**

  It's a singleton, so... you're be able to have a global Context of the current client in your application.
  
* **Easly publish resources**
  
  You just need to call the singleton in the Create routine of your application (or in some moment that you want)
  and assign the resources (that here will be your TClass type) wich you want to publish in your micro-service.
  
  **something like this:**
  
```Delphi
procedure TForm1.FormCreate(Sender: TObject);
begin
    with TROWebServer.GetInstance do
    begin
       AddResource(TWQEcho, '/');

       ResetPort(8000);
       SetExceptionMsgType(HTMLMsg);
       StartServer;
    end;
end;
```

* And easy call

![call_example](https://github.com/Ronald-TR/Delphi-Web-Framework/blob/master/call_example.png)

  The default port is **8011**
  
  but you can change it in the Create constructor of the ROWebServer class.
  
  
  
  ***Beta 1.0.1***

New Features:

* RouteInfo Object Context
* Asynchronous support (for concurrency requests)
* Explained routes and error description in realtime for wrong requests to the server (in JSON or SPA)
* ContentType return support
* Simple render template support
* Exception types in HTML or JSON (explains the resources in real time)
  
