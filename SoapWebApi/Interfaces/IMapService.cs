using CoreWCF;
using SoapWebApi.Models;

namespace SoapWebApi.Interfaces;

[ServiceContract(Namespace = "http://mapservice.soap.api/2024")]
public interface IMapService
{
    [OperationContract]
    MapResponse GetMapByPixelCoordinates(PixelMapRequest request);
        
    [OperationContract]
    MapResponse GetMapByGeoCoordinates(GeoMapRequest request);
        
    [OperationContract]
    string Ping();
}