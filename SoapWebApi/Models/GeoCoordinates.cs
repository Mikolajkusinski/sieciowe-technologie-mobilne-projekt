using System.Runtime.Serialization;

namespace SoapWebApi.Models;

// Use the model namespace so client payload matches DataContractSerializer expectations
[DataContract(Namespace = "http://schemas.datacontract.org/2004/07/SoapWebApi.Models")]
public class GeoCoordinates
{
    [DataMember]
    public double Latitude { get; set; }
        
    [DataMember]
    public double Longitude { get; set; } 
}