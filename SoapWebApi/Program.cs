using CoreWCF;
using CoreWCF.Channels;
using CoreWCF.Configuration;
using CoreWCF.Description;
using SoapWebApi.Interfaces;
using SoapWebApi.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddServiceModelServices();
builder.Services.AddServiceModelMetadata();

builder.Services.AddScoped<MapService>();
builder.Services.AddScoped<IMapService>(provider => provider.GetRequiredService<MapService>());

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseServiceModel(serviceBuilder =>
{
    serviceBuilder.AddService<MapService>(serviceOptions =>
    {
        serviceOptions.DebugBehavior.IncludeExceptionDetailInFaults = app.Environment.IsDevelopment();
    });
    
    var basicBinding = new BasicHttpBinding(BasicHttpSecurityMode.None)
    {
        MaxReceivedMessageSize = 104857600,
        MaxBufferSize = 104857600,
        ReaderQuotas = new System.Xml.XmlDictionaryReaderQuotas
        {
            MaxArrayLength = 104857600,
            MaxStringContentLength = 104857600,
            MaxBytesPerRead = 104857600
        }
    };
    
    serviceBuilder.AddServiceEndpoint<MapService, IMapService>(
        basicBinding,
        "/MapService.svc"
    );
    
    var wsBinding = new WSHttpBinding(SecurityMode.None)
    {
        MaxReceivedMessageSize = 104857600,
        MaxBufferPoolSize = 104857600,
        ReaderQuotas = new System.Xml.XmlDictionaryReaderQuotas
        {
            MaxArrayLength = 104857600,
            MaxStringContentLength = 104857600,
            MaxBytesPerRead = 104857600
        }
    };
    
    serviceBuilder.AddServiceEndpoint<MapService, IMapService>(
        wsBinding,
        "/MapService.ws"
    );

    var serviceMetadataBehavior = app.Services.GetRequiredService<ServiceMetadataBehavior>();
    serviceMetadataBehavior.HttpGetEnabled = true;
});

app.MapGet("/", () => Results.Content(@"
    <!DOCTYPE html>
    <html>
        <head>
            <title>SOAP Map Service</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                h1 { color: #333; }
                .endpoint { background: #f4f4f4; padding: 15px; margin: 10px 0; border-radius: 5px; }
                a { color: #0066cc; text-decoration: none; }
                a:hover { text-decoration: underline; }
                .code { background: #272822; color: #f8f8f2; padding: 15px; border-radius: 5px; overflow-x: auto; }
            </style>
        </head>
        <body>
            <h1>SOAP Map Service - CoreWCF</h1>
            
            <div class='endpoint'>
                <h2>SOAP 1.1 Endpoint (BasicHttpBinding)</h2>
                <p><strong>Service:</strong> <a href='/MapService.svc'>/MapService.svc</a></p>
                <p><strong>WSDL:</strong> <a href='/MapService.svc?wsdl'>/MapService.svc?wsdl</a></p>
            </div>
            
            <div class='endpoint'>
                <h2>SOAP 1.2 Endpoint (WSHttpBinding)</h2>
                <p><strong>Service:</strong> <a href='/MapService.ws'>/MapService.ws</a></p>
                <p><strong>WSDL:</strong> <a href='/MapService.ws?wsdl'>/MapService.ws?wsdl</a></p>
            </div>
            
            <h2>Dostępne metody:</h2>
            <ul>
                <li><strong>GetMapByPixelCoordinates</strong> - Pobiera wycinek mapy na podstawie współrzędnych pikseli</li>
                <li><strong>GetMapByGeoCoordinates</strong> - Pobiera wycinek mapy na podstawie współrzędnych geograficznych</li>
                <li><strong>Ping</strong> - Testowa metoda sprawdzająca działanie usługi</li>
            </ul>
            
            <h2>Przykładowe żądanie SOAP (Ping):</h2>
            <div class='code'>
&lt;soapenv:Envelope xmlns:soapenv=""http://schemas.xmlsoap.org/soap/envelope/"" xmlns:map=""http://mapservice.soap.api/2024""&gt;
   &lt;soapenv:Header/&gt;
   &lt;soapenv:Body&gt;
      &lt;map:Ping/&gt;
   &lt;/soapenv:Body&gt;
&lt;/soapenv:Envelope&gt;
            </div>
            
            <p><em>Uwaga: Umieść obraz mapy Polski w katalogu wwwroot/images/map.png</em></p>
        </body>
    </html>
", "text/html; charset=utf-8"));

app.Run();